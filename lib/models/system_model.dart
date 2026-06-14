import 'content_object.dart';
import 'package:uuid/uuid.dart';
import 'scheduler.dart';

class SystemStep {
  final String id;
  final String title;
  final List<String> substeps;

  SystemStep({
    String? id,
    required this.title,
    this.substeps = const [],
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'substeps': substeps,
    };
  }

  factory SystemStep.fromMap(Map<String, dynamic> map) {
    return SystemStep(
      id: map['id']?.toString(),
      title: map['title']?.toString() ?? 'Sem título',
      substeps: List<String>.from(map['substeps'] as List? ?? []),
    );
  }

  SystemStep copyWith({
    String? title,
    List<String>? substeps,
  }) {
    return SystemStep(
      id: id,
      title: title ?? this.title,
      substeps: substeps ?? this.substeps,
    );
  }
}

class SystemDefinition extends ContentObject {
  String trigger;
  int estimatedMinutes;
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
  String toMarkdown() {
    final map = toBaseMap();
    map['trigger'] = trigger;
    map['estimated_minutes'] = estimatedMinutes;
    map['run_count'] = runCount;
    if (lastRun != null) {
      map['last_run'] = lastRun!.toIso8601String();
    }
    map['average_minutes'] = averageMinutes;
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
      runCount: int.tryParse(frontmatter['run_count']?.toString() ?? '0') ?? 0,
      lastRun: frontmatter['last_run'] != null ? DateTime.tryParse(frontmatter['last_run'].toString()) : null,
      averageMinutes: int.tryParse(frontmatter['average_minutes']?.toString() ?? '0') ?? 0,
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
