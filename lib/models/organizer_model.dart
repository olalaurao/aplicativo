// lib/models/organizer_model.dart
import 'content_object.dart';

enum OrganizerType { area, project, activity, label, person, place }

class Organizer extends ContentObject {
  final OrganizerType organizerType;
  String? parentId;
  DateTime? startDate; // For Projects
  DateTime? endDate; // For Projects
  String? color;
  String? icon;

  Organizer({
    super.id,
    required super.title,
    required this.organizerType,
    this.parentId,
    this.startDate,
    this.endDate,
    this.color,
    this.icon,
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  });

  @override
  String get type => 'organizer';

  @override
  String get displayType => organizerType.name.toUpperCase();

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['organizer_type'] = organizerType.name;
    if (parentId != null) frontmatter['parent_id'] = parentId;
    if (startDate != null) {
      frontmatter['start_date'] = startDate!.toIso8601String();
    }
    if (endDate != null) frontmatter['end_date'] = endDate!.toIso8601String();
    if (color != null) frontmatter['color'] = color;
    if (icon != null) frontmatter['icon'] = icon;

    return generateMarkdown(frontmatter, '');
  }

  factory Organizer.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final typeStr = frontmatter['organizer_type'] as String? ?? 'label';
    final type = OrganizerType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => OrganizerType.label,
    );

    final organizer = Organizer(
      title: frontmatter['title'] is List ? (frontmatter['title'] as List).join(', ') : frontmatter['title']?.toString() ?? '',
      organizerType: type,
    );
    organizer.loadBaseMap(frontmatter);

    organizer.parentId = frontmatter['parent_id'] as String?;
    if (frontmatter['start_date'] != null) {
      organizer.startDate = DateTime.tryParse(frontmatter['start_date']);
    }
    if (frontmatter['end_date'] != null) {
      organizer.endDate = DateTime.tryParse(frontmatter['end_date']);
    }
    organizer.color = frontmatter['color'] as String?;
    organizer.icon = frontmatter['icon'] as String?;

    return organizer;
  }
}


