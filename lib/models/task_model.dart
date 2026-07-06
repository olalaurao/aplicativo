// lib/models/task_model.dart
import 'package:flutter/foundation.dart';
import 'content_object.dart';
import 'shared_types.dart';
import 'scheduler.dart';
import 'reminder_config.dart';
import 'package:uuid/uuid.dart';
import 'relay_step.dart';

enum TaskStage { idea, backlog, todo, inProgress, pending, finalized }

enum TaskPriority { none, low, medium, high }

enum RotationFrequencyType { none, daily, oncePerPeriod, everyNRotations }

/// Triple Check answer for a single dimension (head/heart/hand)
enum TripleCheckAnswer {
  yes,     // Sim
  unsure,  // Incerto
  no,      // Não
}

/// Stores the result of a Triple Check diagnostic on a Task.
class TripleCheck {
  final TripleCheckAnswer head;    // A tarefa faz sentido agora?
  final TripleCheckAnswer heart;   // Você está animado com isso?
  final TripleCheckAnswer hand;    // Você tem o que precisa para começar?
  final String diagnosis;          // Auto-generated diagnosis text
  final DateTime checkedAt;

  const TripleCheck({
    required this.head,
    required this.heart,
    required this.hand,
    required this.diagnosis,
    required this.checkedAt,
  });

  /// V5: blocker is now an array (multiple dimensions can fail simultaneously).
  /// e.g. ['heart', 'hand']
  List<String> get blockers {
    final result = <String>[];
    if (head != TripleCheckAnswer.yes) result.add('head');
    if (heart != TripleCheckAnswer.yes) result.add('heart');
    if (hand != TripleCheckAnswer.yes) result.add('hand');
    return result;
  }

  /// Legacy single-blocker accessor (first blocker or null)
  String? get primaryBlocker => blockers.isEmpty ? null : blockers.first;

  Map<String, dynamic> toMap() => {
    'head': head.name,
    'heart': heart.name,
    'hand': hand.name,
    'blocker': blockers, // V5: array, not scalar
    'diagnosis': diagnosis,
    'checked_at': checkedAt.toIso8601String(),
  };

  factory TripleCheck.fromMap(Map<String, dynamic> m) {
    TripleCheckAnswer parseAnswer(String key) {
      final v = m[key]?.toString() ?? '';
      return TripleCheckAnswer.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TripleCheckAnswer.yes,
      );
    }
    return TripleCheck(
      head: parseAnswer('head'),
      heart: parseAnswer('heart'),
      hand: parseAnswer('hand'),
      diagnosis: m['diagnosis']?.toString() ?? '',
      checkedAt: DateTime.tryParse(m['checked_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  TripleCheck copyWith({
    TripleCheckAnswer? head,
    TripleCheckAnswer? heart,
    TripleCheckAnswer? hand,
    String? diagnosis,
    DateTime? checkedAt,
  }) => TripleCheck(
    head: head ?? this.head,
    heart: heart ?? this.heart,
    hand: hand ?? this.hand,
    diagnosis: diagnosis ?? this.diagnosis,
    checkedAt: checkedAt ?? this.checkedAt,
  );
}

class Task extends ContentObject {
  TaskStage stage;
  TaskPriority priority;
  DateTime? startDate;
  DateTime? endDate;
  List<String> notes;
  List<Subtask> subtasks;
  List<SubtaskSession> sessions;
  Scheduler? scheduler;
  String? color;
  List<OrganizerReference> participants;
  int timerSessions;
  List<Comment> comments;
  String? reflection;
  bool untilDone;
  /// V5: date_range and until_done are mutually exclusive; date_range takes precedence.
  /// When dateRange is set, untilDone is ignored on read and cleared on save.
  String? dateRange; // e.g. '2026-01-01/2026-01-31'
  bool allDay;
  int duration; // minutes
  String? scheduledTime; // HH:MM
  String? exportedCalendarId;
  String? linkedGoogleEventId;
  String? linkedGoogleEventTitle;
  String? linkedGoogleEventDate;
  String? linkedGoogleEventUrl;
  int? pomodoroCount;
  String? timeBlock;
  List<String> dependsOn;
  int? estimatedMinutes;
  TripleCheck? tripleCheck;
  String? linkedSystem;
  String? rotationGroupId;
  RotationFrequencyType rotationFrequencyType = RotationFrequencyType.none;
  int? rotationEveryN;
  int? rotationLastCompletedAtOccurrence;
  Map<String, bool> rotationDailyCompletions = {};
  
