// lib/models/action_menu_item_model.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'task_model.dart';
import 'pillar_model.dart';

class ActionLog {
  final DateTime date;
  final int rating;
  final String? note;

  ActionLog({required this.date, this.rating = 3, this.note});

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'rating': rating,
    if (note != null) 'note': note,
  };

  factory ActionLog.fromMap(Map<String, dynamic> map) => ActionLog(
    date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
    rating: int.tryParse(map['rating']?.toString() ?? '3') ?? 3,
    note: map['note']?.toString(),
  );
}

class ActionMenuItem extends ContentObject {
  EnergyLevel energyLevel;   // quando usar: baixa/média/alta energia disponível
  EnergyLevel energyCost;    // quanto essa ação consome do orçamento de energia do dia
  TaskPriority priority;     // reaproveita o enum que Task/Habit já usam
  List<ActionLog> completionLog;

  ActionMenuItem({
    super.id, required super.title,
    this.energyLevel = EnergyLevel.low,
    this.energyCost = EnergyLevel.low,
    this.priority = TaskPriority.none,
    List<ActionLog>? completionLog,
    super.organizers,   // aqui é como a ação se liga a 1+ Pilares/Valores
    super.categories, super.tags,
    super.createdAt, super.updatedAt, super.obsidianPath, super.archived, super.order,
  }) : completionLog = completionLog ?? [];

  @override
  String get type => ObjectTypes.action;

  @override
  String toMarkdown() {
    final fm = toBaseMap();
    fm['energy_level'] = energyLevel.name;
    fm['energy_cost'] = energyCost.name;
    fm['priority'] = priority.name;
    if (completionLog.isNotEmpty) {
      fm['completion_log'] = completionLog.map((e) => e.toMap()).toList();
    }
    return generateMarkdown(fm, '');
  }

  factory ActionMenuItem.fromMarkdown(Map<String, dynamic> fm, String body) {
    final a = ActionMenuItem(title: fm['title']?.toString() ?? '');
    a.loadBaseMap(fm);
    a.energyLevel = EnergyLevel.values.firstWhere(
      (e) => e.name == fm['energy_level'], orElse: () => EnergyLevel.low);
    a.energyCost = EnergyLevel.values.firstWhere(
      (e) => e.name == fm['energy_cost'], orElse: () => EnergyLevel.low);
    a.priority = TaskPriority.values.firstWhere(
      (e) => e.name == fm['priority'], orElse: () => TaskPriority.none);
    if (fm['completion_log'] != null && fm['completion_log'] is List) {
      a.completionLog = (fm['completion_log'] as List)
          .map((e) => ActionLog.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return a;
  }

  ActionMenuItem copyWith({
    String? title,
    EnergyLevel? energyLevel,
    EnergyLevel? energyCost,
    TaskPriority? priority,
    List<ActionLog>? completionLog,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    bool? archived,
    int? order,
  }) {
    return ActionMenuItem(
      id: id,
      title: title ?? this.title,
      energyLevel: energyLevel ?? this.energyLevel,
      energyCost: energyCost ?? this.energyCost,
      priority: priority ?? this.priority,
      completionLog: completionLog ?? this.completionLog,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
      archived: archived ?? this.archived,
      order: order ?? this.order,
    );
  }
}
