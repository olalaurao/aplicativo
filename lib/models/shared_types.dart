// lib/models/shared_types.dart
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// ObjectTypes — canonical type string constants (V5 complete enum, Part 20).
// Use these instead of raw string literals to avoid typos across the codebase.
// ---------------------------------------------------------------------------
abstract final class ObjectTypes {
  // Content objects
  static const String task         = 'task';
  static const String habit        = 'habit';
  static const String tracker      = 'tracker';
  static const String goal         = 'goal';
  static const String note         = 'note';
  static const String entry        = 'entry';
  static const String event        = 'event';
  static const String reminder     = 'reminder';
  static const String system       = 'system';
  static const String socialPost   = 'social_post';
  static const String moodDef      = 'mood_definition';
  static const String idea         = 'idea';
  static const String inbox        = 'inbox';
  static const String shoppingList = 'shopping_list';
  static const String template     = 'template';
  static const String dailyNote    = 'daily_note';
  static const String analysis     = 'analysis';
  static const String wellbeingIndicator = 'wellbeing_indicator';

  // Organizer objects
  static const String area         = 'area';
  static const String project      = 'project';
  static const String activity     = 'activity';
  static const String label        = 'label';
  static const String person       = 'person';
  static const String dayTheme     = 'day_theme';
  static const String timeBlock    = 'time_block';
  static const String value        = 'value';
  static const String routine      = 'routine';

  // Content objects (continued)
  static const String pillar       = 'pillar';
  static const String action       = 'action';

  /// All canonical types in insertion order.
  static const List<String> all = [
    task, habit, tracker, goal, note, entry, event, reminder, system,
    socialPost, moodDef, idea, inbox, shoppingList, template, dailyNote,
    analysis, wellbeingIndicator, area, project, activity, label, person,
    dayTheme, timeBlock, value, routine, pillar, action,
  ];

  /// Returns true if [type] is a known canonical type string.
  static bool isKnown(String type) => all.contains(type);
}

class TimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  Map<String, dynamic> toMap() {
    return {
      'start_hour': startHour,
      'start_minute': startMinute,
      'end_hour': endHour,
      'end_minute': endMinute,
    };
  }

  factory TimeRange.fromMap(Map<String, dynamic> map) {
    return TimeRange(
      startHour: map['start_hour'] as int? ?? 0,
      startMinute: map['start_minute'] as int? ?? 0,
      endHour: map['end_hour'] as int? ?? 0,
      endMinute: map['end_minute'] as int? ?? 0,
    );
  }
}

enum MarkerType { tag, property, folder }


class TypeSignature {
  final String objectType;
  final MarkerType markerType;
  final String markerValue;
  final String emoji;
  final String? iconName;
  /// Optional hex color (e.g. '#F97316') chosen by the user for this object type.
  /// Used by timeline, month grid, dial legend and completables components.
  final String? colorHex;

  TypeSignature({
    required this.objectType,
    required this.markerType,
    required this.markerValue,
    this.emoji = '',
    this.iconName,
    this.colorHex,
  });

  Map<String, dynamic> toMap() => {
    'objectType': objectType,
    'markerType': markerType.name,
    'markerValue': markerValue,
    'emoji': emoji,
    'iconName': iconName,
    if (colorHex != null) 'colorHex': colorHex,
  };

  factory TypeSignature.fromMap(Map<String, dynamic> map) => TypeSignature(
    objectType: map['objectType'] ?? '',
    markerType: MarkerType.values.firstWhere(
      (e) => e.name == map['markerType'],
      orElse: () => MarkerType.property,
    ),
    markerValue: map['markerValue'] ?? '',
    emoji: map['emoji'] ?? '',
    iconName: map['iconName'],
    colorHex: map['colorHex'] as String?,
  );
}

class OrganizerReference {
  final String type; // e.g., 'area', 'project', 'habit', 'label'
  final String slug;
  final String title;
  final String? icon;
  final String? color;

  OrganizerReference({
    required this.type,
    required this.slug,
    required this.title,
    this.icon,
    this.color,
  });

  bool matches(String orgId, String orgSlug, String orgTitle) {
    if (slug == orgSlug) return true;
    if (slug == orgId) return true;
    final normalizedRef = slug
        .replaceAll('_', '-')
        .replaceAll('/', '-')
        .toLowerCase();
    final normalizedSlug = orgSlug
        .replaceAll('_', '-')
        .replaceAll('/', '-')
        .toLowerCase();
    final normalizedId = orgId
        .replaceAll('_', '-')
        .replaceAll('/', '-')
        .toLowerCase();
    if (normalizedRef == normalizedSlug || normalizedRef == normalizedId) {
      return true;
    }
    if (title.toLowerCase() == orgTitle.toLowerCase()) return true;
    return false;
  }