  // Alignment tracking fields (RA-P1-1)
  int? flexibilityWindowMinutes; // null = alignment tracking off for this task

  // Focus Relay fields (RA-P1-3)
  List<RelayStep>? relaySteps; // null = use flat Pomodoro, non-null = use Relay mode

  bool get isRotationTask => rotationFrequencyType != RotationFrequencyType.none;
  bool get hasDateRange => dateRange != null && dateRange!.trim().isNotEmpty;
  bool get isAlignmentTrackable => flexibilityWindowMinutes != null && scheduledTime != null;
  bool get hasRelaySteps => relaySteps != null && relaySteps!.isNotEmpty;

  void normalizeDateRangeAndUntilDone({bool logWarning = false}) {
    if (hasDateRange && untilDone) {
      if (logWarning) {
        debugPrint(
          'Task data-cleanliness warning: both date_range and until_done were set for "$title"; date_range takes precedence.',
        );
      }
      untilDone = false;
    }
  }

  @override
  bool get isIncomplete => title.trim().isEmpty || stage == TaskStage.idea;

  Task({
    super.id,
    required super.title,
    this.stage = TaskStage.idea,
    this.priority = TaskPriority.none,
    this.startDate,
    this.endDate,
    this.notes = const [],
    this.subtasks = const [],
    this.sessions = const [],
    this.scheduler,
    this.color,
    this.participants = const [],
    this.timerSessions = 0,
    this.comments = const [],
    this.reflection,
    this.untilDone = false,
    this.dateRange,
    this.allDay = false,
    this.duration = 15,
    this.scheduledTime,
    super.archived,
    super.pinned,
    super.organizers,
    super.categories,
    super.tags,
    super.links,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.reminders,
    this.exportedCalendarId,
    this.linkedGoogleEventId,
    this.linkedGoogleEventTitle,
    this.linkedGoogleEventDate,
    this.linkedGoogleEventUrl,
    this.pomodoroCount,
    this.timeBlock,
    this.dependsOn = const [],
    this.estimatedMinutes,
    this.tripleCheck,
    this.linkedSystem,
    this.rotationGroupId,
    this.rotationFrequencyType = RotationFrequencyType.none,
    this.rotationEveryN,
    this.rotationLastCompletedAtOccurrence,
    Map<String, bool>? rotationDailyCompletions,
    this.flexibilityWindowMinutes,
    this.relaySteps,
    DateTime? reminderDate,
  }) : rotationDailyCompletions = rotationDailyCompletions ?? {} {
    if (reminderDate != null) {
      this.reminderDate = reminderDate;
    }
    // V5: date_range wins over until_done if both somehow set
    normalizeDateRangeAndUntilDone();
  }

  DateTime? get reminderDate {
    if (reminders.isEmpty) return null;
    return reminders.first.triggerTime;
  }

  set reminderDate(DateTime? value) {
    if (value == null) {
      reminders = [];
    } else {
      reminders = [
        ReminderConfig(
          id: '${id}_auto',
          triggerTime: value,
          type: NotificationType.push,
          notificationBody: 'Reminder: $title',
        ),
      ];
    }
  }

  @override
  String get type => 'task';

  bool get isCompleted => stage == TaskStage.finalized;

  int get actualMinutes => timerSessions;

  bool isBlocked(List<ContentObject> allObjects) {
    if (dependsOn.isEmpty) return false;
    for (final rawRef in dependsOn) {
      final ref = rawRef.replaceAll('[[', '').replaceAll(']]', '').trim();
      final blockingTask =
          allObjects.cast<ContentObject?>().firstWhere(
                (o) => o is Task && (o.slug == ref || o.id == ref),
                orElse: () => null,
              )
              as Task?;
      if (blockingTask != null && blockingTask.stage != TaskStage.finalized) {
        return true;
      }
    }
    return false;
  }

  String? get scheduledDate {
    if (startDate == null) return null;
    return "${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}";
  }

  DateTime? get deadline => endDate;

