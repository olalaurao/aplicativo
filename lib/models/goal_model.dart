// lib/models/goal_model.dart
import 'content_object.dart';
import 'kpi_model.dart';
import 'scheduler.dart';
import 'shared_types.dart' hide KPI;

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
  List<Subtask> subtasks;
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
    this.kpis = const [],
    this.subtasks = const [],
    this.schedulers = const [],
    this.color,
    this.icon,
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : super();

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

    return goal;
  }

  double get progress {
    if (subtasks.isEmpty) return 0.0;
    final completedCount = subtasks.where((s) => s.completed).length;
    return completedCount / subtasks.length;
  }
}
