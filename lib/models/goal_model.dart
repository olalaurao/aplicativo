// lib/models/goal_model.dart
import 'content_object.dart';
import 'kpi_model.dart';
import 'scheduler.dart';
import 'shared_types.dart' hide KPI;

enum GoalType { oneTime, repeating }

enum GoalStatus { active, completed, cancelled, onHold }

enum GoalMode { standard, plan }

class Goal extends ContentObject {
  String? description;
  GoalType goalType;
  GoalStatus state;
  String? repeatInterval; // weekly, monthly, yearly
  DateTime? startDate;
  DateTime? deadline;
  List<KPI> kpis;
  List<Subtask> subtasks;
  List<Scheduler> schedulers;
  String? color;
  String? icon;
  String? linkedGoogleEventId;
  String? linkedGoogleEventTitle;
  String? linkedGoogleEventDate;
  String? linkedGoogleEventUrl;
  List<String> socialRefs;

  GoalMode goalMode; // default: GoalMode.standard (Regra 5)
  String? objective; // plan mode only
  String? strategy; // plan mode only
  List<String> phases; // plan mode only, default []

  Goal({
    super.id,
    required super.title,
    this.description,
    this.goalType = GoalType.oneTime,
    this.state = GoalStatus.active,
    this.repeatInterval,
    this.startDate,
    this.deadline,
    this.kpis = const [],
    this.subtasks = const [],
    this.schedulers = const [],
    this.color,
    this.icon,
    this.linkedGoogleEventId,
    this.linkedGoogleEventTitle,
    this.linkedGoogleEventDate,
    this.linkedGoogleEventUrl,
    List<String>? socialRefs,
    this.goalMode = GoalMode.standard,
    this.objective,
    this.strategy,
    List<String>? phases,
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  })  : socialRefs = socialRefs ?? [],
        phases = phases ?? [],
        super();

  @override
  String get type => 'goal';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['description'] = description;
    frontmatter['goal_type'] = goalType.name;
    frontmatter['state'] = state.name;
    frontmatter['repeat_interval'] = repeatInterval;
    frontmatter['start_date'] = startDate?.toIso8601String();
    frontmatter['deadline'] = deadline?.toIso8601String();
    frontmatter['kpis'] = kpis.map((e) => e.toMap()).toList();
    frontmatter['subtasks'] = subtasks
        .map((e) => {'title': e.title, 'completed': e.completed})
        .toList();
    frontmatter['color'] = color;
    frontmatter['icon'] = icon;
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
    if (socialRefs.isNotEmpty) {
      frontmatter['social_refs'] = socialRefs;
    }

    frontmatter['goal_mode'] = goalMode.name;
    if (goalMode == GoalMode.plan) {
      if (objective != null) frontmatter['objective'] = objective;
      if (strategy != null) frontmatter['strategy'] = strategy;
      if (phases.isNotEmpty) frontmatter['phases'] = phases;
    }

    return generateMarkdown(frontmatter, description ?? '');
  }

  factory Goal.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final goal = Goal(title: frontmatter['title'] as String? ?? '');
    goal.loadBaseMap(frontmatter);
    goal.description = frontmatter['description'] as String?;
    goal.goalType = GoalType.values.firstWhere(
      (e) => e.name == frontmatter['goal_type'],
      orElse: () => GoalType.oneTime,
    );
    goal.state = GoalStatus.values.firstWhere(
      (e) => e.name == frontmatter['state'],
      orElse: () => GoalStatus.active,
    );
    goal.repeatInterval = frontmatter['repeat_interval'] as String?;
    goal.startDate = frontmatter['start_date'] != null
        ? DateTime.tryParse(frontmatter['start_date'])
        : null;
    goal.deadline = frontmatter['deadline'] != null
        ? DateTime.tryParse(frontmatter['deadline'])
        : null;

    goal.kpis = (frontmatter['kpis'] as List? ?? [])
        .map((e) => KPI.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    goal.subtasks = (frontmatter['subtasks'] as List? ?? [])
        .map(
          (e) => Subtask(title: e['title'], completed: e['completed'] ?? false),
        )
        .toList();

    goal.color = frontmatter['color'] as String?;
    goal.icon = frontmatter['icon'] as String?;
    goal.linkedGoogleEventId = frontmatter['linked_google_event_id']
        ?.toString();
    goal.linkedGoogleEventTitle = frontmatter['linked_google_event_title']
        ?.toString();
    goal.linkedGoogleEventDate = frontmatter['linked_google_event_date']
        ?.toString();
    goal.linkedGoogleEventUrl = frontmatter['linked_google_event_url']
        ?.toString();
    if (frontmatter['social_refs'] is List) {
      goal.socialRefs = (frontmatter['social_refs'] as List)
          .map((e) => e.toString())
          .toList();
    }

    final rawMode = frontmatter['goal_mode']?.toString() ?? 'standard';
    goal.goalMode = GoalMode.values.firstWhere(
      (m) => m.name == rawMode,
      orElse: () => GoalMode.standard,
    );
    goal.objective = frontmatter['objective'] as String?;
    goal.strategy = frontmatter['strategy'] as String?;
    goal.phases = List<String>.from(frontmatter['phases'] as List? ?? []);

    return goal;
  }

  Goal copyWith({
    String? title,
    String? description,
    GoalType? goalType,
    GoalStatus? state,
    String? repeatInterval,
    DateTime? startDate,
    DateTime? deadline,
    List<KPI>? kpis,
    List<Subtask>? subtasks,
    List<Scheduler>? schedulers,
    String? color,
    String? icon,
    String? linkedGoogleEventId,
    String? linkedGoogleEventTitle,
    String? linkedGoogleEventDate,
    String? linkedGoogleEventUrl,
    List<String>? socialRefs,
    GoalMode? goalMode,
    String? objective,
    String? strategy,
    List<String>? phases,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
  }) {
    return Goal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      goalType: goalType ?? this.goalType,
      state: state ?? this.state,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      startDate: startDate ?? this.startDate,
      deadline: deadline ?? this.deadline,
      kpis: kpis ?? this.kpis,
      subtasks: subtasks ?? this.subtasks,
      schedulers: schedulers ?? this.schedulers,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      linkedGoogleEventId: linkedGoogleEventId ?? this.linkedGoogleEventId,
      linkedGoogleEventTitle:
          linkedGoogleEventTitle ?? this.linkedGoogleEventTitle,
      linkedGoogleEventDate:
          linkedGoogleEventDate ?? this.linkedGoogleEventDate,
      linkedGoogleEventUrl: linkedGoogleEventUrl ?? this.linkedGoogleEventUrl,
      socialRefs: socialRefs ?? List<String>.from(this.socialRefs),
      goalMode: goalMode ?? this.goalMode,
      objective: objective ?? this.objective,
      strategy: strategy ?? this.strategy,
      phases: phases ?? this.phases,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
    )
      ..archived = archived
      ..pinned = pinned
      ..tags = List<String>.from(tags)
      ..reminders = List.from(reminders)
      ..order = order;
  }

  double get progress {
    if (subtasks.isEmpty) return 0.0;
    final completedCount = subtasks.where((s) => s.completed).length;
    return completedCount / subtasks.length;
  }
}
