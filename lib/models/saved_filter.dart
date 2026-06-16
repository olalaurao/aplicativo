enum SortField {
  manual, title, created, modified,
  rating, status, type, priority,
  deadline, streak, lastContact,
}

enum GroupField { none, type, status, organizer, tag, date }

enum FilterOperator { equals, contains, notEquals, greaterThan, lessThan, isEmpty }

enum ViewMode { grid, list, grouped, matrix }

class FilterRule {
  final String property;
  final FilterOperator op;
  final dynamic value;
  const FilterRule({required this.property, required this.op, required this.value});

  Map<String, dynamic> toJson() => {'property': property, 'op': op.name, 'value': value};
  factory FilterRule.fromJson(Map<String, dynamic> j) => FilterRule(
    property: j['property'], op: FilterOperator.values.byName(j['op']), value: j['value']);
}

class MatrixConfig {
  final String title;
  final String axisXProperty;
  final List<String> axisXValues;
  final String axisYProperty;
  final List<String> axisYValues;

  const MatrixConfig({
    required this.title,
    required this.axisXProperty,
    required this.axisXValues,
    required this.axisYProperty,
    required this.axisYValues,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'axisXProperty': axisXProperty,
    'axisXValues': axisXValues,
    'axisYProperty': axisYProperty,
    'axisYValues': axisYValues,
  };

  factory MatrixConfig.fromJson(Map<String, dynamic> j) => MatrixConfig(
    title: j['title'],
    axisXProperty: j['axisXProperty'],
    axisXValues: List<String>.from(j['axisXValues'] ?? []),
    axisYProperty: j['axisYProperty'],
    axisYValues: List<String>.from(j['axisYValues'] ?? []),
  );

  static const eisenhower = MatrixConfig(
    title: 'Eisenhower Matrix',
    axisXProperty: 'urgency',
    axisXValues: ['urgent', 'not_urgent'],
    axisYProperty: 'importance',
    axisYValues: ['important', 'not_important'],
  );
}

class SavedFilter {
  final String id;
  final String name;
  final String targetType; // 'note'|'resource'|'habit'|'task'|'goal'|'person'|'journal_entry'|'tracker'|'*'
  final List<FilterRule> rules;
  final SortField sortBy;
  final bool sortAscending;
  final GroupField groupBy;
  final ViewMode viewMode;
  final MatrixConfig? matrixConfig;

  const SavedFilter({
    required this.id, required this.name, required this.targetType,
    this.rules = const [], this.sortBy = SortField.modified,
    this.sortAscending = false, this.groupBy = GroupField.none,
    this.viewMode = ViewMode.grid, this.matrixConfig,
  });

  List<T> apply<T>(List<T> items) =>
    items.where((item) => rules.every((rule) => _matchesRule(item, rule))).toList();

  bool _matchesRule(dynamic item, FilterRule rule) {
    final val = _getProperty(item, rule.property);
    return switch (rule.op) {
      FilterOperator.equals      => val?.toString() == rule.value?.toString(),
      FilterOperator.notEquals   => val?.toString() != rule.value?.toString(),
      FilterOperator.contains    => val is List
          ? (rule.value is List
              ? (rule.value as List).any((v) => val.contains(v))
              : val.contains(rule.value))
          : val?.toString().toLowerCase().contains(rule.value?.toString().toLowerCase() ?? '') == true,
      FilterOperator.greaterThan => (val is num && rule.value is num) && val > (rule.value as num),
      FilterOperator.lessThan    => (val is num && rule.value is num) && val < (rule.value as num),
      FilterOperator.isEmpty     => val == null || (val is List && val.isEmpty) || (val is String && val.isEmpty),
    };
  }

  dynamic _getProperty(dynamic item, String prop) => switch (prop) {
    'noteType'        => item.noteType,
    'status'          => item.status?.name ?? item.stage?.name ?? item.state?.name,
    'tags'            => item.tags,
    'organizers'      => item.organizers?.map((o) => o.slug).toList(),
    'rating'          => item.rating,
    'resourceType'    => item.resourceType,
    'priority'        => item.priority?.name,
    'pinned'          => item.pinned,
    'archived'        => item.archived,
    'author'          => item.author,
    'category'        => item.category,
    'goalType'        => item.goalType?.name,
    'state'           => item.state?.name,
    'contactPriority' => item.contactPriority?.name,
    'moodSlug'        => item.moodSlug,
    _                 => null,
  };