  factory OrganizerReference.fromWikiLink(
    String wikiLink, {
    String defaultType = 'label',
  }) {
    final raw = wikiLink.replaceAll('[', '').replaceAll(']', '').trim();
    final parts = raw.split('/');
    if (parts.length >= 2) {
      final type = parts.first.toLowerCase();
      final slug = parts
          .sublist(1)
          .join('/')
          .toLowerCase()
          .replaceAll(' ', '-');
      final title = slug
          .replaceAll('-', ' ')
          .split(' ')
          .map(
            (word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1)
                : '',
          )
          .join(' ');
      return OrganizerReference(type: type, slug: slug, title: title);
    }
    final slug = raw.toLowerCase().replaceAll(' ', '-');
    final title = raw
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '',
        )
        .join(' ');
    return OrganizerReference(type: defaultType, slug: slug, title: title);
  }

  String toWikiLink() => '[[$slug]]';

  Map<String, dynamic> toMap() => {
    'type': type,
    'slug': slug,
    'title': title,
    if (icon != null) 'icon': icon,
    if (color != null) 'color': color,
  };

  factory OrganizerReference.fromMap(Map<String, dynamic> map) =>
      OrganizerReference(
        type: map['type'] ?? 'label',
        slug: map['slug'] ?? '',
        title: map['title'] ?? '',
        icon: map['icon'],
        color: map['color'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizerReference &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          slug == other.slug;

  @override
  int get hashCode => type.hashCode ^ slug.hashCode;
}

class Comment {
  final String text;
  final DateTime date;
  final List<String> photos;

  Comment({required this.text, required this.date, this.photos = const []});
}

class ActionDef {
  final String type; // add_tracking_record, add_entry, add_text_note, launch_url, etc.
  final String trigger; // slot_complete, day_complete, kpi_reached
  final String? targetTracker;
  /// Parâmetros extras específicos ao tipo de action.
  /// Ex.: add_text_note: {'title': '...'}, launch_url: {'url': '...'}
  final Map<String, dynamic>? params;

  ActionDef({
    required this.type,
    required this.trigger,
    this.targetTracker,
    this.params,
  });

  factory ActionDef.fromJson(Map<String, dynamic> json) {
    return ActionDef(
      type: json['type'] as String,
      trigger: json['trigger'] as String? ?? 'day_complete',
      targetTracker: json['target_tracker'] as String?,
      params: json['params'] != null
          ? Map<String, dynamic>.from(json['params'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'trigger': trigger,
    if (targetTracker != null) 'target_tracker': targetTracker,
    if (params != null) 'params': params,
  };
}

class SubtaskSession {
  final String id;
  final String name;
  final List<String> subtaskIds;

  SubtaskSession({
    required this.id,
    required this.name,
    required this.subtaskIds,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'subtask_ids': subtaskIds,
  };

  factory SubtaskSession.fromMap(Map<String, dynamic> map) => SubtaskSession(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    subtaskIds: () {
      final raw = map['subtask_ids'] ?? map['subtaskIds'];
      if (raw is Iterable) return raw.map((e) => e.toString()).toList();
      return <String>[];
    }(),
  );
}

class Subtask {
  String id;
  String title;
  bool completed;
  String? slug;     // Link para Task completa se promovida
  bool isHeader;    // Se true, é um cabeçalho de grupo
  bool isCollapsed; // Para cabeçalhos de sessão
  String? session;  // Nome do grupo
  /// Data de vencimento específica desta subtask (Tasks Plugin: `[due:: YYYY-MM-DD]`)
  DateTime? dueDate;
  /// Prioridade específica desta subtask (Tasks Plugin: `[priority:: high]`)
  /// Valores: 'none', 'low', 'medium', 'high' — mesmo enum de TaskPriority.
  String? priority;

  Subtask({
    String? id,
    required this.title,
    this.completed = false,
    this.slug,
    this.isHeader = false,
    this.isCollapsed = false,
    this.session,
    this.dueDate,
    this.priority,
  }) : id = id ?? const Uuid().v4();
}

class VaultLinkRef {
  final String? objectSlug;
  final String? objectType;
  final String? noteSlug;
  final String? blockId;
  final String displayTitle;

  const VaultLinkRef({
    this.objectSlug,
    this.objectType,
    this.noteSlug,
    this.blockId,
    required this.displayTitle,
  });

  bool get isRow => noteSlug != null && blockId != null;

  String toWikiLink() =>
      isRow ? '[[$noteSlug^$blockId]]' : '[[$objectSlug]]';

  Map<String, dynamic> toMap() => {
    'link': toWikiLink(),
    'display_title': displayTitle,
    if (objectType != null) 'object_type': objectType,
  };

  factory VaultLinkRef.fromMap(Map<String, dynamic> map) {
    final inner = (map['link']?.toString() ?? '')
        .replaceAll('[[', '')
        .replaceAll(']]', '');
    if (inner.contains('^')) {
      final parts = inner.split('^');
      return VaultLinkRef(
        noteSlug: parts[0],
        blockId: parts.length > 1 ? parts[1] : null,
        displayTitle: map['display_title']?.toString() ?? parts[0],
      );
    }
    return VaultLinkRef(
      objectSlug: inner,
      objectType: map['object_type']?.toString(),
      displayTitle: map['display_title']?.toString() ?? inner,
    );
  }
}

// ---------------------------------------------------------------------------
// DataSourceReference — V5 unified data-source schema (Part 1.4 / Part 16)
// Used by KPI, Combined Analysis, Dashboard Panels and Wellbeing Indicator.
// Replaces the two incompatible V4 per-feature schemas.
// ---------------------------------------------------------------------------

enum DataSourceType {
  trackerField,
  habit,
  journalMood,
  subtasks,
  collection,
  entry,
  timeSpent,
  manualQuantity,
}

enum DataSourceAggregation { sum, average, count, max, min, streak }

class DataSourceReference {
  final DataSourceType sourceType;

  /// WikiLink to the tracker or habit slug.
  /// Omitted for subtasks / entry / timeSpent / manualQuantity.
  final String? sourceId;

  /// Only for [DataSourceType.trackerField] — identifies the specific field.
  final String? fieldId;

  /// Only for [DataSourceType.journalMood] — `pleasantness` or `energy`.
  final String? dimension;

  /// Only for categorical tracker fields: maps string labels to numeric values.
  final Map<String, dynamic>? valueMapping;

  /// Used by KPI. Combined Analysis ignores this (uses raw series).
  final DataSourceAggregation? aggregation;

  const DataSourceReference({
    required this.sourceType,
    this.sourceId,
    this.fieldId,
    this.dimension,
    this.valueMapping,
    this.aggregation,
  });

  Map<String, dynamic> toMap() => {
    'source_type': _sourceTypeToString(sourceType),
    if (sourceId != null) 'source_id': sourceId,
    if (fieldId != null) 'field_id': fieldId,
    if (dimension != null) 'dimension': dimension,
    if (valueMapping != null && valueMapping!.isNotEmpty)
      'value_mapping': valueMapping,
    if (aggregation != null) 'aggregation': aggregation!.name,
  };

  factory DataSourceReference.fromMap(Map<String, dynamic> map) {
    final rawType = map['source_type']?.toString() ?? '';
    final sourceType = _sourceTypeFromString(rawType);
    final rawAgg = map['aggregation']?.toString();
    return DataSourceReference(
      sourceType: sourceType,
      sourceId: map['source_id']?.toString(),
      fieldId: map['field_id']?.toString(),
      dimension: map['dimension']?.toString(),
      valueMapping: map['value_mapping'] is Map
          ? Map<String, dynamic>.from(map['value_mapping'] as Map)
          : null,
      aggregation: rawAgg == null
          ? null
          : DataSourceAggregation.values.firstWhere(
              (e) => e.name == rawAgg,
              orElse: () => DataSourceAggregation.sum,
            ),
    );
  }

  static String _sourceTypeToString(DataSourceType t) {
    switch (t) {
      case DataSourceType.trackerField:
        return 'tracker_field';
      case DataSourceType.habit:
        return 'habit';
      case DataSourceType.journalMood:
        return 'journal_mood';
      case DataSourceType.subtasks:
        return 'subtasks';
      case DataSourceType.collection:
        return 'collection';
      case DataSourceType.entry:
        return 'entry';
      case DataSourceType.timeSpent:
        return 'time_spent';
      case DataSourceType.manualQuantity:
        return 'manual_quantity';
    }
  }

  static DataSourceType _sourceTypeFromString(String s) {
    switch (s) {
      case 'tracker_field':
        return DataSourceType.trackerField;
      case 'habit':
        return DataSourceType.habit;
      case 'journal_mood':
        return DataSourceType.journalMood;
      case 'subtasks':
        return DataSourceType.subtasks;
      case 'collection':
        return DataSourceType.collection;
      case 'entry':
        return DataSourceType.entry;
      case 'time_spent':
        return DataSourceType.timeSpent;
      case 'manual_quantity':
        return DataSourceType.manualQuantity;
      default:
        // Legacy KPI source_type mapping
        if (s.contains('habit')) return DataSourceType.habit;
        if (s.contains('tracker')) return DataSourceType.trackerField;
        if (s.contains('entry') || s.contains('journal')) return DataSourceType.entry;
        if (s.contains('time')) return DataSourceType.timeSpent;
        if (s.contains('subtask') || s.contains('goal')) return DataSourceType.subtasks;
        if (s.contains('collection')) return DataSourceType.collection;
        if (s.contains('mood')) return DataSourceType.journalMood;
        return DataSourceType.manualQuantity;
    }
  }
}

class EventLogEntry {
  final DateTime timestamp;
  final String action;
  final String description;
  final String? oldValue;
  final String? newValue;

  EventLogEntry({
    required this.timestamp,
    required this.action,
    required this.description,
    this.oldValue,
    this.newValue,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'description': description,
    };
    if (oldValue != null) m['old_value'] = oldValue;
    if (newValue != null) m['new_value'] = newValue;
    return m;
  }

  factory EventLogEntry.fromMap(Map<String, dynamic> map) {
    return EventLogEntry(
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      action: map['action']?.toString() ?? 'unknown',
      description: map['description']?.toString() ?? '',
      oldValue: map['old_value']?.toString(),
      newValue: map['new_value']?.toString(),
    );
  }
}
