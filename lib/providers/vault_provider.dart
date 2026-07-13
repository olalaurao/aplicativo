import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/obsidian_service.dart';
import '../services/markdown_parser.dart';
import '../models/shared_types.dart';
import '../models/content_object.dart';
import '../models/task_model.dart';
import '../models/shopping_list_model.dart' as shopping_list_model;
import '../models/journal_entry.dart';
import '../models/habit_model.dart';
import '../models/organizer_model.dart';
import '../models/goal_model.dart';
import '../models/kpi_model.dart';
import '../models/note_model.dart';
import '../models/tracker_model.dart';
import '../models/mood_model.dart';
import '../models/analysis_model.dart';
import '../models/wellbeing_indicator_model.dart';
import '../models/resource_model.dart';
import '../models/social_post.dart';
import '../models/people_model.dart';
import '../models/project_model.dart';
import '../models/snapshot_model.dart';
import '../models/scheduler.dart';
import '../services/kpi_engine.dart';

import '../models/template_model.dart';
import '../models/idea_model.dart';
import '../models/inbox_model.dart';
import '../models/pomodoro_session.dart';

import '../models/sync_action.dart';
import '../services/sync_queue_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../models/reminder_model.dart';
import '../providers/settings_provider.dart';
import '../models/reminder_config.dart';
import '../services/automation_service.dart';
import '../services/widget_service.dart';
import '../services/dataview_generator.dart';
import 'pomodoro_provider.dart';
import '../services/google_drive_sync_service.dart';
import 'vault_isolate.dart';

// Provider for YAML parsing errors
class YamlErrorNotifier extends StateNotifier<List<Map<String, String>>> {
  YamlErrorNotifier() : super([]);

  void setErrors(List<Map<String, String>> errors) {
    state = errors;
  }

  void clearErrors() {
    state = [];
  }
}

final _yamlErrorsProvider = StateNotifierProvider<YamlErrorNotifier, List<Map<String, String>>>((ref) {
  return YamlErrorNotifier();
});

final yamlErrorsProvider = _yamlErrorsProvider;

final obsidianServiceProvider = Provider<ObsidianService>((ref) {
  // 1.2 — Only recreate when vaultName or vaultPath change, not on every
  // settings mutation (accent colour, widget prefs, etc.).
  final vaultName = ref.watch(settingsProvider.select((s) => s.vaultName));
  final vaultPath = ref.watch(settingsProvider.select((s) => s.vaultPath));
  final service = ObsidianService();
  service.initVault(vaultName, customPath: vaultPath);
  return service;
});

String getDailyNoteTemplate(
  String dateStr,
  List<Organizer> dayThemes, {
  List<Habit> activeHabits = const [],
}) {
  const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
  final dayName = weekDayNames[parsedDate.weekday - 1];
  final activeTheme = dayThemes.cast<Organizer?>().firstWhere(
    (theme) => theme?.daysOfWeek.contains(dayName) ?? false,
    orElse: () => null,
  );
  final themeSlug = activeTheme?.id ?? '';
  // Flat habit keys in frontmatter (spec PARTE 20)
  final habitKeys = activeHabits.map((h) => '${h.slug}: false').join('\n');
  final buf = StringBuffer();
  buf.write('---\n');
  buf.write('date: $dateStr\n');
  buf.write('type: daily_note\n');
  buf.write('tags: [daily]\n');
  if (themeSlug.isNotEmpty) buf.write('day_theme: $themeSlug\n');
  if (habitKeys.isNotEmpty) buf.write('$habitKeys\n');
  buf.write('mood_entries: []\n');
  buf.write('---\n\n');
  buf.write('# $dateStr\n\n');
  buf.write('## Journal Entries\n\n');
  buf.write('## Habits\n\n');
  buf.write('## Trackers\n\n');
  buf.write('## Tasks\n\n');
  buf.write('## Pomodoros\n');
  return buf.toString();
}

Map<String, String> _habitLabelsFromRef(Ref ref) {
  return {
    for (final habit in ref.read(habitsProvider))
      habit.slug: habit.displayTitle,
  };
}

Set<String> _pactHabitSlugsFromRef(Ref ref) {
  return ref
      .read(habitsProvider)
      .where((habit) => habit.habitMode == HabitMode.pact)
      .map((habit) => habit.slug)
      .toSet();
}

class _ParsedQuickTask {
  final String title;
  final DateTime? date;
  final String? time;
  final TaskPriority priority;
  final Scheduler? scheduler;
  final String notes;

  const _ParsedQuickTask({
    required this.title,
    required this.date,
    required this.time,
    required this.priority,
    required this.scheduler,
    required this.notes,
  });
}

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService();
});

final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  return GoogleDriveSyncService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final obsidian = ref.watch(obsidianServiceProvider);
  return BackupService(obsidian);
});

final groupedObjectsProvider = Provider<Map<String, List<ContentObject>>>((
  ref,
) {
  final asyncAll = ref.watch(allObjectsProvider.select((async) => async.valueOrNull));
  final all = asyncAll ?? [];
  final map = <String, List<ContentObject>>{};
  for (final obj in all) {
    final type = obj is TrackerDefinition
        ? 'tracker_definition'
        : obj is TrackingRecord
        ? 'tracker_record'
        : obj is MoodDefinition
        ? 'mood_definition'
        : obj is CombinedAnalysis
        ? 'combined_analysis'
        : obj.type;
    map.putIfAbsent(type, () => []).add(obj);
  }
  return map;
});

final objectsByTypeProvider = Provider.family<List<ContentObject>, String>((
  ref,
  type,
) {
  final grouped = ref.watch(groupedObjectsProvider);
  return grouped[type] ?? [];
});

final conflictingObjectsProvider = Provider<Map<String, List<ContentObject>>>((
  ref,
) {
  final objects = ref.watch(allObjectsProvider.select((async) => async.valueOrNull)) ?? [];
  final byKey = <String, List<ContentObject>>{};

  for (final object in objects) {
    if (object.archived) continue;
    if (object is! Note && object is! Organizer) continue;

    final keys = {
      object.slug,
      object.title.trim().toLowerCase(),
      object.obsidianFileName.trim().toLowerCase(),
    }.where((key) => key.isNotEmpty);

    for (final key in keys) {
      byKey.putIfAbsent(key, () => []).add(object);
    }
  }

  return Map.fromEntries(
    byKey.entries.where((entry) {
      final types = entry.value.map((object) => object.type).toSet();
      return entry.value.length > 1 &&
          types.contains('note') &&
          entry.value.any((object) => object is Organizer);
    }),
  );
});

final typeConflictedObjectsProvider = Provider<List<ContentObject>>((ref) {
  final all = ref.watch(allObjectsProvider).valueOrNull ?? [];
  return all.where((obj) => obj.hasTypeConflict).toList();
});

Future<void> _cancelHabitSlotReminderNotification(
  Habit habit,
  int slotIndex,
) async {
  final baseId = _stableNotificationBaseId(habit.id);
  final reminderIndexes = habit.reminders
      .asMap()
      .entries
      .where((entry) {
        final match = RegExp(r'_slot_(\d+)(?:_|$)').firstMatch(entry.value.id);
        return int.tryParse(match?.group(1) ?? '') == slotIndex;
      })
      .map((entry) => entry.key)
      .toList();
  for (final reminderIndex in reminderIndexes) {
    await NotificationService().cancelNotification(baseId + reminderIndex);
  }
}

int _stableNotificationBaseId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return 100000 + (hash % 900000);
}

// Map to store raw daily note data for O(1) lookup
final _dailyNoteDataMapProvider =
    StateProvider<Map<String, Map<String, dynamic>>>((ref) => {});

// Lazy loader for daily notes (Journal Entries, Habits, Trackers)
// Optimized to use the map for O(1) lookup instead of filtering all objects
final dailyNoteDataProvider = Provider.family<Map<String, dynamic>, String>((
  ref,
  dateStr,
) {
  final dataMap = ref.watch(_dailyNoteDataMapProvider);
  if (dataMap.containsKey(dateStr)) {
    return dataMap[dateStr]!;
  }

  // Fallback to searching if map is empty (though AllObjectsNotifier should populate it)
  final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
  final relativePath = 'daily/$dateStr.md';

  final entries = allObjects
      .whereType<JournalEntry>()
      .where((e) => e.obsidianPath == relativePath)
      .toList();

  final trackerRecords = allObjects
      .whereType<TrackingRecord>()
      .where((r) => r.obsidianPath == relativePath)
      .toList();

  final habitCompletions = <String, dynamic>{};
  for (final habit in allObjects.whereType<Habit>()) {
    final record = habit.completionHistory
        .where((r) => r.date.toIso8601String().split('T').first == dateStr)
        .firstOrNull;
    if (record != null) {
      habitCompletions[habit.slug] =
          record.slotCompletions ?? record.completions;
    }
  }

  return {
    'entries': entries,
    'habitCompletions': habitCompletions,
    'trackerRecords': trackerRecords,
    'habits': habitCompletions,
    'trackers': trackerRecords,
    'frontmatter': {},
  };
});

class TasksNotifier extends Notifier<List<Task>> {
  @override
  List<Task> build() {
    return ref.watch(objectsByTypeProvider('task')).cast<Task>();
  }

  Future<void> addTask(Task task) async {
    state = [...state, task];
    await ref.read(vaultProvider.notifier).createObject(task);
  }

  Future<void> updateTask(Task task) async {
    final previous = state
        .where((candidate) => candidate.id == task.id)
        .firstOrNull;
    state = [
      for (final t in state)
        if (t.id == task.id) task else t,
    ];

    await ref.read(vaultProvider.notifier).updateObject(task);
    if (previous?.stage != TaskStage.finalized &&
        task.stage == TaskStage.finalized) {
      await _completeContactTaskIfNeeded(task);
    }
  }

