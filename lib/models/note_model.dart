// lib/models/note_model.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'reminder_config.dart';

enum NoteSubtype { text, outline, collection }

class Note extends ContentObject {
  final NoteSubtype subtype;
  final String body; // Raw markdown or JSON for outline/collection
  String? parentNoteId;
  String? color;
  List<String> socialRefs;

  Note({
    super.id,
    required super.title,
    required this.subtype,
    required this.body,
    this.parentNoteId,
    this.color,
    List<String>? socialRefs,
    super.organizers,
    super.categories,
    super.tags,
    super.reminders,
    super.createdAt,
    super.updatedAt,
    super.archived,
    super.pinned,
    super.order,
    super.obsidianPath,
  }) : socialRefs = socialRefs ?? [];

  @override
  String get type => 'note';

  String get noteType => subtype.name;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['note_subtype'] = subtype.name;
    if (parentNoteId != null) frontmatter['parent_note_id'] = parentNoteId;
    if (color != null) frontmatter['color'] = color;
    if (socialRefs.isNotEmpty) frontmatter['social_refs'] = socialRefs;

    final markdownBody = subtype == NoteSubtype.text
        ? normalizeRichTextBodyForMarkdown(body)
        : body;
    return generateMarkdown(frontmatter, markdownBody);
  }

  factory Note.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final subtypeStr = frontmatter['note_subtype'] as String? ?? 'text';
    final subtype = NoteSubtype.values.firstWhere(
      (e) => e.name == subtypeStr,
      orElse: () => NoteSubtype.text,
    );

    final note = Note(
      title: frontmatter['title'] as String? ?? '',
      subtype: subtype,
      body: body,
    );
    note.loadBaseMap(frontmatter);
    note.parentNoteId = frontmatter['parent_note_id'] as String?;
    note.color = frontmatter['color'] as String?;
    if (frontmatter['social_refs'] is List) {
      note.socialRefs = (frontmatter['social_refs'] as List)
          .map((e) => e.toString())
          .toList();
    }
    return note;
  }

  Note copyWith({
    String? title,
    NoteSubtype? subtype,
    String? body,
    String? parentNoteId,
    String? color,
    List<String>? socialRefs,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    List<ReminderConfig>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? archived,
    bool? pinned,
    int? order,
    String? obsidianPath,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      subtype: subtype ?? this.subtype,
      body: body ?? this.body,
      parentNoteId: parentNoteId ?? this.parentNoteId,
      color: color ?? this.color,
      socialRefs: socialRefs ?? List<String>.from(this.socialRefs),
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      reminders: reminders ?? this.reminders,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      order: order ?? this.order,
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
  }
}
