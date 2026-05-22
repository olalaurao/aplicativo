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
import '../models/journal_entry.dart';
import '../models/habit_model.dart';
import '../models/organizer_model.dart' as organizer_model;
import '../models/goal_model.dart';
import '../models/note_model.dart';
import '../models/tracker_model.dart';
import '../models/mood_model.dart';
import '../models/analysis_model.dart';
import '../models/resource_model.dart';
import '../models/people_model.dart';
import '../models/project_model.dart';
import '../models/snapshot_model.dart';
import '../models/scheduler.dart';
import '../models/day_theme_model.dart';
import '../models/template_model.dart';
import '../models/inbox_model.dart';

import '../models/sync_action.dart';
import '../services/sync_queue_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../models/reminder_model.dart';
import '../models/reminder_config.dart';
import '../services/automation_service.dart';
import '../models/shared_types.dart' as shared_types;
import '../services/widget_service.dart';
import 'settings_provider.dart';
import '../services/google_drive_sync_service.dart';

final obsidianServiceProvider = Provider<ObsidianService>((ref) {
  final service = ObsidianService();
  final settings = ref.watch(settingsProvider);
  service.initVault(settings.vaultName, customPath: settings.vaultPath);
  return service;
});

String getDailyNoteTemplate(String dateStr, List<DayTheme> dayThemes) {
  const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
  final dayName = weekDayNames[parsedDate.weekday - 1];
  final activeTheme = dayThemes.cast<DayTheme?>().firstWhere(
    (theme) => theme?.daysOfWeek.contains(dayName) ?? false,
    orElse: () => null,
  );
  final themeSlug = activeTheme?.id ?? '';
  return '---\n'
      'date: $dateStr\n'
      'type: daily_note\n'
      'day_theme: $themeSlug\n'
      '---\n\n'
      '# $dateStr\n';
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
  final asyncAll = ref.watch(allObjectsProvider);
  final all = asyncAll.valueOrNull ?? [];
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

    // Schedule notification if needed
    if (task.reminderDate != null &&
        task.reminderDate!.isAfter(DateTime.now())) {
      await NotificationService().scheduleNotification(
        id: task.id.hashCode,
        title: 'Lembrete: ${task.title}',
        body: 'Your task is scheduled for now.',
        scheduledDate: task.reminderDate!,
        payload: task.id,
      );
    }
  }

  Future<void> updateTask(Task task) async {
    state = [
      for (final t in state)
        if (t.id == task.id) task else t,
    ];

    await ref.read(vaultProvider.notifier).updateObject(task);
  }

  Future<void> deleteTask(Task task) async {
    state = state.where((t) => t.id != task.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(task);
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<Task>>(() {
  return TasksNotifier();
});

class HabitsNotifier extends Notifier<List<Habit>> {
  @override
  List<Habit> build() {
    return ref.watch(objectsByTypeProvider('habit')).cast<Habit>();
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
          getDailyNoteTemplate(dateStr, dayThemes);

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
        slots[slotIndex] = !_isTruthyCompletion(slots[slotIndex]);
        habitsMap[habit.slug] = slots;
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

      frontmatter['habits'] = habitsMap;

      // Preserve all other sections.
      final entries = MarkdownParser.parseJournalEntries(body, dateStr);
      final tasks = MarkdownParser.parseTasksFromDailyNote(body);
      final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
      final pomodoros = MarkdownParser.parsePomodoros(body);

      final newBody = MarkdownParser.generateDailyNoteBody(
        entries: entries,
        tasks: tasks,
        habits: habitsMap,
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
      final updatedHabit = _updateHabitCompletionState(
        habit,
        date,
        habitsMap[habit.slug],
      );
      state = [
        for (final h in state)
          if (h.id == updatedHabit.id) updatedHabit else h,
      ];

      ref.invalidate(allObjectsProvider);

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

      if (_isHabitValueComplete(habit, habitsMap[habit.slug])) {
        await AutomationService.executeHabitActions(ref, habit, date);
      }
    } catch (e, st) {
      debugPrint('Error toggling habit ${habit.id} on $dateStr: $e\n$st');
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
        getDailyNoteTemplate(dateStr, dayThemes);

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

    frontmatter['habits'] = habitsMap;

    final entries = MarkdownParser.parseJournalEntries(body, dateStr);
    final tasks = MarkdownParser.parseTasksFromDailyNote(body);
    final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
    final pomodoros = MarkdownParser.parsePomodoros(body);

    final newBody = MarkdownParser.generateDailyNoteBody(
      entries: entries,
      tasks: tasks,
      habits: habitsMap,
      trackers: trackers,
      pomodoros: pomodoros,
    );

    final newContent = generateMarkdown(frontmatter, newBody);
    await obsidianService.writeFile(path, newContent);

    ref.invalidate(allObjectsProvider);
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

class OrganizersNotifier extends Notifier<List<organizer_model.Organizer>> {
  @override
  List<organizer_model.Organizer> build() {
    return ref
        .watch(objectsByTypeProvider('organizer'))
        .cast<organizer_model.Organizer>();
  }

  Future<void> addOrganizer(organizer_model.Organizer organizer) async {
    state = [...state, organizer];
    if (!organizer.categories.contains('[[organizers]]')) {
      organizer.categories.add('[[organizers]]');
    }
    await ref.read(vaultProvider.notifier).createObject(organizer);
  }

  Future<void> updateOrganizer(organizer_model.Organizer organizer) async {
    state = [
      for (final o in state)
        if (o.id == organizer.id) organizer else o,
    ];
    await ref.read(vaultProvider.notifier).updateObject(organizer);
  }

  Future<void> deleteOrganizer(organizer_model.Organizer organizer) async {
    state = state.where((o) => o.id != organizer.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(organizer);
  }
}

final organizersProvider =
    NotifierProvider<OrganizersNotifier, List<organizer_model.Organizer>>(() {
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
  final record = TrackingRecord(
    title: '${tracker.title} ${date.toIso8601String().split('T').first}',
    trackerId: tracker.id,
    date: date,
    fieldValues: Map<String, dynamic>.from(values),
    organizers: tracker.organizers,
    categories: const ['[[tracker_records]]'],
  );
  await ref.read(trackingRecordsProvider.notifier).addRecord(record);
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
    final people = ref.watch(objectsByTypeProvider('person')).cast<Person>();

    if (people.isNotEmpty) {
      Future.microtask(
        () => AutomationService.checkPersonContacts(ref, people),
      );
    }

    return people;
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
    state = [
      for (final g in state)
        if (g.id == goal.id) goal else g,
    ];
    await ref.read(vaultProvider.notifier).updateObject(goal);
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

final aggregatedRemindersProvider = Provider<List<Reminder>>((ref) {
  final asyncAll = ref.watch(allObjectsProvider);
  final all = asyncAll.valueOrNull ?? [];
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
        .whereType<organizer_model.Organizer>()
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
  @override
  List<MoodDefinition> build() {
    final asyncValue = ref.watch(allObjectsProvider);
    final data = asyncValue.valueOrNull;

    if (data != null) {
      return data.whereType<MoodDefinition>().toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    }

    return [];
  }

  Future<void> addMood(MoodDefinition mood) async {
    state = [...state, mood];
    await ref.read(vaultProvider.notifier).createObject(mood);
  }

  Future<void> updateMood(MoodDefinition mood) async {
    state = [
      for (final m in state)
        if (m.id == mood.id) mood else m,
    ]..sort((a, b) => a.order.compareTo(b.order));
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
    state = [...state, analysis];
    await ref.read(vaultProvider.notifier).createObject(analysis);
  }

  Future<void> updateAnalysis(CombinedAnalysis analysis) async {
    state = [
      for (final a in state)
        if (a.id == analysis.id) analysis else a,
    ];
    await ref.read(vaultProvider.notifier).updateObject(analysis);
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

class TimeBlocksNotifier extends Notifier<List<TimeBlock>> {
  @override
  List<TimeBlock> build() {
    return ref.watch(objectsByTypeProvider('time_block')).cast<TimeBlock>();
  }

  Future<void> addTimeBlock(TimeBlock timeBlock) async {
    state = [...state, timeBlock];
    await ref.read(vaultProvider.notifier).createObject(timeBlock);
  }

  Future<void> updateTimeBlock(TimeBlock timeBlock) async {
    state = [
      for (final t in state)
        if (t.id == timeBlock.id) timeBlock else t,
    ];
    await ref.read(vaultProvider.notifier).updateObject(timeBlock);
  }

  Future<void> deleteTimeBlock(TimeBlock timeBlock) async {
    state = state.where((t) => t.id != timeBlock.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(timeBlock);
  }
}

final timeBlocksProvider =
    NotifierProvider<TimeBlocksNotifier, List<TimeBlock>>(() {
      return TimeBlocksNotifier();
    });

class DayThemesNotifier extends Notifier<List<DayTheme>> {
  @override
  List<DayTheme> build() {
    return ref.watch(objectsByTypeProvider('day_theme')).cast<DayTheme>();
  }

  Future<void> addDayTheme(DayTheme dayTheme) async {
    state = [...state, dayTheme];
    await ref.read(vaultProvider.notifier).createObject(dayTheme);
  }

  Future<void> updateDayTheme(DayTheme dayTheme) async {
    state = [
      for (final d in state)
        if (d.id == dayTheme.id) dayTheme else d,
    ];
    await ref.read(vaultProvider.notifier).updateObject(dayTheme);
  }

  Future<void> deleteDayTheme(DayTheme dayTheme) async {
    state = state.where((d) => d.id != dayTheme.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(dayTheme);
  }
}

final dayThemesProvider = NotifierProvider<DayThemesNotifier, List<DayTheme>>(
  () {
    return DayThemesNotifier();
  },
);

class TemplatesNotifier extends Notifier<List<TemplateDefinition>> {
  @override
  List<TemplateDefinition> build() {
    final list = ref
        .watch(objectsByTypeProvider('template'))
        .cast<TemplateDefinition>();
    if (list.isEmpty) {
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
        templateType: 'note',
        body:
            '# Pauta\n- [ ] O que correu bem\n- [ ] Desafios e bloqueios\n- [ ] Próximos passos\n\n# Notas da Reunião\n\n# Ações\n',
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
        templateType: 'note',
        body:
            '# Planejamento da Sprint\n\n## Objetivos da Sprint\n- [ ] \n\n## Backlog Priorizado\n- [ ] \n\n## Riscos e Impedimentos\n',
      ),
      TemplateDefinition.create(
        title: 'Projeto novo',
        templateType: 'note',
        body:
            '# Escopo do Projeto\n\n## Visão Geral\n\n## Objetivos e Entregáveis\n- [ ] \n\n## Recursos Necessários\n\n## Cronograma Estimado\n- Fase 1: \n- Fase 2: \n',
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
    final typeSignatures = settings.typeSignatures;

    List<ContentObject> results = [];
    Map<String, List<Map<String, dynamic>>> dailyHabitCompletions = {};
    Map<String, List<Map<String, dynamic>>> dailyTrackerRecords = {};

    // 1. Fetch all markdown files (single call)
    final mdFiles = (await service.getFilesInFolder(
      '',
    )).where((f) => f.path.endsWith('.md')).toList();

    // 2. Read and parse files in parallel batches (max 50 concurrent I/O ops)
    const batchSize = 50;
    final Map<String, Map<String, dynamic>> dailyMap = {};

    for (int i = 0; i < mdFiles.length; i += batchSize) {
      final end = (i + batchSize < mdFiles.length)
          ? i + batchSize
          : mdFiles.length;
      final batch = mdFiles.sublist(i, end);

      await Future.wait(
        batch.map((file) async {
          try {
            final relativePath = service.getRelativePath(file.path);
            final content = await file.readAsString();
            final frontmatter = MarkdownParser.parseFrontmatter(content);
            final body = MarkdownParser.extractBody(content);

            final isDaily = relativePath.split('/').contains('daily');
            String? type = frontmatter['type'];

            final entries = typeSignatures.entries.toList();
            final organizerIdx = entries.indexWhere(
              (e) => e.key == 'organizer',
            );
            if (organizerIdx != -1) {
              final orgEntry = entries.removeAt(organizerIdx);
              entries.add(orgEntry);
            }

            for (final entry in entries) {
              if (MarkdownParser.matchesSignature(
                frontmatter,
                body,
                relativePath,
                entry.value,
              )) {
                type = entry.key;
                break;
              }
            }

            if (isDaily || type == 'daily_note') {
              final dateMatch = RegExp(
                r'(\d{4}-\d{2}-\d{2})',
              ).firstMatch(relativePath);
              if (dateMatch != null) {
                final dateStr = dateMatch.group(1)!;
                final entriesData = MarkdownParser.parseJournalEntries(
                  body,
                  dateStr,
                );
                final List<JournalEntry> journalEntries = [];

                for (final data in entriesData) {
                  final entry = JournalEntry(
                    id: data['id'],
                    body: data['body'],
                    date: _journalEntryDateFromDaily(
                      dateStr,
                      data['time']?.toString(),
                    ),
                    title: data['title']?.toString().isNotEmpty == true
                        ? data['title']
                        : data['time'],
                    moodSlug: data['mood'],
                    obsidianPath: relativePath,
                  );
                  if (data['organizers'] != null) {
                    entry.organizers = (data['organizers'] as List)
                        .map<shared_types.OrganizerReference>(
                          (o) => o is shared_types.OrganizerReference
                              ? o
                              : shared_types.OrganizerReference.fromWikiLink(
                                  o.toString(),
                                ),
                        )
                        .toList();
                  }
                  journalEntries.add(entry);
                  results.add(entry);
                }

                final habits = MarkdownParser.parseHabitCompletions(
                  frontmatter,
                );
                if (habits.isNotEmpty) {
                  dailyHabitCompletions[dateStr] = habits.entries
                      .map((e) => {'slug': e.key, 'value': e.value})
                      .toList();
                }

                final trackers = MarkdownParser.parseTrackerRecords(
                  frontmatter,
                );
                if (trackers.isNotEmpty) {
                  dailyTrackerRecords[dateStr] = trackers.entries
                      .map((e) => {'slug': e.key, 'values': e.value})
                      .toList();
                }

                // Store in dailyMap for the O(1) provider
                dailyMap[dateStr] = {
                  'entries': journalEntries,
                  'habitCompletions': habits,
                  'habits': habits,
                  'trackerRecords': trackers,
                  'frontmatter': frontmatter,
                };
              }
            } else {
              // Normal content object
              final fallbackTitle = relativePath
                  .split('/')
                  .last
                  .replaceAll('.md', '');
              final stableId = relativePath
                  .replaceAll('/', '_')
                  .replaceAll('.md', '');
              ContentObject? obj;

              if (type == 'task') {
                obj = Task.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'habit') {
                obj = Habit.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'project' ||
                  (type == 'organizer' &&
                      frontmatter['organizer_type'] == 'project')) {
                obj = Project.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'person' ||
                  (type == 'organizer' &&
                      frontmatter['organizer_type'] == 'person')) {
                obj = Person.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'organizer' ||
                  type == 'area' ||
                  type == 'activity' ||
                  type == 'place' ||
                  type == 'label') {
                if (frontmatter['organizer_type'] == null &&
                    type != 'organizer') {
                  frontmatter['organizer_type'] = type;
                }
                obj = organizer_model.Organizer.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'resource') {
                obj = Resource.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'goal') {
                obj = Goal.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'note') {
                obj = Note.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'tracker_definition') {
                obj = TrackerDefinition.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'mood_definition') {
                obj = MoodDefinition.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'reminder') {
                obj = Reminder.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'tracker_record') {
                obj = TrackingRecord.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'combined_analysis') {
                obj = CombinedAnalysis.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'snapshot') {
                obj = Snapshot.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'time_block') {
                obj = TimeBlock.fromMap(frontmatter, body: body)
                  ..obsidianPath = relativePath;
              } else if (type == 'day_theme') {
                obj = DayTheme.fromMap(frontmatter, body: body)
                  ..obsidianPath = relativePath;
              } else if (type == 'template') {
                obj = TemplateDefinition.fromMap(
                  frontmatter,
                  stableId,
                  body: body,
                )..obsidianPath = relativePath;
              } else {
                obj = Note(
                  id: stableId,
                  title: frontmatter['title'] ?? fallbackTitle,
                  body: body,
                  subtype: NoteSubtype.text,
                  organizers: [
                    shared_types.OrganizerReference(
                      type: 'person',
                      slug: 'placeholder',
                      title: 'placeholder',
                    ),
                  ],
                )..obsidianPath = relativePath;
              }

              obj.loadBaseMap(frontmatter, fallbackId: stableId);
              if (obj.title == 'Untitled' ||
                  obj.title.toLowerCase() == 'untitled' ||
                  obj.title.isEmpty) {
                obj.title = fallbackTitle;
              }
              results.add(obj);
            }
          } catch (e, st) {
            debugPrint('Error processing file ${file.path}: $e\n$st');
          }
        }),
      );
    }

    // 3. Update the daily data map
    Future.microtask(() {
      ref.read(_dailyNoteDataMapProvider.notifier).state = dailyMap;
    });

    // Deduplicate by ID
    final uniqueResults = <String, ContentObject>{};
    for (final r in results) {
      uniqueResults[r.id] = r;
    }
    List<ContentObject> finalResults = uniqueResults.values.toList();

    // Post-process Habits and Trackers
    for (final habit in finalResults.whereType<Habit>()) {
      habit.completionHistory.clear();
      dailyHabitCompletions.forEach((dateStr, completions) {
        final completion = completions.firstWhere(
          (c) => c['slug'] == habit.slug,
          orElse: () => {},
        );
        if (completion.isNotEmpty) {
          final val = completion['value'];
          bool successful = false;
          int count = 0;
          List<bool>? slotCompletions;

          if (val is bool) {
            successful = val;
            count = val ? habit.dailyGoal : 0;
            slotCompletions = List.filled(habit.dailyGoal, val);
          } else if (val is num) {
            count = val.toInt();
            successful = count >= habit.dailyGoal;
            slotCompletions = List.generate(habit.dailyGoal, (i) => i < count);
          } else if (val is List) {
            slotCompletions = val.map((v) => v == true).toList();
            count = slotCompletions.where((v) => v).length;
            successful = count >= habit.dailyGoal;
          }

          habit.completionHistory.add(
            CompletionRecord(
              date: DateTime.parse(dateStr),
              completions: count,
              slotCompletions: slotCompletions,
              successful: successful,
            ),
          );
        }
      });
      habit.completionHistory.sort((a, b) => a.date.compareTo(b.date));
    }

    final List<TrackingRecord> newRecords = [];
    for (final dateStr in dailyTrackerRecords.keys) {
      for (final recordData in dailyTrackerRecords[dateStr]!) {
        final trackerSlug = recordData['slug'];
        final values = Map<String, dynamic>.from(recordData['values'] as Map);
        newRecords.add(
          TrackingRecord(
            title: 'Record from $dateStr',
            trackerId: trackerSlug,
            date: DateTime.parse(dateStr),
            fieldValues: values,
          )..obsidianPath = 'daily/$dateStr.md',
        );
      }
    }

    finalResults.addAll(newRecords);

    // Final deduplication just in case
    final Map<String, ContentObject> deduplicated = {};
    for (final obj in finalResults) {
      if (obj.id.isNotEmpty) {
        deduplicated[obj.id] = obj;
      }
    }
    return deduplicated.values.toList();
  }

  Future<void> updateObject(ContentObject object) async {
    final service = ref.read(obsidianServiceProvider);
    await service.writeFile(object.obsidianPath, object.toMarkdown());
    ref.invalidateSelf();
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

  return allObjects.where((obj) {
    if (obj.id == targetId) return false;
    if (obj.organizers.any(
      (ref) => ref.slug == targetId || ref.slug == targetSlug,
    )) {
      return true;
    }
    final content = obj.toMarkdown().toLowerCase();
    return content.contains('[[${targetSlug.toLowerCase()}]]') ||
        content.contains('[[${target.title.toLowerCase()}]]');
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
        getDailyNoteTemplate(dateStr, dayThemes);

    final frontmatter = MarkdownParser.parseFrontmatter(content);
    final body = MarkdownParser.extractBody(content);

    // Parse existing sections
    final entries = MarkdownParser.parseJournalEntries(body, dateStr);
    final tasks = MarkdownParser.parseTasksFromDailyNote(body);
    final habits = MarkdownParser.parseHabitCompletions(frontmatter);
    final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
    final pomodoros = MarkdownParser.parsePomodoros(body);

    // Add new entry
    final time =
        '${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')}';
    entries.add({
      'time': time,
      'title': entry.title,
      'body': entry.body,
      'mood': entry.moodSlug,
      'organizers': entry.organizers,
      'date': '$dateStr $time',
    });

    // Sort by time
    entries.sort((a, b) => a['time'].compareTo(b['time']));

    // Update daily mood in frontmatter if provided
    if (entry.moodSlug != null) {
      frontmatter['mood'] = entry.moodSlug;
    }

    final newBody = MarkdownParser.generateDailyNoteBody(
      entries: entries,
      tasks: tasks,
      habits: habits,
      trackers: trackers,
      pomodoros: pomodoros,
    );

    final newContent = generateMarkdown(frontmatter, newBody);

    // 2. Write to local disk
    await obsidianService.writeFile(relativePath, newContent);

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
        getDailyNoteTemplate(dateStr, dayThemes);

    final frontmatter = MarkdownParser.parseFrontmatter(content);
    final body = MarkdownParser.extractBody(content);
    final entries = MarkdownParser.parseJournalEntries(body, dateStr);
    final tasks = MarkdownParser.parseTasksFromDailyNote(body);
    final habits = MarkdownParser.parseHabitCompletions(frontmatter);
    final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
    final pomodoros = MarkdownParser.parsePomodoros(body);

    final originalTime =
        '${sourceEntry.date.hour.toString().padLeft(2, '0')}:${sourceEntry.date.minute.toString().padLeft(2, '0')}';
    final originalTitle = sourceEntry.title.trim();
    final replacementTime =
        '${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')}';
    final replacement = {
      'time': replacementTime,
      'title': entry.title.trim(),
      'body': entry.body,
      'mood': entry.moodSlug,
      'organizers': entry.organizers,
      'date': '$dateStr $replacementTime',
    };

    final index = entries.indexWhere((candidate) {
      final sameTime = candidate['time'] == originalTime;
      final title = (candidate['title'] as String? ?? '').trim();
      return sameTime && (originalTitle.isEmpty || title == originalTitle);
    });
    if (index >= 0) {
      entries[index] = replacement;
    } else {
      entries.add(replacement);
    }

    entries.sort((a, b) => a['time'].compareTo(b['time']));
    if (entry.moodSlug != null) {
      frontmatter['mood'] = entry.moodSlug;
    }

    final newBody = MarkdownParser.generateDailyNoteBody(
      entries: entries,
      tasks: tasks,
      habits: habits,
      trackers: trackers,
      pomodoros: pomodoros,
    );
    final newContent = generateMarkdown(frontmatter, newBody);
    await obsidianService.writeFile(relativePath, newContent);
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

    final originalTime =
        '${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')}';
    final originalTitle = entry.title.trim();

    final index = entries.indexWhere((candidate) {
      final sameTime = candidate['time'] == originalTime;
      final title = (candidate['title'] as String? ?? '').trim();
      return sameTime && (originalTitle.isEmpty || title == originalTitle);
    });

    if (index >= 0) {
      entries.removeAt(index);
    }

    final newBody = MarkdownParser.generateDailyNoteBody(
      entries: entries,
      tasks: tasks,
      habits: habits,
      trackers: trackers,
      pomodoros: pomodoros,
    );
    final newContent = generateMarkdown(frontmatter, newBody);
    await obsidianService.writeFile(relativePath, newContent);
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
  @override
  void build() {
    _purgeOldDeletedFiles();
  }

  String _signatureKeyFor(ContentObject object) {
    if (object is TrackerDefinition) return 'tracker_definition';
    if (object is TrackingRecord) return 'tracker_record';
    if (object is MoodDefinition) return 'mood_definition';
    if (object is CombinedAnalysis) return 'combined_analysis';
    if (object is TimeBlock) return 'time_block';
    if (object is DayTheme) return 'day_theme';
    if (object is TemplateDefinition) return 'template';
    if (object is organizer_model.Organizer) {
      return object.organizerType.name;
    }
    return object.type;
  }

  String _defaultFolderForSignature(String type) {
    return switch (type) {
      'task' => 'tasks',
      'habit' => 'habits',
      'goal' => 'goals',
      'note' => 'notes',
      'resource' => 'resources',
      'person' => 'organizers/people',
      'project' => 'organizers/projects',
      'area' => 'organizers/areas',
      'activity' => 'organizers/activities',
      'place' => 'organizers/places',
      'label' => 'organizers/labels',
      'organizer' => 'organizers',
      'tracker_definition' || 'tracker_record' => 'trackers',
      'mood_definition' => 'moods',
      'combined_analysis' => 'analyses',
      'snapshot' => 'snapshots',
      'time_block' => 'time_blocks',
      'day_theme' => 'day_themes',
      'template' => 'templates',
      'reminder' => 'reminders',
      _ => 'app',
    };
  }

  Future<void> _scheduleObjectReminders(ContentObject object) async {
    // Cancel previous reminders for this object using the current and legacy
    // ID schemes. Older builds used a hash per reminder config, so keep this
    // cleanup until those scheduled alarms naturally disappear from devices.
    final baseId = object.id.hashCode.abs() % 1000000;
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
          payload: object.id,
        );
      }
    }
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
    final baseId = object.id.hashCode.abs() % 1000000;
    for (int i = 0; i < 50; i++) {
      await NotificationService().cancelNotification(baseId + i);
    }
    for (final config in object.reminders) {
      final legacyReminderId = (object.id + config.id).hashCode.abs() % 1000000;
      await NotificationService().cancelNotification(legacyReminderId);
    }
  }

  Future<String> _writeObject(
    ContentObject object, {
    required SyncOperation operation,
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
      defaultFolder: _defaultFolderForSignature(signatureKey),
    );
    final relativePath = prepared['path']!;
    final oldPath = object.obsidianPath;

    if (operation == SyncOperation.update &&
        oldPath.isNotEmpty &&
        oldPath != relativePath) {
      await obsidianService.deleteFile(oldPath);
    }

    object.obsidianPath = relativePath;

    await obsidianService.writeFile(relativePath, prepared['markdown']!);
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

    Future.microtask(() => AutomationService.updateAllKPIs(ref));
    return relativePath;
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

    // 1. Move old file to _deleted/ and delete original
    if (object.obsidianPath.isNotEmpty) {
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
    }

    // 2. Map old object fields and body content to the new object
    String bodyContent = '';
    if (object is Task) {
      bodyContent = object.notes.join('\n');
    } else if (object is Habit) {
      bodyContent = object.description ?? '';
    } else if (object is Goal) {
      bodyContent = object.description ?? '';
    } else if (object is Note) {
      bodyContent = object.body;
    } else if (object is Project) {
      bodyContent = object.description ?? '';
    } else if (object is organizer_model.Organizer) {
      bodyContent = '';
    }

    ContentObject newObject;
    final baseId = object.id;
    final baseTitle = object.title;
    final baseCreatedAt = object.createdAt;
    final baseOrganizers = object.organizers;

    switch (targetType.toLowerCase()) {
      case 'task':
        newObject = Task(
          id: baseId,
          title: baseTitle,
          stage: TaskStage.idea,
          notes: bodyContent.isNotEmpty ? [bodyContent] : const [],
          createdAt: baseCreatedAt,
          organizers: baseOrganizers,
          categories: ['[[tasks]]'],
        );
        break;
      case 'habit':
        newObject = Habit(
          id: baseId,
          title: baseTitle,
          color: '#F97316',
          description: bodyContent,
          createdAt: baseCreatedAt,
          organizers: baseOrganizers,
          categories: ['[[habits]]'],
        );
        break;
      case 'goal':
        newObject = Goal(
          id: baseId,
          title: baseTitle,
          description: bodyContent,
          createdAt: baseCreatedAt,
          organizers: baseOrganizers,
          categories: ['[[goals]]'],
        );
        break;
      case 'note':
        newObject = Note(
          id: baseId,
          title: baseTitle,
          subtype: NoteSubtype.text,
          body: bodyContent,
          createdAt: baseCreatedAt,
          organizers: baseOrganizers,
          categories: ['[[notes]]'],
        );
        break;
      case 'project':
        newObject = Project(
          id: baseId,
          title: baseTitle,
          description: bodyContent,
          createdAt: baseCreatedAt,
          organizers: baseOrganizers,
          categories: ['[[projects]]'],
        );
        break;
      case 'organizer':
        final orgTypeStr = extraFields?['organizerType']?.toString() ?? 'area';
        final orgType = organizer_model.OrganizerType.values.firstWhere(
          (e) => e.name == orgTypeStr,
          orElse: () => organizer_model.OrganizerType.area,
        );
        newObject = organizer_model.Organizer(
          id: baseId,
          title: baseTitle,
          organizerType: orgType,
          createdAt: baseCreatedAt,
          organizers: baseOrganizers,
          categories: ['[[organizers]]'],
        );
        break;
      case 'person':
        newObject = Person(
          id: baseId,
          title: baseTitle,
          createdAt: baseCreatedAt,
          organizers: baseOrganizers,
          categories: ['[[people]]'],
        );
        break;
      case 'resource':
        newObject = Resource(
          id: baseId,
          title: baseTitle,
          resourceType: 'General',
          synopsis: bodyContent,
          createdAt: baseCreatedAt,
          organizers: baseOrganizers,
          categories: ['[[resources]]'],
        );
        break;
      case 'tracker':
      case 'tracker_definition':
        newObject = TrackerDefinition(
          id: baseId,
          title: baseTitle,
          description: bodyContent,
          createdAt: baseCreatedAt,
          organizers: baseOrganizers,
          categories: ['[[trackers]]'],
        );
        break;
      default:
        throw Exception('Unsupported conversion target type: $targetType');
    }

    // 3. Write new file and invalidate providers
    await _writeObject(newObject, operation: SyncOperation.create);

    _invalidateObjectProviders(object);
    _invalidateObjectProviders(newObject);
    await _updateWidgetsFor(newObject);
  }

  Future<void> _purgeOldDeletedFiles() async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final files = await obsidianService.getFilesInFolder('_deleted');
    final now = DateTime.now();

    for (final file in files) {
      final stat = await file.stat();
      final diff = now.difference(stat.modified);
      if (diff.inDays > 30) {
        await obsidianService.deleteFile(file.path);
      }
    }
  }

  Future<void> updateObject(ContentObject object) async {
    await _writeObject(object, operation: SyncOperation.update);
  }

  Future<void> archiveObject(ContentObject object) async {
    object.archived = true;
    await updateObject(object);
  }

  Future<void> unarchiveObject(ContentObject object) async {
    object.archived = false;
    await updateObject(object);
  }

  Future<void> deleteObject(ContentObject object) async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final syncQueue = ref.read(syncQueueServiceProvider);

    if (object.obsidianPath.isNotEmpty) {
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

  Future<void> _snoozeNotification(String objectId, String payload) async {
    final uri = Uri.tryParse(payload);
    final snoozeMinutes =
        int.tryParse(uri?.queryParameters['snooze'] ?? '10') ?? 10;

    final allObjects = await ref.read(allObjectsProvider.future);
    final target = allObjects.firstWhere(
      (o) => o.id == objectId,
      orElse: () => throw Exception('Object not found'),
    );

    final newTime = DateTime.now().add(Duration(minutes: snoozeMinutes));

    await NotificationService().scheduleReminder(
      id: objectId.hashCode,
      title: target.title,
      config: ReminderConfig(
        id: 'snooze_${objectId}_${DateTime.now().millisecondsSinceEpoch}',
        triggerTime: newTime,
        type: NotificationType.alarm, // Keep same type for snooze
      ),
      payload: payload,
    );
  }

  String? _objectIdFromNotificationPayload(String payload) {
    final uri = Uri.tryParse(payload);
    if (uri != null && uri.queryParameters['oid'] != null) {
      return uri.queryParameters['oid'];
    }
    if (uri != null && uri.queryParameters['id'] != null) {
      return uri.queryParameters['id'];
    }
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return payload.split('|').first.split('?').first;
  }

  Future<void> _markNotificationTargetDone(String objectId) async {
    final allObjects = await ref.read(allObjectsProvider.future);
    final target = allObjects
        .where((object) => object.id == objectId)
        .firstOrNull;
    if (target == null) return;

    if (target is Task) {
      target.stage = TaskStage.finalized;
      target.reflection ??= 'Completed from notification.';
      await ref.read(tasksProvider.notifier).updateTask(target);
      await _completeContactTaskIfNeeded(target);
    } else if (target is Reminder) {
      target.isCompleted = true;
      await ref.read(remindersProvider.notifier).updateReminder(target);
    } else if (target is Habit) {
      await ref
          .read(habitsProvider.notifier)
          .toggleHabit(target, DateTime.now());
    }
  }

  Future<void> _recordNotificationDismissal(String objectId) async {
    final allObjects = await ref.read(allObjectsProvider.future);
    final target = allObjects
        .where((object) => object.id == objectId)
        .firstOrNull;
    if (target == null) return;
    target.updatedAt = DateTime.now();
    await updateObject(target);
  }

  Future<void> _completeContactTaskIfNeeded(Task task) async {
    if (!task.title.toLowerCase().startsWith('contatar ')) return;

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

          // Auto-archive items older than 30 days
          if (now.difference(item.createdAt).inDays > 30) {
            final fileName = rel.split('/').last;
            await obsidian.writeFile('_deleted/$fileName', content);
            await obsidian.deleteFile(rel);
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
    final obsidian = ref.read(obsidianServiceProvider);
    final now = DateTime.now();
    final slug =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    final item = InboxItem(title: text.trim(), content: '', createdAt: now);
    item.obsidianPath = 'inbox/$slug.md';
    await obsidian.writeFile(item.obsidianPath, item.toMarkdown());
    ref.invalidateSelf();
  }

  Future<void> deleteItem(InboxItem item) async {
    final obsidian = ref.read(obsidianServiceProvider);
    // Move to _deleted
    if (item.obsidianPath.isNotEmpty) {
      final fileName = item.obsidianPath.split('/').last;
      final content = await obsidian.readFile(item.obsidianPath);
      if (content != null) {
        await obsidian.writeFile('_deleted/$fileName', content);
      }
      await obsidian.deleteFile(item.obsidianPath);
    }
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