  @override
  DateTime? get baseTime {
    // Start date is the primary reference for tasks
    final refDate = startDate ?? endDate;
    if (refDate == null) return null;

    if (scheduledTime != null) {
      try {
        final parts = scheduledTime!.split(':');
        return DateTime(
          refDate.year,
          refDate.month,
          refDate.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      } catch (_) {}
    }
    // Default to 9 AM on the reference date
    return DateTime(refDate.year, refDate.month, refDate.day, 9, 0);
  }

  @override
  List<ReminderConfig> get reminders {
    // If user has defined custom reminders, use them
    if (super.reminders.isNotEmpty) return super.reminders;

    // Fallback to auto reminder if there's a base time
    final base = baseTime;
    if (base == null || isCompleted) return [];

    return [
      ReminderConfig(
        id: '${id}_default',
        minutesBefore: 60, // 1 hour before
        type: NotificationType.push,
        notificationBody: 'Reminder: $title',
      ),
    ];
  }

  @override
  String toMarkdown() {
    normalizeDateRangeAndUntilDone(logWarning: true);
    final frontmatter = toBaseMap();
    frontmatter['stage'] = stage.name;
    frontmatter['priority'] = priority.name;
    if (startDate != null) {
      frontmatter['start_date'] = startDate!.toIso8601String();
    }
    if (endDate != null) frontmatter['end_date'] = endDate!.toIso8601String();
    if (color != null) frontmatter['color'] = color;
    frontmatter['until_done'] = untilDone;
    frontmatter['all_day'] = allDay;
    frontmatter['duration'] = duration;
    if (timerSessions > 0) {
      frontmatter['timer_sessions'] = timerSessions;
    }
    if (scheduledTime != null) frontmatter['scheduled_time'] = scheduledTime;
    frontmatter['archived'] = archived;
    frontmatter['pinned'] = pinned;
    if (exportedCalendarId != null) {
      frontmatter['calendar_id'] = exportedCalendarId;
    }
    if (linkedGoogleEventId != null) {
      frontmatter['linked_google_event_id'] = linkedGoogleEventId;
    }
    if (linkedGoogleEventTitle != null) {
      frontmatter['linked_google_event_title'] = linkedGoogleEventTitle;
    }
    if (linkedGoogleEventDate != null) {
      frontmatter['linked_google_event_date'] = linkedGoogleEventDate;
    }
    if (linkedGoogleEventUrl != null) {
      frontmatter['linked_google_event_url'] = linkedGoogleEventUrl;
    }
    if (pomodoroCount != null) {
      frontmatter['pomodoro_count'] = pomodoroCount;
    }
    if (timeBlock != null) {
      frontmatter['time_block'] = timeBlock;
    }
    if (dependsOn.isNotEmpty) {
      frontmatter['depends_on'] = dependsOn;
    }
    if (hasDateRange) {
      frontmatter['date_range'] = dateRange;
      // V5: date_range wins — never write until_done when date_range is set
      frontmatter.remove('until_done');
    }
    if (estimatedMinutes != null) {
      frontmatter['estimated_minutes'] = estimatedMinutes;
    }
    if (reflection != null && reflection!.isNotEmpty) {
      frontmatter['reflection'] = reflection;
    }
    // Triple Check block — stored inline in frontmatter, never as separate file
    frontmatter['triple_check'] = tripleCheck?.toMap();
    if (linkedSystem != null) {
      frontmatter['linked_system'] = linkedSystem;
    }
    if (rotationGroupId != null) {
      frontmatter['rotation_group'] = '[[$rotationGroupId]]';
    }
    if (rotationFrequencyType != RotationFrequencyType.none) {
      frontmatter['rotation_frequency_type'] = switch (rotationFrequencyType) {
        RotationFrequencyType.daily => 'daily',
        RotationFrequencyType.oncePerPeriod => 'once_per_period',
        RotationFrequencyType.everyNRotations => 'every_n_rotations',
        RotationFrequencyType.none => 'none',
      };
    }
    if (rotationEveryN != null) frontmatter['rotation_every_n'] = rotationEveryN;
    if (rotationLastCompletedAtOccurrence != null) {
      frontmatter['rotation_last_completed_at_occurrence'] =
          rotationLastCompletedAtOccurrence;
    }
    if (rotationDailyCompletions.isNotEmpty) {
      frontmatter['rotation_daily_completions'] = rotationDailyCompletions;
    }
    if (flexibilityWindowMinutes != null) {
      frontmatter['flexibility_window_minutes'] = flexibilityWindowMinutes;
    }
    if (relaySteps != null && relaySteps!.isNotEmpty) {
      frontmatter['relay_steps'] = relaySteps!.map((s) => s.toMap()).toList();
    }

    if (scheduler != null) frontmatter['scheduler'] = scheduler!.toMap();

    // Build sessions list dynamically from subtasks to ensure frontmatter is always in sync with body checklist!
    final List<SubtaskSession> derivedSessions = [];
    String? currentSessionName;
    List<String> currentSubtaskIds = [];
    String? currentSessionId;

    for (final subtask in subtasks) {
      if (subtask.isHeader) {
        if (currentSessionName != null) {
          derivedSessions.add(
            SubtaskSession(
              id: currentSessionId ?? const Uuid().v4(),
              name: currentSessionName,
              subtaskIds: currentSubtaskIds,
            ),
          );
        }
        currentSessionName = subtask.title;
        currentSessionId = subtask.id;
        currentSubtaskIds = [];
      } else {
        if (currentSessionName == null) {
          currentSessionName = "Geral";
          currentSessionId = "general";
        }
        currentSubtaskIds.add(subtask.id);
      }
    }
    if (currentSessionName != null) {
      derivedSessions.add(
        SubtaskSession(
          id: currentSessionId ?? const Uuid().v4(),
          name: currentSessionName,
          subtaskIds: currentSubtaskIds,
        ),
      );
    }
    sessions = derivedSessions;

    if (sessions.isNotEmpty) {
      frontmatter['subtask_sessions'] = sessions.map((s) => s.toMap()).toList();
    }

    final buffer = StringBuffer();
    if (notes.isNotEmpty) {
      buffer.writeln(notes.join('\n'));
      buffer.writeln();
    }

    if (subtasks.isNotEmpty) {
      buffer.writeln('## Subtasks');
      for (final subtask in subtasks) {
        if (subtask.isHeader) {
          buffer.writeln('- **${subtask.title}**');
        } else {
          final check = subtask.completed ? '[x]' : '[ ]';
          final title = subtask.slug != null
              ? '[[${subtask.slug!}]]'
              : subtask.title;
          // Sintaxe Tasks Plugin do Obsidian: campos inline [chave:: valor]
          final fields = StringBuffer();
          if (subtask.dueDate != null) {
            final d = subtask.dueDate!;
            final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            fields.write(' [due:: $dateStr]');
          }
          if (subtask.priority != null && subtask.priority != 'none') {
            fields.write(' [priority:: ${subtask.priority}]');
          }
          buffer.writeln('- $check $title$fields');
        }
      }
      buffer.writeln();
    }

    return generateMarkdown(frontmatter, buffer.toString());
  }

  factory Task.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final task = Task(
      title: frontmatter['title'] is List
          ? (frontmatter['title'] as List).join(', ')
          : frontmatter['title']?.toString() ?? '',
      notes: [],
      subtasks: [],
      sessions: [],
    );
    task.loadBaseMap(frontmatter);

    // Parse stage/priority (simplified)
    if (frontmatter['stage'] != null) {
      task.stage = TaskStage.values.firstWhere(
        (e) => e.name == frontmatter['stage'],
        orElse: () => TaskStage.todo,
      );
    }
    if (frontmatter['start_date'] != null) {
      task.startDate = DateTime.tryParse(frontmatter['start_date'] as String);
    }
    if (frontmatter['end_date'] != null) {
      task.endDate = DateTime.tryParse(frontmatter['end_date'] as String);
    }
    task.color = frontmatter['color'] is List
        ? (frontmatter['color'] as List).join(', ')
        : frontmatter['color']?.toString();
    task.untilDone = frontmatter['until_done'] as bool? ?? false;
    task.allDay = frontmatter['all_day'] as bool? ?? false;
    final d = frontmatter['duration'];
    task.duration = d is int
        ? d
        : int.tryParse(d?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ??
              15;
    task.scheduledTime = frontmatter['scheduled_time'] is List
        ? (frontmatter['scheduled_time'] as List).join(', ')
        : frontmatter['scheduled_time']?.toString();
    final timer = frontmatter['timer_sessions'];
    task.timerSessions = timer is num
        ? timer.toInt()
        : int.tryParse(timer?.toString() ?? '') ?? 0;
    task.archived = frontmatter['archived'] as bool? ?? false;
    task.pinned = frontmatter['pinned'] as bool? ?? false;
    if (frontmatter['reminder_date'] != null) {
      task.reminderDate = DateTime.tryParse(
        frontmatter['reminder_date'] as String,
      );
    }
    task.exportedCalendarId = frontmatter['calendar_id'] is List
        ? (frontmatter['calendar_id'] as List).join(', ')
        : frontmatter['calendar_id']?.toString();
    task.linkedGoogleEventId = frontmatter['linked_google_event_id'] is List
        ? (frontmatter['linked_google_event_id'] as List).join(', ')
        : frontmatter['linked_google_event_id']?.toString();
    task.linkedGoogleEventTitle =
        frontmatter['linked_google_event_title'] is List
        ? (frontmatter['linked_google_event_title'] as List).join(', ')
        : frontmatter['linked_google_event_title']?.toString();
    task.linkedGoogleEventDate = frontmatter['linked_google_event_date'] is List
        ? (frontmatter['linked_google_event_date'] as List).join(', ')
        : frontmatter['linked_google_event_date']?.toString();
    task.linkedGoogleEventUrl = frontmatter['linked_google_event_url'] is List
        ? (frontmatter['linked_google_event_url'] as List).join(', ')
        : frontmatter['linked_google_event_url']?.toString();
    task.reflection = frontmatter['reflection'] is List
        ? (frontmatter['reflection'] as List).join(', ')
        : frontmatter['reflection']?.toString();

    final pc = frontmatter['pomodoro_count'];
    task.pomodoroCount = pc is num
        ? pc.toInt()
        : int.tryParse(pc?.toString() ?? '');
    task.timeBlock = frontmatter['time_block'] is List
        ? (frontmatter['time_block'] as List).join(', ')
        : frontmatter['time_block']?.toString();
    if (frontmatter['depends_on'] != null &&
        frontmatter['depends_on'] is List) {
      task.dependsOn = (frontmatter['depends_on'] as List)
          .map((e) => e.toString())
          .toList();
    }
    task.dateRange = frontmatter['date_range']?.toString();
    // V5: if date_range is present, until_done is ignored
    task.normalizeDateRangeAndUntilDone(logWarning: true);
    final em = frontmatter['estimated_minutes'];
    task.estimatedMinutes = em is num
        ? em.toInt()
        : int.tryParse(em?.toString() ?? '');
    // Parse Triple Check block
    if (frontmatter['triple_check'] is Map) {
      try {
        task.tripleCheck = TripleCheck.fromMap(
          Map<String, dynamic>.from(frontmatter['triple_check'] as Map),
        );
      } catch (e) {
        debugPrint('TripleCheck parse error: $e');
      }
    }
    task.linkedSystem = frontmatter['linked_system']?.toString();
    if (frontmatter['scheduler'] != null) {
      task.scheduler = Scheduler.fromMap(
        Map<String, dynamic>.from(frontmatter['scheduler'] as Map),
      );
    }
    if (frontmatter['priority'] != null) {
      task.priority = TaskPriority.values.firstWhere(
        (e) => e.name == frontmatter['priority'],
        orElse: () => TaskPriority.none,
      );
    }
    final rotGroup = frontmatter['rotation_group'];
    if (rotGroup != null) {
      final raw = rotGroup.toString().replaceAll('[', '').replaceAll(']', '');
      task.rotationGroupId = raw.trim();
    }
    final rotType = frontmatter['rotation_frequency_type']?.toString();
    if (rotType != null) {
      task.rotationFrequencyType = RotationFrequencyType.values.firstWhere(
        (e) =>
            e.name == rotType ||
            e.name == rotType.replaceAll('_', '') ||
            (rotType == 'once_per_period' && e == RotationFrequencyType.oncePerPeriod) ||
            (rotType == 'every_n_rotations' && e == RotationFrequencyType.everyNRotations),
        orElse: () => RotationFrequencyType.none,
      );
    }
    final rotN = frontmatter['rotation_every_n'];
    task.rotationEveryN =
        rotN is num ? rotN.toInt() : int.tryParse(rotN?.toString() ?? '');
    final rotLast = frontmatter['rotation_last_completed_at_occurrence'];
    task.rotationLastCompletedAtOccurrence = rotLast is num
        ? rotLast.toInt()
        : int.tryParse(rotLast?.toString() ?? '');
    if (frontmatter['rotation_daily_completions'] is Map) {
      task.rotationDailyCompletions = Map<String, bool>.from(
        (frontmatter['rotation_daily_completions'] as Map).map(
          (k, v) => MapEntry(k.toString(), v == true),
        ),
      );
    }
    final fwm = frontmatter['flexibility_window_minutes'];
    task.flexibilityWindowMinutes = fwm is num
        ? fwm.toInt()
        : int.tryParse(fwm?.toString() ?? '');
    if (frontmatter['relay_steps'] is List) {
      task.relaySteps = (frontmatter['relay_steps'] as List)
          .whereType<Map>()
          .map((s) => RelayStep.fromMap(Map<String, dynamic>.from(s)))
          .toList();
    }

    final List<SubtaskSession> fmSessions = [];
    final rawSessions =
        frontmatter['subtask_sessions'] ?? frontmatter['sessions'];
    if (rawSessions is List) {
      fmSessions.addAll(
        rawSessions.map(
          (e) => SubtaskSession.fromMap(Map<String, dynamic>.from(e as Map)),
        ),
      );
    }
    task.sessions = fmSessions;

    // Parse body for subtasks
    final lines = body.split('\n');
    bool inSubtasks = false;
    int sessionIndex = -1;
    int subtaskInSessionIndex = 0;

    for (final line in lines) {
      if (line.trim().toLowerCase() == '## subtasks') {
        inSubtasks = true;
        continue;
      }

      if (line.startsWith('## ')) {
        inSubtasks = false;
      }

      if (line.startsWith('- [ ] ') ||
          line.startsWith('- [x] ') ||
          line.startsWith('- [X] ')) {
        final completed = line.substring(3, 4).toLowerCase() == 'x';
        String content = line.substring(6).trim();
        // Extrair campos Tasks Plugin inline: [due:: ...] [priority:: ...]
        DateTime? dueDate;
        String? subtaskPriority;
        final dueMatch = RegExp(r'\[due::\s*(\d{4}-\d{2}-\d{2})\]').firstMatch(content);
        if (dueMatch != null) {
          dueDate = DateTime.tryParse(dueMatch.group(1)!);
          content = content.replaceAll(dueMatch.group(0)!, '').trim();
        }
        final priorityMatch = RegExp(r'\[priority::\s*(\w+)\]').firstMatch(content);
        if (priorityMatch != null) {
          subtaskPriority = priorityMatch.group(1)?.toLowerCase();
          content = content.replaceAll(priorityMatch.group(0)!, '').trim();
        }
        String? slug;
        if (content.startsWith('[[') && content.endsWith(']]')) {
          slug = content.substring(2, content.length - 2);
        }
        if (inSubtasks || !body.toLowerCase().contains('## subtasks')) {
          String? subtaskId;
          if (sessionIndex >= 0 && sessionIndex < fmSessions.length) {
            final ids = fmSessions[sessionIndex].subtaskIds;
            if (subtaskInSessionIndex < ids.length) {
              subtaskId = ids[subtaskInSessionIndex];
            }
          }
          task.subtasks.add(
            Subtask(
              id: subtaskId,
              title: content,
              completed: completed,
              slug: slug,
              dueDate: dueDate,
              priority: subtaskPriority,
            ),
          );
          subtaskInSessionIndex++;
        }
      } else if (line.startsWith('- **') && line.endsWith('**')) {
        // Detected a header
        final title = line.substring(4, line.length - 2).trim();
        if (inSubtasks || !body.toLowerCase().contains('## subtasks')) {
          sessionIndex++;
          subtaskInSessionIndex = 0;
          String? sessionId;
          if (sessionIndex >= 0 && sessionIndex < fmSessions.length) {
            sessionId = fmSessions[sessionIndex].id;
          }
          task.subtasks.add(
            Subtask(id: sessionId, title: title, isHeader: true),
          );
        }
      } else if (line.trim().isNotEmpty && !line.startsWith('## ')) {
        task.notes.add(line);
      }
    }

    return task;
  }

  Task copyWith({
    String? title,
    TaskStage? stage,
    TaskPriority? priority,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? notes,
    List<Subtask>? subtasks,
    List<SubtaskSession>? sessions,
    Scheduler? scheduler,
    String? color,
    List<OrganizerReference>? participants,
    int? timerSessions,
    List<Comment>? comments,
    String? reflection,
    bool? untilDone,
    String? dateRange,
    bool? allDay,
    int? duration,
    String? scheduledTime,
    bool? archived,
    bool? pinned,
    List<ReminderConfig>? reminders,
    String? exportedCalendarId,
    String? linkedGoogleEventId,
    String? linkedGoogleEventTitle,
    String? linkedGoogleEventDate,
    String? linkedGoogleEventUrl,
    int? pomodoroCount,
    String? timeBlock,
    List<String>? dependsOn,
    int? estimatedMinutes,
    TripleCheck? tripleCheck,
    bool clearTripleCheck = false,
    String? linkedSystem,
    String? rotationGroupId,
    RotationFrequencyType? rotationFrequencyType,
    int? rotationEveryN,
    int? rotationLastCompletedAtOccurrence,
    Map<String, bool>? rotationDailyCompletions,
    int? flexibilityWindowMinutes,
    List<RelayStep>? relaySteps,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    List<String>? links,
    int? order,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      stage: stage ?? this.stage,
      priority: priority ?? this.priority,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      subtasks: subtasks ?? this.subtasks,
      sessions: sessions ?? this.sessions,
      scheduler: scheduler ?? this.scheduler,
      color: color ?? this.color,
      participants: participants ?? this.participants,
      timerSessions: timerSessions ?? this.timerSessions,
      comments: comments ?? this.comments,
      reflection: reflection ?? this.reflection,
      untilDone: untilDone ?? this.untilDone,
      dateRange: dateRange ?? this.dateRange,
      allDay: allDay ?? this.allDay,
      duration: duration ?? this.duration,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      reminders: reminders ?? this.reminders,
      exportedCalendarId: exportedCalendarId ?? this.exportedCalendarId,
      linkedGoogleEventId: linkedGoogleEventId ?? this.linkedGoogleEventId,
      linkedGoogleEventTitle:
          linkedGoogleEventTitle ?? this.linkedGoogleEventTitle,
      linkedGoogleEventDate:
          linkedGoogleEventDate ?? this.linkedGoogleEventDate,
      linkedGoogleEventUrl: linkedGoogleEventUrl ?? this.linkedGoogleEventUrl,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      timeBlock: timeBlock ?? this.timeBlock,
      dependsOn: dependsOn ?? this.dependsOn,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      tripleCheck: clearTripleCheck ? null : (tripleCheck ?? this.tripleCheck),
      linkedSystem: linkedSystem ?? this.linkedSystem,
      rotationGroupId: rotationGroupId ?? this.rotationGroupId,
      rotationFrequencyType:
          rotationFrequencyType ?? this.rotationFrequencyType,
      rotationEveryN: rotationEveryN ?? this.rotationEveryN,
      rotationLastCompletedAtOccurrence: rotationLastCompletedAtOccurrence ??
          this.rotationLastCompletedAtOccurrence,
      rotationDailyCompletions: rotationDailyCompletions ??
          Map<String, bool>.from(this.rotationDailyCompletions),
      flexibilityWindowMinutes: flexibilityWindowMinutes ?? this.flexibilityWindowMinutes,
      relaySteps: relaySteps ?? this.relaySteps,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      links: links ?? this.links,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      obsidianPath: obsidianPath,
    )..order = order ?? this.order;
  }

  /// Returns true if the task has been stuck in its current stage for 7+ days
  /// without a Triple Check being performed (or if one was performed but had blockers).
  bool get needsTripleCheckBadge {
    if (stage == TaskStage.finalized || stage == TaskStage.idea) return false;
    // Already recently checked → don't show badge
    if (tripleCheck != null) {
      final daysSinceCheck = DateTime.now().difference(tripleCheck!.checkedAt).inDays;
      if (daysSinceCheck < 7) return false;
    }
    // Check if stuck for 7+ days (use updatedAt as proxy)
    final daysSinceUpdate = DateTime.now().difference(updatedAt).inDays;
    return daysSinceUpdate >= 7;
  }
}
