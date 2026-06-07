// lib/models/habit_model.dart
import 'package:flutter/material.dart';
import 'content_object.dart';
import 'shared_types.dart';
import 'scheduler.dart';
import 'journal_entry.dart';
import 'task_model.dart'; // For TaskPriority

import 'reminder_config.dart';

enum HabitStatus { active, paused, completed }

enum HabitInputType { boolean, numeric, mood, duration }

enum HabitMode { habit, pact }

enum PactOutcome { persist, pause, pivot }

class PactCycle {
  final DateTime startedAt;
  final DateTime endsAt;
  final PactOutcome outcome;
  final String? reflection;
  final bool? hypothesisCorrect;
  final String? endedReason;

  PactCycle({
    required this.startedAt,
    required this.endsAt,
    required this.outcome,
    this.reflection,
    this.hypothesisCorrect,
    this.endedReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'started_at': startedAt.toIso8601String().split('T').first,
      'ends_at': endsAt.toIso8601String().split('T').first,
      'outcome': outcome.name,
      if (reflection != null) 'reflection': reflection,
      if (hypothesisCorrect != null) 'hypothesis_correct': hypothesisCorrect,
      if (endedReason != null) 'ended_reason': endedReason,
    };
  }

  factory PactCycle.fromMap(Map<dynamic, dynamic> map) {
    bool? hypCorrect;
    if (map['hypothesis_correct'] != null) {
      if (map['hypothesis_correct'] is bool) {
        hypCorrect = map['hypothesis_correct'] as bool;
      } else if (map['hypothesis_correct'].toString().toLowerCase() == 'true') {
        hypCorrect = true;
      } else if (map['hypothesis_correct'].toString().toLowerCase() == 'false') {
        hypCorrect = false;
      }
    }
    return PactCycle(
      startedAt: DateTime.parse(map['started_at'].toString()),
      endsAt: DateTime.parse(map['ends_at'].toString()),
      outcome: PactOutcome.values.firstWhere(
        (e) => e.name == map['outcome'].toString(),
        orElse: () => PactOutcome.persist,
      ),
      reflection: map['reflection']?.toString(),
      hypothesisCorrect: hypCorrect,
      endedReason: map['ended_reason']?.toString(),
    );
  }
}

class HabitSlot {
  DateTime? time;
  bool completed;
  String? label;
  bool reminderEnabled;
  TimeOfDay? reminderTime;
  NotificationType notificationType;
  List<ActionDef> actions;

  HabitSlot({
    this.time,
    this.completed = false,
    this.label,
    this.reminderEnabled = false,
    this.reminderTime,
    this.notificationType = NotificationType.push,
    List<ActionDef>? actions,
  }) : actions = actions ?? [];
}

class CompletionRecord {
  DateTime date;
  int completions;
  List<bool>? slotCompletions;
  bool successful;
  double? value;
  List<Comment> comments;
  List<JournalEntry> journalEntries; // Or references

  CompletionRecord({
    required this.date,
    this.completions = 0,
    this.slotCompletions,
    this.successful = false,
    this.value,
    List<Comment>? comments,
    List<JournalEntry>? journalEntries,
  }) : comments = comments ?? [],
       journalEntries = journalEntries ?? [];
}

class Habit extends ContentObject {
  String? description;
  String color;
  String? icon;
  String completionUnit;
  int dailyGoal;
  List<HabitSlot> slots;
  List<Scheduler> schedulers;
  String? linkedTrackerSlug;
  String? timeBlock;
  List<CompletionRecord> completionHistory;
  List<ActionDef> actions;
  HabitStatus status;
  DateTime? habitStartDate;
  TaskPriority priority;
  int streak;
  bool isNegative;
  HabitInputType inputType;

  // Pact fields
  HabitMode habitMode;
  String? statement;
  String? curiosityQuestion;
  String? hypothesis;
  DateTime? startedAt;
  DateTime? endsAt;
  PactOutcome? pactOutcome;
  List<PactCycle> previousCycles;

