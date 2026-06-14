import 'content_object.dart';
import 'package:uuid/uuid.dart';

class ShoppingItem extends ContentObject {
  bool isCompleted;

  ShoppingItem({
    String? id,
    required String title,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String obsidianPath = '',
    bool archived = false,
    List<String>? categories,
  }) : super(
          id: id ?? const Uuid().v4(),
          title: title,
          createdAt: createdAt ?? DateTime.now(),
          updatedAt: updatedAt ?? DateTime.now(),
          obsidianPath: obsidianPath,
          archived: archived,
          categories: categories,
        );

  @override
  String get type => 'shopping_item';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['completed'] = isCompleted;
    return generateMarkdown(frontmatter, '');
  }

  factory ShoppingItem.fromMarkdown(Map<String, dynamic> map, String body) {
    final item = ShoppingItem(
      title: map['title']?.toString() ?? '',
      isCompleted: map['completed'] == true || map['completed'] == 'true',
    );
    item.loadBaseMap(map);
    return item;
  }

  ShoppingItem copyWith({
    String? title,
    bool? isCompleted,
    DateTime? updatedAt,
    int? order,
    List<String>? categories,
  }) {
    final item = ShoppingItem(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath,
      archived: archived,
      categories: categories ?? this.categories,
    )..loadBaseMap(toBaseMap()); // copy organizers, etc.
    if (order != null) item.order = order;
    return item;
  }
}
