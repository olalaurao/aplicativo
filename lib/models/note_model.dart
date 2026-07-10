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
  bool isChecklist;
  String? schedulerSlug;
  bool showInPlanner;
  String? coverImagePath;

  Note({
    super.id,
    required super.title,
    required this.subtype,
    required this.body,
    this.parentNoteId,
    this.color,
    this.isChecklist = false,
    this.schedulerSlug,
    this.showInPlanner = false,
    this.coverImagePath,
    super.organizers,
    super.categories,
    super.tags,
    super.links,
    super.reminders,
    super.createdAt,
    super.updatedAt,
    super.archived,
    super.pinned,
    super.order,
    super.obsidianPath,
  });

  @override
  String get type => 'note';

  @override
  bool get isIncomplete => title.trim().isEmpty;

  String get noteType => subtype.name;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['note_subtype'] = subtype.name;
    if (parentNoteId != null) frontmatter['parent_note_id'] = parentNoteId;
    if (color != null) frontmatter['color'] = color;
    if (isChecklist) frontmatter['is_checklist'] = true;
    if (schedulerSlug != null) frontmatter['scheduler_slug'] = schedulerSlug;
    if (showInPlanner) frontmatter['show_in_planner'] = true;
    if (coverImagePath != null) frontmatter['cover_image_path'] = coverImagePath;
    if (links.isNotEmpty) frontmatter['links'] = links;

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
      links: List<String>.from(frontmatter['links'] as List? ?? []),
    );
    note.loadBaseMap(frontmatter);
    note.parentNoteId = frontmatter['parent_note_id'] as String?;
    note.color = frontmatter['color'] as String?;
    note.isChecklist = frontmatter['is_checklist'] == true;
    note.schedulerSlug = frontmatter['scheduler_slug']?.toString();
    note.showInPlanner = frontmatter['show_in_planner'] == true;
    note.coverImagePath = frontmatter['cover_image_path'] as String?;
    return note;
  }

  Note copyWith({
    String? title,
    NoteSubtype? subtype,
    String? body,
    String? parentNoteId,
    String? color,
    bool? isChecklist,
    String? schedulerSlug,
    bool? showInPlanner,
    String? coverImagePath,
    List<String>? links,
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
      isChecklist: isChecklist ?? this.isChecklist,
      schedulerSlug: schedulerSlug ?? this.schedulerSlug,
      showInPlanner: showInPlanner ?? this.showInPlanner,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      links: links ?? List<String>.from(this.links),
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
