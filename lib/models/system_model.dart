import 'content_object.dart';
import 'package:uuid/uuid.dart';
import 'scheduler.dart';
import 'reminder_config.dart';
import 'checklist_step.dart';

// Type alias for backward compatibility
typedef SystemStep = ChecklistStep;

class SystemDefinition extends ContentObject {
  String trigger;
  int estimatedMinutes;
  // Derived fields — never persisted. Computed from linked Task history.
  // See SystemsProvider._deriveSystemStats() for calculation logic.
  int runCount;
  DateTime? lastRun;
  int averageMinutes;
  List<SystemStep> steps;
  String description;
  Scheduler? scheduler;

  SystemDefinition({
    super.id,
    required super.title,
    this.trigger = '',
    this.estimatedMinutes = 0,
    this.runCount = 0,
    this.lastRun,
    this.averageMinutes = 0,
    this.steps = const [],
    this.description = '',
    this.scheduler,
    super.createdAt,
    super.updatedAt,
    super.archived,
    super.pinned,
    super.obsidianPath,
  });

  @override
  String get type => 'system';

  @override
  bool get isIncomplete => title.trim().isEmpty || steps.isEmpty;

  @override
  String toMarkdown() {
    final map = toBaseMap();
    map['trigger'] = trigger;
    map['estimated_minutes'] = estimatedMinutes;
    map['steps'] = steps.map((s) => s.toMap()).toList();
    if (scheduler != null) {
      map['scheduler'] = scheduler!.toMap();
    }

    return generateMarkdown(map, description);
  }

  factory SystemDefinition.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
    String filePath,
  ) {
    final system = SystemDefinition(
      title: frontmatter['title']?.toString() ?? 'Sem título',
      trigger: frontmatter['trigger']?.toString() ?? '',
      estimatedMinutes: int.tryParse(frontmatter['estimated_minutes']?.toString() ?? '0') ?? 0,
      description: body.trim(),
      obsidianPath: filePath,
    );

    if (frontmatter['scheduler'] != null && frontmatter['scheduler'] is Map) {
      system.scheduler = Scheduler.fromMap(Map<String, dynamic>.from(frontmatter['scheduler'] as Map));
    }

    system.loadBaseMap(frontmatter);

    if (frontmatter['steps'] is List) {
      system.steps = (frontmatter['steps'] as List)
          .whereType<Map>()
          .map((m) => SystemStep.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }

    return system;
  }

  SystemDefinition copyWith({
    String? title,
    String? trigger,
    int? estimatedMinutes,
    int? runCount,
    DateTime? lastRun,
    int? averageMinutes,
    List<SystemStep>? steps,
    String? description,
    Scheduler? scheduler,
    bool? archived,
    bool? pinned,
  }) {
    return SystemDefinition(
      id: id,
      title: title ?? this.title,
      trigger: trigger ?? this.trigger,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      runCount: runCount ?? this.runCount,
      lastRun: lastRun ?? this.lastRun,
      averageMinutes: averageMinutes ?? this.averageMinutes,
      steps: steps ?? this.steps,
      description: description ?? this.description,
      scheduler: scheduler ?? this.scheduler,
      createdAt: createdAt,
      updatedAt: updatedAt,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      obsidianPath: obsidianPath,
    );
  }
}
