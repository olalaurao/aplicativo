// lib/models/monthly_focus_model.dart
import 'content_object.dart';
import 'shared_types.dart';

class MonthlyFocus extends ContentObject {
  int year;
  int month;
  List<String> goalIds;
  String? habitId;
  List<String> selfCareIds;
  String? reflection;

  MonthlyFocus({
    super.id,
    required super.title,
    required this.year,
    required this.month,
    List<String>? goalIds,
    this.habitId,
    List<String>? selfCareIds,
    this.reflection,
    super.organizers,
    super.categories,
    super.tags,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.archived,
  })  : goalIds = goalIds ?? [],
        selfCareIds = selfCareIds ?? [];

  @override
  String get type => ObjectTypes.monthlyFocus;

  @override
  String toMarkdown() {
    final fm = toBaseMap();
    fm['year'] = year;
    fm['month'] = month;
    if (goalIds.isNotEmpty) fm['goal_ids'] = goalIds;
    if (habitId != null) fm['habit_id'] = habitId;
    if (selfCareIds.isNotEmpty) fm['self_care_ids'] = selfCareIds;
    return generateMarkdown(fm, reflection ?? '');
  }

  factory MonthlyFocus.fromMarkdown(Map<String, dynamic> fm, String body) {
    final title = fm['title']?.toString() ?? 'Monthly Focus';
    final m = MonthlyFocus(
      title: title,
      year: int.tryParse(fm['year']?.toString() ?? '') ?? DateTime.now().year,
      month: int.tryParse(fm['month']?.toString() ?? '') ?? DateTime.now().month,
    );
    m.loadBaseMap(fm);

    if (fm['goal_ids'] is List) {
      m.goalIds = (fm['goal_ids'] as List).map((e) => e.toString()).toList();
    }
    m.habitId = fm['habit_id']?.toString();
    if (fm['self_care_ids'] is List) {
      m.selfCareIds = (fm['self_care_ids'] as List).map((e) => e.toString()).toList();
    }
    
    m.reflection = body.trim().isNotEmpty ? body : null;

    return m;
  }

  MonthlyFocus copyWith({
    String? title,
    int? year,
    int? month,
    List<String>? goalIds,
    String? habitId,
    List<String>? selfCareIds,
    String? reflection,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    bool? archived,
  }) {
    return MonthlyFocus(
      id: id,
      title: title ?? this.title,
      year: year ?? this.year,
      month: month ?? this.month,
      goalIds: goalIds ?? this.goalIds,
      habitId: habitId ?? this.habitId,
      selfCareIds: selfCareIds ?? this.selfCareIds,
      reflection: reflection ?? this.reflection,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
      archived: archived ?? this.archived,
    );
  }
}
