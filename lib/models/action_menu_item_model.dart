// lib/models/action_menu_item_model.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'task_model.dart';
import 'pillar_model.dart';

class ActionMenuItem extends ContentObject {
  EnergyLevel energyLevel;   // quando usar: baixa/média/alta energia disponível
  EnergyLevel energyCost;    // quanto essa ação consome do orçamento de energia do dia
  TaskPriority priority;     // reaproveita o enum que Task/Habit já usam

  ActionMenuItem({
    super.id, required super.title,
    this.energyLevel = EnergyLevel.low,
    this.energyCost = EnergyLevel.low,
    this.priority = TaskPriority.none,
    super.organizers,   // aqui é como a ação se liga a 1+ Pilares/Valores
    super.categories, super.tags,
    super.createdAt, super.updatedAt, super.obsidianPath, super.archived, super.order,
  });

  @override
  String get type => ObjectTypes.action;

  @override
  String toMarkdown() {
    final fm = toBaseMap();
    fm['energy_level'] = energyLevel.name;
    fm['energy_cost'] = energyCost.name;
    fm['priority'] = priority.name;
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
    return a;
  }

  ActionMenuItem copyWith({
    String? title,
    EnergyLevel? energyLevel,
    EnergyLevel? energyCost,
    TaskPriority? priority,
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
