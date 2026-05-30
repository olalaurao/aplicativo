import 'content_object.dart';
import 'reminder_config.dart';
import 'shared_types.dart';

class Event extends ContentObject {
  DateTime startDatetime;
  DateTime? endDatetime;
  String? location;
  String? description;
  List<String> participants;
  String? googleEventId;
  String? googleCalendarId;
  String? googleEventUrl;

  Event({
    super.id,
    required super.title,
    required this.startDatetime,
    this.endDatetime,
    this.location,
    this.description,
    List<String>? participants,
    this.googleEventId,
    this.googleCalendarId,
    this.googleEventUrl,
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
  }) : participants = participants ?? [];

  @override
  String get type => 'event';

  @override
  DateTime? get baseTime => startDatetime;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['start_datetime'] = startDatetime.toIso8601String();
    if (endDatetime != null) {
      frontmatter['end_datetime'] = endDatetime!.toIso8601String();
    }
    if (_hasText(location)) frontmatter['location'] = location;
    if (_hasText(description)) frontmatter['description'] = description;
    if (participants.isNotEmpty) frontmatter['participants'] = participants;
    if (_hasText(googleEventId)) frontmatter['google_event_id'] = googleEventId;
    if (_hasText(googleCalendarId)) {
      frontmatter['google_calendar_id'] = googleCalendarId;
    }
    if (_hasText(googleEventUrl)) frontmatter['google_event_url'] = googleEventUrl;
    return generateMarkdown(frontmatter, description ?? '');
  }

  factory Event.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final start = DateTime.tryParse(
          frontmatter['start_datetime']?.toString() ??
              frontmatter['start']?.toString() ??
              '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final event = Event(
      title: frontmatter['title']?.toString() ?? '',
      startDatetime: start,
      endDatetime: DateTime.tryParse(
        frontmatter['end_datetime']?.toString() ??
            frontmatter['end']?.toString() ??
            '',
      ),
    );
    event.loadBaseMap(frontmatter);
    event.location = frontmatter['location']?.toString();
    event.description = frontmatter['description']?.toString() ?? body;
    event.participants = _stringList(frontmatter['participants']);
    event.googleEventId =
        frontmatter['google_event_id']?.toString() ??
        frontmatter['linked_google_event_id']?.toString();
    event.googleCalendarId = frontmatter['google_calendar_id']?.toString();
    event.googleEventUrl =
        frontmatter['google_event_url']?.toString() ??
        frontmatter['linked_google_event_url']?.toString();
    return event;
  }

  Event copyWith({
    String? title,
    DateTime? startDatetime,
    DateTime? endDatetime,
    String? location,
    String? description,
    List<String>? participants,
    String? googleEventId,
    String? googleCalendarId,
    String? googleEventUrl,
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
    return Event(
      id: id,
      title: title ?? this.title,
      startDatetime: startDatetime ?? this.startDatetime,
      endDatetime: endDatetime ?? this.endDatetime,
      location: location ?? this.location,
      description: description ?? this.description,
      participants: participants ?? List<String>.from(this.participants),
      googleEventId: googleEventId ?? this.googleEventId,
      googleCalendarId: googleCalendarId ?? this.googleCalendarId,
      googleEventUrl: googleEventUrl ?? this.googleEventUrl,
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

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return [];
    return [text];
  }
}
