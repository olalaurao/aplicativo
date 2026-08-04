import 'content_object.dart';
import 'organizer_model.dart';
import 'scheduler.dart';
import 'reminder_config.dart';
import 'shared_types.dart';
import 'task_model.dart';
import 'kpi_model.dart' as kpi;
import 'checklist_step.dart';

enum ProjectState { active, paused, completed, archived }

class RotationGroup {
  final String id;
  final String name;
  final String? emoji;
  final String? colorHex;
  final int periodDays;
  final int order;

  const RotationGroup({
    required this.id,
    required this.name,
    this.emoji,
    this.colorHex,
    required this.periodDays,
    required this.order,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (emoji != null) 'emoji': emoji,
    if (colorHex != null) 'color': colorHex,
    'period_days': periodDays,
    'order': order,
  };

  factory RotationGroup.fromMap(Map<String, dynamic> map) => RotationGroup(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    emoji: map['emoji']?.toString(),
    colorHex: map['color']?.toString(),
    periodDays: map['period_days'] as int? ?? 7,
    order: map['order'] as int? ?? 0,
  );
}

class RotationScheduleOverride {
  final String scopeKey;
  final String? scheduledTime;
  final int? durationMinutes;

  const RotationScheduleOverride({
    required this.scopeKey,
    this.scheduledTime,
    this.durationMinutes,
  });

  Map<String, dynamic> toMap() => {
    'scope_key': scopeKey,
    if (scheduledTime != null) 'scheduled_time': scheduledTime,
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
  };

  factory RotationScheduleOverride.fromMap(Map<String, dynamic> map) =>
      RotationScheduleOverride(
        scopeKey: map['scope_key']?.toString() ?? '',
        scheduledTime: map['scheduled_time']?.toString(),
        durationMinutes: map['duration_minutes'] is num
            ? (map['duration_minutes'] as num).toInt()
            : int.tryParse(map['duration_minutes']?.toString() ?? ''),
      );
}

/// Trigger modes for a rotation reminder.
enum RotationReminderTriggerMode {
  /// Fire at the rotation block's scheduled start time.
  atStartTime,
  /// Fire N minutes before the rotation block's scheduled start time.
  minutesBefore,
  /// Fire at a fixed time of day (HH:mm) on rotation days.
  atTimeOfDay,
}

/// Reminder configuration attached to a rotation project.
/// Can apply to all groups (groupId == null) or a specific group.
class RotationReminderConfig {
  final String id;
  /// Null = applies to all rotation groups.
  final String? groupId;
  final RotationReminderTriggerMode triggerMode;
  /// Used when [triggerMode] == [RotationReminderTriggerMode.minutesBefore].
  final int? minutesBefore;
  /// Used when [triggerMode] == [RotationReminderTriggerMode.atTimeOfDay]. Format: "HH:mm".
  final String? timeOfDay;
  final NotificationType notificationType;

  const RotationReminderConfig({
    required this.id,
    this.groupId,
    this.triggerMode = RotationReminderTriggerMode.atStartTime,
    this.minutesBefore,
    this.timeOfDay,
    this.notificationType = NotificationType.push,
  });

