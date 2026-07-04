// lib/models/inbox_model.dart
import 'content_object.dart';

class InboxItem extends ContentObject {
  final String content;
  
  InboxItem({
    super.id,
    required super.title,
    required this.content,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  });

  @override
  String get type => 'inbox';

  @override
  bool get isIncomplete => title.trim().isEmpty;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    return generateMarkdown(frontmatter, content);
  }

  factory InboxItem.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final item = InboxItem(
      title: frontmatter['title'] as String? ?? 'Untitled',
      content: body,
    );
    item.loadBaseMap(frontmatter);
    return item;
  }

  InboxItem copyWith({
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
  }) {
    return InboxItem(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
  }
}