  Scheduler? get scheduler => schedulers.isNotEmpty ? schedulers.first : null;
  set scheduler(Scheduler? s) {
    if (s == null) {
      schedulers = [];
    } else {
      schedulers = [s];
    }
  }

  Habit({
    super.id,
    required super.title,
    this.description,
    required this.color,
    this.icon,
    this.completionUnit = 'times',
    this.dailyGoal = 1,
    List<HabitSlot>? slots,
    List<Scheduler>? schedulers,
    this.linkedTrackerSlug,
    this.timeBlock,
    this.streak = 0,
    List<CompletionRecord>? completionHistory,
    List<ActionDef>? actions,
    this.status = HabitStatus.active,
    this.habitStartDate,
    this.priority = TaskPriority.none,
    super.archived,
    this.isNegative = false,
    this.inputType = HabitInputType.boolean,
    this.habitMode = HabitMode.habit,
    this.statement,
    this.curiosityQuestion,
    this.hypothesis,
    this.startedAt,
    this.endsAt,
    this.pactOutcome,
    List<PactCycle>? previousCycles,
    super.organizers,
    super.categories,
    super.tags,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : slots = slots ?? [],
       schedulers = schedulers ?? [],
       completionHistory = completionHistory ?? [],
       actions = actions ?? [],
       previousCycles = previousCycles ?? [];

  @override
  String get type => 'habit';

  @override
  List<ReminderConfig> get reminders {
    final now = DateTime.now();
    return slots
        .asMap()
        .entries
        .where((e) => e.value.reminderEnabled && e.value.reminderTime != null)
        .map((e) {
          final slot = e.value;
          final idx = e.key;
          DateTime trigger = DateTime(
            now.year,
            now.month,
            now.day,
            slot.reminderTime!.hour,
            slot.reminderTime!.minute,
          );
          if (trigger.isBefore(now)) {
            trigger = trigger.add(
              const Duration(days: 1),
            ); // Schedule for next day if already passed today
          }
          return ReminderConfig(
            id: '${id}_slot_$idx',
            triggerTime: trigger,
            type: slot.notificationType,
            notificationBody: 'Hora de: $title',
          );
        })
        .toList();
  }

  @override
  set reminders(List<ReminderConfig> value) {
    // We don't allow setting reminders directly on Habits, as they are derived from slots.
  }

  Habit copyWith({
    String? title,
    String? description,
    String? color,
    String? icon,
    String? completionUnit,
    int? dailyGoal,
    List<HabitSlot>? slots,
    List<Scheduler>? schedulers,
    String? linkedTrackerSlug,
    String? timeBlock,
    int? streak,
    List<CompletionRecord>? completionHistory,
    List<ActionDef>? actions,
    HabitStatus? status,
    DateTime? habitStartDate,
    TaskPriority? priority,
    bool? archived,
    bool? isNegative,
    HabitInputType? inputType,
    int? order,
    HabitMode? habitMode,
    String? statement,
    String? curiosityQuestion,
    String? hypothesis,
    DateTime? startedAt,
    DateTime? endsAt,
    PactOutcome? pactOutcome,
    List<PactCycle>? previousCycles,
  }) {
    final newHabit = Habit(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      completionUnit: completionUnit ?? this.completionUnit,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      slots: slots ?? this.slots,
      schedulers: schedulers ?? this.schedulers,
      linkedTrackerSlug: linkedTrackerSlug ?? this.linkedTrackerSlug,
      timeBlock: timeBlock ?? this.timeBlock,
      streak: streak ?? this.streak,
      completionHistory: completionHistory ?? this.completionHistory,
      actions: actions ?? this.actions,
      status: status ?? this.status,
      habitStartDate: habitStartDate ?? this.habitStartDate,
      priority: priority ?? this.priority,
      archived: archived ?? this.archived,
      isNegative: isNegative ?? this.isNegative,
      inputType: inputType ?? this.inputType,
      habitMode: habitMode ?? this.habitMode,
      statement: statement ?? this.statement,
      curiosityQuestion: curiosityQuestion ?? this.curiosityQuestion,
      hypothesis: hypothesis ?? this.hypothesis,
      startedAt: startedAt ?? this.startedAt,
      endsAt: endsAt ?? this.endsAt,
      pactOutcome: pactOutcome ?? this.pactOutcome,
      previousCycles: previousCycles ?? this.previousCycles,
      organizers: organizers,
      categories: categories,
      tags: tags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      obsidianPath: obsidianPath,
    );
    newHabit.order = order ?? this.order;
    return newHabit;
  }

  bool get isCompletedToday => daysSinceLastCompletion == 0;

  int get daysSinceLastCompletion {
    if (completionHistory.isEmpty) return -1;

    if (isNegative) {
      // For negative habits, we want days since the last record (failure)
      final lastFailure = completionHistory.last;
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day).difference(
        DateTime(
          lastFailure.date.year,
          lastFailure.date.month,
          lastFailure.date.day,
        ),
      );
      return diff.inDays;
    } else {
      final last = completionHistory.last;
      final now = DateTime.now();
      final diff = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(last.date.year, last.date.month, last.date.day));
      return diff.inDays;
    }
  }

