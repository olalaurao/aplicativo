// lib/models/tracker_model.dart
import 'content_object.dart';
import 'shared_types.dart';

// A6.2 — Alert levels for health tracker fields
enum FieldAlertLevel { none, info, warning, critical }

// E14 — Data source types for health alerts
enum FieldDataSource { tracker, habit, recurringTask }

enum InputFieldType {
  text,
  selection,
  quantity,
  checklist,
  checkbox,
  media,
  mood,
  range,
  duration,
}

class InputField {
  String id;
  String title;
  InputFieldType type;
  dynamic defaultValue;
  List<OrganizerReference> organizers;

  // Specific properties based on type
  String? unit; // for quantity
  double? min; // for range
  double? max; // for range
  List<String>? options; // for selection/checklist
  String? optionsSourceCollectionSlug; // NEW — if set, options are read live from that Collection note

  // A6.2 — Health alert fields
  FieldAlertLevel alertLevel;
  double? alertThreshold; // triggers alert when value <= threshold
  String? alertNote; // explanatory context (e.g. "depends on medication")
  bool alwaysAlert; // true = any record triggers alert (e.g. hair loss patch)

  // E14 — Alternative data sources
  FieldDataSource dataSource;
  String? linkedHabitId; // if dataSource == habit
  String? linkedTaskTitle; // if dataSource == recurringTask

  InputField({
    required this.id,
    required this.title,
    required this.type,
    this.defaultValue,
    List<OrganizerReference>? organizers,
    this.unit,
    this.min,
    this.max,
    this.options,
    this.optionsSourceCollectionSlug,
    this.alertLevel = FieldAlertLevel.none,
    this.alertThreshold,
    this.alertNote,
    this.alwaysAlert = false,
    this.dataSource = FieldDataSource.tracker,
    this.linkedHabitId,
    this.linkedTaskTitle,
  }) : organizers = organizers ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'default_value': defaultValue,
      'unit': unit,
      'min': min,
      'max': max,
      'options': options,
      'options_source_collection_slug': optionsSourceCollectionSlug,
      'organizers': organizers.map((e) => e.toWikiLink()).toList(),
      // A6.2 alert fields
      'alert_level': alertLevel.name,
      if (alertThreshold != null) 'alert_threshold': alertThreshold,
      if (alertNote != null) 'alert_note': alertNote,
      if (alwaysAlert) 'always_alert': true,
      // E14 data source
      'data_source': dataSource.name,
      if (linkedHabitId != null) 'linked_habit_id': linkedHabitId,
      if (linkedTaskTitle != null) 'linked_task_title': linkedTaskTitle,
    };
  }

  factory InputField.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    return InputField(
      id: map['id']?.toString() ?? map['slug']?.toString() ?? '',
      title: map['title']?.toString() ?? map['name']?.toString() ?? '',
      type: InputFieldType.values.firstWhere(
        (e) => e.name == map['type']?.toString(),
        orElse: () => InputFieldType.text,
      ),
      defaultValue: map['default_value'],
      unit: map['unit']?.toString(),
      min: (map['min'] as num?)?.toDouble(),
      max: (map['max'] as num?)?.toDouble(),
      options: rawOptions is List
          ? rawOptions.map((option) => option.toString()).toList()
          : const [],
      optionsSourceCollectionSlug: map['options_source_collection_slug']?.toString(),
      organizers: (map['organizers'] as List? ?? [])
          .map((e) => OrganizerReference.fromWikiLink(e.toString()))
          .toList(),
      // A6.2 alert fields
      alertLevel: FieldAlertLevel.values.firstWhere(
        (e) => e.name == map['alert_level']?.toString(),
        orElse: () => FieldAlertLevel.none),
      alertThreshold: (map['alert_threshold'] as num?)?.toDouble(),
      alertNote: map['alert_note']?.toString(),
      alwaysAlert: map['always_alert'] as bool? ?? false,
      // E14 data source
      dataSource: FieldDataSource.values.firstWhere(
        (e) => e.name == map['data_source']?.toString(),
        orElse: () => FieldDataSource.tracker),
      linkedHabitId: map['linked_habit_id']?.toString(),
      linkedTaskTitle: map['linked_task_title']?.toString(),
    );
  }
}

class TrackerSection {
  String title;
  List<InputField> inputFields;

