// lib/models/moc_model.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'reminder_config.dart';

class MocDefinition extends ContentObject {
  String description;
  List<String> children; // List of WikiLinks, e.g., ["[[target-slug]]"]

  MocDefinition({
    super.id,
    required super.title,
    this.description = '',
    List<String>? children,
    super.organizers,
    super.categories,
    super.tags,
    super.moc,
    super.reminders,
    super.createdAt,
    super.updatedAt,
    super.archived,
    super.pinned,
    super.order,
    super.obsidianPath,
  }) : children = children ?? [];

  @override
  String get type => 'moc';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['description'] = description;
    frontmatter['children'] = children;

    return generateMarkdown(frontmatter, description);
  }

  factory MocDefinition.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    List<String> childrenList = [];
    if (frontmatter['children'] != null && frontmatter['children'] is List) {
      childrenList = (frontmatter['children'] as List).map((e) => e.toString()).toList();
    }
    final mocDef = MocDefinition(
      title: frontmatter['title'] as String? ?? '',
      description: frontmatter['description'] as String? ?? body,
      children: childrenList,
    );
    mocDef.loadBaseMap(frontmatter);
    return mocDef;
  }

  MocDefinition copyWith({
    String? title,
    String? description,
    List<String>? children,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    List<String>? moc,
    List<ReminderConfig>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? archived,
    bool? pinned,
    int? order,
    String? obsidianPath,
  }) {
    return MocDefinition(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      children: children ?? this.children,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      moc: moc ?? this.moc,
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
