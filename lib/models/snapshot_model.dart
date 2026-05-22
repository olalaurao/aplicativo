// lib/models/snapshot_model.dart
import 'content_object.dart';

class Snapshot extends ContentObject {
  final String parentId; // Goal or Project ID
  final Map<String, double> kpiValues;
  final String reflection;
  final DateTime date;

  Snapshot({
    super.id,
    required super.title,
    required this.parentId,
    required this.kpiValues,
    required this.reflection,
    required this.date,
    super.createdAt,
    super.updatedAt,
  }) : super();

  @override
  String get type => 'snapshot';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['parent_id'] = parentId;
    frontmatter['kpi_values'] = kpiValues;
    frontmatter['date'] = date.toIso8601String();

    return generateMarkdown(frontmatter, reflection);
  }

  factory Snapshot.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final snapshot = Snapshot(
      title: frontmatter['title'] as String? ?? 'Snapshot',
      parentId: frontmatter['parent_id'] as String,
      kpiValues: Map<String, double>.from(frontmatter['kpi_values'] ?? {}),
      reflection: body,
      date: DateTime.parse(frontmatter['date']),
    );
    snapshot.loadBaseMap(frontmatter);
    return snapshot;
  }
}
