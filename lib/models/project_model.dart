import 'content_object.dart';
import 'organizer_model.dart';
import 'task_model.dart';

enum ProjectState { active, paused, completed, archived }

class Project extends Organizer {
  ProjectState state;
  TaskPriority priority;
  String? description;
  String? primaryKpiId;
  List<String> secondaryKpiIds;
  List<String> taskLinks; // List of Task slugs/IDs
  List<String> quickAccessLinks; // List of WikiLinks
  int totalPomodoroTime; // Minutes

  Project({
    super.id,
    required super.title,
    this.state = ProjectState.active,
    this.priority = TaskPriority.none,
    this.description,
    this.primaryKpiId,
    List<String>? secondaryKpiIds,
    List<String>? taskLinks,
    List<String>? quickAccessLinks,
    this.totalPomodoroTime = 0,
    super.parentId,
    super.startDate,
    super.endDate,
    super.color,
    super.icon,
    super.organizers,
    super.categories,
    super.moc,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : secondaryKpiIds = secondaryKpiIds ?? [],
       taskLinks = taskLinks ?? [],
       quickAccessLinks = quickAccessLinks ?? [],
       super(organizerType: OrganizerType.project);

  @override
  String get type => 'project';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['organizer_type'] = organizerType.name;
    frontmatter['state'] = state.name;
    frontmatter['priority'] = priority.name;
    if (description != null) frontmatter['description'] = description;
    if (primaryKpiId != null) frontmatter['primary_kpi'] = primaryKpiId;
    frontmatter['secondary_kpis'] = secondaryKpiIds;
    frontmatter['tasks'] = taskLinks;
    frontmatter['quick_access'] = quickAccessLinks;
    frontmatter['total_pomodoro_time'] = totalPomodoroTime;

    // Add organizer-specific fields
    if (startDate != null) {
      frontmatter['start_date'] = startDate!.toIso8601String();
    }
    if (endDate != null) frontmatter['end_date'] = endDate!.toIso8601String();
    if (color != null) frontmatter['color'] = color;
    if (icon != null) frontmatter['icon'] = icon;

    return generateMarkdown(frontmatter, description ?? '');
  }

  factory Project.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final project = Project(
      title: frontmatter['title'] as String? ?? '',
    );
    project.loadBaseMap(frontmatter);

    if (frontmatter['state'] != null) {
      project.state = ProjectState.values.firstWhere(
        (e) => e.name == frontmatter['state'],
        orElse: () => ProjectState.active,
      );
    }
    if (frontmatter['priority'] != null) {
      project.priority = TaskPriority.values.firstWhere(
        (e) => e.name == frontmatter['priority'],
        orElse: () => TaskPriority.none,
      );
    }
    project.description = frontmatter['description'] is List ? (frontmatter['description'] as List).join(', ') : frontmatter['description']?.toString() ?? body;
    project.primaryKpiId = frontmatter['primary_kpi'] is List ? (frontmatter['primary_kpi'] as List).join(', ') : frontmatter['primary_kpi']?.toString();
    project.secondaryKpiIds = List<String>.from(
      frontmatter['secondary_kpis'] as List? ?? [],
    );
    project.taskLinks = List<String>.from(frontmatter['tasks'] as List? ?? []);
    project.quickAccessLinks = List<String>.from(
      frontmatter['quick_access'] as List? ?? [],
    );
    final tpt = frontmatter['total_pomodoro_time'];
    project.totalPomodoroTime = tpt is int ? tpt : int.tryParse(tpt?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;

    if (frontmatter['start_date'] != null) {
      project.startDate = DateTime.tryParse(frontmatter['start_date']);
    }
    if (frontmatter['end_date'] != null) {
      project.endDate = DateTime.tryParse(frontmatter['end_date']);
    }
    project.color = frontmatter['color'] is List ? (frontmatter['color'] as List).join(', ') : frontmatter['color']?.toString();
    project.icon = frontmatter['icon'] is List ? (frontmatter['icon'] as List).join(', ') : frontmatter['icon']?.toString();

    return project;
  }
}
