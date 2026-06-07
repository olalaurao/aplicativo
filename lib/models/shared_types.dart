// lib/models/shared_types.dart
import 'package:uuid/uuid.dart';

enum MarkerType { tag, property, folder }

class TypeSignature {
  final String objectType;
  final MarkerType markerType;
  final String markerValue;

  TypeSignature({
    required this.objectType,
    required this.markerType,
    required this.markerValue,
  });

  Map<String, dynamic> toMap() => {
    'objectType': objectType,
    'markerType': markerType.name,
    'markerValue': markerValue,
  };

  factory TypeSignature.fromMap(Map<String, dynamic> map) => TypeSignature(
    objectType: map['objectType'] ?? '',
    markerType: MarkerType.values.firstWhere(
      (e) => e.name == map['markerType'],
      orElse: () => MarkerType.property,
    ),
    markerValue: map['markerValue'] ?? '',
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

  String toWikiLink() => type == 'label' ? '[[$slug]]' : '[[$type/$slug]]';

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
  final String type; // add_tracking_record, add_entry, etc.
  final String trigger; // slot_complete, day_complete
  final String? targetTracker;

  ActionDef({required this.type, required this.trigger, this.targetTracker});

  factory ActionDef.fromJson(Map<String, dynamic> json) {
    return ActionDef(
      type: json['type'] as String,
      trigger: json['trigger'] as String,
      targetTracker: json['target_tracker'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'trigger': trigger,
    if (targetTracker != null) 'target_tracker': targetTracker,
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
  String? slug; // Link to a full Task file if promoted
  bool isHeader; // If true, this is a group header
  bool isCollapsed; // For session headers
  String? session; // Group name

  Subtask({
    String? id,
    required this.title,
    this.completed = false,
    this.slug,
    this.isHeader = false,
    this.isCollapsed = false,
    this.session,
  }) : id = id ?? const Uuid().v4();
}

class KPI {
  final String id;
  final String title;
  final String source; // e.g., 'habit', 'tracker', 'pomodoro', 'manual'
  final String? sourceId;
  final String? sourceField;
  final double goalValue;
  final String unit;

  KPI({
    required this.id,
    required this.title,
    required this.source,
    this.sourceId,
    this.sourceField,
    required this.goalValue,
    this.unit = '',
  });
}
