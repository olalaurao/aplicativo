// lib/models/shopping_list_model.dart
// A6.5 — ShoppingList & ShoppingItem models.
// Dedicated type for shopping lists: ultra-fast capture, native Android widget,
// category grouping, checked-item hiding.

import 'content_object.dart';
import 'shared_types.dart';

enum ShoppingItemStatus { active, checked, archived }

class ShoppingItem {
  final String id;
  final String name;
  final String? quantity; // "2 kg", "1 caixa"
  final String? category; // "Hortifruti", "Limpeza"
  final String? note;
  final ShoppingItemStatus status;
  final int order;

  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity,
    this.category,
    this.note,
    this.status = ShoppingItemStatus.active,
    this.order = 0,
  });

  bool get isChecked => status == ShoppingItemStatus.checked;

  ShoppingItem copyWith({
    String? name,
    String? quantity,
    String? category,
    String? note,
    ShoppingItemStatus? status,
    int? order,
  }) => ShoppingItem(
    id: id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    category: category ?? this.category,
    note: note ?? this.note,
    status: status ?? this.status,
    order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (quantity != null) 'quantity': quantity,
    if (category != null) 'category': category,
    if (note != null) 'note': note,
    'status': status.name,
    'order': order,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    quantity: j['quantity']?.toString(),
    category: j['category']?.toString(),
    note: j['note']?.toString(),
    status: ShoppingItemStatus.values.firstWhere(
      (e) => e.name == j['status']?.toString(),
      orElse: () => ShoppingItemStatus.active,
    ),
    order: (j['order'] as num?)?.toInt() ?? 0,
  );
}

class ShoppingList extends ContentObject {
  final List<ShoppingItem> items;
  final bool hideChecked;
  final String? color;
  final String emoji;

  ShoppingList({
    required super.id,
    required super.title,
    super.createdAt,
    super.updatedAt,
    super.archived = false,
    super.organizers = const [],
    super.tags = const [],
    this.color,
    this.emoji = '🛒',
    this.items = const [],
    this.hideChecked = true,
  });

  @override
  String get type => 'shopping_list';

  @override
  bool get isIncomplete => title.trim().isEmpty;

  @override
  String get obsidianFileName => title;

  @override
  String get slug => id;

  List<ShoppingItem> get activeItems =>
      items.where((i) => i.status == ShoppingItemStatus.active).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  List<ShoppingItem> get checkedItems =>
      items.where((i) => i.status == ShoppingItemStatus.checked).toList();

  int get activeCount => activeItems.length;
  int get checkedCount => checkedItems.length;
  int get totalCount =>
      items.where((i) => i.status != ShoppingItemStatus.archived).length;

  ShoppingList copyWith({
    String? title,
    List<ShoppingItem>? items,
    bool? hideChecked,
    bool? archived,
    List<OrganizerReference>? organizers,
    List<String>? tags,
    String? color,
    String? emoji,
    DateTime? updatedAt,
  }) => ShoppingList(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archived: archived ?? this.archived,
    organizers: organizers ?? this.organizers,
    tags: tags ?? this.tags,
    color: color ?? this.color,
    emoji: emoji ?? this.emoji,
    items: items ?? this.items,
    hideChecked: hideChecked ?? this.hideChecked,
  );

  @override
  String toMarkdown() {
    final fm = <String, dynamic>{
      'id': id,
      'type': 'shopping_list',
      'title': title,
      'hide_checked': hideChecked,
      'archived': archived,
      if (organizers.isNotEmpty)
        'organizers': organizers.map((o) => o.toWikiLink()).toList(),
      if (tags.isNotEmpty) 'tags': tags,
      if (color != null) 'color': color,
      'emoji': emoji,
      'items': items.map((i) => i.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    // Body: markdown checklist representation
    final buf = StringBuffer();
    for (final item in activeItems) {
      final qty = item.quantity != null ? ' (${item.quantity})' : '';
      buf.writeln('- [ ] ${item.name}$qty');
    }
    for (final item in checkedItems) {
      final qty = item.quantity != null ? ' (${item.quantity})' : '';
      buf.writeln('- [x] ${item.name}$qty');
    }
    return generateMarkdown(fm, buf.toString().trim());
  }

  factory ShoppingList.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final rawItems = frontmatter['items'];
    final List<ShoppingItem> items = [];
    if (rawItems is List) {
      items.addAll(
        rawItems.whereType<Map>().map(
          (i) => ShoppingItem.fromJson(Map<String, dynamic>.from(i)),
        ),
      );
    }
    final sl = ShoppingList(
      id: frontmatter['id']?.toString() ?? '',
      title: frontmatter['title']?.toString() ?? '',
      hideChecked: frontmatter['hide_checked'] as bool? ?? true,
      archived: frontmatter['archived'] as bool? ?? false,
      organizers: (frontmatter['organizers'] as List? ?? [])
          .map((o) => OrganizerReference.fromWikiLink(o.toString()))
          .toList(),
      tags: List<String>.from(frontmatter['tags'] ?? []),
      color: frontmatter['color']?.toString(),
      emoji: frontmatter['emoji']?.toString() ?? '🛒',
      items: items,
      createdAt: frontmatter['created_at'] != null
          ? DateTime.tryParse(frontmatter['created_at'].toString())
          : null,
      updatedAt: frontmatter['updated_at'] != null
          ? DateTime.tryParse(frontmatter['updated_at'].toString())
          : null,
    );
    return sl;
  }
}
