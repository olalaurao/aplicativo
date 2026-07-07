// lib/models/event_model.dart
// V5 F1.14: Event absorbs CalendarSession.
// "Calendar Session" is now Event with a `pomodoro` block present.
// exported_calendar_id removed — replaced by source + linked_google_event_* pair.
import 'content_object.dart';
import 'reminder_config.dart';
import 'scheduler.dart';
import 'shared_types.dart';

/// Source of the event. Determines editability:
/// - [app]: fully editable inside the app.
/// - [googleCalendar]: read-only; shown with "Open in Google Calendar" button.
enum EventSource { app, googleCalendar }

/// V5 event state (supersedes CalendarSessionState).
enum EventState { scheduled, inProgress, completed, backlog, cancelled }

/// Pomodoro configuration block embedded in an Event.
/// When present, the Event is a "time-blocked Pomodoro plan."
class EventPomodoro {
  final int workDuration;        // minutes
  final int shortBreakDuration;  // minutes
  final int longBreakDuration;   // minutes
  final int longBreakAfterBlocks;

  const EventPomodoro({
    this.workDuration = 25,
    this.shortBreakDuration = 5,
    this.longBreakDuration = 20,
    this.longBreakAfterBlocks = 4,
  });

  Map<String, dynamic> toMap() => {
    'work_duration': workDuration,
    'short_break_duration': shortBreakDuration,
    'long_break_duration': longBreakDuration,
    'long_break_after_blocks': longBreakAfterBlocks,
  };

  factory EventPomodoro.fromMap(Map<String, dynamic> map) => EventPomodoro(
    workDuration: map['work_duration'] as int? ?? 25,
    shortBreakDuration: map['short_break_duration'] as int? ?? 5,
    longBreakDuration: map['long_break_duration'] as int? ?? 20,
    longBreakAfterBlocks: map['long_break_after_blocks'] as int? ?? 4,
  );
}

class Event extends ContentObject {
  DateTime date;
  EventSource source;
  EventState state;
  String? timeOfDay;
  int duration;           // minutes
  String? endTime;
  bool multiDay;
  /// WikiLink to a Task e.g. "[[task-slug]]"
  String? task;
  /// WikiLink to a Goal e.g. "[[goal-slug]]"
  String? goal;
  List<String> subtasks;  // inline checklist
  String? note;
  List<String> participants;
  Scheduler? scheduler;
  bool backlog;
  /// Optional pomodoro block. When present, Event = "Calendar Session" in V4 terms.
  EventPomodoro? pomodoro;
  // Google Calendar fields — only present when source == googleCalendar
  String? linkedGoogleEventId;
  String? linkedGoogleEventTitle;
  String? linkedGoogleEventUrl;

  // Backwards compatibility V4 fields
  String? location;
  String? googleCalendarId;

  // Getters/Setters for V4 compatibilities
  DateTime get startDatetime => date;
  set startDatetime(DateTime value) {
    date = value;
  }