  /// Compute the concrete trigger DateTime for a given rotation day.
  /// [blockStart] is the scheduled start of the rotation block (DateTime).
  DateTime? computeTriggerTime(DateTime blockStart) {
    switch (triggerMode) {
      case RotationReminderTriggerMode.atStartTime:
        return blockStart;
      case RotationReminderTriggerMode.minutesBefore:
        final mins = minutesBefore ?? 10;
        return blockStart.subtract(Duration(minutes: mins));
      case RotationReminderTriggerMode.atTimeOfDay:
        final parts = (timeOfDay ?? '09:00').split(':');
        final hour = int.tryParse(parts[0]) ?? 9;
        final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        return DateTime(
          blockStart.year,
          blockStart.month,
          blockStart.day,
          hour,
          minute,
        );
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    if (groupId != null) 'group_id': groupId,
    'trigger_mode': triggerMode.name,
    if (minutesBefore != null) 'minutes_before': minutesBefore,
    if (timeOfDay != null) 'time_of_day': timeOfDay,
    'notification_type': notificationType.name,
  };

  factory RotationReminderConfig.fromMap(Map<String, dynamic> map) =>
      RotationReminderConfig(
        id: map['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: map['group_id']?.toString(),
        triggerMode: RotationReminderTriggerMode.values.firstWhere(
          (e) => e.name == map['trigger_mode'],
          orElse: () => RotationReminderTriggerMode.atStartTime,
        ),
        minutesBefore: map['minutes_before'] is num
            ? (map['minutes_before'] as num).toInt()
            : int.tryParse(map['minutes_before']?.toString() ?? ''),
        timeOfDay: map['time_of_day']?.toString(),
        notificationType: NotificationType.values.firstWhere(
          (e) => e.name == map['notification_type'],
          orElse: () => NotificationType.push,
        ),
      );

  RotationReminderConfig copyWith({
    String? id,
    String? groupId,
    bool clearGroupId = false,
    RotationReminderTriggerMode? triggerMode,
    int? minutesBefore,
    bool clearMinutesBefore = false,
    String? timeOfDay,
    bool clearTimeOfDay = false,
    NotificationType? notificationType,
  }) => RotationReminderConfig(
    id: id ?? this.id,
    groupId: clearGroupId ? null : (groupId ?? this.groupId),
    triggerMode: triggerMode ?? this.triggerMode,
    minutesBefore: clearMinutesBefore ? null : (minutesBefore ?? this.minutesBefore),
    timeOfDay: clearTimeOfDay ? null : (timeOfDay ?? this.timeOfDay),
    notificationType: notificationType ?? this.notificationType,
  );
}

/// A phase groups Tasks by stage within a Project.
/// Each phase has a name and a list of WikiLinks to child Tasks.
class ProjectPhase {
  final String id;
  final String name;
  final String? description;
  final int order;
  final List<String> taskLinks; // WikiLinks to tasks in this phase

  const ProjectPhase({
    required this.id,
    required this.name,
    this.description,
    this.order = 0,
    this.taskLinks = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'order': order,
    'tasks': taskLinks,
  };

  factory ProjectPhase.fromMap(Map<String, dynamic> map) => ProjectPhase(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    description: map['description']?.toString(),
    order: map['order'] as int? ?? 0,
    taskLinks: List<String>.from(map['tasks'] as List? ?? []),
  );

  ProjectPhase copyWith({
    String? id,
    String? name,
    String? description,
    int? order,
    List<String>? taskLinks,
  }) => ProjectPhase(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    order: order ?? this.order,
    taskLinks: taskLinks ?? this.taskLinks,
  );
}

class Project extends Organizer {
  String? description;
  String? primaryKpiId;
  List<String> secondaryKpiIds;
  List<kpi.KPI> kpis;
  List<String> taskLinks; // List of Task slugs/IDs
  List<String> quickAccessLinks; // List of WikiLinks
  int totalPomodoroTime; // Minutes
  String? linkedGoogleEventId;
  String? linkedGoogleEventTitle;
  String? linkedGoogleEventDate;
  String? linkedGoogleEventUrl;
  @override Scheduler? scheduler;
  List<RotationGroup> rotationGroups = [];
  DateTime? rotationStartDate;
  String? rotationCurrentGroupId;
  DateTime? rotationCurrentPeriodStart;
  int rotationCycleNumber = 1;
  String? rotationScheduledTime;
  int? rotationDurationMinutes;
  List<RotationScheduleOverride> rotationScheduleOverrides = [];
  /// V5: absorbed from Goal's plan_mode
  String? objective;       // the why
  String? strategy;        // the how
  List<ProjectPhase> phases; // array grouping Tasks by stage
  List<ChecklistStep> steps; // actionable checklist steps
  /// V5: set on old file when a scheduled restart creates a new Project
  String? supersededBy;   // WikiLink e.g. "[[new-project-slug]]"
  String? methodLabel;
  /// Hierarchical progress combination mode: 'simple', 'weighted', 'children_only'
  String? hierarchyCombinationMode;
  /// Reminders attached to this project's rotation blocks.
  List<RotationReminderConfig> rotationReminders;

  bool get hasRotation =>
      rotationGroups.isNotEmpty && rotationStartDate != null;
  int get rotationCycleLengthDays =>
      rotationGroups.fold(0, (sum, g) => sum + g.periodDays);

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
    List<kpi.KPI>? kpis,
    List<String>? taskLinks,
    List<String>? quickAccessLinks,
    this.totalPomodoroTime = 0,
    this.linkedGoogleEventId,
    this.linkedGoogleEventTitle,
    this.linkedGoogleEventDate,
    this.linkedGoogleEventUrl,
    this.scheduler,
    super.reminders,
    List<RotationGroup>? rotationGroups,
    this.rotationStartDate,
    this.rotationCurrentGroupId,
    this.rotationCurrentPeriodStart,
    this.rotationCycleNumber = 1,
    this.rotationScheduledTime,
    this.rotationDurationMinutes,
    List<RotationScheduleOverride>? rotationScheduleOverrides,
    this.methodLabel,
    this.objective,
    this.strategy,
    List<ProjectPhase>? phases,
    List<ChecklistStep>? steps,
    this.supersededBy,
    this.hierarchyCombinationMode,
    List<RotationReminderConfig>? rotationReminders,
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
       kpis = kpis ?? [],
       taskLinks = taskLinks ?? [],
       quickAccessLinks = quickAccessLinks ?? [],
       rotationGroups = rotationGroups ?? [],
       rotationScheduleOverrides = rotationScheduleOverrides ?? [],
       phases = phases ?? [],
       steps = steps ?? [],
       rotationReminders = rotationReminders ?? [],
       super(
         organizerType: OrganizerType.project,
         state: state.name,
         priority: priority.name,
       );

  @override
  String get type => 'project';

  @override
  bool get isIncomplete => title.trim().isEmpty;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['organizer_type'] = organizerType.name;
    frontmatter['state'] = projectState.name;
    frontmatter['priority'] = projectPriority.name;
    if (description != null) frontmatter['description'] = description;
    if (primaryKpiId != null) frontmatter['primary_kpi'] = primaryKpiId;
    frontmatter['secondary_kpis'] = secondaryKpiIds;
    if (kpis.isNotEmpty) frontmatter['kpis'] = kpis.map((e) => e.toMap()).toList();
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
    if (scheduler != null) {
      frontmatter['scheduler'] = scheduler!.toMap();
    }
    if (rotationGroups.isNotEmpty) {
      frontmatter['rotation_groups'] =
          rotationGroups.map((g) => g.toMap()).toList();
    }
    if (rotationStartDate != null) {
      frontmatter['rotation_start_date'] =
          rotationStartDate!.toIso8601String().split('T').first;
    }
    if (rotationCurrentGroupId != null) {
      frontmatter['rotation_current_group'] = rotationCurrentGroupId;
    }
    if (rotationCurrentPeriodStart != null) {
      frontmatter['rotation_current_period_start'] =
          rotationCurrentPeriodStart!.toIso8601String().split('T').first;
    }
    if (rotationCycleNumber != 1) {
      frontmatter['rotation_cycle_number'] = rotationCycleNumber;
    }
    if (rotationScheduledTime != null) {
      frontmatter['rotation_scheduled_time'] = rotationScheduledTime;
    }
    if (rotationDurationMinutes != null) {
      frontmatter['rotation_duration_minutes'] = rotationDurationMinutes;
    }
    if (rotationScheduleOverrides.isNotEmpty) {
      frontmatter['rotation_schedule_overrides'] =
          rotationScheduleOverrides.map((o) => o.toMap()).toList();
    }
    if (methodLabel != null) frontmatter['method_label'] = methodLabel;

    // V5: Plan-mode fields absorbed from Goal
    if (objective != null) frontmatter['objective'] = objective;
    if (strategy != null) frontmatter['strategy'] = strategy;
    if (phases.isNotEmpty) {
      frontmatter['phases'] = phases.map((p) => p.toMap()).toList();
    }
    if (steps.isNotEmpty) {
      frontmatter['steps'] = steps.map((s) => s.toMap()).toList();
    }
    if (supersededBy != null) frontmatter['superseded_by'] = supersededBy;
    if (hierarchyCombinationMode != null) frontmatter['hierarchy_combination_mode'] = hierarchyCombinationMode;
    if (rotationReminders.isNotEmpty) {
      frontmatter['rotation_reminders'] =
          rotationReminders.map((r) => r.toMap()).toList();
    }

    // Add organizer-specific fields
    if (startDate != null) {
      frontmatter['start_date'] = startDate!.toIso8601String();
    }
    if (endDate != null) frontmatter['end_date'] = endDate!.toIso8601String();
    if (parentId != null) frontmatter['parent_id'] = parentId;
    if (color != null) frontmatter['color'] = color;
    if (icon != null) frontmatter['icon'] = icon;

    return generateMarkdown(frontmatter, description ?? '');
  }

  factory Project.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final project = Project(title: frontmatter['title'] as String? ?? '');
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
    project.description = frontmatter['description'] is List
        ? (frontmatter['description'] as List).join(', ')
        : frontmatter['description']?.toString() ?? body;
    project.primaryKpiId = frontmatter['primary_kpi'] is List
        ? (frontmatter['primary_kpi'] as List).join(', ')
        : frontmatter['primary_kpi']?.toString();
    project.secondaryKpiIds = List<String>.from(
      frontmatter['secondary_kpis'] as List? ?? [],
    );
    project.kpis = (frontmatter['kpis'] as List? ?? [])
        .whereType<Map>()
        .map((e) => kpi.KPI.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    project.taskLinks = List<String>.from(frontmatter['tasks'] as List? ?? []);
    project.quickAccessLinks = List<String>.from(
      frontmatter['quick_access'] as List? ?? [],
    );
    final tpt = frontmatter['total_pomodoro_time'];
    project.totalPomodoroTime = tpt is int
        ? tpt
        : int.tryParse(
                tpt?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '',
              ) ??
              0;

    if (frontmatter['start_date'] != null) {
      project.startDate = DateTime.tryParse(frontmatter['start_date']);
    }
    if (frontmatter['end_date'] != null) {
      project.endDate = DateTime.tryParse(frontmatter['end_date']);
    }
    project.parentId = frontmatter['parent_id'] as String?;
    project.color = frontmatter['color'] is List
        ? (frontmatter['color'] as List).join(', ')
        : frontmatter['color']?.toString();
    project.icon = frontmatter['icon'] is List
        ? (frontmatter['icon'] as List).join(', ')
        : frontmatter['icon']?.toString();
    project.linkedGoogleEventId = frontmatter['linked_google_event_id']
        ?.toString();
    project.linkedGoogleEventTitle = frontmatter['linked_google_event_title']
        ?.toString();
    project.linkedGoogleEventDate = frontmatter['linked_google_event_date']
        ?.toString();
    project.linkedGoogleEventUrl = frontmatter['linked_google_event_url']
        ?.toString();
    if (frontmatter['scheduler'] is Map) {
      project.scheduler = Scheduler.fromMap(
        Map<String, dynamic>.from(frontmatter['scheduler'] as Map),
      );
    }
    if (frontmatter['rotation_groups'] is List) {
      project.rotationGroups = (frontmatter['rotation_groups'] as List)
          .whereType<Map>()
          .map((m) => RotationGroup.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    if (frontmatter['rotation_start_date'] != null) {
      project.rotationStartDate =
          DateTime.tryParse(frontmatter['rotation_start_date'].toString());
    }
    project.rotationCurrentGroupId = frontmatter['rotation_current_group']?.toString();
    if (frontmatter['rotation_current_period_start'] != null) {
      project.rotationCurrentPeriodStart =
          DateTime.tryParse(frontmatter['rotation_current_period_start'].toString());
    }
    project.rotationCycleNumber = frontmatter['rotation_cycle_number'] as int? ?? 1;
    project.rotationScheduledTime = frontmatter['rotation_scheduled_time']?.toString();
    final rotationDuration = frontmatter['rotation_duration_minutes'];
    project.rotationDurationMinutes = rotationDuration is num
        ? rotationDuration.toInt()
        : int.tryParse(rotationDuration?.toString() ?? '');
    if (frontmatter['rotation_schedule_overrides'] is List) {
      project.rotationScheduleOverrides =
          (frontmatter['rotation_schedule_overrides'] as List)
              .whereType<Map>()
              .map(
                (m) => RotationScheduleOverride.fromMap(
                  Map<String, dynamic>.from(m),
                ),
              )
              .where((o) => o.scopeKey.isNotEmpty)
              .toList();
    }
    project.methodLabel = frontmatter['method_label']?.toString();
    project.hierarchyCombinationMode = frontmatter['hierarchy_combination_mode']?.toString();

    // V5: Plan-mode fields
    project.objective = frontmatter['objective'] is List
        ? (frontmatter['objective'] as List).join('\n')
        : frontmatter['objective']?.toString();
    project.strategy = frontmatter['strategy'] is List
        ? (frontmatter['strategy'] as List).join('\n')
        : frontmatter['strategy']?.toString();
    if (frontmatter['phases'] is List) {
      project.phases = (frontmatter['phases'] as List)
          .whereType<Map>()
          .map((m) => ProjectPhase.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    if (frontmatter['steps'] is List) {
      project.steps = (frontmatter['steps'] as List)
          .whereType<Map>()
          .map((m) => ChecklistStep.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    project.supersededBy = frontmatter['superseded_by']?.toString();
    if (frontmatter['rotation_reminders'] is List) {
      project.rotationReminders = (frontmatter['rotation_reminders'] as List)
          .whereType<Map>()
          .map(
            (m) => RotationReminderConfig.fromMap(Map<String, dynamic>.from(m)),
          )
          .toList();
    }

    return project;
  }

  @override
  Project copyWith({
    String? title,
    OrganizerType? organizerType,
    String? parentId,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
    String? icon,
    String? state,
    String? priority,
    String? statement,
    List<TimeRange>? timeRanges,
    int? energyLevel,
    List<String>? daysOfWeek,
    Scheduler? scheduler,
    List<ReminderConfig>? reminders,
    bool? isWildcard,
    String? energyImpact,
    String? reviewStatus,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    List<kpi.KPI>? kpis,
    List<ChecklistStep>? steps,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      state: ProjectState.values.firstWhere(
        (e) => e.name == (state ?? this.state),
        orElse: () => projectState,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == (priority ?? this.priority),
        orElse: () => projectPriority,
      ),
      description: description,
      primaryKpiId: primaryKpiId,
      secondaryKpiIds: secondaryKpiIds,
      kpis: kpis ?? this.kpis,
      taskLinks: taskLinks,
      quickAccessLinks: quickAccessLinks,
      totalPomodoroTime: totalPomodoroTime,
      linkedGoogleEventId: linkedGoogleEventId,
      linkedGoogleEventTitle: linkedGoogleEventTitle,
      linkedGoogleEventDate: linkedGoogleEventDate,
      linkedGoogleEventUrl: linkedGoogleEventUrl,
      scheduler: scheduler,
      rotationGroups: rotationGroups,
      rotationStartDate: rotationStartDate,
      rotationCurrentGroupId: rotationCurrentGroupId,
      rotationCurrentPeriodStart: rotationCurrentPeriodStart,
      rotationCycleNumber: rotationCycleNumber,
      rotationScheduledTime: rotationScheduledTime,
      rotationDurationMinutes: rotationDurationMinutes,
      rotationScheduleOverrides: rotationScheduleOverrides,
      methodLabel: methodLabel,
      objective: objective,
      strategy: strategy,
      phases: phases,
      steps: steps ?? this.steps,
      supersededBy: supersededBy,
      parentId: parentId ?? this.parentId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obsidianPath: obsidianPath ?? this.obsidianPath,
    )
      ..isWildcard = isWildcard ?? this.isWildcard
      ..energyImpact = energyImpact ?? this.energyImpact
      ..reviewStatus = reviewStatus ?? this.reviewStatus;
  }

  Project copyProjectWith({
    String? title,
    ProjectState? state,
    TaskPriority? priority,
    String? description,
    String? primaryKpiId,
    List<String>? secondaryKpiIds,
    List<String>? taskLinks,
    List<String>? quickAccessLinks,
    int? totalPomodoroTime,
    String? linkedGoogleEventId,
    String? linkedGoogleEventTitle,
    String? linkedGoogleEventDate,
    String? linkedGoogleEventUrl,
    Scheduler? scheduler,
    List<RotationGroup>? rotationGroups,
    DateTime? rotationStartDate,
    String? rotationCurrentGroupId,
    DateTime? rotationCurrentPeriodStart,
    int? rotationCycleNumber,
    String? rotationScheduledTime,
    int? rotationDurationMinutes,
    List<RotationScheduleOverride>? rotationScheduleOverrides,
    String? methodLabel,
    String? objective,
    String? strategy,
    List<ProjectPhase>? phases,
    List<ChecklistStep>? steps,
    String? supersededBy,
    String? hierarchyCombinationMode,
    List<RotationReminderConfig>? rotationReminders,
    String? parentId,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
    String? icon,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    List<kpi.KPI>? kpis,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      state: state ?? projectState,
      priority: priority ?? projectPriority,
      description: description ?? this.description,
      primaryKpiId: primaryKpiId ?? this.primaryKpiId,
      secondaryKpiIds: secondaryKpiIds ?? this.secondaryKpiIds,
      kpis: kpis ?? this.kpis,
      taskLinks: taskLinks ?? this.taskLinks,
      quickAccessLinks: quickAccessLinks ?? this.quickAccessLinks,
      totalPomodoroTime: totalPomodoroTime ?? this.totalPomodoroTime,
      linkedGoogleEventId: linkedGoogleEventId ?? this.linkedGoogleEventId,
      linkedGoogleEventTitle:
          linkedGoogleEventTitle ?? this.linkedGoogleEventTitle,
      linkedGoogleEventDate:
          linkedGoogleEventDate ?? this.linkedGoogleEventDate,
      linkedGoogleEventUrl: linkedGoogleEventUrl ?? this.linkedGoogleEventUrl,
      scheduler: scheduler ?? this.scheduler,
      rotationGroups: rotationGroups ?? this.rotationGroups,
      rotationStartDate: rotationStartDate ?? this.rotationStartDate,
      rotationCurrentGroupId: rotationCurrentGroupId ?? this.rotationCurrentGroupId,
      rotationCurrentPeriodStart: rotationCurrentPeriodStart ?? this.rotationCurrentPeriodStart,
      rotationCycleNumber: rotationCycleNumber ?? this.rotationCycleNumber,
      rotationScheduledTime: rotationScheduledTime ?? this.rotationScheduledTime,
      rotationDurationMinutes: rotationDurationMinutes ?? this.rotationDurationMinutes,
      rotationScheduleOverrides:
          rotationScheduleOverrides ?? this.rotationScheduleOverrides,
      methodLabel: methodLabel ?? this.methodLabel,
      objective: objective ?? this.objective,
      hierarchyCombinationMode: hierarchyCombinationMode ?? this.hierarchyCombinationMode,
      strategy: strategy ?? this.strategy,
      phases: phases ?? this.phases,
      steps: steps ?? this.steps,
      supersededBy: supersededBy ?? this.supersededBy,
      rotationReminders: rotationReminders ?? this.rotationReminders,
      parentId: parentId ?? this.parentId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
  }
}
