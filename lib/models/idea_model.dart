import 'content_object.dart';
import 'shared_types.dart';

class IdeaDefinition extends ContentObject {
  List<String> linkedTaskIds;
  String body;

  IdeaDefinition({
    super.id,
    required super.title,
    this.linkedTaskIds = const [],
    this.body = '',
    super.createdAt,
    super.updatedAt,
    super.archived,
    super.pinned,
    super.obsidianPath,
  });

  @override
  String get type => 'idea';

  @override
  String toMarkdown() {
    final map = toBaseMap();
    if (linkedTaskIds.isNotEmpty) {
      map['linked_tasks'] = linkedTaskIds;
    }
    return generateMarkdown(map, body);
  }

  factory IdeaDefinition.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String bodyContent,
    String filePath,
  ) {
    final idea = IdeaDefinition(
      title: frontmatter['title']?.toString() ?? 'Sem título',
      body: bodyContent.trim(),
      obsidianPath: filePath,
    );

    idea.loadBaseMap(frontmatter);

    if (frontmatter['linked_tasks'] is List) {
      idea.linkedTaskIds = (frontmatter['linked_tasks'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return idea;
  }

  IdeaDefinition copyWith({
    String? title,
    List<String>? linkedTaskIds,
    String? body,
    bool? archived,
    bool? pinned,
  }) {
    return IdeaDefinition(
      id: id,
      title: title ?? this.title,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      obsidianPath: obsidianPath,
    );
  }
}
