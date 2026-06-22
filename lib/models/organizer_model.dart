// lib/models/organizer_model.dart
import 'content_object.dart';
import 'shared_types.dart';


enum OrganizerType {
  area,
  project,
  activity,
  task,
  goal,
  habit,
  tracker,
  label,
  person,
  place
}

class Organizer extends ContentObject {
  final OrganizerType organizerType;
  String? parentId;
  DateTime? startDate; // For Projects
  DateTime? endDate; // For Projects
  String? color;
  String? icon;
  String? state; // active | paused | completed (for project type)
  String? priority; // none | low | medium | high (for project type)

  Organizer({
    super.id,
    required super.title,
    required this.organizerType,
    this.parentId,
    this.startDate,
    this.endDate,
    this.color,
    this.icon,
    this.state,
    this.priority,
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  });

  @override
  String get type => organizerType.name;

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
    if (state != null) frontmatter['state'] = state;
    if (priority != null) frontmatter['priority'] = priority;

    return generateMarkdown(frontmatter, '');
  }

  factory Organizer.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final typeStr = frontmatter['type']?.toString() ?? '';
    final subtypeStr = frontmatter['organizer_type']?.toString() ?? typeStr;
    final type = OrganizerType.values.firstWhere(
      (e) => e.name == subtypeStr,
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
    organizer.state = frontmatter['state'] as String?;
    organizer.priority = frontmatter['priority'] as String?;

    return organizer;
  }

  Organizer copyWith({
    String? title,
    OrganizerType? organizerType,
    String? parentId,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
    String? icon,
    String? state,
    String? priority,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
  }) {
    return Organizer(
      id: id,
      title: title ?? this.title,
      organizerType: organizerType ?? this.organizerType,
      parentId: parentId ?? this.parentId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      state: state ?? this.state,
      priority: priority ?? this.priority,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
  }
}