  DateTime? get endDatetime {
    if (endTime != null && endTime!.contains(':')) {
      final parts = endTime!.split(':');
      final h = int.tryParse(parts.first) ?? date.hour;
      final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }
    return date.add(Duration(minutes: duration));
  }
  set endDatetime(DateTime? value) {
    if (value != null) {
      duration = value.difference(date).inMinutes;
      endTime = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
  }

  String? get description => note;
  set description(String? value) {
    note = value;
  }

  String? get googleEventId => linkedGoogleEventId;
  set googleEventId(String? value) {
    linkedGoogleEventId = value;
  }

  String? get googleEventUrl => linkedGoogleEventUrl;
  set googleEventUrl(String? value) {
    linkedGoogleEventUrl = value;
  }

  Event({
    super.id,
    required super.title,
    DateTime? date,
    DateTime? startDatetime,
    DateTime? endDatetime,
    this.source = EventSource.app,
    this.state = EventState.scheduled,
    this.timeOfDay,
    this.duration = 60,
    this.endTime,
    this.multiDay = false,
    this.task,
    this.goal,
    List<String>? subtasks,
    String? note,
    String? description,
    List<String>? participants,
    this.scheduler,
    this.backlog = false,
    this.pomodoro,
    String? linkedGoogleEventId,
    String? googleEventId,
    this.linkedGoogleEventTitle,
    String? linkedGoogleEventUrl,
    String? googleEventUrl,
    this.location,
    this.googleCalendarId,
    super.organizers,
    super.categories,
    super.tags,
    super.links,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.archived,
    super.pinned,
    super.order,
    super.reminders,
  }) : date = date ?? startDatetime ?? DateTime.now(),
       note = note ?? description,
       linkedGoogleEventId = linkedGoogleEventId ?? googleEventId,
       linkedGoogleEventUrl = linkedGoogleEventUrl ?? googleEventUrl,
       subtasks = subtasks ?? [],
       participants = participants ?? [] {
    if (endDatetime != null) {
      final start = this.date;
      duration = endDatetime.difference(start).inMinutes;
      endTime = '${endDatetime.hour.toString().padLeft(2, '0')}:${endDatetime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  String get type => 'event';

  @override
  bool get isIncomplete => title.trim().isEmpty;

  @override
  DateTime? get baseTime => date;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['date'] = date.toIso8601String().split('T').first;
    frontmatter['source'] = source == EventSource.googleCalendar
        ? 'google_calendar'
        : 'app';
    frontmatter['state'] = _stateToString(state);
    if (timeOfDay != null) frontmatter['time_of_day'] = timeOfDay;
    frontmatter['duration'] = duration;
    if (endTime != null) frontmatter['end_time'] = endTime;
    frontmatter['multi_day'] = multiDay;
    if (task != null && task!.isNotEmpty) frontmatter['task'] = task;
    if (goal != null && goal!.isNotEmpty) frontmatter['goal'] = goal;
    if (subtasks.isNotEmpty) frontmatter['subtasks'] = subtasks;
    if (note != null) frontmatter['note'] = note;
    if (participants.isNotEmpty) frontmatter['participants'] = participants;
    if (scheduler != null) frontmatter['scheduler'] = scheduler!.toMap();
    frontmatter['backlog'] = backlog;
    if (pomodoro != null) frontmatter['pomodoro'] = pomodoro!.toMap();
    if (linkedGoogleEventId != null) {
      frontmatter['linked_google_event_id'] = linkedGoogleEventId;
    }
    if (linkedGoogleEventTitle != null) {
      frontmatter['linked_google_event_title'] = linkedGoogleEventTitle;
    }
    if (linkedGoogleEventUrl != null) {
      frontmatter['linked_google_event_url'] = linkedGoogleEventUrl;
    }
    return generateMarkdown(frontmatter, note ?? '');
  }

  factory Event.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final rawDate = frontmatter['date']?.toString() ??
        frontmatter['start_datetime']?.toString() ??
        '';
    final parsedDate = DateTime.tryParse(rawDate) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    // Parse source
    EventSource source = EventSource.app;
    final srcStr = frontmatter['source']?.toString() ?? '';
    if (srcStr == 'google_calendar') source = EventSource.googleCalendar;

    // Parse state — supports both V4 CalendarSession names and V5 Event names
    EventState state = EventState.scheduled;
    final stateStr = frontmatter['state']?.toString()
        .replaceAll('_', '')
        .toLowerCase() ?? '';
    if (stateStr == 'inprogress' || stateStr == 'in_progress') {
      state = EventState.inProgress;
    } else if (stateStr == 'completed') {
      state = EventState.completed;
    } else if (stateStr == 'backlog') {
      state = EventState.backlog;
    } else if (stateStr == 'cancelled') {
      state = EventState.cancelled;
    }

    // Parse task/goal WikiLinks (also read legacy linked_task/linked_goal from CalendarSession)
    String? parseWikiLink(dynamic val) {
      if (val == null) return null;
      final str = val.toString().trim();
      final match = RegExp(r'\[\[(.*?)\]\]').firstMatch(str);
      return match != null ? '[[${match.group(1)!}]]' : '[[$str]]';
    }

    final taskLink = frontmatter['task'] != null
        ? parseWikiLink(frontmatter['task'])
        : (frontmatter['linked_task'] != null
            ? parseWikiLink(frontmatter['linked_task'])
            : null);
    final goalLink = frontmatter['goal'] != null
        ? parseWikiLink(frontmatter['goal'])
        : (frontmatter['linked_goal'] != null
            ? parseWikiLink(frontmatter['linked_goal'])
            : null);

    // Parse pomodoro block
    EventPomodoro? pomodoro;
    if (frontmatter['pomodoro'] is Map) {
      pomodoro = EventPomodoro.fromMap(
        Map<String, dynamic>.from(frontmatter['pomodoro'] as Map),
      );
    }

    // Parse subtasks
    final List<String> subs = [];
    if (frontmatter['subtasks'] is List) {
      subs.addAll(
        (frontmatter['subtasks'] as List).map((e) => e.toString()),
      );
    }

    // Parse participants
    final List<String> parts = [];
    if (frontmatter['participants'] is List) {
      parts.addAll(
        (frontmatter['participants'] as List).map((e) => e.toString()),
      );
    }

    final event = Event(
      title: frontmatter['title']?.toString() ?? '',
      date: parsedDate,
      source: source,
      state: state,
      timeOfDay: frontmatter['time_of_day']?.toString(),
      duration: int.tryParse(frontmatter['duration']?.toString() ?? '') ?? 60,
      endTime: frontmatter['end_time']?.toString(),
      multiDay: frontmatter['multi_day'] == true,
      task: taskLink,
      goal: goalLink,
      subtasks: subs,
      note: frontmatter['note']?.toString() ?? body,
      participants: parts,
      backlog: frontmatter['backlog'] == true,
      pomodoro: pomodoro,
      linkedGoogleEventId: frontmatter['linked_google_event_id']?.toString() ??
          frontmatter['google_event_id']?.toString(),
      linkedGoogleEventTitle: frontmatter['linked_google_event_title']?.toString(),
      linkedGoogleEventUrl: frontmatter['linked_google_event_url']?.toString() ??
          frontmatter['google_event_url']?.toString(),
      location: frontmatter['location']?.toString(),
      googleCalendarId: frontmatter['google_calendar_id']?.toString(),
    );
    event.loadBaseMap(frontmatter);
    if (frontmatter['scheduler'] is Map) {
      event.scheduler = Scheduler.fromMap(
        Map<String, dynamic>.from(frontmatter['scheduler'] as Map),
      );
    }
    return event;
  }

  Event copyWith({
    String? title,
    DateTime? date,
    EventSource? source,
    EventState? state,
    String? timeOfDay,
    int? duration,
    String? endTime,
    bool? multiDay,
    String? task,
    String? goal,
    List<String>? subtasks,
    String? note,
    List<String>? participants,
    Scheduler? scheduler,
    bool? backlog,
    EventPomodoro? pomodoro,
    String? linkedGoogleEventId,
    String? linkedGoogleEventTitle,
    String? linkedGoogleEventUrl,
    String? location,
    String? googleCalendarId,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    List<String>? links,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    bool? archived,
    bool? pinned,
    int? order,
    List<ReminderConfig>? reminders,
  }) {
    return Event(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      source: source ?? this.source,
      state: state ?? this.state,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      duration: duration ?? this.duration,
      endTime: endTime ?? this.endTime,
      multiDay: multiDay ?? this.multiDay,
      task: task ?? this.task,
      goal: goal ?? this.goal,
      subtasks: subtasks ?? List<String>.from(this.subtasks),
      note: note ?? this.note,
      participants: participants ?? List<String>.from(this.participants),
      scheduler: scheduler ?? this.scheduler,
      backlog: backlog ?? this.backlog,
      pomodoro: pomodoro ?? this.pomodoro,
      linkedGoogleEventId: linkedGoogleEventId ?? this.linkedGoogleEventId,
      linkedGoogleEventTitle: linkedGoogleEventTitle ?? this.linkedGoogleEventTitle,
      linkedGoogleEventUrl: linkedGoogleEventUrl ?? this.linkedGoogleEventUrl,
      location: location ?? this.location,
      googleCalendarId: googleCalendarId ?? this.googleCalendarId,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      links: links ?? this.links,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obsidianPath: obsidianPath ?? this.obsidianPath,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      order: order ?? this.order,
      reminders: reminders ?? this.reminders,
    );
  }

  static String _stateToString(EventState s) {
    switch (s) {
      case EventState.inProgress: return 'in_progress';
      case EventState.completed: return 'completed';
      case EventState.backlog: return 'backlog';
      case EventState.cancelled: return 'cancelled';
      case EventState.scheduled: return 'scheduled';
    }
  }
}
