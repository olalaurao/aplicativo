// lib/models/idea_model.dart
// A6.4 — Upgraded Idea model with full status, horizon, priority, conversion
// tracking. Retains IdeaDefinition name for backward-compat with existing callers.

import 'content_object.dart';
import 'shared_types.dart';
import 'task_model.dart'; // TaskPriority

enum IdeaStatus { raw, developing, readyToAct, converted, dropped }

enum IdeaHorizon { now, soon, someday, noDeadline }

class IdeaDefinition extends ContentObject {
  String body;
  IdeaStatus status;
  IdeaHorizon horizon;
  TaskPriority? priority;
  DateTime? targetDate;

  /// 'task' | 'project' | 'goal' | 'note'
  String? convertedToType;
  String? convertedToId;

  /// [[wiki-links]] to related objects
  List<String> linkedSlugs;

  // Kept for backward-compat
  List<String> linkedTaskIds;

  String? color;
  String? emoji;

  IdeaDefinition({
    super.id,
    required super.title,
    this.body = '',
    this.status = IdeaStatus.raw,
    this.horizon = IdeaHorizon.someday,
    this.priority,
    this.targetDate,
    this.convertedToType,
    this.convertedToId,
    this.linkedSlugs = const [],
    this.linkedTaskIds = const [],
    super.createdAt,
    super.updatedAt,
    super.archived,
    super.pinned,
    super.organizers,
    super.tags,
    this.color,
    this.emoji,
    super.obsidianPath,
  });

  bool get isConverted => convertedToType != null;

  @override
  String get type => 'idea';

  @override
  String toMarkdown() {
    final map = toBaseMap();
    map['status'] = status.name;
    map['horizon'] = horizon.name;
    if (priority != null) map['priority'] = priority!.name;
    if (targetDate != null) {
      map['target_date'] = targetDate!.toIso8601String().split('T').first;
    }
    if (linkedSlugs.isNotEmpty) map['linked_slugs'] = linkedSlugs;
    if (linkedTaskIds.isNotEmpty) map['linked_tasks'] = linkedTaskIds;
    if (convertedToType != null) map['converted_to_type'] = convertedToType;
    if (convertedToId != null) map['converted_to_id'] = convertedToId;
    return generateMarkdown(map, body);
  }

  factory IdeaDefinition.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String bodyContent,
    String filePath,
  ) {
    final idea = IdeaDefinition(
      title: frontmatter['title']?.toString() ?? 'Sem título',
      body: bodyContent.trim(),
      obsidianPath: filePath,
    );

    idea.loadBaseMap(frontmatter);

    // Status & horizon
    if (frontmatter['status'] != null) {
      idea.status = IdeaStatus.values.firstWhere(
        (e) => e.name == frontmatter['status']?.toString(),
        orElse: () => IdeaStatus.raw,
      );
    }
    if (frontmatter['horizon'] != null) {
      idea.horizon = IdeaHorizon.values.firstWhere(
        (e) => e.name == frontmatter['horizon']?.toString(),
        orElse: () => IdeaHorizon.someday,
      );
    }
    if (frontmatter['priority'] != null) {
      idea.priority = TaskPriority.values.firstWhere(
        (e) => e.name == frontmatter['priority']?.toString(),
        orElse: () => TaskPriority.none,
      );
    }
    if (frontmatter['target_date'] != null) {
      idea.targetDate = DateTime.tryParse(frontmatter['target_date'].toString());
    }
    if (frontmatter['linked_slugs'] is List) {
      idea.linkedSlugs = (frontmatter['linked_slugs'] as List)
          .map((e) => e.toString())
          .toList();
    }
    if (frontmatter['linked_tasks'] is List) {
      idea.linkedTaskIds = (frontmatter['linked_tasks'] as List)
          .map((e) => e.toString())
          .toList();
    }
    idea.convertedToType = frontmatter['converted_to_type']?.toString();
    idea.convertedToId = frontmatter['converted_to_id']?.toString();

    return idea;
  }

  IdeaDefinition copyWith({
    String? title,
    String? body,
    IdeaStatus? status,
    IdeaHorizon? horizon,
    TaskPriority? priority,
    DateTime? targetDate,
    bool? archived,
    bool? pinned,
    List<OrganizerReference>? organizers,
    List<String>? tags,
    String? color,
    String? emoji,
    List<String>? linkedSlugs,
    List<String>? linkedTaskIds,
    String? convertedToType,
    String? convertedToId,
    DateTime? updatedAt,
  }) {
    return IdeaDefinition(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      status: status ?? this.status,
      horizon: horizon ?? this.horizon,
      priority: priority ?? this.priority,
      targetDate: targetDate ?? this.targetDate,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      organizers: organizers ?? this.organizers,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      linkedSlugs: linkedSlugs ?? this.linkedSlugs,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      convertedToType: convertedToType ?? this.convertedToType,
      convertedToId: convertedToId ?? this.convertedToId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obsidianPath: obsidianPath,
    );
  }
}
