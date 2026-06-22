import 'content_object.dart';
import 'reminder_config.dart';
import 'shared_types.dart';

enum CalendarSessionState { scheduled, inProgress, completed, backlog, cancelled }

class CalendarSession extends ContentObject {
  DateTime date;
  CalendarSessionState state;
  String? timeOfDay;
  int duration;
  String? endTime;
  bool multiDay;
  String? linkedTaskId; // slug
  String? linkedGoalId; // slug
  List<String> subtasks;
  String? note;
  String? color;
  List<String> places;
  List<String> participants;
  String? linkedGoogleEventId;
  String? linkedGoogleEventTitle;
  DateTime? linkedGoogleEventDate;
  String? linkedGoogleEventUrl;
  int timerMinutesWorked;
  bool backlog;

  CalendarSession({
    super.id,
    required super.title,
    required this.date,
    this.state = CalendarSessionState.scheduled,
    this.timeOfDay,
    this.duration = 60,
    this.endTime,
    this.multiDay = false,
    this.linkedTaskId,
    this.linkedGoalId,
    List<String>? subtasks,
    this.note,
    this.color,
    List<String>? places,
    List<String>? participants,
    this.linkedGoogleEventId,
    this.linkedGoogleEventTitle,
    this.linkedGoogleEventDate,
    this.linkedGoogleEventUrl,
    this.timerMinutesWorked = 0,
    this.backlog = false,
    super.organizers,
    super.categories,
    super.tags,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.archived,
    super.pinned,
    super.order,
    super.reminders,
  }) : subtasks = subtasks ?? [],
       places = places ?? [],
       participants = participants ?? [];

  @override
  String get type => 'calendar_session';

  @override
  DateTime? get baseTime => date;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['date'] = date.toIso8601String().split('T').first;
    frontmatter['state'] = state.name.replaceAll(RegExp(r'([A-Z])'), r'_\1').toLowerCase();
    if (timeOfDay != null) frontmatter['time_of_day'] = timeOfDay;
    frontmatter['duration'] = duration;
    if (endTime != null) frontmatter['end_time'] = endTime;
    frontmatter['multi_day'] = multiDay;
    if (linkedTaskId != null && linkedTaskId!.isNotEmpty) {
      frontmatter['linked_task'] = '[[$linkedTaskId]]';
    }
    if (linkedGoalId != null && linkedGoalId!.isNotEmpty) {
      frontmatter['linked_goal'] = '[[$linkedGoalId]]';
    }
    if (subtasks.isNotEmpty) frontmatter['subtasks'] = subtasks;
    if (note != null) frontmatter['note'] = note;
    if (color != null) frontmatter['color'] = color;
    if (places.isNotEmpty) frontmatter['places'] = places;
    if (participants.isNotEmpty) frontmatter['participants'] = participants;
    if (linkedGoogleEventId != null) frontmatter['linked_google_event_id'] = linkedGoogleEventId;
    if (linkedGoogleEventTitle != null) frontmatter['linked_google_event_title'] = linkedGoogleEventTitle;
    if (linkedGoogleEventDate != null) {
      frontmatter['linked_google_event_date'] = linkedGoogleEventDate!.toIso8601String();
    }
    if (linkedGoogleEventUrl != null) frontmatter['linked_google_event_url'] = linkedGoogleEventUrl;
    frontmatter['timer_minutes_worked'] = timerMinutesWorked;
    frontmatter['backlog'] = backlog;