  Future<void> deleteTask(Task task) async {
    state = state.where((t) => t.id != task.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(task);
  }

  Future<void> _completeContactTaskIfNeeded(Task task) async {
    final title = task.title.toLowerCase();
    if (!title.startsWith('contact ') && !title.startsWith('contatar ')) {
      return;
    }

    Person? person;
    final personRef = task.organizers
        .where((organizer) => organizer.type == 'person')
        .firstOrNull;
    final people = ref.read(peopleProvider);
    if (personRef != null) {
      person = people
          .where(
            (candidate) =>
                candidate.id == personRef.slug ||
                candidate.slug == personRef.slug ||
                candidate.title == personRef.title,
          )
          .firstOrNull;
    }
    person ??= people
        .where(
          (candidate) =>
              title == 'contact ${candidate.title.toLowerCase()}' ||
              title == 'contatar ${candidate.title.toLowerCase()}',
        )
        .firstOrNull;
    if (person == null) return;

    await ref
        .read(peopleProvider.notifier)
        .updatePerson(person.copyWith(lastContactDate: DateTime.now()));
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<Task>>(() {
  return TasksNotifier();
});

class ShoppingListsNotifier
    extends Notifier<List<shopping_list_model.ShoppingList>> {
  @override
  List<shopping_list_model.ShoppingList> build() {
    return ref
        .watch(objectsByTypeProvider('shopping_list'))
        .cast<shopping_list_model.ShoppingList>();
  }

  Future<void> addShoppingList(
    shopping_list_model.ShoppingList shoppingList,
  ) async {
    state = [...state, shoppingList];
    await ref.read(vaultProvider.notifier).createObject(shoppingList);
  }

  Future<void> updateShoppingList(
    shopping_list_model.ShoppingList shoppingList,
  ) async {
    state = [
      for (final item in state)
        if (item.id == shoppingList.id) shoppingList else item,
    ];
    await ref.read(vaultProvider.notifier).updateObject(shoppingList);
  }

  Future<void> deleteShoppingList(
    shopping_list_model.ShoppingList shoppingList,
  ) async {
    state = state.where((item) => item.id != shoppingList.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(shoppingList);
  }
}

final shoppingListsProvider =
    NotifierProvider<
      ShoppingListsNotifier,
      List<shopping_list_model.ShoppingList>
    >(() {
      return ShoppingListsNotifier();
    });

class HabitsNotifier extends Notifier<List<Habit>> {
  @override
  List<Habit> build() {
    final habits = ref.watch(objectsByTypeProvider('habit')).cast<Habit>();
    if (habits.isNotEmpty) {
      Future.microtask(
        () => AutomationService.checkPactExpirations(ref, habits),
      );
    }
    return habits;
  }

  Future<void> addHabit(Habit habit) async {
    state = [...state, habit];
    await ref.read(vaultProvider.notifier).createObject(habit);
  }

  Future<void> toggleHabit(Habit habit, DateTime date, {int? slotIndex}) async {
    final dateStr = date.toIso8601String().split('T').first;
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);

    try {
      final path = 'daily/$dateStr.md';
      final dayThemes = ref.read(dayThemesProvider);
      final content =
          await obsidianService.readFile(path) ??
          getDailyNoteTemplate(
            dateStr,
            dayThemes,
            activeHabits: state
                .where((h) => h.status == HabitStatus.active)
                .toList(),
          );

      final frontmatter = MarkdownParser.parseFrontmatter(content);
      final body = MarkdownParser.extractBody(content);

      final habitsMap = MarkdownParser.parseHabitCompletions(frontmatter);
      final currentVal = habitsMap[habit.slug];

      if (slotIndex != null) {
        List<dynamic> slots = [];
        if (currentVal is List) {
          slots = List.from(currentVal);
        } else if (currentVal is bool) {
          slots = [currentVal];
        } else if (currentVal is num) {
          slots = List.generate(
            habit.dailyGoal,
            (i) => i < (currentVal).toInt(),
          );
        } else if (currentVal != null) {
          // Handle unexpected types gracefully by wrapping in a list.
          slots = [currentVal];
        }

        while (slots.length <= slotIndex) {
          slots.add(false);
        }
        final nextValue = !_isTruthyCompletion(slots[slotIndex]);
        slots[slotIndex] = nextValue;
        habitsMap[habit.slug] = slots;
        if (nextValue == true) {
          await _cancelHabitSlotReminderNotification(habit, slotIndex);
          await AutomationService.executeHabitSlotActions(ref, habit, date);
        }
      } else {
        if (currentVal is bool) {
          habitsMap[habit.slug] = !currentVal;
        } else if (currentVal is num) {
          habitsMap[habit.slug] = (currentVal == 0) ? (habit.dailyGoal) : 0;
        } else if (currentVal is List) {
          final allComplete =
              currentVal.isNotEmpty && currentVal.every(_isTruthyCompletion);
          final slotCount = currentVal.isNotEmpty
              ? currentVal.length
              : habit.dailyGoal;
          habitsMap[habit.slug] = List.filled(slotCount, !allComplete);
        } else {
          habitsMap[habit.slug] = true;
        }
      }

      final updatedHabit = _updateHabitCompletionState(
        habit,
        date,
        habitsMap[habit.slug],
      );
      state = [
        for (final h in state)
          if (h.id == updatedHabit.id) updatedHabit else h,
      ];
      ref.read(allObjectsProvider.notifier).replaceObjectInMemory(updatedHabit);
      
      // Save habit's own .md file with updated completion history
      await ref.read(vaultProvider.notifier).updateObject(updatedHabit);

      // Write habit completions as flat frontmatter keys (Obsidian format)
      // Remove old nested 'habits' key if it exists
      frontmatter.remove('habits');
      habitsMap.forEach((slug, value) {
        frontmatter[slug] = value;
      });

      // Preserve all other sections.
      final entries = MarkdownParser.parseJournalEntries(body, dateStr);
      final tasks = MarkdownParser.parseTasksFromDailyNote(body);
      final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
      final pomodoros = MarkdownParser.parsePomodoros(body);

      final newBody = MarkdownParser.generateDailyNoteBody(
        entries: entries,
        tasks: tasks,
        habits: habitsMap,
        habitLabels: _habitLabelsFromRef(ref),
        pactHabitSlugs: _pactHabitSlugsFromRef(ref),
        trackers: trackers,
        pomodoros: pomodoros,
      );

      final newContent = generateMarkdown(frontmatter, newBody);
      await obsidianService.writeFile(path, newContent);

      _updateDailyNoteCache(
        dateStr: dateStr,
        habitsMap: habitsMap,
        frontmatter: frontmatter,
        trackers: trackers,
      );
      ref.read(allObjectsProvider.notifier).replaceObjectInMemory(updatedHabit);
      // ref.invalidate(objectsByTypeProvider('habit')); // Removed - replaceObjectInMemory handles it
      ref.invalidate(dailyNoteDataProvider(dateStr));

      await syncQueue.enqueueAction(
        SyncAction(
          objectType: 'daily_note',
          objectId: dateStr,
          operation: SyncOperation.update,
          payload: frontmatter,
        ),
      );

      // Update Android Widget.
      WidgetService.updateHabits(state);

      if (!_isHabitValueComplete(habit, currentVal) &&
          _isHabitValueComplete(habit, habitsMap[habit.slug])) {
        await AutomationService.executeHabitActions(ref, habit, date);
      }
    } catch (e, st) {
      debugPrint('Error toggling habit ${habit.id} on $dateStr: $e\n$st');
      rethrow;
    }
  }

  Future<void> toggleChecklistItem(
    Habit habit,
    DateTime date,
    String itemId,
  ) async {
    if (!habit.isChecklistHabit) return;
    final dateStr = date.toIso8601String().split('T').first;
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);

    try {
      final path = 'daily/$dateStr.md';
      final dayThemes = ref.read(dayThemesProvider);
      final content =
          await obsidianService.readFile(path) ??
          getDailyNoteTemplate(
            dateStr,
            dayThemes,
            activeHabits: state
                .where((h) => h.status == HabitStatus.active)
                .toList(),
          );

      final frontmatter = MarkdownParser.parseFrontmatter(content);
      final body = MarkdownParser.extractBody(content);
      final habitsMap = MarkdownParser.parseHabitCompletions(frontmatter);
      final currentVal = habitsMap[habit.slug];

      final checklistMap = currentVal is Map
          ? Map<String, dynamic>.from(currentVal)
          : <String, dynamic>{};
      checklistMap[itemId] = !(checklistMap[itemId] == true);
      habitsMap[habit.slug] = checklistMap;

      final updatedHabit = _updateHabitCompletionState(
        habit,
        date,
        checklistMap,
      );
      state = [
        for (final h in state)
          if (h.id == updatedHabit.id) updatedHabit else h,
      ];
      ref.read(allObjectsProvider.notifier).replaceObjectInMemory(updatedHabit);
      
      // Save habit's own .md file with updated completion history
      await ref.read(vaultProvider.notifier).updateObject(updatedHabit);

      frontmatter.remove('habits');
      habitsMap.forEach((slug, value) {
        frontmatter[slug] = value;
      });

      final entries = MarkdownParser.parseJournalEntries(body, dateStr);
      final tasks = MarkdownParser.parseTasksFromDailyNote(body);
      final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
      final pomodoros = MarkdownParser.parsePomodoros(body);

      final newBody = MarkdownParser.generateDailyNoteBody(
        entries: entries,
        tasks: tasks,
        habits: habitsMap,
        habitLabels: _habitLabelsFromRef(ref),
        pactHabitSlugs: _pactHabitSlugsFromRef(ref),
        trackers: trackers,
        pomodoros: pomodoros,
      );

      final newContent = generateMarkdown(frontmatter, newBody);
      await obsidianService.writeFile(path, newContent);

      _updateDailyNoteCache(
        dateStr: dateStr,
        habitsMap: habitsMap,
        frontmatter: frontmatter,
        trackers: trackers,
      );
      // ref.invalidate(objectsByTypeProvider('habit')); // Removed - replaceObjectInMemory handles it
      ref.invalidate(dailyNoteDataProvider(dateStr));

      await syncQueue.enqueueAction(
        SyncAction(
          objectType: 'daily_note',
          objectId: dateStr,
          operation: SyncOperation.update,
          payload: frontmatter,
        ),
      );
      WidgetService.updateHabits(state);
    } catch (e, st) {
      debugPrint(
        'Error toggling checklist item $itemId for ${habit.id} on $dateStr: $e\n$st',
      );
      rethrow;
    }
  }

  bool _isTruthyCompletion(dynamic value) {
    return value == true || (value is num && value > 0);
  }

  bool _isHabitValueComplete(Habit habit, dynamic value) {
    if (value is bool) return value;
    if (value is num) return value >= habit.dailyGoal;
    if (value is List) {
      return value.every(_isTruthyCompletion) &&
          value.length >= habit.dailyGoal;
    }
    return false;
  }

  CompletionRecord _completionRecordFromValue(
    Habit habit,
    DateTime date,
    dynamic value,
  ) {
    int count = 0;
    List<bool>? slotCompletions;

    if (value is bool) {
      count = value ? habit.dailyGoal : 0;
      slotCompletions = List.filled(habit.dailyGoal, value);
    } else if (value is num) {
      count = value.toInt();
      slotCompletions = List.generate(habit.dailyGoal, (i) => i < count);
    } else if (value is List) {
      slotCompletions = value.map(_isTruthyCompletion).toList();
      count = slotCompletions.where((completed) => completed).length;
    }

    return CompletionRecord(
      date: DateTime(date.year, date.month, date.day),
      completions: count,
      slotCompletions: slotCompletions,
      successful: count >= habit.dailyGoal,
      completedAt: DateTime.now(),
    );
  }

  Habit _updateHabitCompletionState(Habit habit, DateTime date, dynamic value) {
    final dateStr = date.toIso8601String().split('T').first;
    final history = habit.completionHistory
        .where(
          (record) => record.date.toIso8601String().split('T').first != dateStr,
        )
        .toList();

    history.add(_completionRecordFromValue(habit, date, value));
    history.sort((a, b) => a.date.compareTo(b.date));

    final updatedHabit = habit.copyWith(completionHistory: history);
    updatedHabit.calculateStreak();
    return updatedHabit;
  }

  void _updateDailyNoteCache({
    required String dateStr,
    required Map<String, dynamic> habitsMap,
    required Map<String, dynamic> frontmatter,
    required Map<String, dynamic> trackers,
  }) {
    final notifier = ref.read(_dailyNoteDataMapProvider.notifier);
    final current = notifier.state;
    final existing = current[dateStr] ?? const <String, dynamic>{};

    notifier.state = {
      ...current,
      dateStr: {
        ...existing,
        'entries': existing['entries'] ?? const <JournalEntry>[],
        'habitCompletions': Map<String, dynamic>.from(habitsMap),
        'habits': Map<String, dynamic>.from(habitsMap),
        'trackerRecords': existing['trackerRecords'] ?? trackers,
        'frontmatter': frontmatter,
      },
    };
  }

  Future<void> deleteHabit(Habit habit) async {
    state = state.where((h) => h.id != habit.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(habit);
  }

  Future<void> recordHabitValue(
    Habit habit,
    DateTime date,
    double value, {
    int? slotIndex,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);

    final path = 'daily/$dateStr.md';
    final dayThemes = ref.read(dayThemesProvider);
    final content =
        await obsidianService.readFile(path) ??
        getDailyNoteTemplate(
          dateStr,
          dayThemes,
          activeHabits: state
              .where((h) => h.status == HabitStatus.active)
              .toList(),
        );

    final frontmatter = MarkdownParser.parseFrontmatter(content);
    final body = MarkdownParser.extractBody(content);

    final habitsMap = MarkdownParser.parseHabitCompletions(frontmatter);

    if (slotIndex != null) {
      List<dynamic> slots = [];
      if (habitsMap[habit.slug] is List) {
        slots = List.from(habitsMap[habit.slug]);
      } else if (habitsMap[habit.slug] != null) {
        slots = [habitsMap[habit.slug]];
      }

      while (slots.length <= slotIndex) {
        slots.add(0);
      }
      slots[slotIndex] = value;
      habitsMap[habit.slug] = slots;
    } else {
      habitsMap[habit.slug] = value;
    }

    // Update habit's completion history and save its .md file
    final updatedHabit = _updateHabitCompletionState(habit, date, habitsMap[habit.slug]);
    state = [
      for (final h in state)
        if (h.id == updatedHabit.id) updatedHabit else h,
    ];
    await ref.read(vaultProvider.notifier).updateObject(updatedHabit);

    // Write habit completions as flat frontmatter keys (Obsidian format)
    frontmatter.remove('habits');
    habitsMap.forEach((slug, value) {
      frontmatter[slug] = value;
    });

    final entries = MarkdownParser.parseJournalEntries(body, dateStr);
    final tasks = MarkdownParser.parseTasksFromDailyNote(body);
    final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
    final pomodoros = MarkdownParser.parsePomodoros(body);

    final newBody = MarkdownParser.generateDailyNoteBody(
      entries: entries,
      tasks: tasks,
      habits: habitsMap,
      habitLabels: _habitLabelsFromRef(ref),
      pactHabitSlugs: _pactHabitSlugsFromRef(ref),
      trackers: trackers,
      pomodoros: pomodoros,
    );

    final newContent = generateMarkdown(frontmatter, newBody);
    await obsidianService.writeFile(path, newContent);

    // ref.invalidate(allObjectsProvider); // Removed - replaceObjectInMemory handles it
    ref.invalidate(dailyNoteDataProvider(dateStr));

    await syncQueue.enqueueAction(
      SyncAction(
        objectType: 'daily_note',
        objectId: dateStr,
        operation: SyncOperation.update,
        payload: frontmatter,
      ),
    );
  }

  Future<void> updateHabit(Habit updatedHabit) async {
    // Update local state first to reflect change immediately
    state = [
      for (final h in state)
        if (h.id == updatedHabit.id) updatedHabit else h,
    ];
    await ref.read(vaultProvider.notifier).updateObject(updatedHabit);
  }
}

final habitsProvider = NotifierProvider<HabitsNotifier, List<Habit>>(() {
  return HabitsNotifier();
});

class OrganizersNotifier extends Notifier<List<Organizer>> {
  @override
  List<Organizer> build() {
    final areas = ref
        .watch(objectsByTypeProvider('area'))
        .cast<Organizer>();
    final projects = ref
        .watch(objectsByTypeProvider('project'))
        .cast<Organizer>();
    final activities = ref
        .watch(objectsByTypeProvider('activity'))
        .cast<Organizer>();
    final people = ref
        .watch(objectsByTypeProvider('person'))
        .cast<Organizer>();
    final labels = ref
        .watch(objectsByTypeProvider('label'))
        .cast<Organizer>();
    final dayThemes = ref
        .watch(objectsByTypeProvider('dayTheme'))
        .cast<Organizer>();
    final timeBlocks = ref
        .watch(objectsByTypeProvider('timeBlock'))
        .cast<Organizer>();

    return [...areas, ...projects, ...activities, ...people, ...labels, ...dayThemes, ...timeBlocks];
  }

  Future<void> addOrganizer(Organizer organizer) async {
    state = [...state, organizer];
    if (!organizer.categories.contains('[[organizers]]')) {
      organizer.categories.add('[[organizers]]');
    }
    await ref.read(vaultProvider.notifier).createObject(organizer);
  }

  Future<void> updateOrganizer(Organizer organizer) async {
    state = [
      for (final o in state)
        if (o.id == organizer.id) organizer else o,
    ];
    await ref.read(vaultProvider.notifier).updateObject(organizer);
  }

  Future<void> deleteOrganizer(Organizer organizer) async {
    state = state.where((o) => o.id != organizer.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(organizer);
  }
}

final organizersProvider =
    NotifierProvider<OrganizersNotifier, List<Organizer>>(() {
      return OrganizersNotifier();
    });

class TrackersNotifier extends Notifier<List<TrackerDefinition>> {
  @override
  List<TrackerDefinition> build() {
    return ref
        .watch(objectsByTypeProvider('tracker_definition'))
        .cast<TrackerDefinition>();
  }

  Future<void> addTracker(TrackerDefinition tracker) async {
    state = [...state, tracker];
    if (!tracker.categories.contains('[[trackers]]')) {
      tracker.categories.add('[[trackers]]');
    }
    await ref.read(vaultProvider.notifier).createObject(tracker);
  }

  Future<void> updateTracker(TrackerDefinition tracker) async {
    state = [
      for (final t in state)
        if (t.id == tracker.id) tracker else t,
    ];
    await ref.read(vaultProvider.notifier).updateObject(tracker);
  }

  Future<void> deleteTracker(TrackerDefinition tracker) async {
    state = state.where((t) => t.id != tracker.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(tracker);
  }
}

final trackersProvider =
    NotifierProvider<TrackersNotifier, List<TrackerDefinition>>(() {
      return TrackersNotifier();
    });

Future<void> saveTrackerRecord(
  WidgetRef ref,
  TrackerDefinition tracker,
  DateTime date,
  Map<String, dynamic> values,
) async {
  final timestamp = date.toIso8601String();
  final record = TrackingRecord(
    title: '${tracker.title} $timestamp',
    trackerId: tracker.id,
    date: date,
    fieldValues: Map<String, dynamic>.from(values),
    organizers: tracker.organizers,
    categories: const ['[[tracker_records]]'],
  );
  await ref.read(trackingRecordsProvider.notifier).addRecord(record);
  await AutomationService.executeTrackerActions(ref, tracker, record);
}

class ProjectsNotifier extends Notifier<List<Project>> {
  @override
  List<Project> build() {
    return ref.watch(objectsByTypeProvider('project')).cast<Project>();
  }

  Future<void> addProject(Project project) async {
    state = [...state, project];
    await ref.read(vaultProvider.notifier).createObject(project);
  }

  Future<void> updateProject(Project project) async {
    state = [
      for (final p in state)
        if (p.id == project.id) project else p,
    ];
    await ref.read(vaultProvider.notifier).updateObject(project);
  }

  Future<void> deleteProject(Project project) async {
    state = state.where((p) => p.id != project.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(project);
  }
}

final projectsProvider = NotifierProvider<ProjectsNotifier, List<Project>>(
  () => ProjectsNotifier(),
);

class PeopleNotifier extends Notifier<List<Person>> {
  @override
  List<Person> build() {
    // 1.4 — Side-effect removed from build(); contact check is now triggered
    // from the AppLifecycleListener.onResume in main.dart.
    return ref.watch(objectsByTypeProvider('person')).cast<Person>();
  }

  /// Trigger contact birthday/anniversary check. Called from lifecycle events.
  Future<void> checkPersonContactsNow() {
    final people = state;
    if (people.isEmpty) return Future.value();
    return AutomationService.checkPersonContacts(ref, people);
  }

  Future<void> addPerson(Person person) async {
    state = [...state, person];
    await ref.read(vaultProvider.notifier).createObject(person);
  }

  Future<void> updatePerson(Person person) async {
    state = [
      for (final p in state)
        if (p.id == person.id) person else p,
    ];
    await ref.read(vaultProvider.notifier).updateObject(person);
  }

  Future<void> deletePerson(Person person) async {
    state = state.where((p) => p.id != person.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(person);
  }
}

final peopleProvider = NotifierProvider<PeopleNotifier, List<Person>>(
  () => PeopleNotifier(),
);

class SnapshotsNotifier extends Notifier<List<Snapshot>> {
  @override
  List<Snapshot> build() {
    return ref.watch(objectsByTypeProvider('snapshot')).cast<Snapshot>();
  }

  Future<void> addSnapshot(Snapshot snapshot) async {
    state = [...state, snapshot];
    if (!snapshot.categories.contains('[[snapshots]]')) {
      snapshot.categories.add('[[snapshots]]');
    }
    await ref.read(vaultProvider.notifier).createObject(snapshot);
  }

  Future<void> updateSnapshot(Snapshot snapshot) async {
    state = [
      for (final s in state)
        if (s.id == snapshot.id) snapshot else s,
    ];
    await ref.read(vaultProvider.notifier).updateObject(snapshot);
  }

  Future<void> deleteSnapshot(Snapshot snapshot) async {
    state = state.where((s) => s.id != snapshot.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(snapshot);
  }
}

final snapshotsProvider = NotifierProvider<SnapshotsNotifier, List<Snapshot>>(
  () => SnapshotsNotifier(),
);

class ResourcesNotifier extends Notifier<List<Resource>> {
  @override
  List<Resource> build() {
    return ref.watch(objectsByTypeProvider('resource')).cast<Resource>();
  }

  Future<void> addResource(Resource resource) async {
    state = [...state, resource];
    await ref.read(vaultProvider.notifier).createObject(resource);
  }

  Future<void> deleteResource(Resource resource) async {
    state = state.where((r) => r.id != resource.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(resource);
  }

  Future<void> updateResource(Resource resource) async {
    state = [
      for (final r in state)
        if (r.id == resource.id) resource else r,
    ];
    await ref.read(vaultProvider.notifier).updateObject(resource);
  }
}

final resourcesProvider = NotifierProvider<ResourcesNotifier, List<Resource>>(
  () => ResourcesNotifier(),
);

class SocialPostsNotifier extends Notifier<List<SocialPost>> {
  @override
  List<SocialPost> build() {
    return ref.watch(objectsByTypeProvider('social_post')).cast<SocialPost>();
  }

  Future<void> addPost(SocialPost post) async {
    state = [...state, post];
    await ref.read(vaultProvider.notifier).createObject(post);
  }

  Future<void> updatePost(SocialPost post) async {
    state = [
      for (final item in state)
        if (item.id == post.id) post else item,
    ];
    await ref.read(vaultProvider.notifier).updateObject(post);
  }

  Future<void> deletePost(SocialPost post) async {
    state = state.where((item) => item.id != post.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(post);
  }

  Future<void> toggleWatched(SocialPost post) async {
    await updatePost(post.copyWith(watched: !post.watched));
  }
}

final socialPostsProvider =
    NotifierProvider<SocialPostsNotifier, List<SocialPost>>(
      () => SocialPostsNotifier(),
    );

class GoalsNotifier extends Notifier<List<Goal>> {
  @override
  List<Goal> build() {
    return ref.watch(objectsByTypeProvider('goal')).cast<Goal>();
  }

  Future<void> addGoal(Goal goal) async {
    state = [...state, goal];
    await ref.read(vaultProvider.notifier).createObject(goal);
  }

  Future<void> updateGoal(Goal goal) async {
    // Update KPI values before persisting
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final updatedKpis = List<KPI>.from(goal.kpis);
    KPIEngine.updateKPIValues(
      kpis: updatedKpis,
      habits: allObjects.whereType<Habit>().toList(),
      trackerRecords: allObjects.whereType<TrackingRecord>().toList(),
      entries: allObjects.whereType<JournalEntry>().toList(),
      moods: allObjects.whereType<MoodDefinition>().toList(),
      notes: allObjects.whereType<Note>().toList(),
      tasks: allObjects.whereType<Task>().toList(),
    );
    final updatedGoal = goal.copyWith(kpis: updatedKpis);
    
    state = [
      for (final g in state)
        if (g.id == goal.id) updatedGoal else g,
    ];
    await ref.read(vaultProvider.notifier).updateObject(updatedGoal);
  }

  Future<void> deleteGoal(Goal goal) async {
    state = state.where((g) => g.id != goal.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(goal);
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, List<Goal>>(() {
  return GoalsNotifier();
});

class NotesNotifier extends Notifier<List<Note>> {
  @override
  List<Note> build() {
    return ref.watch(objectsByTypeProvider('note')).cast<Note>();
  }

  Future<void> addNote(Note note) async {
    state = [...state, note];
    await ref.read(vaultProvider.notifier).createObject(note);
  }

  Future<void> updateNote(Note note) async {
    state = [
      for (final n in state)
        if (n.id == note.id) note else n,
    ];
    await ref.read(vaultProvider.notifier).updateObject(note);
  }

  Future<void> deleteNote(Note note) async {
    state = state.where((n) => n.id != note.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(note);
  }
}

final notesProvider = NotifierProvider<NotesNotifier, List<Note>>(() {
  return NotesNotifier();
});

class IdeasNotifier extends Notifier<List<IdeaDefinition>> {
  @override
  List<IdeaDefinition> build() {
    return ref.watch(objectsByTypeProvider('idea')).cast<IdeaDefinition>();
  }

  Future<void> addIdea(IdeaDefinition idea) async {
    state = [...state, idea];
    await ref.read(vaultProvider.notifier).createObject(idea);
  }

  Future<void> updateIdea(IdeaDefinition idea) async {
    state = [
      for (final item in state)
        if (item.id == idea.id) idea else item,
    ];
    await ref.read(vaultProvider.notifier).updateObject(idea);
  }

  Future<void> deleteIdea(IdeaDefinition idea) async {
    state = state.where((item) => item.id != idea.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(idea);
  }
}

final ideasProvider = NotifierProvider<IdeasNotifier, List<IdeaDefinition>>(() {
  return IdeasNotifier();
});

class RemindersNotifier extends Notifier<List<Reminder>> {
  @override
  List<Reminder> build() {
    return ref.watch(objectsByTypeProvider('reminder')).cast<Reminder>();
  }

  Future<void> addReminder(Reminder reminder) async {
    state = [...state, reminder];
    await ref.read(vaultProvider.notifier).createObject(reminder);
  }

  Future<void> updateReminder(Reminder reminder) async {
    state = [
      for (final r in state)
        if (r.id == reminder.id) reminder else r,
    ];
    await ref.read(vaultProvider.notifier).updateObject(reminder);
  }
}

final remindersProvider = NotifierProvider<RemindersNotifier, List<Reminder>>(
  () {
    return RemindersNotifier();
  },
);

final aggregatedRemindersProvider = Provider.autoDispose<List<Reminder>>((ref) {
  final asyncAll = ref.watch(allObjectsProvider.select((async) => async.valueOrNull));
  final all = asyncAll ?? [];
  final List<Reminder> results = [];

  for (final obj in all) {
    if (obj is Reminder) {
      results.add(obj);
    } else if (obj.reminders.isNotEmpty) {
      final base = obj.baseTime ?? obj.createdAt;
      for (final config in obj.reminders) {
        final time = config.calculateTriggerTime(base);
        results.add(
          Reminder(
            id: '${obj.id}_${config.id}',
            title: obj.title,
            time: time,
            isCompleted: (obj is Task) ? obj.isCompleted : false,
            notes: 'Linked to ${obj.type}: ${obj.title}',
          )..obsidianPath = obj.obsidianPath,
        );
      }
    }
  }

  return results;
});

final organizerListProvider = Provider<List<OrganizerReference>>((ref) {
  final asyncValue = ref.watch(allObjectsProvider);
  final data = asyncValue.valueOrNull;
  if (data != null) {
    return data
        .whereType<Organizer>()
        .map(
          (o) => OrganizerReference(
            type: o.organizerType.name,
            slug: o.id,
            title: o.title,
            icon: o.icon,
            color: o.color,
          ),
        )
        .toList();
  }
  return [];
});

class TrackingRecordsNotifier extends Notifier<List<TrackingRecord>> {
  @override
  List<TrackingRecord> build() {
    final asyncValue = ref.watch(allObjectsProvider);
    final data = asyncValue.valueOrNull;

    if (data != null) {
      return data.whereType<TrackingRecord>().toList();
    }

    return [];
  }

  Future<void> addRecord(TrackingRecord record) async {
    state = [...state, record];
    await ref.read(vaultProvider.notifier).createObject(record);
  }
}

final trackingRecordsProvider =
    NotifierProvider<TrackingRecordsNotifier, List<TrackingRecord>>(() {
      return TrackingRecordsNotifier();
    });

class MoodsNotifier extends Notifier<List<MoodDefinition>> {
  bool _isSeedingSystemMoods = false;

  @override
  List<MoodDefinition> build() {
    final asyncValue = ref.watch(allObjectsProvider);
    final data = asyncValue.valueOrNull;

    if (data != null) {
      final moods = data.whereType<MoodDefinition>().toList()
        ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
      final shouldSeed =
          moods.isEmpty ||
          !moods.any((mood) => mood.source == MoodSource.system);
      if (shouldSeed && !_isSeedingSystemMoods) {
        Future.microtask(seedSystemMoods);
      }
      return moods;
    }

    return [];
  }

  Future<void> seedSystemMoods() async {
    if (_isSeedingSystemMoods) return;
    _isSeedingSystemMoods = true;
    try {
      final obsidian = ref.read(obsidianServiceProvider);
      for (final mood in MoodDefinition.systemMoods) {
        final path = 'moods/${mood.id}.md';
        final exists = await obsidian.fileExists(path);
        if (!exists) {
          await obsidian.writeFile(path, mood.toMarkdown());
        }
      }
      ref.invalidate(allObjectsProvider);
    } catch (e) {
      debugPrint('Error seeding system moods: $e');
    } finally {
      _isSeedingSystemMoods = false;
    }
  }

  Future<void> addMood(MoodDefinition mood) async {
    state = [...state, mood];
    await ref.read(vaultProvider.notifier).createObject(mood);
  }

  Future<void> ensureMoodFileExists(String moodId) async {
    final mood = state.firstWhere(
      (m) => m.id == moodId,
      orElse: () => MoodDefinition.systemMoods.firstWhere(
        (m) => m.id == moodId,
        orElse: () => MoodDefinition(
          id: moodId,
          label: moodId,
          emoji: '😐',
          color: '#9E9E9E',
        ),
      ),
    );
    final obsidian = ref.read(obsidianServiceProvider);
    final path = 'moods/${mood.id}.md';
    if (await obsidian.fileExists(path)) return;
    await obsidian.writeFile(path, mood.toMarkdown());
    if (!state.any((m) => m.id == mood.id)) {
      state = [...state, mood];
    }
  }

  Future<void> updateMood(MoodDefinition mood) async {
    state = [
      for (final m in state)
        if (m.id == mood.id) mood else m,
    ]..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    await ref.read(vaultProvider.notifier).updateObject(mood);
  }

  Future<void> deleteMood(MoodDefinition mood) async {
    state = state.where((m) => m.id != mood.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(mood);
  }
}

final moodsProvider = NotifierProvider<MoodsNotifier, List<MoodDefinition>>(() {
  return MoodsNotifier();
});

class CombinedAnalysisNotifier extends Notifier<List<CombinedAnalysis>> {
  @override
  List<CombinedAnalysis> build() {
    final asyncValue = ref.watch(allObjectsProvider);
    final data = asyncValue.valueOrNull;

    if (data != null) {
      return data.whereType<CombinedAnalysis>().toList();
    }

    return [];
  }

  Future<void> addAnalysis(CombinedAnalysis analysis) async {
    await ref.read(vaultProvider.notifier).createObject(analysis);
    state = [...state, analysis];
  }

  Future<void> updateAnalysis(CombinedAnalysis analysis) async {
    await ref.read(vaultProvider.notifier).updateObject(analysis);
    state = [
      for (final a in state)
        if (a.id == analysis.id) analysis else a,
    ];
  }

  Future<void> deleteAnalysis(CombinedAnalysis analysis) async {
    state = state.where((a) => a.id != analysis.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(analysis);
  }
}

final combinedAnalysisProvider =
    NotifierProvider<CombinedAnalysisNotifier, List<CombinedAnalysis>>(() {
      return CombinedAnalysisNotifier();
    });

final analysesProvider = combinedAnalysisProvider;

class TimeBlocksNotifier extends Notifier<List<Organizer>> {
  @override
  List<Organizer> build() {
    return ref.watch(objectsByTypeProvider('timeBlock')).cast<Organizer>();
  }

  Future<void> addTimeBlock(Organizer timeBlock) async {
    state = [...state, timeBlock];
    await ref.read(vaultProvider.notifier).createObject(timeBlock);
  }

  Future<void> updateTimeBlock(Organizer timeBlock) async {
    state = [
      for (final t in state)
        if (t.id == timeBlock.id) timeBlock else t,
    ];
    await ref.read(vaultProvider.notifier).updateObject(timeBlock);
  }

  Future<void> deleteTimeBlock(Organizer timeBlock) async {
    state = state.where((t) => t.id != timeBlock.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(timeBlock);
  }
}

final timeBlocksProvider =
    NotifierProvider<TimeBlocksNotifier, List<Organizer>>(() {
      return TimeBlocksNotifier();
    });

class DayThemesNotifier extends Notifier<List<Organizer>> {
  @override
  List<Organizer> build() {
    return ref.watch(objectsByTypeProvider('dayTheme')).cast<Organizer>();
  }

  Future<void> addDayTheme(Organizer dayTheme) async {
    state = [...state, dayTheme];
    await ref.read(vaultProvider.notifier).createObject(dayTheme);
  }

  Future<void> updateDayTheme(Organizer dayTheme) async {
    state = [
      for (final d in state)
        if (d.id == dayTheme.id) dayTheme else d,
    ];
    await ref.read(vaultProvider.notifier).updateObject(dayTheme);
  }

  Future<void> deleteDayTheme(Organizer dayTheme) async {
    state = state.where((d) => d.id != dayTheme.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(dayTheme);
  }
}

final dayThemesProvider = NotifierProvider<DayThemesNotifier, List<Organizer>>(
  () {
    return DayThemesNotifier();
  },
);

class TemplatesNotifier extends Notifier<List<TemplateDefinition>> {
  // 2.4 — guard flag: seed only once per app session.
  bool _seeded = false;

  @override
  List<TemplateDefinition> build() {
    final list = ref
        .watch(objectsByTypeProvider('template'))
        .cast<TemplateDefinition>();
    if (list.isEmpty && !_seeded) {
      _seeded = true;
      Future.microtask(() => _seedDefaultTemplates());
    }
    return list;
  }

  Future<void> _seedDefaultTemplates() async {
    final allObjects = await ref.read(allObjectsProvider.future);
    final templates = allObjects.whereType<TemplateDefinition>();
    if (templates.isNotEmpty) return;

    final defaultTemplates = [
      TemplateDefinition.create(
        title: 'Reunião 1:1',
        templateType: 'entry',
        body:
            '# Reunião 1:1\n\n## Assunto\n\n## Decisões\n- \n\n## Próximos passos\n- [ ] \n',
      ),
      TemplateDefinition.create(
        title: 'Weekly Review',
        templateType: 'entry',
        body:
            '# Revisão Semanal\n\n## Conquistas da Semana\n- \n\n## O que não funcionou\n- \n\n## Hábitos e Métricas\n- [ ] Meditação\n- [ ] Exercícios\n- [ ] Água\n\n## Planejamento para a Próxima Semana\n- \n',
      ),
      TemplateDefinition.create(
        title: 'Leitura',
        templateType: 'note',
        body:
            '# Ficha de Leitura\n\n## Resumo do Livro\n\n## Principais Aprendizados\n1. \n2. \n3. \n\n## Citações Favoritas\n> \n\n## Ações práticas a implementar\n- [ ] \n',
      ),
      TemplateDefinition.create(
        title: 'Sprint Planning',
        templateType: 'entry',
        body:
            '# Sprint Planning\n\n## Goals\n- [ ] \n\n## Tasks\n- [ ] \n\n## Capacidade\n\n## Riscos e Impedimentos\n',
      ),
      TemplateDefinition.create(
        title: 'Projeto novo',
        templateType: 'goal',
        body:
            '# Projeto novo\n\n## Objetivo\n\n## KPIs\n- \n\n## Timeline\n- Fase 1: \n- Fase 2: \n\n## Riscos\n- \n',
      ),
    ];

    for (final template in defaultTemplates) {
      await addTemplate(template);
    }
  }

  Future<void> addTemplate(TemplateDefinition template) async {
    state = [...state, template];
    await ref.read(vaultProvider.notifier).createObject(template);
  }

  Future<void> updateTemplate(TemplateDefinition template) async {
    state = [
      for (final t in state)
        if (t.id == template.id) template else t,
    ];
    await ref.read(vaultProvider.notifier).updateObject(template);
  }

  Future<void> deleteTemplate(TemplateDefinition template) async {
    state = state.where((t) => t.id != template.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(template);
  }
}

final templatesProvider =
    NotifierProvider<TemplatesNotifier, List<TemplateDefinition>>(() {
      return TemplatesNotifier();
    });

final allEntriesProvider = Provider<List<JournalEntry>>((ref) {
  final asyncValue = ref.watch(allObjectsProvider);
  final data = asyncValue.valueOrNull;

  if (data != null) {
    return data.whereType<JournalEntry>().toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  return [];
});

final pmnByReferencedDateProvider = Provider<Map<String, List<JournalEntry>>>((
  ref,
) {
  final all = ref.watch(allObjectsProvider).valueOrNull ?? [];
  final map = <String, List<JournalEntry>>{};
  for (final entry in all.whereType<JournalEntry>()) {
    if (entry.entryType != JournalEntryType.pmn) continue;
    for (final date in entry.referencedDates) {
      final dateStr = date.toIso8601String().split('T').first;
      map.putIfAbsent(dateStr, () => []).add(entry);
    }
  }
  return map;
});

DateTime _journalEntryDateFromDaily(String dateStr, String? time) {
  final base = DateTime.tryParse(dateStr) ?? DateTime.now();
  final timeParts = (time ?? '').split(':');
  final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
  final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;

  return DateTime(base.year, base.month, base.day, hour, minute);
}

class AllObjectsNotifier extends AsyncNotifier<List<ContentObject>> {
  @override
  Future<List<ContentObject>> build() async {
    final service = ref.watch(obsidianServiceProvider);
    final settings = ref.watch(settingsProvider);

    // 1. Run migrations on the main thread that require SharedPreferences/platform channels.
    // migrateDailyHabitCompletions uses SharedPreferences, so we keep it here.
    await service.migrateDailyHabitCompletions(
      ref.read(sharedPreferencesProvider),
    );

    // 2. Offload listing, reading, parsing and post-processing to the background isolate.
    final parsedVault = await parseVaultInIsolate(
      VaultIsolateParams(
        vaultName: settings.vaultName,
        vaultPath: service.vaultPath, // Use the resolved absolute vault path!
        folderPaths: settings.folderPaths,
        typeSignatures: settings.typeSignatures,
        dailyNoteFolder: settings.dailyNoteFolder,
        dailyNoteIdentifier: settings.dailyNoteIdentifier,
        dailyNoteDateFormat: settings.dailyNoteDateFormat,
      ),
    );

    // 3. Display user-friendly error messages for YAML parsing errors
    if (parsedVault.yamlErrors.isNotEmpty) {
      // Store errors in a provider for UI display
      ref.read(_yamlErrorsProvider.notifier).setErrors(parsedVault.yamlErrors);
      
      for (final error in parsedVault.yamlErrors) {
        final filePath = error['file'] ?? 'unknown file';
        final errorMessage = error['error'] ?? 'Unknown error';
        debugPrint('[YAML Error] File: $filePath, Error: $errorMessage');
      }
    } else {
      // Clear errors if none
      ref.read(_yamlErrorsProvider.notifier).clearErrors();
    }

    // 4. Write repaired YAML files on the main thread (asynchronously via microtask)
    for (final relativePath in parsedVault.needsRewritePaths) {
      final obj = parsedVault.objects.firstWhere(
        (o) => o.obsidianPath == relativePath,
      );
      Future.microtask(() async {
        try {
          await service.writeFile(relativePath, obj.toMarkdown());
          debugPrint('[Vault] Rewrote repaired YAML: $relativePath');
        } catch (e) {
          debugPrint('[Vault] Failed to rewrite repaired YAML: $e');
        }
      });
    }

    // 4. Update the daily data map on the main thread (asynchronously via microtask)
    Future.microtask(() {
      ref.read(_dailyNoteDataMapProvider.notifier).state = parsedVault.dailyMap;
    });

    return parsedVault.objects;
  }

  Future<void> updateObject(ContentObject object) async {
    final service = ref.read(obsidianServiceProvider);
    object.updatedAt = DateTime.now();
    await service.writeFile(object.obsidianPath, object.toMarkdown());
    ref.invalidateSelf();
  }

  void replaceObjectInMemory(ContentObject object) {
    final objects = state.valueOrNull;
    if (objects == null) return;

    var replaced = false;
    final updated = <ContentObject>[];
    for (final current in objects) {
      if (current.id == object.id) {
        updated.add(object);
        replaced = true;
      } else {
        updated.add(current);
      }
    }

    if (!replaced) updated.add(object);
    state = AsyncData(updated);
  }
}

final allObjectsProvider =
    AsyncNotifierProvider<AllObjectsNotifier, List<ContentObject>>(() {
      return AllObjectsNotifier();
    });

final backlinksProvider = FutureProvider.family<List<ContentObject>, String>((
  ref,
  targetId,
) async {
  final allObjects = await ref.watch(allObjectsProvider.future);
  final target = allObjects.firstWhere(
    (obj) => obj.id == targetId,
    orElse: () => throw Exception('Target not found'),
  );
  final targetSlug = target.slug;
  final targetKeys =
      <String>{
            target.id,
            targetSlug,
            target.title,
            target.obsidianFileName,
            if (target.obsidianPath.isNotEmpty)
              target.obsidianPath.replaceAll(RegExp(r'\.md$'), ''),
          }
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet();

  return allObjects.where((obj) {
    if (obj.id == targetId) return false;
    if (target is MoodDefinition && obj is JournalEntry) {
      final moodSlug = obj.moodSlug?.trim().toLowerCase();
      if (moodSlug != null && targetKeys.contains(moodSlug)) return true;
    }
    if (obj.organizers.any(
      (ref) => ref.slug == targetId || ref.slug == targetSlug,
    )) {
      return true;
    }
    final content = obj.toMarkdown().toLowerCase();
    return targetKeys.any(
      (key) =>
          content.contains('[[$key]]') ||
          content.contains('[[$key|') ||
          content.contains('[[moods/$key]]') ||
          content.contains('[[moods/$key|'),
    );
  }).toList();
});

class JournalNotifier extends Notifier<List<JournalEntry>> {
  @override
  List<JournalEntry> build() {
    final today = DateTime.now();
    final dateStr = today.toIso8601String().split('T').first;
    final data = ref.watch(dailyNoteDataProvider(dateStr));
    final entriesList = data['entries'] as List?;

    if (entriesList != null) {
      return entriesList.cast<JournalEntry>();
    }

    return [];
  }

  String _entryTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _entryTimeFor(JournalEntry entry) {
    final explicitTime = entry.timeOfDay?.trim();
    if (explicitTime != null &&
        RegExp(r'^\d{1,2}:\d{2}$').hasMatch(explicitTime)) {
      final parts = explicitTime.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour < 24 &&
          minute >= 0 &&
          minute < 60) {
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    }
    return _entryTime(entry.date);
  }

  bool _isImplicitTimeTitle(String title, String time) {
    final trimmed = title.trim();
    return trimmed.isEmpty || trimmed == time;
  }

  String _storedTitleForEntry(JournalEntry entry) {
    final time = _entryTimeFor(entry);
    final title = entry.title.trim();
    return _isImplicitTimeTitle(title, time) ? '' : title;
  }

  Map<String, dynamic> _dailyMapForEntry(JournalEntry entry, String dateStr) {
    final time = _entryTimeFor(entry);
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? entry.date.hour;
    final minute = int.tryParse(parts[1]) ?? entry.date.minute;
    return {
      'time': time,
      'title': _storedTitleForEntry(entry),
      'body': entry.body,
      'mood': entry.moodSlug,
      'organizers': entry.organizers,
      'date': DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
        hour,
        minute,
      ).toIso8601String(),
      if (entry.entryType != JournalEntryType.standard)
        'entry_type': JournalEntry.entryTypeToString(entry.entryType),
      if (entry.category != null) 'category': entry.category,
      if (entry.energyValue != null) 'energy_value': entry.energyValue,
    };
  }

  int _findEntryIndex(
    List<Map<String, dynamic>> entries,
    JournalEntry sourceEntry,
  ) {
    final originalTime = _entryTimeFor(sourceEntry);
    final originalTitle = sourceEntry.title.trim();

    return entries.indexWhere((candidate) {
      if (candidate['time'] != originalTime) return false;
      final candidateTitle = (candidate['title'] as String? ?? '').trim();
      if (_isImplicitTimeTitle(originalTitle, originalTime)) {
        return candidateTitle.isEmpty || candidateTitle == originalTime;
      }
      return candidateTitle == originalTitle;
    });
  }

  void _updateEntryCache({
    required String dateStr,
    required String relativePath,
    required List<Map<String, dynamic>> entries,
    required Map<String, dynamic> frontmatter,
    required Map<String, dynamic> habits,
    required Map<String, dynamic> trackers,
  }) {
    final journalEntries = entries.map((data) {
      final title = data['title']?.toString().trim() ?? '';
      final time = data['time']?.toString();
      final entry = JournalEntry(
        body: data['body']?.toString() ?? '',
        date: _journalEntryDateFromDaily(dateStr, time),
        timeOfDay: time,
        title: title.isNotEmpty ? title : time,
        moodSlug: data['mood']?.toString(),
        obsidianPath: relativePath,
      );
      final organizers = data['organizers'];
      if (organizers is List) {
        entry.organizers = organizers
            .map<OrganizerReference>(
              (organizer) => organizer is OrganizerReference
                  ? organizer
                  : OrganizerReference.fromWikiLink(organizer.toString()),
            )
            .toList();
      }
      return entry;
    }).toList();

    final notifier = ref.read(_dailyNoteDataMapProvider.notifier);
    final current = notifier.state;
    notifier.state = {
      ...current,
      dateStr: {
        'entries': journalEntries,
        'habitCompletions': habits,
        'habits': habits,
        'trackerRecords': trackers,
        'frontmatter': frontmatter,
      },
    };

    final todayStr = DateTime.now().toIso8601String().split('T').first;
    if (dateStr == todayStr) {
      state = journalEntries;
    }
  }

  Future<void> addEntry(JournalEntry entry) async {
    final normalizedDate = DateTime(
      entry.date.year,
      entry.date.month,
      entry.date.day,
    );
    final dateStr = normalizedDate.toIso8601String().split('T').first;
    final obsidianService = ref.read(obsidianServiceProvider);
    final settings = ref.read(settingsProvider);
    await obsidianService.initVault(
      settings.vaultName,
      customPath: settings.vaultPath,
    );

    final syncQueue = ref.read(syncQueueServiceProvider);

    final relativePath = 'daily/$dateStr.md';
    entry.obsidianPath = relativePath;

    // 1. Read existing or create new
    final dayThemes = ref.read(dayThemesProvider);
    String content =
        await obsidianService.readFile(relativePath) ??
        getDailyNoteTemplate(
          dateStr,
          dayThemes,
          activeHabits: ref
              .read(habitsProvider)
              .where((h) => h.status == HabitStatus.active)
              .toList(),
        );

    final frontmatter = MarkdownParser.parseFrontmatter(content);
    final body = MarkdownParser.extractBody(content);

    // Parse existing sections
    final entries = MarkdownParser.parseJournalEntries(body, dateStr);
    final tasks = MarkdownParser.parseTasksFromDailyNote(body);
    final habits = MarkdownParser.parseHabitCompletions(frontmatter);
    final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
    final pomodoros = MarkdownParser.parsePomodoros(body);

    // Add new entry
    entries.add(_dailyMapForEntry(entry, dateStr));

    // Sort by time
    entries.sort((a, b) => a['time'].compareTo(b['time']));
    await _syncMoodEntriesFrontmatter(frontmatter, entries);

    final newBody = MarkdownParser.generateDailyNoteBody(
      entries: entries,
      tasks: tasks,
      habits: habits,
      habitLabels: _habitLabelsFromRef(ref),
      pactHabitSlugs: _pactHabitSlugsFromRef(ref),
      trackers: trackers,
      pomodoros: pomodoros,
    );

    final newContent = generateMarkdown(frontmatter, newBody);

    // 2. Write to local disk
    await obsidianService.writeFile(relativePath, newContent);
    _updateEntryCache(
      dateStr: dateStr,
      relativePath: relativePath,
      entries: entries,
      frontmatter: frontmatter,
      habits: habits,
      trackers: trackers,
    );

    // 3. Queue for Sync
    await syncQueue.enqueueAction(
      SyncAction(
        objectType: 'daily_note',
        objectId: dateStr,
        operation: SyncOperation.update,
        payload: frontmatter,
      ),
    );

    ref.invalidate(dailyNoteDataProvider(dateStr));
    ref.invalidate(allObjectsProvider);
  }

  Future<void> _syncMoodEntriesFrontmatter(
    Map<String, dynamic> frontmatter,
    List<Map<String, dynamic>> entries,
  ) async {
    frontmatter.remove('mood_entries');
    frontmatter.remove('mood_pleasantness');
    frontmatter.remove('mood_energy');
    frontmatter.remove('mood_label');
    frontmatter.remove('mood_emoji');

    final moodEntries = <Map<String, dynamic>>[];
    final resolvedMoods = <String, MoodDefinition>{};

    for (final entry in entries) {
      final rawMood = entry['mood']?.toString().trim();
      final time = entry['time']?.toString().trim();
      if (rawMood == null || rawMood.isEmpty || time == null || time.isEmpty) {
        continue;
      }

      final moodIds = rawMood
          .split(RegExp(r'[,;|]'))
          .map((mood) => mood.replaceAll('[[', '').replaceAll(']]', '').trim())
          .where((mood) => mood.isNotEmpty)
          .toList();

      for (final moodId in moodIds) {
        final mood =
            resolvedMoods[moodId] ?? await _resolveMoodDefinition(moodId);
        resolvedMoods[moodId] = mood;
        moodEntries.add({
          'time': time,
          'pleasantness': mood.pleasantness,
          'energy': mood.energy,
          'label': mood.label,
          'emoji': mood.emoji,
        });
      }
    }

    frontmatter['mood_entries'] = moodEntries;
    if (moodEntries.isNotEmpty) {
      final latest = moodEntries.last;
      frontmatter['mood_pleasantness'] = latest['pleasantness'];
      frontmatter['mood_energy'] = latest['energy'];
      frontmatter['mood_label'] = latest['label'];
      frontmatter['mood_emoji'] = latest['emoji'];
    }
  }

  Future<MoodDefinition> _resolveMoodDefinition(String moodId) async {
    await ref.read(moodsProvider.notifier).ensureMoodFileExists(moodId);
    final availableMoods = [
      ...ref.read(moodsProvider),
      ...MoodDefinition.systemMoods,
    ];
    return availableMoods.firstWhere(
      (mood) => mood.id == moodId || mood.slug == moodId,
      orElse: () => MoodDefinition(
        id: moodId,
        label: moodId,
        emoji: '😐',
        color: '#9E9E9E',
      ),
    );
  }

  Future<void> updateEntry(
    JournalEntry entry, {
    JournalEntry? originalEntry,
  }) async {
    final sourceEntry = originalEntry ?? entry;

    // Check if the date has changed
    final dateChanged =
        entry.date.year != sourceEntry.date.year ||
        entry.date.month != sourceEntry.date.month ||
        entry.date.day != sourceEntry.date.day;

    if (dateChanged) {
      // 1. Delete from the old day
      await deleteEntry(sourceEntry);
      // 2. Add to the new day
      await addEntry(entry);
      return;
    }

    final normalizedDate = DateTime(
      sourceEntry.date.year,
      sourceEntry.date.month,
      sourceEntry.date.day,
    );
    final dateStr = normalizedDate.toIso8601String().split('T').first;
    final obsidianService = ref.read(obsidianServiceProvider);
    final settings = ref.read(settingsProvider);
    await obsidianService.initVault(
      settings.vaultName,
      customPath: settings.vaultPath,
    );

    final syncQueue = ref.read(syncQueueServiceProvider);
    final relativePath = 'daily/$dateStr.md';
    final dayThemes = ref.read(dayThemesProvider);
    final content =
        await obsidianService.readFile(relativePath) ??
        getDailyNoteTemplate(
          dateStr,
          dayThemes,
          activeHabits: ref
              .read(habitsProvider)
              .where((h) => h.status == HabitStatus.active)
              .toList(),
        );

    final frontmatter = MarkdownParser.parseFrontmatter(content);
    final body = MarkdownParser.extractBody(content);
    final entries = MarkdownParser.parseJournalEntries(body, dateStr);
    final tasks = MarkdownParser.parseTasksFromDailyNote(body);
    final habits = MarkdownParser.parseHabitCompletions(frontmatter);
    final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
    final pomodoros = MarkdownParser.parsePomodoros(body);

    entry.obsidianPath = relativePath;
    final replacement = _dailyMapForEntry(entry, dateStr);

    final index = _findEntryIndex(entries, sourceEntry);
    if (index >= 0) {
      entries[index] = replacement;
    } else {
      debugPrint(
        'Journal update could not match entry in $relativePath; appending replacement.',
      );
      entries.add(replacement);
    }

    entries.sort((a, b) => a['time'].compareTo(b['time']));
    await _syncMoodEntriesFrontmatter(frontmatter, entries);

    final newBody = MarkdownParser.generateDailyNoteBody(
      entries: entries,
      tasks: tasks,
      habits: habits,
      habitLabels: _habitLabelsFromRef(ref),
      pactHabitSlugs: _pactHabitSlugsFromRef(ref),
      trackers: trackers,
      pomodoros: pomodoros,
    );
    final newContent = generateMarkdown(frontmatter, newBody);
    await obsidianService.writeFile(relativePath, newContent);
    _updateEntryCache(
      dateStr: dateStr,
      relativePath: relativePath,
      entries: entries,
      frontmatter: frontmatter,
      habits: habits,
      trackers: trackers,
    );
    await syncQueue.enqueueAction(
      SyncAction(
        objectType: 'daily_note',
        objectId: dateStr,
        operation: SyncOperation.update,
        payload: frontmatter,
      ),
    );

    ref.invalidate(dailyNoteDataProvider(dateStr));
    ref.invalidate(allObjectsProvider);
  }

  Future<void> deleteEntry(JournalEntry entry) async {
    final normalizedDate = DateTime(
      entry.date.year,
      entry.date.month,
      entry.date.day,
    );
    final dateStr = normalizedDate.toIso8601String().split('T').first;
    final obsidianService = ref.read(obsidianServiceProvider);
    final settings = ref.read(settingsProvider);
    await obsidianService.initVault(
      settings.vaultName,
      customPath: settings.vaultPath,
    );

    final syncQueue = ref.read(syncQueueServiceProvider);
    final relativePath = 'daily/$dateStr.md';
    final content = await obsidianService.readFile(relativePath);
    if (content == null) return;

    final frontmatter = MarkdownParser.parseFrontmatter(content);
    final body = MarkdownParser.extractBody(content);
    final entries = MarkdownParser.parseJournalEntries(body, dateStr);
    final tasks = MarkdownParser.parseTasksFromDailyNote(body);
    final habits = MarkdownParser.parseHabitCompletions(frontmatter);
    final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
    final pomodoros = MarkdownParser.parsePomodoros(body);

    final index = _findEntryIndex(entries, entry);

    if (index >= 0) {
      entries.removeAt(index);
    } else {
      debugPrint('Journal delete could not match entry in $relativePath.');
    }

    await _syncMoodEntriesFrontmatter(frontmatter, entries);

    final newBody = MarkdownParser.generateDailyNoteBody(
      entries: entries,
      tasks: tasks,
      habits: habits,
      habitLabels: _habitLabelsFromRef(ref),
      pactHabitSlugs: _pactHabitSlugsFromRef(ref),
      trackers: trackers,
      pomodoros: pomodoros,
    );
    final newContent = generateMarkdown(frontmatter, newBody);
    await obsidianService.writeFile(relativePath, newContent);
    _updateEntryCache(
      dateStr: dateStr,
      relativePath: relativePath,
      entries: entries,
      frontmatter: frontmatter,
      habits: habits,
      trackers: trackers,
    );
    await syncQueue.enqueueAction(
      SyncAction(
        objectType: 'daily_note',
        objectId: dateStr,
        operation: SyncOperation.update,
        payload: frontmatter,
      ),
    );

    ref.invalidate(dailyNoteDataProvider(dateStr));
    ref.invalidate(allObjectsProvider);
  }
}

final todayJournalProvider =
    NotifierProvider<JournalNotifier, List<JournalEntry>>(() {
      return JournalNotifier();
    });

class VaultNotifier extends Notifier<void> {
  // 3.2 — Debounce rapid KPI recalculations (e.g. completing multiple habits
  // quickly triggers a single update 3 s after the last write).
  Timer? _kpiDebounce;

  @override
  void build() {
    _purgeOldDeletedFiles();
  }

  String _signatureKeyFor(ContentObject object) {
    if (object is TrackerDefinition) return 'tracker_definition';
    if (object is TrackingRecord) return 'tracker_record';
    if (object is MoodDefinition) return 'mood_definition';
    if (object is CombinedAnalysis) return 'combined_analysis';
    if (object is WellbeingIndicator) return 'wellbeing_indicator';
    // TimeBlock and DayTheme are now Organizer.
    if (object is TemplateDefinition) return 'template';
    if (object is Organizer) {
      return object.organizerType.name;
    }
    return object.type;
  }

  String _defaultFolderForSignature(String type) {
    return switch (type) {
      'mood_definition' => 'moods',
      'combined_analysis' => 'analyses',
      'goal' => 'goals',
      'task' => 'tasks',
      'habit' => 'habits',
      'tracker_definition' => 'trackers',
      'note' => 'notes',
      'resource' => 'resources',
      'person' => 'organizers/people',
      'project' => 'organizers/projects',
      'area' => 'organizers/areas',
      'activity' => 'organizers/activities',
      'label' => 'organizers/labels',
      'dayTheme' || 'day_theme' => 'organizers/day_themes',
      'timeBlock' || 'time_block' => 'organizers/time_blocks',
      _ => 'app',
    };
  }

  Future<void> _scheduleObjectReminders(ContentObject object) async {
    // Cancel previous reminders for this object using the current and legacy
    // ID schemes. Older builds used a hash per reminder config, so keep this
    // cleanup until those scheduled alarms naturally disappear from devices.
    final baseId = _stableNotificationBaseId(object.id);
    for (int i = 0; i < 50; i++) {
      await NotificationService().cancelNotification(baseId + i);
    }
    for (final config in object.reminders) {
      final legacyReminderId = (object.id + config.id).hashCode.abs() % 1000000;
      await NotificationService().cancelNotification(legacyReminderId);
    }

    final baseTime = object.baseTime ?? DateTime.now();
    final settings = ref.read(settingsProvider);

    for (var index = 0; index < object.reminders.length; index++) {
      final config = object.reminders[index];
      final triggerTime = config.calculateTriggerTime(baseTime);
      if (triggerTime.isAfter(DateTime.now())) {
        final habitSlotIndex = object is Habit
            ? _slotIndexFromReminderConfig(config)
            : null;
        if (object is Habit &&
            habitSlotIndex != null &&
            _isHabitSlotCompletedOn(object, triggerTime, habitSlotIndex)) {
          continue;
        }

        // Sleep In Tomorrow logic for Habits
        if (object is Habit &&
            settings.sleepInTomorrow &&
            settings.sleepInDate.isNotEmpty) {
          final triggerDateStr = triggerTime.toIso8601String().split('T').first;
          if (triggerDateStr == settings.sleepInDate) {
            final parts = settings.sleepInUntil.split(':');
            final sleepUntilHour = int.tryParse(parts.first) ?? 10;
            final sleepUntilMinute = parts.length > 1
                ? int.tryParse(parts[1]) ?? 0
                : 0;
            final limitTime = DateTime(
              triggerTime.year,
              triggerTime.month,
              triggerTime.day,
              sleepUntilHour,
              sleepUntilMinute,
            );
            if (triggerTime.isBefore(limitTime)) {
              // Ignore this notification trigger because of sleep-in mode
              continue;
            }
          }
        }

        final reminderId = baseId + index;
        await NotificationService().scheduleReminder(
          id: reminderId,
          title: object.title,
          config: config,
          payload: object is Habit && habitSlotIndex != null
              ? 'Quartzo://notification?oid=${Uri.encodeComponent(object.id)}&type=habit&slot=$habitSlotIndex'
              : object.id,
        );
      }
    }
  }

  int? _slotIndexFromReminderConfig(ReminderConfig config) {
    final match = RegExp(r'_slot_(\d+)(?:_|$)').firstMatch(config.id);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  bool _isHabitSlotCompletedOn(Habit habit, DateTime date, int slotIndex) {
    final dateStr = date.toIso8601String().split('T').first;
    final record = habit.completionHistory
        .where(
          (entry) => entry.date.toIso8601String().split('T').first == dateStr,
        )
        .firstOrNull;
    final slots = record?.slotCompletions;
    return slots != null &&
        slotIndex < slots.length &&
        slots[slotIndex] == true;
  }

  Future<void> rescheduleAllHabits() async {
    final allObjects = await ref.read(allObjectsProvider.future);
    final habits = allObjects.whereType<Habit>();
    for (final habit in habits) {
      await _scheduleObjectReminders(habit);
    }
  }

  void _invalidateObjectProviders(ContentObject object) {
    final key = _signatureKeyFor(object);
    ref.invalidate(allObjectsProvider);
    ref.invalidate(objectsByTypeProvider(object.type));
    ref.invalidate(objectsByTypeProvider(key));

    if (object.obsidianPath.startsWith('daily/')) {
      final dateMatch = RegExp(
        r'(\d{4}-\d{2}-\d{2})',
      ).firstMatch(object.obsidianPath);
      if (dateMatch != null) {
        ref.invalidate(dailyNoteDataProvider(dateMatch.group(1)!));
      }
    }
  }

  Future<void> _updateWidgetsFor(ContentObject object) async {
    if (object is Task) {
      final tasks = ref.read(tasksProvider);
      final pending =
          tasks.where((t) => t.stage != TaskStage.finalized).toList()..sort(
            (a, b) => (a.scheduledTime ?? '99:99').compareTo(
              b.scheduledTime ?? '99:99',
            ),
          );
      WidgetService.updateNextTask(pending.isNotEmpty ? pending.first : null);
    } else if (object is Habit) {
      WidgetService.updateHabits(ref.read(habitsProvider));
    } else if (object is Note && object.pinned) {
      WidgetService.updateNote(
        widgetId: 0,
        title: object.title,
        content: object.body,
        slug: object.slug,
      );
    }
  }

  Future<void> _cancelObjectReminders(ContentObject object) async {
    final baseId = _stableNotificationBaseId(object.id);
    for (int i = 0; i < 50; i++) {
      await NotificationService().cancelNotification(baseId + i);
    }
    for (final config in object.reminders) {
      final legacyReminderId = (object.id + config.id).hashCode.abs() % 1000000;
      await NotificationService().cancelNotification(legacyReminderId);
    }
  }

  Future<void> rescheduleAllObjectReminders() async {
    await NotificationService().cancelAllScheduled();
    final allObjects = await ref.read(allObjectsProvider.future);
    for (final object in allObjects) {
      await _scheduleObjectReminders(object);
    }
    await NotificationService().showQuickCaptureNotification();
  }

  Future<String> _writeObject(
    ContentObject object, {
    required SyncOperation operation,
    String? preservedSourceMarkdown,
  }) async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);
    final settings = ref.read(settingsProvider);
    final signatureKey = _signatureKeyFor(object);
    final sig =
        settings.typeSignatures[signatureKey] ??
        settings.typeSignatures[object.type];

    object.updatedAt = DateTime.now();
    final prepared = MarkdownParser.prepareForSave(
      object,
      sig,
      defaultFolder:
          settings.folderPaths[signatureKey] ??
          settings.folderPaths[object.type] ??
          _defaultFolderForSignature(signatureKey),
    );
    var relativePath = prepared['path']!;
    final oldPath = object.obsidianPath;

    // Resolve slug collision (avoid overwriting files belonging to different IDs)
    final folder = relativePath.contains('/')
        ? relativePath.substring(0, relativePath.lastIndexOf('/'))
        : '';
    final filename = relativePath.contains('/')
        ? relativePath.substring(folder.length + 1, relativePath.length - 3)
        : relativePath.substring(0, relativePath.length - 3);

    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    var pathToCheck = relativePath;
    var suffixCounter = 1;

    if (oldPath != pathToCheck) {
      while (true) {
        final collision = allObjects.any(
          (o) => o.id != object.id && o.obsidianPath == pathToCheck,
        );
        if (!collision) {
          if (await obsidianService.fileExists(pathToCheck)) {
            try {
              final content = await obsidianService.readFile(pathToCheck);
              if (content != null) {
                final fm = MarkdownParser.parseFrontmatter(content);
                if (fm['id']?.toString() == object.id) {
                  break;
                }
              }
            } catch (_) {}
            suffixCounter++;
            pathToCheck = folder.isNotEmpty
                ? '$folder/$filename-$suffixCounter.md'
                : '$filename-$suffixCounter.md';
            continue;
          }
          break;
        }
        suffixCounter++;
        pathToCheck = folder.isNotEmpty
            ? '$folder/$filename-$suffixCounter.md'
            : '$filename-$suffixCounter.md';
      }
    }
    relativePath = pathToCheck;
    object.obsidianPath = relativePath;

    var markdown = prepared['markdown']!;
    if (preservedSourceMarkdown != null) {
      if (oldPath != relativePath &&
          await obsidianService.fileExists(relativePath)) {
        throw Exception(
          'Target file already exists: $relativePath. Use merge instead.',
        );
      }
      markdown = _mergeConvertedMarkdown(
        sourceMarkdown: preservedSourceMarkdown,
        convertedMarkdown: markdown,
        target: object,
      );
    }
    if (object is TrackerDefinition) {
      final dataviewBlock = DataviewGenerator.generateTrackerDataviewBlock(
        object,
      );
      final chartBlock = DataviewGenerator.generateChartBlock(object);
      markdown = [
        markdown.trimRight(),
        '## Obsidian Views',
        dataviewBlock,
        if (chartBlock.isNotEmpty) chartBlock,
      ].join('\n\n');
    } else if (object is CombinedAnalysis) {
      final trackerBlock = DataviewGenerator.generateTrackerPluginBlock(object);

      final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
      final entries = ref.read(allEntriesProvider);
      final pomodoros = ref.read(pomodoroProvider).history;

      final List<DateTime> dates = [];
      final today = DateTime.now();
      final dateRange = object.defaultDateRange;
      if (dateRange != null) {
        var current = DateTime(
          dateRange.start.year,
          dateRange.start.month,
          dateRange.start.day,
        );
        final end = DateTime(
          dateRange.end.year,
          dateRange.end.month,
          dateRange.end.day,
        );
        while (!current.isAfter(end)) {
          dates.add(current);
          current = current.add(const Duration(days: 1));
        }
      } else {
        for (int i = 0; i < 14; i++) {
          dates.add(
            DateTime(
              today.year,
              today.month,
              today.day,
            ).subtract(Duration(days: 13 - i)),
          );
        }
      }

      final List<String> labels = dates
          .map(
            (d) =>
                '${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}',
          )
          .toList();

      final List<List<num>> seriesData = [];
      for (final source in object.dataSources) {
        final List<num> values = [];
        for (final date in dates) {
          final val = _getValueForDate(
            source: source,
            date: date,
            allObjects: allObjects,
            entries: entries,
            pomodoros: pomodoros,
          );
          values.add(val ?? 0);
        }
        seriesData.add(values);
      }

      final chartBlock = DataviewGenerator.generateChartsPluginBlock(
        object,
        labels: labels,
        seriesData: seriesData,
      );

      final List<String> blocks = [markdown.trimRight()];
      if (trackerBlock.isNotEmpty) {
        blocks.add('## Obsidian Tracker');
        blocks.add(trackerBlock);
      }
      if (chartBlock.isNotEmpty) {
        blocks.add('## Obsidian Charts');
        blocks.add(chartBlock);
      }
      markdown = blocks.join('\n\n');
    }

    await obsidianService.writeFile(relativePath, markdown);
    if (object is Note && object.subtype == NoteSubtype.collection) {
      await obsidianService.syncCollectionToBase(object);
    }
    if (operation == SyncOperation.update &&
        oldPath.isNotEmpty &&
        oldPath != relativePath) {
      await obsidianService.deleteFile(oldPath);
    }
    await syncQueue.enqueueAction(
      SyncAction(
        objectType: signatureKey,
        objectId: object.id,
        operation: operation,
        payload: object.toBaseMap(),
      ),
    );
    await _scheduleObjectReminders(object);
    await _updateWidgetsFor(object);
    _invalidateObjectProviders(object);

    if (_shouldUpdateKpisAfterWrite(object)) {
      _kpiDebounce?.cancel();
      _kpiDebounce = Timer(const Duration(seconds: 3), () async {
        try {
          await AutomationService.updateAllKPIs(ref);
        } catch (e, st) {
          debugPrint('Failed to update KPIs after vault write: $e\n$st');
        }
      });
    }
    return relativePath;
  }

  double? _getValueForDate({
    required MetricSource source,
    required DateTime date,
    required List<ContentObject> allObjects,
    required List<JournalEntry> entries,
    required List<PomodoroSession> pomodoros,
  }) {
    switch (source.type) {
      case MetricType.mood:
        final dayEntries = entries
            .where(
              (e) =>
                  e.date.year == date.year &&
                  e.date.month == date.month &&
                  e.date.day == date.day &&
                  e.moodSlug != null,
            )
            .toList();
        if (dayEntries.isNotEmpty) {
          final moods = allObjects.whereType<MoodDefinition>().toList();
          final values = dayEntries
              .map(
                (entry) => moods
                    .where(
                      (m) => m.id == entry.moodSlug || m.slug == entry.moodSlug,
                    )
                    .firstOrNull,
              )
              .whereType<MoodDefinition>()
              .map((mood) {
                if (source.dimension == 'energy') {
                  return mood.energy.toDouble();
                } else if (source.dimension == 'pleasantness') {
                  return mood.pleasantness.toDouble();
                }
                return (mood.pleasantness + mood.energy) / 2.0;
              })
              .toList();
          if (values.isNotEmpty) {
            return values.reduce((a, b) => a + b) / values.length;
          }
        }
        return null;

      case MetricType.habit:
        final habit = allObjects
            .whereType<Habit>()
            .where((h) => h.id == source.id)
            .firstOrNull;
        if (habit == null) return null;
        final record = habit.completionHistory
            .where(
              (c) =>
                  c.date.year == date.year &&
                  c.date.month == date.month &&
                  c.date.day == date.day,
            )
            .firstOrNull;
        if (record == null) return null;
        return record.successful || record.completions > 0 ? 1.0 : 0.0;

      case MetricType.trackerField:
        final records = allObjects.whereType<TrackingRecord>().toList();
        final dayRecords = records
            .where(
              (r) =>
                  _recordBelongsToTracker(r, source.id, allObjects) &&
                  r.date.year == date.year &&
                  r.date.month == date.month &&
                  r.date.day == date.day,
            )
            .toList();
        if (dayRecords.isEmpty) return null;

        var total = 0.0;
        var foundValue = false;
        final fieldId = source.fieldId ?? '';
        for (final record in dayRecords) {
          final val = record.fieldValues[fieldId];
          if (val is num) {
            total += val.toDouble();
            foundValue = true;
          } else if (val is bool) {
            total += val ? 1.0 : 0.0;
            foundValue = true;
          } else if (val is List) {
            total += val.length.toDouble();
            foundValue = true;
          } else if (val is String) {
            final parsed = double.tryParse(val);
            if (parsed != null) {
              total += parsed;
              foundValue = true;
            }
          }
        }
        return foundValue ? total : null;

      case MetricType.trackerScore:
        final records = allObjects.whereType<TrackingRecord>().toList();
        final count = records
            .where(
              (r) =>
                  _recordBelongsToTracker(r, source.id, allObjects) &&
                  r.date.year == date.year &&
                  r.date.month == date.month &&
                  r.date.day == date.day,
            )
            .length
            .toDouble();
        return count == 0 ? null : count;

      case MetricType.googleCalendar:
        return 0;

      case MetricType.pomodoro:
        final sessions = pomodoros.where(
          (s) =>
              s.date.year == date.year &&
              s.date.month == date.month &&
              s.date.day == date.day &&
              s.state == PomodoroSessionState.completed,
        );
        if (sessions.isEmpty) return null;
        return sessions.fold<double>(0, (sum, s) => sum + s.minutesWorked);

      case MetricType.kpi:
        // KPI values are calculated separately in CombinedAnalysisScreen
        return null;
    }
  }

  bool _recordBelongsToTracker(
    TrackingRecord record,
    String trackerId,
    List<ContentObject> allObjects,
  ) {
    if (record.trackerId == trackerId) return true;
    final tracker = allObjects
        .whereType<TrackerDefinition>()
        .where((t) => t.id == trackerId || t.slug == trackerId)
        .firstOrNull;
    if (tracker == null) return false;
    return record.trackerId == tracker.slug ||
        record.trackerId == tracker.title ||
        record.trackerId == tracker.id;
  }

  String _mergeConvertedMarkdown({
    required String sourceMarkdown,
    required String convertedMarkdown,
    required ContentObject target,
  }) {
    final sourceFrontmatter = MarkdownParser.parseFrontmatter(sourceMarkdown);
    final convertedFrontmatter = MarkdownParser.parseFrontmatter(
      convertedMarkdown,
    );
    final sourceBody = MarkdownParser.extractBody(sourceMarkdown);
    final convertedBody = MarkdownParser.extractBody(convertedMarkdown);

    final mergedFrontmatter = <String, dynamic>{
      ...sourceFrontmatter,
      ...convertedFrontmatter,
    };

    final sourceCategories = sourceFrontmatter['categories'];
    final convertedCategories = convertedFrontmatter['categories'];
    if (sourceCategories is List || convertedCategories is List) {
      mergedFrontmatter['categories'] = <dynamic>{
        if (sourceCategories is List) ...sourceCategories,
        if (convertedCategories is List) ...convertedCategories,
      }.toList();
    }

    final sourceTags = sourceFrontmatter['tags'];
    final convertedTags = convertedFrontmatter['tags'];
    if (sourceTags is List || convertedTags is List) {
      mergedFrontmatter['tags'] = <dynamic>{
        if (sourceTags is List) ...sourceTags,
        if (convertedTags is List) ...convertedTags,
      }.toList();
    }

    final sourceAliases = sourceFrontmatter['aliases'];
    final convertedAliases = convertedFrontmatter['aliases'];
    if (sourceAliases is List || convertedAliases is List) {
      mergedFrontmatter['aliases'] = <dynamic>{
        if (sourceAliases is List) ...sourceAliases,
        if (convertedAliases is List) ...convertedAliases,
      }.toList();
    }

    final body = convertedBody.trim().isEmpty && sourceBody.trim().isNotEmpty
        ? sourceBody
        : convertedBody;

    debugPrint(
      'Converted ${target.id} to ${_signatureKeyFor(target)} at '
      '${target.obsidianPath}; preserved '
      '${sourceFrontmatter.length} source frontmatter fields.',
    );
    return generateMarkdown(mergedFrontmatter, body);
  }

  bool _shouldUpdateKpisAfterWrite(ContentObject object) {
    return object is Habit ||
        object is TrackingRecord ||
        object is JournalEntry ||
        object is Note ||
        object is MoodDefinition ||
        object is Task;
  }

  Future<void> createObject(ContentObject object) async {
    await _writeObject(object, operation: SyncOperation.create);
  }

  Future<void> importExistingVault(String sourcePath) async {
    final service = ref.read(obsidianServiceProvider);
    final sourceDir = Directory(sourcePath);
    if (!await sourceDir.exists()) return;

    final mdFiles = sourceDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();

    int copied = 0;
    for (final file in mdFiles) {
      try {
        final content = await file.readAsString();
        final relativePath = file.path.replaceFirst(sourcePath, '');
        final cleanRelativePath =
            relativePath.startsWith(Platform.pathSeparator)
            ? relativePath.substring(1)
            : relativePath;
        final normalizedPath = cleanRelativePath.replaceAll(
          Platform.pathSeparator,
          '/',
        );

        await service.writeFile(normalizedPath, content);
        copied++;
      } catch (e) {
        debugPrint('Failed to copy file ${file.path}: $e');
      }
    }

    debugPrint('Imported $copied files from $sourcePath');
    ref.invalidate(allObjectsProvider);
  }

  Future<void> changeObjectType(
    ContentObject object,
    String targetType, {
    Map<String, dynamic>? extraFields,
  }) async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);
    final sourcePath = object.obsidianPath;
    final sourceMarkdown = sourcePath.isNotEmpty
        ? await obsidianService.readFile(sourcePath)
        : null;
    if (sourcePath.isNotEmpty && sourceMarkdown == null) {
      final error = Exception('Could not read source file: $sourcePath');
      await _recordConversionFailure(
        object: object,
        targetType: targetType,
        sourcePath: sourcePath,
        extraFields: extraFields,
        error: error,
        stackTrace: StackTrace.current,
      );
      throw error;
    }

    // 2. Map old object fields and body content to the new object
    String bodyContent = '';
    if (sourceMarkdown != null) {
      bodyContent = MarkdownParser.extractBody(sourceMarkdown);
    } else if (object is Task) {
      bodyContent = object.notes.join('\n');
    } else if (object is Habit) {
      bodyContent = object.description ?? '';
    } else if (object is Goal) {
      bodyContent = object.description ?? '';
    } else if (object is Note) {
      bodyContent = object.body;
    } else if (object is Project) {
      bodyContent = object.description ?? '';
    } else if (object is Organizer) {
      bodyContent = '';
    }

    ContentObject newObject;
    final baseId = object.id;
    final baseTitle = object.title;
    final baseCreatedAt = object.createdAt;
    final baseUpdatedAt = object.updatedAt;
    final baseOrganizers = object.organizers;
    final baseCategories = object.categories;
    final baseTags = object.tags;

    switch (targetType.toLowerCase()) {
      case 'task':
        newObject = Task(
          id: baseId,
          title: baseTitle,
          stage: TaskStage.idea,
          notes: bodyContent.isNotEmpty ? [bodyContent] : const [],
          createdAt: baseCreatedAt,
          updatedAt: baseUpdatedAt,
          organizers: baseOrganizers,
          categories: _mergedCategories(baseCategories, '[[tasks]]'),
          tags: baseTags,
        );
        break;
      case 'habit':
        newObject = Habit(
          id: baseId,
          title: baseTitle,
          color: '#F97316',
          description: bodyContent,
          createdAt: baseCreatedAt,
          updatedAt: baseUpdatedAt,
          organizers: baseOrganizers,
          categories: _mergedCategories(baseCategories, '[[habits]]'),
          tags: baseTags,
        );
        break;
      case 'goal':
        newObject = Goal(
          id: baseId,
          title: baseTitle,
          description: bodyContent,
          createdAt: baseCreatedAt,
          updatedAt: baseUpdatedAt,
          organizers: baseOrganizers,
          categories: _mergedCategories(baseCategories, '[[goals]]'),
        );
        break;
      case 'note':
        newObject = Note(
          id: baseId,
          title: baseTitle,
          subtype: NoteSubtype.text,
          body: bodyContent,
          createdAt: baseCreatedAt,
          updatedAt: baseUpdatedAt,
          organizers: baseOrganizers,
          categories: _mergedCategories(baseCategories, '[[notes]]'),
          tags: baseTags,
        );
        break;
      case 'project':
        newObject = Project(
          id: baseId,
          title: baseTitle,
          description: bodyContent,
          createdAt: baseCreatedAt,
          updatedAt: baseUpdatedAt,
          organizers: baseOrganizers,
          categories: _mergedCategories(baseCategories, '[[projects]]'),
        );
        break;
      case 'organizer':
        final orgTypeStr = extraFields?['organizerType']?.toString() ?? 'area';
        final orgType = OrganizerType.values.firstWhere(
          (e) => e.name == orgTypeStr,
          orElse: () => OrganizerType.area,
        );
        newObject = Organizer(
          id: baseId,
          title: baseTitle,
          organizerType: orgType,
          createdAt: baseCreatedAt,
          updatedAt: baseUpdatedAt,
          organizers: baseOrganizers,
          categories: _mergedCategories(baseCategories, '[[organizers]]'),
        );
        break;
      case 'person':
        newObject = Person(
          id: baseId,
          title: baseTitle,
          createdAt: baseCreatedAt,
          updatedAt: baseUpdatedAt,
          organizers: baseOrganizers,
          categories: _mergedCategories(baseCategories, '[[people]]'),
        );
        break;
      case 'resource':
        newObject = Resource(
          id: baseId,
          title: baseTitle,
          mediaType: 'General',
          synopsis: bodyContent,
          createdAt: baseCreatedAt,
          updatedAt: baseUpdatedAt,
          organizers: baseOrganizers,
          categories: _mergedCategories(baseCategories, '[[resources]]'),
        );
        break;
      case 'tracker':
      case 'tracker_definition':
        newObject = TrackerDefinition(
          id: baseId,
          title: baseTitle,
          description: bodyContent,
          createdAt: baseCreatedAt,
          updatedAt: baseUpdatedAt,
          organizers: baseOrganizers,
          categories: _mergedCategories(baseCategories, '[[trackers]]'),
          tags: baseTags,
        );
        break;
      default:
        throw Exception('Unsupported conversion target type: $targetType');
    }

    try {
      final targetPath = await _writeObject(
        newObject,
        operation: SyncOperation.create,
        preservedSourceMarkdown: sourceMarkdown,
      );

      if (sourcePath.isNotEmpty && sourcePath != targetPath) {
        final timestamp = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .replaceAll('.', '-');
        final fileName = sourcePath.split('/').last;
        final deletedPath = '_deleted/${timestamp}_$fileName';

        await obsidianService.moveFile(sourcePath, deletedPath);
        await syncQueue.enqueueAction(
          SyncAction(
            objectType: _signatureKeyFor(object),
            objectId: object.id,
            operation: SyncOperation.delete,
            payload: object.toBaseMap(),
          ),
        );
        debugPrint(
          'Converted ${object.id}: moved old file $sourcePath to $deletedPath '
          'after writing $targetPath.',
        );
      }
    } catch (e, st) {
      await _recordConversionFailure(
        object: object,
        targetType: targetType,
        sourcePath: sourcePath,
        extraFields: extraFields,
        error: e,
        stackTrace: st,
      );
      debugPrint(
        'Failed to convert ${object.id} from ${object.type} to $targetType. '
        'sourcePath=$sourcePath targetExtra=$extraFields error=$e\n$st',
      );
      rethrow;
    }

    _invalidateObjectProviders(object);
    _invalidateObjectProviders(newObject);
    await _updateWidgetsFor(newObject);
  }

  Future<void> redirectAndDeleteObject({
    required ContentObject source,
    required ContentObject target,
    bool mergeBodyIntoTarget = true,
  }) async {
    if (source.id == target.id || source.obsidianPath == target.obsidianPath) {
      throw Exception('Source and target must be different objects.');
    }

    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);
    final sourcePath = source.obsidianPath;
    final targetPath = target.obsidianPath;
    if (sourcePath.isEmpty || targetPath.isEmpty) {
      throw Exception('Both objects need vault file paths before merging.');
    }

    final sourceMarkdown = await obsidianService.readFile(sourcePath);
    final targetMarkdown = await obsidianService.readFile(targetPath);
    if (sourceMarkdown == null) {
      throw Exception('Could not read source file: $sourcePath');
    }
    if (targetMarkdown == null) {
      throw Exception('Could not read target file: $targetPath');
    }

    try {
      if (mergeBodyIntoTarget) {
        final mergedTarget = _mergeSourceContentIntoTargetMarkdown(
          source: source,
          sourceMarkdown: sourceMarkdown,
          targetMarkdown: targetMarkdown,
        );
        if (mergedTarget != targetMarkdown) {
          await obsidianService.writeFile(targetPath, mergedTarget);
        }
      }

      final files = await obsidianService.getAllMarkdownFiles();
      final changedPaths = <String>{};
      for (final file in files) {
        final relativePath = obsidianService.getRelativePath(file.path);
        if (relativePath == sourcePath) continue;

        final content = await file.readAsString();
        final updated = _replaceObjectReferences(content, source, target);
        if (updated != content) {
          await obsidianService.writeFile(relativePath, updated);
          changedPaths.add(relativePath);
        }
      }

      for (final path in changedPaths) {
        await syncQueue.enqueueAction(
          SyncAction(
            objectType: 'vault_file',
            objectId: path,
            operation: SyncOperation.update,
            payload: {'path': path},
          ),
        );
      }

      await deleteObject(source);
      _invalidateObjectProviders(source);
      _invalidateObjectProviders(target);
      debugPrint(
        'Redirected ${source.id} ($sourcePath) into ${target.id} '
        '($targetPath); updated ${changedPaths.length} files.',
      );
    } catch (e, st) {
      await _recordMergeFailure(
        source: source,
        target: target,
        error: e,
        stackTrace: st,
      );
      debugPrint('Failed to redirect ${source.id} into ${target.id}: $e\n$st');
      rethrow;
    }
  }

  String _mergeSourceContentIntoTargetMarkdown({
    required ContentObject source,
    required String sourceMarkdown,
    required String targetMarkdown,
  }) {
    final sourceBody = MarkdownParser.extractBody(sourceMarkdown).trim();
    final targetBody = MarkdownParser.extractBody(targetMarkdown).trimRight();
    final frontmatter = MarkdownParser.parseFrontmatter(targetMarkdown);

    final aliases = <String>{
      ...((frontmatter['aliases'] as List?)?.map((item) => item.toString()) ??
          const <String>[]),
      source.title,
      source.obsidianFileName,
    }..removeWhere((item) => item.trim().isEmpty);
    frontmatter['aliases'] = aliases.toList();

    if (sourceBody.isEmpty || targetBody.contains(sourceBody)) {
      return generateMarkdown(frontmatter, targetBody);
    }

    final mergedBody = [
      targetBody,
      '',
      '## Conteúdo mesclado de ${source.title}',
      '',
      sourceBody,
    ].join('\n').trim();
    return generateMarkdown(frontmatter, mergedBody);
  }

  String _replaceObjectReferences(
    String content,
    ContentObject source,
    ContentObject target,
  ) {
    var updated = content;
    final targetRef = _primaryWikiLinkTarget(target);
    for (final key in _referenceKeysFor(source)) {
      final escaped = RegExp.escape(key);
      updated = updated.replaceAllMapped(
        RegExp(
          r'\[\[\s*' + escaped + r'\s*(\|[^\]]+)?\]\]',
          caseSensitive: false,
        ),
        (match) => '[[$targetRef${match.group(1) ?? ''}]]',
      );
    }
    return updated;
  }

  Set<String> _referenceKeysFor(ContentObject object) {
    final withoutExtension = object.obsidianPath.replaceAll(
      RegExp(r'\.md$', caseSensitive: false),
      '',
    );
    return {
      object.id,
      object.slug,
      object.title,
      object.obsidianFileName,
      if (withoutExtension.isNotEmpty) withoutExtension,
      if (object.type.isNotEmpty && object.slug.isNotEmpty)
        '${object.type}/${object.slug}',
      if (object is Note && object.slug.isNotEmpty) 'note/${object.slug}',
    }.map((item) => item.trim()).where((item) => item.isNotEmpty).toSet();
  }

  String _primaryWikiLinkTarget(ContentObject object) {
    final withoutExtension = object.obsidianPath.replaceAll(
      RegExp(r'\.md$', caseSensitive: false),
      '',
    );
    if (withoutExtension.isNotEmpty) return withoutExtension;
    if (object.slug.isNotEmpty) return object.slug;
    return object.title;
  }

  List<String> _mergedCategories(List<String> current, String required) {
    return <String>{...current, required}.toList();
  }

  Future<void> _recordConversionFailure({
    required ContentObject object,
    required String targetType,
    required String sourcePath,
    required Map<String, dynamic>? extraFields,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    try {
      final obsidianService = ref.read(obsidianServiceProvider);
      const logPath = '_conflicts/conversion_errors.log';
      final existing = await obsidianService.readFile(logPath) ?? '';
      final timestamp = DateTime.now().toIso8601String();
      final entry = [
        '[$timestamp] changeObjectType failed',
        'objectId: ${object.id}',
        'title: ${object.title}',
        'fromType: ${object.type}',
        'targetType: $targetType',
        'sourcePath: $sourcePath',
        'extraFields: $extraFields',
        'error: $error',
        'stackTrace: $stackTrace',
        '',
      ].join('\n');
      await obsidianService.writeFile(logPath, '$existing$entry');
    } catch (logError, logStack) {
      debugPrint('Failed to record conversion failure: $logError\n$logStack');
    }
  }

  Future<void> _recordMergeFailure({
    required ContentObject source,
    required ContentObject target,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    try {
      final obsidianService = ref.read(obsidianServiceProvider);
      const logPath = '_conflicts/merge_errors.log';
      final existing = await obsidianService.readFile(logPath) ?? '';
      final timestamp = DateTime.now().toIso8601String();
      final entry = [
        '[$timestamp] redirectAndDeleteObject failed',
        'sourceId: ${source.id}',
        'sourceTitle: ${source.title}',
        'sourcePath: ${source.obsidianPath}',
        'targetId: ${target.id}',
        'targetTitle: ${target.title}',
        'targetPath: ${target.obsidianPath}',
        'error: $error',
        'stackTrace: $stackTrace',
        '',
      ].join('\n');
      await obsidianService.writeFile(logPath, '$existing$entry');
    } catch (logError, logStack) {
      debugPrint('Failed to record merge failure: $logError\n$logStack');
    }
  }

  Future<void> _purgeOldDeletedFiles() async {
    final obsidianService = ref.read(obsidianServiceProvider);

    final foldersToPurge = ['_deleted', '_conflicts'];
    final now = DateTime.now();

    for (final folder in foldersToPurge) {
      final files = await obsidianService.getFilesInFolder(
        folder,
        includeDeleted: true,
      );

      for (final file in files) {
        final stat = await file.stat();
        final diff = now.difference(stat.modified);
        if (diff.inDays > 30) {
          await obsidianService.deleteFile(
            obsidianService.getRelativePath(file.path),
          );
        }
      }
    }
  }

  Future<void> updateObject(ContentObject object) async {
    await _writeObject(object, operation: SyncOperation.update);
  }

  Future<void> archiveObject(ContentObject object) async {
    // F2.17: Archive sets archived flag in place, never moves file
    object.archived = true;
    await updateObject(object);
  }

  Future<void> unarchiveObject(ContentObject object) async {
    // F2.17: Unarchive reverts archived flag in place
    object.archived = false;
    await updateObject(object);
  }

  Future<void> deleteObject(ContentObject object) async {
    // F2.17: Delete moves file to _deleted/ (permanent erase after 30 days)
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);

    if (object.obsidianPath.isNotEmpty) {
      debugPrint('Deleting: ${object.obsidianPath}');
      final fileName = object.obsidianPath.split('/').last;
      final deletedPath = '_deleted/$fileName';

      final content = await obsidianService.readFile(object.obsidianPath);
      if (content != null) {
        await obsidianService.writeFile(deletedPath, content);
      }

      await obsidianService.deleteFile(object.obsidianPath);

      await syncQueue.enqueueAction(
        SyncAction(
          objectType: _signatureKeyFor(object),
          objectId: object.id,
          operation: SyncOperation.delete,
          payload: object.toBaseMap(),
        ),
      );

      await _cancelObjectReminders(object);
      _invalidateObjectProviders(object);
      await _updateWidgetsFor(object);
    }
  }

  Future<void> restoreObject(ContentObject object, String originalPath) async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);

    final fileName = originalPath.split('/').last;
    final deletedPath = '_deleted/$fileName';

    final content = await obsidianService.readFile(deletedPath);
    if (content != null) {
      await obsidianService.writeFile(originalPath, content);
      await obsidianService.deleteFile(deletedPath);

      await syncQueue.enqueueAction(
        SyncAction(
          objectType: _signatureKeyFor(object),
          objectId: object.id,
          operation: SyncOperation.create,
          payload: object.toBaseMap(),
        ),
      );

      object.obsidianPath = originalPath;
      await _scheduleObjectReminders(object);
      await _updateWidgetsFor(object);
      _invalidateObjectProviders(object);
    }
  }

  Future<void> restoreDeletedFile(String deletedPath) async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);
    final fileName = deletedPath.split('/').last;

    final content = await obsidianService.readFile(deletedPath);
    if (content == null) return;

    final frontmatter = MarkdownParser.parseFrontmatter(content);
    final type = frontmatter['type']?.toString();
    final folder = switch (type) {
      'task' => 'tasks',
      'habit' => 'habits',
      'tracker' || 'tracker_definition' => 'trackers',

      'goal' => 'goals',
      'note' => 'notes',
      'resource' => 'resources',
      'person' => 'organizers/people',
      'project' => 'organizers/projects',
      'organizer' => 'organizers',
      'mood_definition' => 'moods',
      'combined_analysis' => 'analyses',
      'wellbeing_indicator' => 'app',
      'snapshot' => 'snapshots',
      _ => 'app',
    };
    final originalPath = '$folder/$fileName';

    await obsidianService.writeFile(originalPath, content);
    await obsidianService.deleteFile(deletedPath);

    await syncQueue.enqueueAction(
      SyncAction(
        objectType: type ?? 'file',
        objectId: frontmatter['id']?.toString() ?? fileName,
        operation: SyncOperation.create,
        payload: Map<String, dynamic>.from(frontmatter),
      ),
    );

    ref.invalidate(allObjectsProvider);
  }

  Future<void> processPendingNotificationActions() async {
    final actions = await NotificationService().takePendingActions();
    if (actions.isEmpty) return;

    for (final action in actions) {
      final actionId = action['action']?.toString();
      final payload = action['payload']?.toString();
      if (payload == null || payload.isEmpty) continue;

      if (payload.contains('action=weekly_review')) {
        await _generateWeeklyReviewDraft();
        continue;
      }

      if (actionId == 'quick_entry_text') {
        await createQuickJournalEntry(payload);
        continue;
      }
      if (actionId == 'quick_task_text') {
        await createQuickTaskFromNaturalLanguage(payload);
        continue;
      }
      if (actionId == 'quick_habit_text') {
        await createQuickHabit(payload);
        continue;
      }
      if (actionId == 'toggle_habit') {
        final habit = ref
            .read(habitsProvider)
            .where(
              (candidate) =>
                  candidate.id == payload || candidate.slug == payload,
            )
            .firstOrNull;
        if (habit != null) {
          await ref
              .read(habitsProvider.notifier)
              .toggleHabit(habit, DateTime.now());
        }
        continue;
      }

      final objectId = _objectIdFromNotificationPayload(payload);
      if (objectId == null || objectId.isEmpty) continue;

      if (actionId == 'done') {
        await _markNotificationTargetDone(objectId);
      } else if (actionId == 'dismiss') {
        await _recordNotificationDismissal(objectId);
      } else if (actionId == 'snooze') {
        await _snoozeNotification(objectId, payload);
      }
    }
  }

  Future<void> createQuickJournalEntry(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;

    await ref
        .read(todayJournalProvider.notifier)
        .addEntry(JournalEntry(body: body, date: DateTime.now()));
    await NotificationService().showQuickCaptureNotification();
  }

  Future<void> createQuickTaskFromNaturalLanguage(String text) async {
    final parsed = _parseQuickTask(text);
    if (parsed.title.isEmpty) return;

    await ref
        .read(tasksProvider.notifier)
        .addTask(
          Task(
            title: parsed.title,
            stage: TaskStage.todo,
            priority: parsed.priority,
            startDate: parsed.date,
            endDate: parsed.date,
            scheduledTime: parsed.time,
            reminderDate: parsed.date != null && parsed.time != null
                ? _combineDateAndTime(parsed.date!, parsed.time!)
                : null,
            scheduler: parsed.scheduler,
            notes: parsed.notes.isEmpty ? const [] : [parsed.notes],
          ),
        );
    await NotificationService().showQuickCaptureNotification();
  }

  Future<void> createQuickHabit(String text) async {
    final title = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (title.isEmpty) return;

    await ref
        .read(habitsProvider.notifier)
        .addHabit(
          Habit(
            title: title,
            color: '#F97316',
            icon: 'check_circle',
            dailyGoal: 1,
            slots: [HabitSlot(label: 'Padrão')],
            schedulers: [
              Scheduler(
                startDate: DateTime.now(),
                rules: [
                  SchedulerRule(
                    repeatType: RepeatType.numberOfDays,
                    interval: 1,
                  ),
                ],
              ),
            ],
            habitStartDate: DateTime.now(),
          ),
        );
    await NotificationService().showQuickCaptureNotification();
  }

  _ParsedQuickTask _parseQuickTask(String rawText) {
    var text = rawText.trim().replaceAll(RegExp(r'\s+'), ' ');
    DateTime? date;
    String? time;
    TaskPriority priority = TaskPriority.none;
    Scheduler? scheduler;
    final notes = <String>[];
    final now = DateTime.now();

    final timeMatch = RegExp(
      r'\b(?:às|as|at)?\s*(\d{1,2})(?::|h)(\d{2})?\b',
    ).firstMatch(text.toLowerCase());
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(1) ?? '');
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      if (hour != null && hour >= 0 && hour <= 23 && minute <= 59) {
        time =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        text = text.replaceFirst(timeMatch.group(0)!, '').trim();
      }
    }

    final lower = text.toLowerCase();
    if (lower.contains('amanhã') || lower.contains('amanha')) {
      date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      text = text.replaceAll(
        RegExp(r'\bamanh[ãa]\b', caseSensitive: false),
        '',
      );
    } else if (RegExp(r'\bhoje\b', caseSensitive: false).hasMatch(text)) {
      date = DateTime(now.year, now.month, now.day);
      text = text.replaceAll(RegExp(r'\bhoje\b', caseSensitive: false), '');
    }

    final dayMatch = RegExp(
      r'\b(?:até|ate|dia)\s+(\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (dayMatch != null) {
      final day = int.tryParse(dayMatch.group(1) ?? '');
      if (day != null && day >= 1 && day <= 31) {
        var candidate = DateTime(now.year, now.month, day);
        if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
          candidate = DateTime(now.year, now.month + 1, day);
        }
        date = candidate;
        text = text.replaceFirst(dayMatch.group(0)!, '').trim();
      }
    }

    final priorityPatterns = {
      TaskPriority.high: RegExp(
        r'\b(alta prioridade|prioridade alta|urgente)\b',
        caseSensitive: false,
      ),
      TaskPriority.medium: RegExp(
        r'\b(m[ée]dia prioridade|prioridade m[ée]dia)\b',
        caseSensitive: false,
      ),
      TaskPriority.low: RegExp(
        r'\b(baixa prioridade|prioridade baixa)\b',
        caseSensitive: false,
      ),
    };
    for (final entry in priorityPatterns.entries) {
      if (entry.value.hasMatch(text)) {
        priority = entry.key;
        text = text.replaceAll(entry.value, '').trim();
        break;
      }
    }

    final weekdays = {
      'segunda': 'monday',
      'terça': 'tuesday',
      'terca': 'tuesday',
      'quarta': 'wednesday',
      'quinta': 'thursday',
      'sexta': 'friday',
      'sábado': 'saturday',
      'sabado': 'saturday',
      'domingo': 'sunday',
    };
    final repeatMatch = RegExp(
      r'\b(todo|toda|todos|todas)\s+(segunda|terça|terca|quarta|quinta|sexta|sábado|sabado|domingo)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (repeatMatch != null) {
      final weekday = weekdays[repeatMatch.group(2)!.toLowerCase()];
      if (weekday != null) {
        scheduler = Scheduler(
          startDate: DateTime(now.year, now.month, now.day),
          rules: [
            SchedulerRule(
              repeatType: RepeatType.daysOfWeek,
              daysOfWeek: [weekday],
            ),
          ],
        );
        notes.add('Recurrence detected: ${repeatMatch.group(0)}.');
        text = text.replaceFirst(repeatMatch.group(0)!, '').trim();
      }
    }

    return _ParsedQuickTask(
      title: text.replaceAll(RegExp(r'\s+'), ' ').trim(),
      date: date,
      time: time,
      priority: priority,
      scheduler: scheduler,
      notes: notes.join('\n'),
    );
  }

  DateTime _combineDateAndTime(DateTime date, String time) {
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts.first) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  /// Extracts the object ID (uuid) from a notification payload string.
  /// Supports both `?id=<uuid>` and `?oid=<uuid>` query params, and the
  /// legacy format where the payload IS the object id.
  String? _objectIdFromNotificationPayload(String payload) {
    if (payload.isEmpty) return null;
    final uri = Uri.tryParse(payload);
    if (uri != null) {
      final id = uri.queryParameters['oid'] ?? uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) return id;
    }
    // Legacy: payload is plain object id
    final clean = payload.split('?').first.split('&').first.trim();
    return clean.isNotEmpty ? clean : null;
  }

  /// Marks the notification target as done — Task → finalized,
  /// Reminder → isCompleted, Habit → toggle for today.
  Future<void> _markNotificationTargetDone(String objectId) async {
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final target = allObjects.where((o) => o.id == objectId).firstOrNull;
    if (target == null) {
      debugPrint('NotificationAction done: object $objectId not found');
      return;
    }

    try {
      if (target is Task) {
        // Use copyWith — never mutate Task fields directly
        final updated = target.copyWith(
          stage: TaskStage.finalized,
          reflection: target.reflection ?? 'Concluído via notificação.',
        );
        await ref.read(tasksProvider.notifier).updateTask(updated);
        await _completeContactTaskIfNeeded(updated);
      } else if (target is Reminder) {
        // Reminder is a mutable model — set field then persist
        target.isCompleted = true;
        await ref.read(remindersProvider.notifier).updateReminder(target);
      } else if (target is Habit) {
        await ref
            .read(habitsProvider.notifier)
            .toggleHabit(target, DateTime.now());
      }
      debugPrint('NotificationAction done: marked $objectId as done');
    } catch (e) {
      debugPrint('NotificationAction done: error for $objectId: $e');
    }
  }

  /// Dismisses the notification without completing the object.
  /// Simply touches updatedAt so the object is not re-alerted.
  Future<void> _recordNotificationDismissal(String objectId) async {
    // No-op is acceptable — cancellation already happened in notification_service.
    // We just log it.
    debugPrint('NotificationAction dismiss: $objectId dismissed');
  }

  /// Re-schedules a reminder for [objectId] based on the snooze duration
  /// encoded in the payload (defaults to 10 min).
  Future<void> _snoozeNotification(String objectId, String payload) async {
    final snoozeMinutes = _snoozeMinutesFromPayload(payload);
    final fireAt = DateTime.now().add(Duration(minutes: snoozeMinutes));

    // Find the object to re-use its title
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final target = allObjects.where((o) => o.id == objectId).firstOrNull;
    final title = target?.title ?? 'Lembrete';

    final notifId = DateTime.now().millisecondsSinceEpoch % 100000;
    await NotificationService().scheduleReminder(
      id: notifId,
      title: title,
      config: ReminderConfig(
        id: '${objectId}_snooze_$notifId',
        triggerTime: fireAt,
        type: NotificationType.push,
        notificationBody: 'Adiado por ${snoozeMinutes}min',
        snoozeMinutes: snoozeMinutes,
      ),
      payload: objectId,
    );
    debugPrint(
      'NotificationAction snooze: $objectId snoozed for ${snoozeMinutes}min',
    );
  }

  int _snoozeMinutesFromPayload(String payload) {
    final match = RegExp(r'snooze=(\d+)').firstMatch(payload);
    return int.tryParse(match?.group(1) ?? '') ?? 10;
  }

  Future<void> _completeContactTaskIfNeeded(Task task) async {
    final title = task.title.toLowerCase();
    if (!title.startsWith('contact ') && !title.startsWith('contatar ')) {
      return;
    }

    final personRef = task.organizers
        .where((organizer) => organizer.type == 'person')
        .firstOrNull;
    if (personRef == null) return;

    final people = ref.read(peopleProvider);
    final person = people
        .where(
          (candidate) =>
              candidate.id == personRef.slug ||
              candidate.slug == personRef.slug,
        )
        .firstOrNull;
    if (person == null) return;

    final updatedPerson = person.copyWith(lastContactDate: DateTime.now());
    await ref.read(peopleProvider.notifier).updatePerson(updatedPerson);
    await archiveObject(task);
  }

  Future<void> _generateWeeklyReviewDraft() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final tasks = ref.read(tasksProvider);
    final completedThisWeek = tasks
        .where(
          (t) =>
              t.stage == TaskStage.finalized &&
              t.updatedAt.isAfter(startOfWeek) &&
              t.updatedAt.isBefore(endOfWeek),
        )
        .length;

    final body =
        '''
### 📈 Weekly Review
**Semana:** ${startOfWeek.day}/${startOfWeek.month} a ${endOfWeek.day}/${endOfWeek.month}

**Estatísticas Rápidas:**
- Tarefas concluídas: $completedThisWeek
- Maior vitória da semana: 
- O que poderia ter sido melhor: 
- Foco para a próxima semana: 

**Revisão de Metas e Projetos:**
- 

**Limpeza:**
- [ ] Inbox zero (Email, Slack, App)
- [ ] Arquivar notas e tarefas antigas
- [ ] Revisar calendário da próxima semana
''';

    await ref
        .read(todayJournalProvider.notifier)
        .addEntry(
          JournalEntry(id: const Uuid().v4(), body: body, date: DateTime.now()),
        );

    debugPrint('Weekly review draft generated.');
  }
}

final vaultProvider = NotifierProvider<VaultNotifier, void>(
  () => VaultNotifier(),
);

// ─── Inbox ───────────────────────────────────────────────────────────────────

class InboxNotifier extends AsyncNotifier<List<InboxItem>> {
  final List<String> autoArchivedTitles = [];

  void clearAutoArchived() {
    autoArchivedTitles.clear();
  }

  @override
  Future<List<InboxItem>> build() async {
    return _load();
  }

  Future<List<InboxItem>> _load() async {
    final obsidian = ref.read(obsidianServiceProvider);
    try {
      final files = await obsidian.getFilesInFolder('inbox');
      final items = <InboxItem>[];
      final now = DateTime.now();
      for (final file in files) {
        if (!file.path.endsWith('.md')) continue;
        try {
          final content = await file.readAsString();
          final fm = MarkdownParser.parseFrontmatter(content);
          final body = MarkdownParser.extractBody(content);
          final item = InboxItem.fromMarkdown(fm, body);
          // Derive path from file
          final vaultRoot = obsidian.vaultPath;
          final rel = file.path
              .replaceAll('\\', '/')
              .replaceFirst(vaultRoot.replaceAll('\\', '/'), '')
              .replaceFirst(RegExp(r'^/'), '');
          item.obsidianPath = rel;

          // Auto-archive items older than 30 days through VaultNotifier so
          // deletion, sync queue, reminders and widget updates stay consistent.
          if (now.difference(item.createdAt).inDays > 30) {
            await ref.read(vaultProvider.notifier).deleteObject(item);
            autoArchivedTitles.add(item.title);
            continue;
          }

          items.add(item);
        } catch (e) {
          debugPrint('Inbox parse error: $e');
        }
      }
      // Oldest first for triaging
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (e) {
      debugPrint('Inbox load error: $e');
      return [];
    }
  }

  Future<void> addItem(String text) async {
    final now = DateTime.now();
    final slug =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    final item = InboxItem(title: text.trim(), content: '', createdAt: now);
    item.obsidianPath = 'app/$slug.md';
    await ref.read(vaultProvider.notifier).createObject(item);
    ref.invalidateSelf();
  }

  Future<void> deleteItem(InboxItem item) async {
    await ref.read(vaultProvider.notifier).deleteObject(item);
    ref.invalidateSelf();
  }

  Future<void> triageItem(InboxItem item) async {
    // Just delete from inbox after triaging — caller will create new object
    await deleteItem(item);
  }

  int get pendingCount => state.valueOrNull?.length ?? 0;
}

final inboxProvider = AsyncNotifierProvider<InboxNotifier, List<InboxItem>>(
  () => InboxNotifier(),
);

final inboxCountProvider = Provider<int>((ref) {
  return ref.watch(inboxProvider).valueOrNull?.length ?? 0;
});

