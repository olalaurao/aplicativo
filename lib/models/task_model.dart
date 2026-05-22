// lib/models/task_model.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'scheduler.dart';
import 'reminder_config.dart';
import 'package:uuid/uuid.dart';

enum TaskStage { idea, todo, inProgress, pending, finalized }

enum TaskPriority { none, low, medium, high }

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
  List<OrganizerReference> places;
  int timerSessions;
  List<Comment> comments;
  String? reflection;
  bool untilDone;
  bool allDay;
  int duration; // minutes
  String? scheduledTime; // HH:MM
  String? exportedCalendarId;
  int? pomodoroCount;
  String? timeBlock;
  List<String> dependsOn;
  int? estimatedMinutes;

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
    this.places = const [],
    this.timerSessions = 0,
    this.comments = const [],
    this.reflection,
    this.untilDone = false,
    this.allDay = false,
    this.duration = 15,
    this.scheduledTime,
    super.archived,
    super.pinned,
    super.organizers,
    super.categories,
    super.tags,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.reminders,
    this.exportedCalendarId,
    this.pomodoroCount,
    this.timeBlock,
    this.dependsOn = const [],
    this.estimatedMinutes,
    DateTime? reminderDate,
  }) {
    if (reminderDate != null) {
      this.reminderDate = reminderDate;
    }
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

  int get actualMinutes => (pomodoroCount ?? 0) * 25;

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
    if (scheduledTime != null) frontmatter['scheduled_time'] = scheduledTime;
    frontmatter['archived'] = archived;
    frontmatter['pinned'] = pinned;
    if (exportedCalendarId != null) {
      frontmatter['calendar_id'] = exportedCalendarId;
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
    if (estimatedMinutes != null) {
      frontmatter['estimated_minutes'] = estimatedMinutes;
    }
    if (reflection != null && reflection!.isNotEmpty) {
      frontmatter['reflection'] = reflection;
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
              id: currentSessionId ?? Uuid().v4(),
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
          id: currentSessionId ?? Uuid().v4(),
          name: currentSessionName,
          subtaskIds: currentSubtaskIds,
        ),
      );
    }
    this.sessions = derivedSessions;

    if (sessions.isNotEmpty) {
      frontmatter['sessions'] = sessions.map((s) => s.toMap()).toList();
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
          buffer.writeln('- $check $title');
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
    final em = frontmatter['estimated_minutes'];
    task.estimatedMinutes = em is num
        ? em.toInt()
        : int.tryParse(em?.toString() ?? '');
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

    final List<SubtaskSession> fmSessions = [];
    if (frontmatter['sessions'] != null && frontmatter['sessions'] is List) {
      fmSessions.addAll(
        (frontmatter['sessions'] as List).map(
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
    List<OrganizerReference>? places,
    int? timerSessions,
    List<Comment>? comments,
    String? reflection,
    bool? untilDone,
    bool? allDay,
    int? duration,
    String? scheduledTime,
    bool? archived,
    bool? pinned,
    List<ReminderConfig>? reminders,
    String? exportedCalendarId,
    int? pomodoroCount,
    String? timeBlock,
    List<String>? dependsOn,
    int? estimatedMinutes,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
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
      places: places ?? this.places,
      timerSessions: timerSessions ?? this.timerSessions,
      comments: comments ?? this.comments,
      reflection: reflection ?? this.reflection,
      untilDone: untilDone ?? this.untilDone,
      allDay: allDay ?? this.allDay,
      duration: duration ?? this.duration,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      reminders: reminders ?? this.reminders,
      exportedCalendarId: exportedCalendarId ?? this.exportedCalendarId,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      timeBlock: timeBlock ?? this.timeBlock,
      dependsOn: dependsOn ?? this.dependsOn,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      obsidianPath: obsidianPath,
    )..order = order ?? this.order;
  }
}
