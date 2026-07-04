// lib/models/snapshot_model.dart
import 'content_object.dart';

class Snapshot extends ContentObject {
  /// V5: subject can reference Goal, Project, Task, or Note.
  /// Stored as a WikiLink string e.g. "[[my-project-slug]]".
  final String parentId;
  final Map<String, double> kpiValues;
  final String reflection;
  final DateTime date;
  final List<String> photos;

  Snapshot({
    super.id,
    required super.title,
    required this.parentId,
    required this.kpiValues,
    required this.reflection,
    required this.date,
    this.photos = const [],
    super.createdAt,
    super.updatedAt,
  }) : super();

  @override
  String get type => 'snapshot';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['subject'] = parentId.startsWith('[[')
        ? parentId
        : '[[$parentId]]';
    frontmatter['kpi_values'] = kpiValues;
    frontmatter['date'] = date.toIso8601String();
    if (photos.isNotEmpty) frontmatter['photos'] = photos;

    return generateMarkdown(frontmatter, reflection);
  }

  factory Snapshot.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final subject = frontmatter['subject']?.toString();
    final parent =
        subject != null && subject.startsWith('[[') && subject.endsWith(']]')
        ? subject.substring(2, subject.length - 2)
        : subject ?? frontmatter['parent_id']?.toString() ?? '';
    final rawKpis = Map<String, dynamic>.from(
      frontmatter['kpi_values'] as Map? ?? {},
    );
    final snapshot = Snapshot(
      title: frontmatter['title'] as String? ?? 'Snapshot',
      parentId: parent,
      kpiValues: rawKpis.map(
        (key, value) => MapEntry(
          key,
          value is num
              ? value.toDouble()
              : double.tryParse(value.toString()) ?? 0,
        ),
      ),
      reflection: body,
      date:
          DateTime.tryParse(frontmatter['date']?.toString() ?? '') ??
          DateTime.now(),
      photos: List<String>.from(frontmatter['photos'] as List? ?? []),
    );
    snapshot.loadBaseMap(frontmatter);
    return snapshot;
  }
}
