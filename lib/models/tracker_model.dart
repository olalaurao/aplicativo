// lib/models/tracker_model.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'package:flutter/foundation.dart';

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
      'organizers': organizers.map((e) => e.toWikiLink()).toList(),
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
      organizers: (map['organizers'] as List? ?? [])
          .map((e) => OrganizerReference.fromWikiLink(e.toString()))
          .toList(),
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

  TrackerDefinition({
    super.id,
    required super.title,
    this.color = '#6B5EA8',
    this.icon,
    this.description,
    this.sections = const [],
    super.organizers,
    super.categories,
    super.tags,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  });

  @override
  String get type => 'tracker_definition';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['color'] = color;
    frontmatter['icon'] = icon;
    frontmatter['description'] = description;
    frontmatter['sections'] = sections.map((e) => e.toMap()).toList();
    
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
    debugPrint('Tracker sections: ${tracker.sections.length}');
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
}