    return generateMarkdown(frontmatter, note ?? '');
  }

  factory CalendarSession.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    CalendarSessionState state = CalendarSessionState.scheduled;
    final stateStr = frontmatter['state']?.toString().replaceAll('_', '').toLowerCase();
    if (stateStr == 'inprogress') state = CalendarSessionState.inProgress;
    if (stateStr == 'completed') state = CalendarSessionState.completed;
    if (stateStr == 'backlog') state = CalendarSessionState.backlog;
    if (stateStr == 'cancelled') state = CalendarSessionState.cancelled;

    final rawDate = frontmatter['date']?.toString();
    final parsedDate = rawDate == null ? null : DateTime.tryParse(rawDate);

    String? parseWikiLink(dynamic val) {
      if (val == null) return null;
      final str = val.toString().trim();
      final match = RegExp(r'\[\[(.*?)\]\]').firstMatch(str);
      return match != null ? match.group(1) : str;
    }

    final List<String> subs = [];
    if (frontmatter['subtasks'] is List) {
      subs.addAll((frontmatter['subtasks'] as List).map((item) => item.toString()));
    }

    final List<String> pl = [];
    if (frontmatter['places'] is List) {
      pl.addAll((frontmatter['places'] as List).map((item) => item.toString()));
    }

    final List<String> pt = [];
    if (frontmatter['participants'] is List) {
      pt.addAll((frontmatter['participants'] as List).map((item) => item.toString()));
    }

    final session = CalendarSession(
      title: frontmatter['title']?.toString() ?? '',
      date: parsedDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      state: state,
      timeOfDay: frontmatter['time_of_day']?.toString(),
      duration: int.tryParse(frontmatter['duration']?.toString() ?? '') ?? 60,
      endTime: frontmatter['end_time']?.toString(),
      multiDay: frontmatter['multi_day'] == true,
      linkedTaskId: parseWikiLink(frontmatter['linked_task']),
      linkedGoalId: parseWikiLink(frontmatter['linked_goal']),
      subtasks: subs,
      note: frontmatter['note']?.toString() ?? body,
      color: frontmatter['color']?.toString(),
      places: pl,
      participants: pt,
      linkedGoogleEventId: frontmatter['linked_google_event_id']?.toString(),
      linkedGoogleEventTitle: frontmatter['linked_google_event_title']?.toString(),
      linkedGoogleEventDate: DateTime.tryParse(frontmatter['linked_google_event_date']?.toString() ?? ''),
      linkedGoogleEventUrl: frontmatter['linked_google_event_url']?.toString(),
      timerMinutesWorked: int.tryParse(frontmatter['timer_minutes_worked']?.toString() ?? '') ?? 0,
      backlog: frontmatter['backlog'] == true,
    );
    session.loadBaseMap(frontmatter);
    return session;
  }

  CalendarSession copyWith({
    String? title,
    DateTime? date,
    CalendarSessionState? state,
    String? timeOfDay,
    int? duration,
    String? endTime,
    bool? multiDay,
    String? linkedTaskId,
    String? linkedGoalId,
    List<String>? subtasks,
    String? note,
    String? color,
    List<String>? places,
    List<String>? participants,
    String? linkedGoogleEventId,
    String? linkedGoogleEventTitle,
    DateTime? linkedGoogleEventDate,
    String? linkedGoogleEventUrl,
    int? timerMinutesWorked,
    bool? backlog,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    bool? archived,
    bool? pinned,
    int? order,
    List<ReminderConfig>? reminders,
  }) {
    return CalendarSession(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      state: state ?? this.state,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      duration: duration ?? this.duration,
      endTime: endTime ?? this.endTime,
      multiDay: multiDay ?? this.multiDay,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
      subtasks: subtasks ?? this.subtasks,
      note: note ?? this.note,
      color: color ?? this.color,
      places: places ?? this.places,
      participants: participants ?? this.participants,
      linkedGoogleEventId: linkedGoogleEventId ?? this.linkedGoogleEventId,
      linkedGoogleEventTitle: linkedGoogleEventTitle ?? this.linkedGoogleEventTitle,
      linkedGoogleEventDate: linkedGoogleEventDate ?? this.linkedGoogleEventDate,
      linkedGoogleEventUrl: linkedGoogleEventUrl ?? this.linkedGoogleEventUrl,
      timerMinutesWorked: timerMinutesWorked ?? this.timerMinutesWorked,
      backlog: backlog ?? this.backlog,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obsidianPath: obsidianPath ?? this.obsidianPath,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      order: order ?? this.order,
      reminders: reminders ?? this.reminders,
    );
  }
}