  void calculateStreak() {
    if (completionHistory.isEmpty) {
      streak = 0;
      return;
    }

    // Simple streak calculation: consecutive days with success
    int currentStreak = 0;
    final sortedHistory = [...completionHistory]
      ..sort((a, b) => b.date.compareTo(a.date));

    DateTime checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);

    // Check if there was success today or yesterday
    bool foundStart = false;

    for (final record in sortedHistory) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (recordDate == checkDate ||
          recordDate == checkDate.subtract(const Duration(days: 1))) {
        if (record.successful || (isNegative && recordDate != checkDate)) {
          currentStreak++;
          checkDate = recordDate.subtract(const Duration(days: 1));
          foundStart = true;
        } else if (foundStart) {
          break;
        }
      } else if (recordDate.isBefore(checkDate)) {
        break;
      }
    }
    streak = currentStreak;
  }

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['color'] = color;
    if (description != null) frontmatter['description'] = description;
    if (icon != null) frontmatter['icon'] = icon;
    frontmatter['completion_unit'] = completionUnit;
    frontmatter['daily_goal'] = dailyGoal;
    if (linkedTrackerSlug != null) {
      frontmatter['linked_tracker_slug'] = linkedTrackerSlug;
    }
    if (timeBlock != null) frontmatter['time_block'] = timeBlock;

    if (slots.isNotEmpty) {
      frontmatter['slots'] = slots
          .map(
            (s) => {
              if (s.time != null) 'time': s.time!.toIso8601String(),
              'completed': s.completed,
              if (s.label != null) 'label': s.label,
              'reminder_enabled': s.reminderEnabled,
              if (s.reminderTime != null)
                'reminder_time':
                    '${s.reminderTime!.hour}:${s.reminderTime!.minute}',
              'notification_type': s.notificationType.name,
            },
          )
          .toList();
    }
    if (schedulers.isNotEmpty) {
      frontmatter['schedulers'] = schedulers.map((s) => s.toMap()).toList();
    }
    if (actions.isNotEmpty) {
      frontmatter['actions'] = actions.map((a) => a.toJson()).toList();
    }

    frontmatter['streak'] = streak;
    frontmatter['status'] = status.name;
    if (habitStartDate != null) {
      frontmatter['habit_start_date'] = habitStartDate!.toIso8601String();
    }
    frontmatter['priority'] = priority.name;
    frontmatter['archived'] = archived;
    frontmatter['is_negative'] = isNegative;
    frontmatter['input_type'] = inputType.name;

    // Pact fields
    frontmatter['habit_mode'] = habitMode.name;
    if (statement != null) frontmatter['statement'] = statement;
    if (curiosityQuestion != null) frontmatter['curiosity_question'] = curiosityQuestion;
    if (hypothesis != null) frontmatter['hypothesis'] = hypothesis;
    if (startedAt != null) frontmatter['started_at'] = startedAt!.toIso8601String().split('T').first;
    if (endsAt != null) frontmatter['ends_at'] = endsAt!.toIso8601String().split('T').first;
    if (pactOutcome != null) {
      frontmatter['pact_outcome'] = pactOutcome!.name;
    } else {
      frontmatter['pact_outcome'] = null;
    }
    frontmatter['previous_cycles'] = previousCycles.map((c) => c.toMap()).toList();

    // Yesplification for the body: a log of completions
    final buffer = StringBuffer();
    if (description != null) {
      buffer.writeln(description);
      buffer.writeln();
    }

    buffer.writeln('## History');
    for (final record in completionHistory) {
      final status = record.successful ? '[x]' : '[ ]';
      final valStr = record.value != null ? ' value:${record.value}' : '';
      buffer.writeln(
        '- $status ${record.date.toIso8601String().split('T').first} (${record.completions}/$dailyGoal)$valStr',
      );
    }

    return generateMarkdown(frontmatter, buffer.toString());
  }

  factory Habit.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final resolvedTitle = _resolveHabitTitle(frontmatter, body);
    final habit = Habit(
      title: resolvedTitle,
      color: frontmatter['color'] as String? ?? '#000000',
    );
    habit.loadBaseMap(frontmatter);
    if (displayTitleFromValue(habit.title, id: habit.id) == null &&
        resolvedTitle.isNotEmpty) {
      habit.title = resolvedTitle;
    }

    habit.description = frontmatter['description'] as String?;
    habit.icon = frontmatter['icon'] as String?;
    habit.completionUnit = frontmatter['completion_unit'] as String? ?? 'times';
    habit.linkedTrackerSlug = frontmatter['linked_tracker_slug'] as String?;
    final dg = frontmatter['daily_goal'];
    habit.dailyGoal = dg is int ? dg : int.tryParse(dg?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 1;

    final st = frontmatter['streak'];
    habit.streak = st is int ? st : int.tryParse(st?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;

    if (frontmatter['slots'] != null && frontmatter['slots'] is Iterable) {
      habit.slots = (frontmatter['slots'] as Iterable).map((s) {
        if (s is Map) {
          TimeOfDay? rTime;
          if (s['reminder_time'] != null) {
            final parts = s['reminder_time'].toString().split(':');
            if (parts.length == 2) {
              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);
              if (hour != null &&
                  minute != null &&
                  hour >= 0 &&
                  hour <= 23 &&
                  minute >= 0 &&
                  minute <= 59) {
                rTime = TimeOfDay(hour: hour, minute: minute);
              }
            }
          }
          return HabitSlot(
            time: s['time'] != null
                ? DateTime.tryParse(s['time'].toString())
                : null,
            completed: s['completed'] == true,
            label: s['label']?.toString(),
            reminderEnabled: s['reminder_enabled'] == true,
            reminderTime: rTime,
            notificationType: NotificationType.values.firstWhere(
              (e) => e.name == s['notification_type'],
              orElse: () => NotificationType.push,
            ),
          );
        }
        return HabitSlot();
      }).toList();
    }
    if (frontmatter['schedulers'] != null &&
        frontmatter['schedulers'] is Iterable) {
      habit.schedulers = (frontmatter['schedulers'] as Iterable)
          .whereType<Map>()
          .map((s) => Scheduler.fromMap(Map<String, dynamic>.from(s)))
          .toList();
    }
    if (frontmatter['actions'] != null && frontmatter['actions'] is Iterable) {
      habit.actions = (frontmatter['actions'] as Iterable)
          .whereType<Map>()
          .map((a) => ActionDef.fromJson(Map<String, dynamic>.from(a)))
          .toList();
    }

    if (frontmatter['status'] != null) {
      habit.status = HabitStatus.values.firstWhere(
        (e) => e.name == frontmatter['status'],
        orElse: () => HabitStatus.active,
      );
    }
    if (frontmatter['habit_start_date'] != null) {
      habit.habitStartDate = DateTime.tryParse(frontmatter['habit_start_date']);
    }
    if (frontmatter['priority'] != null) {
      habit.priority = TaskPriority.values.firstWhere(
        (e) => e.name == frontmatter['priority'],
        orElse: () => TaskPriority.none,
      );
    }
    habit.archived = frontmatter['archived'] as bool? ?? false;
    habit.isNegative = frontmatter['is_negative'] as bool? ?? false;
    if (frontmatter['input_type'] != null) {
      habit.inputType = HabitInputType.values.firstWhere(
        (e) => e.name == frontmatter['input_type'],
        orElse: () => HabitInputType.boolean,
      );
    }

    // Pact fields
    if (frontmatter['habit_mode'] != null) {
      habit.habitMode = HabitMode.values.firstWhere(
        (e) => e.name == frontmatter['habit_mode'].toString(),
        orElse: () => HabitMode.habit,
      );
    } else {
      habit.habitMode = HabitMode.habit;
    }
    habit.statement = frontmatter['statement'] as String?;
    habit.curiosityQuestion = frontmatter['curiosity_question'] as String?;
    habit.hypothesis = frontmatter['hypothesis'] as String?;
    if (frontmatter['started_at'] != null) {
      habit.startedAt = DateTime.tryParse(frontmatter['started_at'].toString());
    }
    if (frontmatter['ends_at'] != null) {
      habit.endsAt = DateTime.tryParse(frontmatter['ends_at'].toString());
    }
    if (frontmatter['pact_outcome'] != null) {
      final outcomeStr = frontmatter['pact_outcome'].toString();
      final match = PactOutcome.values.where((e) => e.name == outcomeStr);
      habit.pactOutcome = match.isNotEmpty ? match.first : null;
    }
    if (frontmatter['previous_cycles'] != null && frontmatter['previous_cycles'] is Iterable) {
      habit.previousCycles = (frontmatter['previous_cycles'] as Iterable).map((item) {
        if (item is Map) {
          return PactCycle.fromMap(item);
        }
        return null;
      }).whereType<PactCycle>().toList();
    }

    // Parse history
    final lines = body.split('\n');
    for (final line in lines) {
      if (line.startsWith('- [x] ') || line.startsWith('- [ ] ')) {
        final successful = line.startsWith('- [x] ');
        final dateStr = line.substring(6, 16); // Extract YYYY-MM-DD
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final valueMatch = RegExp(r'value:([\d.]+)').firstMatch(line);
          final value = valueMatch != null
              ? double.tryParse(valueMatch.group(1)!)
              : null;

          habit.completionHistory.add(
            CompletionRecord(date: date, successful: successful, value: value),
          );
        }
      }
    }

    return habit;
  }
}

String _resolveHabitTitle(Map<String, dynamic> frontmatter, String body) {
  final frontmatterTitle = displayTitleFromValue(
    frontmatter['title']?.toString(),
    id: frontmatter['id']?.toString(),
  );
  if (frontmatterTitle != null) return frontmatterTitle;

  final aliases = frontmatter['aliases'];
  if (aliases is List) {
    for (final alias in aliases) {
      final aliasTitle = displayTitleFromValue(
        alias?.toString(),
        id: frontmatter['id']?.toString(),
      );
      if (aliasTitle != null) return aliasTitle;
    }
  }

  final heading = RegExp(
    r'^\s{0,3}#{1,6}\s+(.+?)\s*$',
    multiLine: true,
  ).firstMatch(body)?.group(1);
  return displayTitleFromValue(heading, id: frontmatter['id']?.toString()) ?? '';
}