  TrackerSection({this.title = '', List<InputField>? inputFields})
    : inputFields = inputFields ?? [];

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'input_fields': inputFields.map((e) => e.toMap()).toList(),
    };
  }

  factory TrackerSection.fromMap(Map<String, dynamic> map) {
    final rawFields =
        map['input_fields'] ?? map['inputFields'] ?? map['fields'] ?? [];
    return TrackerSection(
      title: map['title']?.toString() ?? map['name']?.toString() ?? '',
      inputFields: (rawFields is List ? rawFields : const [])
          .whereType<Map>()
          .map((e) => InputField.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class TrackerDefinition extends ContentObject {
  String color;
  String? icon;
  String? description;
  List<TrackerSection> sections;
  bool isHealthTracker; // A6.3
  List<ActionDef> actions;

  TrackerDefinition({
    super.id,
    required super.title,
    this.color = '#6B5EA8',
    this.icon,
    this.description,
    this.sections = const [],
    this.isHealthTracker = false,
    List<ActionDef>? actions,
    super.organizers,
    super.categories,
    super.tags,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : actions = actions ?? [];

  @override
  String get type => 'tracker_definition';

  @override
  bool get isIncomplete => title.trim().isEmpty || sections.isEmpty;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['color'] = color;
    frontmatter['icon'] = icon;
    frontmatter['description'] = description;
    frontmatter['sections'] = sections.map((e) => e.toMap()).toList();
    if (isHealthTracker) frontmatter['is_health_tracker'] = true;
    if (actions.isNotEmpty) {
      frontmatter['actions'] = actions.map((action) => action.toJson()).toList();
    }
    
    final buffer = StringBuffer();
    if (description != null && description!.isNotEmpty) {
      buffer.writeln(description);
      buffer.writeln();
    }
    
    for (final section in sections) {
      buffer.writeln('## ${section.title}');
      for (final field in section.inputFields) {
        if (field.type == InputFieldType.quantity || field.type == InputFieldType.range || field.type == InputFieldType.duration || field.type == InputFieldType.mood || field.type == InputFieldType.checkbox) {
          buffer.writeln('### ${field.title}');
          buffer.writeln('```tracker');
          buffer.writeln('searchType: frontmatter');
          buffer.writeln('searchTarget: $slug.${field.id}');
          buffer.writeln('folder: daily');
          buffer.writeln('line:');
          buffer.writeln('  title: "${field.title}"');
          buffer.writeln('  yAxisLabel: ${field.unit ?? "Value"}');
          buffer.writeln('  lineColor: "$color"');
          buffer.writeln('```');
          buffer.writeln();
        }
      }
    }
    
    return generateMarkdown(frontmatter, buffer.toString());
  }

  factory TrackerDefinition.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final tracker = TrackerDefinition(
      title: frontmatter['title'] as String? ?? '',
    );
    tracker.loadBaseMap(frontmatter);
    tracker.color = frontmatter['color'] as String? ?? '#6B5EA8';
    tracker.icon = frontmatter['icon'] as String?;
    tracker.description = frontmatter['description'] as String?;
    tracker.sections = _parseSections(frontmatter['sections'], body);
    tracker.isHealthTracker = frontmatter['is_health_tracker'] as bool? ?? false;
    if (frontmatter['actions'] is Iterable) {
      tracker.actions = (frontmatter['actions'] as Iterable)
          .whereType<Map>()
          .map((action) => ActionDef.fromJson(Map<String, dynamic>.from(action)))
          .toList();
    }
    return tracker;
  }

  static List<TrackerSection> _parseSections(dynamic rawSections, String body) {
    if (rawSections is List) {
      return rawSections
          .whereType<Map>()
          .map((e) => TrackerSection.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (rawSections is Map) {
      return rawSections.entries.map((entry) {
        final value = entry.value;
        if (value is Map) {
          final section = Map<String, dynamic>.from(value);
          section.putIfAbsent('title', () => entry.key.toString());
          return TrackerSection.fromMap(section);
        }
        if (value is List) {
          return TrackerSection(
            title: entry.key.toString(),
            inputFields: value.whereType<Map>().map((field) {
              return InputField.fromMap(Map<String, dynamic>.from(field));
            }).toList(),
          );
        }
        return TrackerSection(title: entry.key.toString());
      }).toList();
    }

    final sections = <TrackerSection>[];
    TrackerSection? current;
    for (final line in body.split('\n')) {
      final sectionMatch = RegExp(r'^##\s+(.+)$').firstMatch(line.trim());
      if (sectionMatch != null) {
        current = TrackerSection(title: sectionMatch.group(1)!.trim());
        sections.add(current);
        continue;
      }
      final fieldMatch = RegExp(r'^###\s+(.+)$').firstMatch(line.trim());
      if (fieldMatch != null) {
        current ??= TrackerSection(title: 'Default Section');
        if (!sections.contains(current)) sections.add(current);
        final title = fieldMatch.group(1)!.trim();
        current.inputFields.add(
          InputField(
            id: title
                .toLowerCase()
                .replaceAll(RegExp(r'\s+'), '_')
                .replaceAll(RegExp(r'[^a-z0-9_]'), ''),
            title: title,
            type: InputFieldType.text,
          ),
        );
      }
    }
    return sections;
  }
}

class TrackingRecord extends ContentObject {
  String trackerId;
  DateTime date;
  Map<String, dynamic> fieldValues;

  TrackingRecord({
    super.id,
    required super.title,
    required this.trackerId,
    required this.date,
    this.fieldValues = const {},
    super.organizers,
    super.categories,
    super.tags,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : super();

  @override
  String get type => 'tracker_record';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['tracker_id'] = trackerId;
    frontmatter['date'] = date.toIso8601String();
    frontmatter['field_values'] = fieldValues;
    return generateMarkdown(frontmatter, '');
  }

  factory TrackingRecord.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final record = TrackingRecord(
      title: frontmatter['title'] is List ? (frontmatter['title'] as List).join(', ') : frontmatter['title']?.toString() ?? 'Entry',
      trackerId: frontmatter['tracker_id'] is List ? (frontmatter['tracker_id'] as List).join(', ') : frontmatter['tracker_id']?.toString() ?? '',
      date: DateTime.tryParse(frontmatter['date'] ?? '') ?? DateTime.now(),
    );
    record.loadBaseMap(frontmatter);
    record.fieldValues = Map<String, dynamic>.from(
      frontmatter['field_values'] as Map? ?? {},
    );
    return record;
  }

  TrackingRecord copyWith({
    String? trackerId,
    DateTime? date,
    Map<String, dynamic>? fieldValues,
  }) {
    return TrackingRecord(
      id: id,
      title: title,
      trackerId: trackerId ?? this.trackerId,
      date: date ?? this.date,
      fieldValues: fieldValues ?? this.fieldValues,
      organizers: organizers,
      categories: categories,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      obsidianPath: obsidianPath,
    );
  }
}
