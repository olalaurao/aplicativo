// lib/models/mood_model.dart
import 'content_object.dart';

class MoodDefinition extends ContentObject {
  final String label;
  final String emoji;
  final int numericValue;
  final String color;
  final int order;

  MoodDefinition({
    super.id, // slug like 'good', 'bad'
    required super.title, // same as label or more descriptive
    required this.label,
    required this.emoji,
    required this.numericValue,
    required this.color,
    required this.order,
    super.obsidianPath,
  });

  MoodDefinition copyWith({
    String? id,
    String? title,
    String? label,
    String? emoji,
    int? numericValue,
    String? color,
    int? order,
    String? obsidianPath,
  }) {
    final copy = MoodDefinition(
      id: id ?? this.id,
      title: title ?? this.title,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      numericValue: numericValue ?? this.numericValue,
      color: color ?? this.color,
      order: order ?? this.order,
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
    copy.loadBaseMap(toBaseMap());
    return copy;
  }


  @override
  String get type => 'mood_definition';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['label'] = label;
    frontmatter['emoji'] = emoji;
    frontmatter['numeric_value'] = numericValue;
    frontmatter['color'] = color;
    frontmatter['order'] = order;
    return generateMarkdown(frontmatter, '# $label');
  }

  factory MoodDefinition.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final mood = MoodDefinition(
      id: frontmatter['id'] as String? ?? 'neutral',
      title: frontmatter['title'] as String? ?? 'Neutral',
      label: frontmatter['label'] as String? ?? 'Neutral',
      emoji: frontmatter['emoji'] as String? ?? '😐',
      numericValue: (frontmatter['numeric_value'] as num? ?? 3).toInt(),
      color: frontmatter['color'] as String? ?? '#9E9E9E',
      order: (frontmatter['order'] as num? ?? 3).toInt(),
    );
    mood.loadBaseMap(frontmatter);
    return mood;
  }
}
