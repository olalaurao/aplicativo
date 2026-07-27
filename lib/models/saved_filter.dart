enum SortField {
  manual,
  title,
  created,
  modified,
  rating,
  status,
  type,
  priority,
  deadline,
  streak,
  lastContact,
}

enum GroupField { none, type, status, organizer, tag, date }

enum FilterOperator {
  equals,
  contains,
  notEquals,
  greaterThan,
  lessThan,
  isEmpty,
}

enum ViewMode { grid, list, grouped }

class FilterRule {
  final String property;
  final FilterOperator op;
  final dynamic value;
  const FilterRule({
    required this.property,
    required this.op,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
    'property': property,
    'op': op.name,
    'value': value,
  };
  factory FilterRule.fromJson(Map<String, dynamic> j) => FilterRule(
    property: j['property'],
    op: FilterOperator.values.byName(j['op']),
    value: j['value'],
  );
}

class SavedFilter {
  final String id;
  final String name;
  final String
  targetType; // 'note'|'resource'|'habit'|'task'|'goal'|'person'|'entry'|'tracker'|'*'
  final List<FilterRule> rules;
  final SortField sortBy;
  final bool sortAscending;
  final GroupField groupBy;
  final ViewMode viewMode;
  final List<String> visibleProperties;
  final bool includeSortProperty;

  const SavedFilter({
    required this.id,
    required this.name,
    required this.targetType,
    this.rules = const [],
    this.sortBy = SortField.modified,
    this.sortAscending = false,
    this.groupBy = GroupField.none,
    this.viewMode = ViewMode.grid,
    this.visibleProperties = const [],
    this.includeSortProperty = true,
  });

  List<T> apply<T>(List<T> items) => items
      .where((item) => rules.every((rule) => _matchesRule(item, rule)))
      .toList();

  bool _matchesRule(dynamic item, FilterRule rule) {
    final val = _getProperty(item, rule.property);
    return switch (rule.op) {
      FilterOperator.equals => val?.toString() == rule.value?.toString(),
      FilterOperator.notEquals => val?.toString() != rule.value?.toString(),
      FilterOperator.contains =>
        val is List
            ? (rule.value is List
                  ? (rule.value as List).any((v) => val.contains(v))
                  : val.contains(rule.value))
            : val?.toString().toLowerCase().contains(
                    rule.value?.toString().toLowerCase() ?? '',
                  ) ==
                  true,
      FilterOperator.greaterThan =>
        (val is num && rule.value is num) && val > (rule.value as num),
      FilterOperator.lessThan =>
        (val is num && rule.value is num) && val < (rule.value as num),
      FilterOperator.isEmpty =>
        val == null ||
            (val is List && val.isEmpty) ||
            (val is String && val.isEmpty),
    };
  }

  dynamic _getProperty(dynamic item, String prop) {
    return switch (prop) {
      'title' => _read(() => item.title),
      'kind' || 'type' => _read(() => item.kind) ?? _read(() => item.type),
      'noteType' => _read(() => item.noteType),
      'status' =>
        _enumName(_read(() => item.status)) ??
            _enumName(_read(() => item.stage)) ??
            _enumName(_read(() => item.state)),
      'stage' => _enumName(_read(() => item.stage)),
      'state' => _enumName(_read(() => item.state)),
      'tags' => _read(() => item.tags),
      'organizers' => _organizerValues(_read(() => item.organizers)),
      'created' => _read(() => item.createdAt),
      'modified' => _read(() => item.updatedAt),
      'rating' => _read(() => item.rating),
      'resourceType' =>
        _read(() => item.mediaType) ?? _read(() => item.resourceType),
      'priority' =>
        _enumName(_read(() => item.priority)) ??
            _enumName(_read(() => item.projectPriority)),
      'pinned' => _read(() => item.pinned),
      'archived' => _read(() => item.archived),
      'author' => _read(() => item.author),
      'category' => _read(() => item.category),
      'year' => _read(() => item.year),
      'goalType' => _enumName(_read(() => item.goalType)),
      'contactPriority' => _enumName(_read(() => item.contactPriority)),
      'moodSlug' => _read(() => item.moodSlug),
      _ => null,
    };
  }

