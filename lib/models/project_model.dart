import 'content_object.dart';
import 'organizer_model.dart';
import 'task_model.dart';

enum ProjectState { active, paused, completed, archived }

class Project extends Organizer {
  String? description;
  String? primaryKpiId;
  List<String> secondaryKpiIds;
  List<String> taskLinks; // List of Task slugs/IDs
  List<String> quickAccessLinks; // List of WikiLinks
  int totalPomodoroTime; // Minutes
  String? linkedGoogleEventId;
  String? linkedGoogleEventTitle;
  String? linkedGoogleEventDate;
  String? linkedGoogleEventUrl;

  ProjectState get projectState => ProjectState.values.firstWhere(
        (e) => e.name == super.state,
        orElse: () => ProjectState.active,
      );
  set projectState(ProjectState value) => super.state = value.name;

  TaskPriority get projectPriority => TaskPriority.values.firstWhere(
        (e) => e.name == super.priority,
        orElse: () => TaskPriority.none,
      );
  set projectPriority(TaskPriority value) => super.priority = value.name;

  Project({
    super.id,
    required super.title,
    ProjectState state = ProjectState.active,
    TaskPriority priority = TaskPriority.none,
    this.description,
    this.primaryKpiId,
    List<String>? secondaryKpiIds,
    List<String>? taskLinks,
    List<String>? quickAccessLinks,
    this.totalPomodoroTime = 0,
    this.linkedGoogleEventId,
    this.linkedGoogleEventTitle,
    this.linkedGoogleEventDate,
    this.linkedGoogleEventUrl,
    super.parentId,
    super.startDate,
    super.endDate,
    super.color,
    super.icon,
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : secondaryKpiIds = secondaryKpiIds ?? [],
       taskLinks = taskLinks ?? [],
       quickAccessLinks = quickAccessLinks ?? [],
       super(
         organizerType: OrganizerType.project,
         state: state.name,
         priority: priority.name,
       );

  @override
  String get type => 'project';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['organizer_type'] = organizerType.name;
    frontmatter['state'] = projectState.name;
    frontmatter['priority'] = projectPriority.name;
    if (description != null) frontmatter['description'] = description;
    if (primaryKpiId != null) frontmatter['primary_kpi'] = primaryKpiId;
    frontmatter['secondary_kpis'] = secondaryKpiIds;
    frontmatter['tasks'] = taskLinks;
    frontmatter['quick_access'] = quickAccessLinks;
    frontmatter['total_pomodoro_time'] = totalPomodoroTime;
    if (linkedGoogleEventId != null) {
      frontmatter['linked_google_event_id'] = linkedGoogleEventId;
    }
    if (linkedGoogleEventTitle != null) {
      frontmatter['linked_google_event_title'] = linkedGoogleEventTitle;
    }
    if (linkedGoogleEventDate != null) {
      frontmatter['linked_google_event_date'] = linkedGoogleEventDate;
    }
    if (linkedGoogleEventUrl != null) {
      frontmatter['linked_google_event_url'] = linkedGoogleEventUrl;
    }

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
      project.projectState = ProjectState.values.firstWhere(
        (e) => e.name == frontmatter['state'],
        orElse: () => ProjectState.active,
      );
    }
    if (frontmatter['priority'] != null) {
      project.projectPriority = TaskPriority.values.firstWhere(
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
    project.linkedGoogleEventId =
        frontmatter['linked_google_event_id']?.toString();
    project.linkedGoogleEventTitle =
        frontmatter['linked_google_event_title']?.toString();
    project.linkedGoogleEventDate =
        frontmatter['linked_google_event_date']?.toString();
    project.linkedGoogleEventUrl =
        frontmatter['linked_google_event_url']?.toString();

    return project;
  }
}