  SavedFilter copyWith({
    String? name, List<FilterRule>? rules, SortField? sortBy,
    bool? sortAscending, GroupField? groupBy, ViewMode? viewMode,
    MatrixConfig? matrixConfig,
  }) => SavedFilter(
    id: id, name: name ?? this.name, targetType: targetType,
    rules: rules ?? this.rules, sortBy: sortBy ?? this.sortBy,
    sortAscending: sortAscending ?? this.sortAscending,
    groupBy: groupBy ?? this.groupBy, viewMode: viewMode ?? this.viewMode,
    matrixConfig: matrixConfig ?? this.matrixConfig,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'targetType': targetType,
    'rules': rules.map((r) => r.toJson()).toList(),
    'sortBy': sortBy.name, 'sortAscending': sortAscending,
    'groupBy': groupBy.name, 'viewMode': viewMode.name,
    if (matrixConfig != null) 'matrixConfig': matrixConfig!.toJson(),
  };

  factory SavedFilter.fromJson(Map<String, dynamic> j) => SavedFilter(
    id: j['id'], name: j['name'], targetType: j['targetType'],
    rules: (j['rules'] as List? ?? []).map((r) => FilterRule.fromJson(r as Map<String, dynamic>)).toList(),
    sortBy: SortField.values.byName(j['sortBy'] ?? 'modified'),
    sortAscending: j['sortAscending'] ?? false,
    groupBy: GroupField.values.byName(j['groupBy'] ?? 'none'),
    viewMode: ViewMode.values.byName(j['viewMode'] ?? 'grid'),
    matrixConfig: j['matrixConfig'] != null ? MatrixConfig.fromJson(j['matrixConfig']) : null,
  );
}

class FilterProperty {
  final String key;
  final String label;
  final List<String>? allowedValues;
  const FilterProperty({required this.key, required this.label, this.allowedValues});
}

class NoteFilterProperties {
  static const all = [
    FilterProperty(key: 'noteType', label: 'Tipo', allowedValues: ['text', 'outline', 'collection']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'pinned', label: 'Fixado', allowedValues: ['true', 'false']),
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
  ];
}

class ResourceFilterProperties {
  static const all = [
    FilterProperty(key: 'resourceType', label: 'Tipo', allowedValues: ['Book', 'Podcast', 'Movie', 'Article', 'Course']),
    FilterProperty(key: 'status', label: 'Status', allowedValues: ['toConsume', 'inProgress', 'completed', 'dropped']),
    FilterProperty(key: 'author', label: 'Autor'),
    FilterProperty(key: 'category', label: 'Categoria'),
    FilterProperty(key: 'rating', label: 'Rating'),
    FilterProperty(key: 'tags', label: 'Tags'),
  ];
}

class HabitFilterProperties {
  static const all = [
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class TaskFilterProperties {
  static const all = [
    FilterProperty(key: 'status', label: 'Status', allowedValues: ['idea','todo','inProgress','pending','finalized']),
    FilterProperty(key: 'priority', label: 'Prioridade', allowedValues: ['low','medium','high','critical']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
  ];
}

class GoalFilterProperties {
  static const all = [
    FilterProperty(key: 'state', label: 'Estado', allowedValues: ['active','completed','onHold','cancelled']),
    FilterProperty(key: 'goalType', label: 'Tipo', allowedValues: ['repeating','oneTime']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class PersonFilterProperties {
  static const all = [
    FilterProperty(key: 'contactPriority', label: 'Prioridade', allowedValues: ['low','medium','high','critical']),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class JournalFilterProperties {
  static const all = [
    FilterProperty(key: 'moodSlug', label: 'Mood'),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class TrackerFilterProperties {
  static const all = [
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'archived', label: 'Arquivado', allowedValues: ['true', 'false']),
  ];
}
