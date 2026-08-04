// lib/models/goal_model.dart
// V5: Goal simplified — identity/aspiration object only.
// objective, strategy, phases moved to Project (see project_model.dart).
// goal_mode removed per V5 Rule 5.
import 'content_object.dart';
import 'kpi_model.dart';
import 'scheduler.dart';
import 'shared_types.dart';

enum GoalType { oneTime, repeating }

enum GoalStatus { active, completed, cancelled, onHold }

class Goal extends ContentObject {
  String? description;
  GoalType goalType;
  GoalStatus state;
  String? repeatInterval; // weekly, monthly, yearly
  DateTime? startDate;
  DateTime? deadline;
  List<KPI> kpis;
  double? targetValue;
  List<int> activeMonths;
  List<String> linkedObjectives;

  /// V5: links replaces old `subtasks` (WikiLinks) — Goal never embeds Task files.
  /// Use the universal `links` field (ContentObject.links) to reference Tasks/Projects.
  List<Scheduler> schedulers;
  String? color;
  String? icon;

  Goal({
    super.id,
    required super.title,
    this.description,
    this.goalType = GoalType.oneTime,
    this.state = GoalStatus.active,
    this.repeatInterval,
    this.startDate,
    this.deadline,
    this.targetValue,
    this.activeMonths = const [],
    this.linkedObjectives = const [],
    this.kpis = const [],
    this.schedulers = const [],
    this.color,
    this.icon,
    super.organizers,
    super.categories,
    super.tags,
    super.links,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : super();

  @override
  String get type => 'goal';

  @override
  bool get isIncomplete => title.trim().isEmpty;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    if (description != null) frontmatter['description'] = description;
    frontmatter['goal_type'] = goalType.name;
    frontmatter['state'] = state.name;
    if (repeatInterval != null) frontmatter['repeat_interval'] = repeatInterval;
    if (targetValue != null) frontmatter['target_value'] = targetValue;
    if (activeMonths.isNotEmpty) frontmatter['active_months'] = activeMonths;
    if (linkedObjectives.isNotEmpty) frontmatter['linked_objectives'] = linkedObjectives;
    if (startDate != null)
      frontmatter['start_date'] = startDate!.toIso8601String();
    if (deadline != null) frontmatter['deadline'] = deadline!.toIso8601String();
    if (kpis.isNotEmpty)
      frontmatter['kpis'] = kpis.map((e) => e.toMap()).toList();
    if (schedulers.isNotEmpty) {
      frontmatter['schedulers'] = schedulers.map((e) => e.toMap()).toList();
    }
    if (color != null) frontmatter['color'] = color;
    if (icon != null) frontmatter['icon'] = icon;
    // V5: goal_mode, objective, strategy, phases removed — moved to Project.
    // V5: social_refs removed — folded into universal `links` field (ContentObject).
    // V5: subtasks removed — use links field to reference Tasks.
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
    if (frontmatter['target_value'] != null) {
      goal.targetValue = (frontmatter['target_value'] as num).toDouble();
    }
    if (frontmatter['active_months'] != null) {
      goal.activeMonths = (frontmatter['active_months'] as List)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0 && e <= 12)
          .toList();
    }
    if (frontmatter['linked_objectives'] != null) {
      goal.linkedObjectives = (frontmatter['linked_objectives'] as List).map((e) => e.toString()).toList();
    }
    goal.startDate = frontmatter['start_date'] != null
        ? DateTime.tryParse(frontmatter['start_date'].toString())
        : null;
    goal.deadline = frontmatter['deadline'] != null
        ? DateTime.tryParse(frontmatter['deadline'].toString())
        : null;

    goal.kpis = (frontmatter['kpis'] as List? ?? [])
        .whereType<Map>()
        .map((e) => KPI.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    goal.schedulers = (frontmatter['schedulers'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Scheduler.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    goal.color = frontmatter['color'] as String?;
    goal.icon = frontmatter['icon'] as String?;

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
    double? targetValue,
    List<int>? activeMonths,
    List<String>? linkedObjectives,
    List<KPI>? kpis,
    List<Scheduler>? schedulers,
    String? color,
    String? icon,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    List<String>? links,
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
        targetValue: targetValue ?? this.targetValue,
        activeMonths: activeMonths ?? this.activeMonths,
        linkedObjectives: linkedObjectives ?? this.linkedObjectives,
        kpis: kpis ?? this.kpis,
        schedulers: schedulers ?? this.schedulers,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        organizers: organizers ?? this.organizers,
        categories: categories ?? this.categories,
        tags: tags ?? this.tags,
        links: links ?? this.links,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        obsidianPath: obsidianPath ?? this.obsidianPath,
      )
      ..archived = archived
      ..pinned = pinned
      ..reminders = List.from(reminders)
      ..order = order;
  }

  /// Progress is derived from KPIs; Goals no longer embed subtasks directly.
  /// Use links to Tasks/Projects and check their completion instead.
  double get progress {
    if (kpis.isEmpty) return 0.0;
    final total = kpis.fold<double>(0, (sum, k) => sum + k.targetValue);
    if (total == 0) return 0.0;
    final current = kpis.fold<double>(
      0,
      (sum, k) => sum + k.currentValue.clamp(0, k.targetValue),
    );
    return (current / total).clamp(0.0, 1.0);
  }
}