  dynamic _read(dynamic Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  String? _enumName(dynamic value) {
    if (value == null) return null;
    final name = _read(() => value.name);
    return name?.toString() ?? value.toString();
  }

  List<String>? _organizerValues(dynamic organizers) {
    if (organizers is! Iterable) return null;
    return organizers
        .map((organizer) {
          final slug = _read(() => organizer.slug);
          final title = _read(() => organizer.title);
          return (slug ?? title)?.toString();
        })
        .whereType<String>()
        .toList();
  }

  SavedFilter copyWith({
    String? name,
    List<FilterRule>? rules,
    SortField? sortBy,
    bool? sortAscending,
    GroupField? groupBy,
    ViewMode? viewMode,
    List<String>? visibleProperties,
    bool? includeSortProperty,
  }) => SavedFilter(
    id: id,
    name: name ?? this.name,
    targetType: targetType,
    rules: rules ?? this.rules,
    sortBy: sortBy ?? this.sortBy,
    sortAscending: sortAscending ?? this.sortAscending,
    groupBy: groupBy ?? this.groupBy,
    viewMode: viewMode ?? this.viewMode,
    visibleProperties: visibleProperties ?? this.visibleProperties,
    includeSortProperty: includeSortProperty ?? this.includeSortProperty,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetType': targetType,
    'rules': rules.map((r) => r.toJson()).toList(),
    'sortBy': sortBy.name,
    'sortAscending': sortAscending,
    'groupBy': groupBy.name,
    'viewMode': viewMode.name,
    'visibleProperties': visibleProperties,
    'includeSortProperty': includeSortProperty,
  };

  factory SavedFilter.fromJson(Map<String, dynamic> j) => SavedFilter(
    id: j['id'],
    name: j['name'],
    targetType: j['targetType'],
    rules: (j['rules'] as List? ?? [])
        .map((r) => FilterRule.fromJson(r as Map<String, dynamic>))
        .toList(),
    sortBy: SortField.values.byName(j['sortBy'] ?? 'modified'),
    sortAscending: j['sortAscending'] ?? false,
    groupBy: GroupField.values.byName(j['groupBy'] ?? 'none'),
    viewMode: ViewMode.values.byName(j['viewMode'] ?? 'grid'),
    visibleProperties: List<String>.from(j['visibleProperties'] as List? ?? []),
    includeSortProperty: j['includeSortProperty'] ?? true,
  );
}

class FilterProperty {
  final String key;
  final String label;
  final List<String>? allowedValues;
  const FilterProperty({
    required this.key,
    required this.label,
    this.allowedValues,
  });
}

class NoteFilterProperties {
  static const all = [
    FilterProperty(key: 'created', label: 'Created'),
    FilterProperty(key: 'modified', label: 'Modified'),
    FilterProperty(
      key: 'noteType',
      label: 'Type',
      allowedValues: ['text', 'outline', 'collection'],
    ),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(
      key: 'pinned',
      label: 'Pinned',
      allowedValues: ['true', 'false'],
    ),
    FilterProperty(
      key: 'archived',
      label: 'Archived',
      allowedValues: ['true', 'false'],
    ),
  ];
}

class ResourceFilterProperties {
  static const all = [
    FilterProperty(key: 'created', label: 'Created'),
    FilterProperty(key: 'modified', label: 'Modified'),
    FilterProperty(
      key: 'resourceType',
      label: 'Type',
      allowedValues: ['Book', 'Podcast', 'Movie', 'Article', 'Course'],
    ),
    FilterProperty(
      key: 'status',
      label: 'Status',
      allowedValues: ['toConsume', 'inProgress', 'completed', 'dropped'],
    ),
    FilterProperty(key: 'author', label: 'Author'),
    FilterProperty(key: 'category', label: 'Category'),
    FilterProperty(key: 'rating', label: 'Rating'),
    FilterProperty(
      key: 'priority',
      label: 'Priority',
      allowedValues: ['none', 'low', 'medium', 'high'],
    ),
    FilterProperty(key: 'year', label: 'Year'),
    FilterProperty(key: 'tags', label: 'Tags'),
  ];
}

class HabitFilterProperties {
  static const all = [
    FilterProperty(
      key: 'archived',
      label: 'Archived',
      allowedValues: ['true', 'false'],
    ),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class TaskFilterProperties {
  static const all = [
    FilterProperty(
      key: 'status',
      label: 'Status',
      allowedValues: ['idea', 'todo', 'inProgress', 'pending', 'finalized'],
    ),
    FilterProperty(
      key: 'priority',
      label: 'Priority',
      allowedValues: ['low', 'medium', 'high'],
    ),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(
      key: 'archived',
      label: 'Archived',
      allowedValues: ['true', 'false'],
    ),
  ];
}

class GoalFilterProperties {
  static const all = [
    FilterProperty(
      key: 'state',
      label: 'State',
      allowedValues: ['active', 'completed', 'onHold', 'cancelled'],
    ),
    FilterProperty(
      key: 'goalType',
      label: 'Type',
      allowedValues: ['repeating', 'oneTime'],
    ),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
  ];
}

class PersonFilterProperties {
  static const all = [
    FilterProperty(
      key: 'contactPriority',
      label: 'Priority',
      allowedValues: ['low', 'medium', 'high'],
    ),
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
    FilterProperty(
      key: 'archived',
      label: 'Archived',
      allowedValues: ['true', 'false'],
    ),
  ];
}

class InboxFilterProperties {
  static const all = [
    FilterProperty(
      key: 'kind',
      label: 'Type',
      allowedValues: ['captured', 'idea', 'task', 'project', 'goal'],
    ),
    FilterProperty(key: 'title', label: 'Title'),
    FilterProperty(
      key: 'status',
      label: 'Status',
      allowedValues: [
        'raw',
        'developing',
        'readyToAct',
        'idea',
        'backlog',
        'active',
      ],
    ),
    FilterProperty(
      key: 'priority',
      label: 'Priority',
      allowedValues: ['none', 'low', 'medium', 'high'],
    ),
    FilterProperty(key: 'created', label: 'Created'),
    FilterProperty(key: 'modified', label: 'Modified'),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(
      key: 'archived',
      label: 'Archived',
      allowedValues: ['true', 'false'],
    ),
    FilterProperty(
      key: 'pinned',
      label: 'Pinned',
      allowedValues: ['true', 'false'],
    ),
  ];
}

class PillarFilterProperties {
  static const all = [
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'created', label: 'Created'),
    FilterProperty(key: 'modified', label: 'Modified'),
  ];
}

class SystemFilterProperties {
  static const all = [
    FilterProperty(
      key: 'archived',
      label: 'Archived',
      allowedValues: ['true', 'false'],
    ),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'created', label: 'Created'),
    FilterProperty(key: 'modified', label: 'Modified'),
  ];
}

class ProjectFilterProperties {
  static const all = [
    FilterProperty(
      key: 'status',
      label: 'Status',
      allowedValues: ['active', 'completed', 'onHold', 'cancelled'],
    ),
    FilterProperty(
      key: 'priority',
      label: 'Priority',
      allowedValues: ['none', 'low', 'medium', 'high'],
    ),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'created', label: 'Created'),
    FilterProperty(key: 'modified', label: 'Modified'),
    FilterProperty(
      key: 'archived',
      label: 'Archived',
      allowedValues: ['true', 'false'],
    ),
  ];
}

class OrganizerFilterProperties {
  static const all = [
    FilterProperty(
      key: 'archived',
      label: 'Archived',
      allowedValues: ['true', 'false'],
    ),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'created', label: 'Created'),
    FilterProperty(key: 'modified', label: 'Modified'),
  ];
}

class IdeaFilterProperties {
  static const all = [
    FilterProperty(
      key: 'horizon',
      label: 'Horizon',
      allowedValues: ['now', 'soon', 'someday', 'noDeadline'],
    ),
    FilterProperty(
      key: 'archived',
      label: 'Archived',
      allowedValues: ['true', 'false'],
    ),
    FilterProperty(key: 'tags', label: 'Tags'),
    FilterProperty(key: 'organizers', label: 'Organizer'),
    FilterProperty(key: 'created', label: 'Created'),
    FilterProperty(key: 'modified', label: 'Modified'),
  ];
}
