// lib/models/journal_entry.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'reminder_config.dart';
import 'package:flutter/foundation.dart';

class JournalEntry extends ContentObject {
  String body;
  DateTime date;
  String? timeOfDay;
  String? moodSlug; // Reference to MoodDefinition.id
  List<String> photos;
  String? location;
  String? templateId;
  List<Comment> comments;
  Map<String, dynamic>? weather;

  JournalEntry({
    super.id,
    String? title,
    required this.body,
    required this.date,
    this.timeOfDay,
    this.moodSlug,
    this.photos = const [],
    this.location,
    this.templateId,
    this.comments = const [],
    this.weather,
    super.organizers,
    super.categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.obsidianPath,
  }) : super(
         title: title ?? '',
         createdAt: createdAt ?? date,
         updatedAt: updatedAt ?? createdAt ?? date,
       );

  @override
  String get type => 'journal_entry';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['date'] = date.toIso8601String();
    if (timeOfDay != null) frontmatter['time'] = timeOfDay;
    if (moodSlug != null) frontmatter['mood'] = moodSlug;
    if (location != null) frontmatter['location'] = location;
    if (photos.isNotEmpty) frontmatter['photos'] = photos;

    return generateMarkdown(
      frontmatter,
      normalizeRichTextBodyForMarkdown(body),
    );
  }

  factory JournalEntry.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final rawDate = frontmatter['date']?.toString();
    final parsedDate = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (rawDate != null && parsedDate == null) {
      debugPrint('Invalid journal entry date in frontmatter: $rawDate');
    }
    final entry = JournalEntry(
      title: frontmatter['title'] as String?,
      body: body,
      date: parsedDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      timeOfDay: frontmatter['time']?.toString(),
    );
    entry.loadBaseMap(frontmatter);

    entry.moodSlug = frontmatter['mood'] as String?;
    entry.location = frontmatter['location'] as String?;
    final rawPhotos = frontmatter['photos'];
    if (rawPhotos is List) {
      entry.photos = rawPhotos.map((item) => item.toString()).toList();
    } else if (rawPhotos is String && rawPhotos.trim().isNotEmpty) {
      entry.photos = [rawPhotos.trim()];
    }

    return entry;
  }

  JournalEntry copyWith({
    String? body,
    DateTime? date,
    String? timeOfDay,
    String? moodSlug,
    List<String>? photos,
    String? location,
    String? templateId,
    List<Comment>? comments,
    Map<String, dynamic>? weather,
    String? title,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<ReminderConfig>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
  }) {
    return JournalEntry(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      date: date ?? this.date,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      moodSlug: moodSlug ?? this.moodSlug,
      photos: photos ?? this.photos,
      location: location ?? this.location,
      templateId: templateId ?? this.templateId,
      comments: comments ?? this.comments,
      weather: weather ?? this.weather,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
    )..reminders = reminders ?? this.reminders;
  }
}
