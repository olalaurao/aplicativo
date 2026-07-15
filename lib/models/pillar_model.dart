// lib/models/pillar_model.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'task_model.dart';
import 'reminder_config.dart';

enum EnergyLevel { low, mid, high }

class PillarTouch {
  final DateTime date;
  final String? actionId;  // referência a um ActionMenuItem real, opcional
  final String? note;      // reflexão livre, opcional

  PillarTouch({required this.date, this.actionId, this.note});

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    if (actionId != null) 'action_id': actionId,
    if (note != null) 'note': note,
  };

  factory PillarTouch.fromMap(Map<String, dynamic> map) => PillarTouch(
    date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
    actionId: map['action_id']?.toString(),
    note: map['note']?.toString(),
  );
}

class Pillar extends ContentObject {
  String? why;                       // a abstração / frase-âncora
  String color;
  String? icon;
  List<PillarTouch> touchLog;

  Pillar({
    super.id, required super.title, this.why,
    this.color = '#8B5CF6', this.icon,
    List<PillarTouch>? touchLog,
    super.organizers, super.categories, super.tags,
    super.createdAt, super.updatedAt, super.obsidianPath, super.archived,
  }) : touchLog = touchLog ?? [];

  @override
  String get type => ObjectTypes.pillar;

  // last touch, for "última vez: há N dias" — nunca "quebrou streak"
  DateTime? get lastTouch =>
      touchLog.isEmpty ? null : (touchLog.map((t) => t.date).toList()..sort()).last;

  int touchesInLast(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return touchLog.where((t) => t.date.isAfter(cutoff)).length;
  }

  @override
  String toMarkdown() {
    final fm = toBaseMap();
    if (why != null) fm['why'] = why;
    fm['color'] = color;
    if (icon != null) fm['icon'] = icon;
    fm['touch_log'] = touchLog.map((t) => t.toMap()).toList();
    return generateMarkdown(fm, why ?? '');
  }

  factory Pillar.fromMarkdown(Map<String, dynamic> fm, String body) {
    final p = Pillar(title: fm['title']?.toString() ?? '');
    p.loadBaseMap(fm);
    p.why = fm['why']?.toString();
    p.color = fm['color']?.toString() ?? '#8B5CF6';
    p.icon = fm['icon']?.toString();
    p.touchLog = (fm['touch_log'] as List? ?? [])
        .whereType<Map>().map((m) => PillarTouch.fromMap(Map<String, dynamic>.from(m))).toList();
    return p;
  }

  Pillar copyWith({
    String? title,
    String? why,
    String? color,
    String? icon,
    List<PillarTouch>? touchLog,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    bool? archived,
  }) {
    return Pillar(
      id: id,
      title: title ?? this.title,
      why: why ?? this.why,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      touchLog: touchLog ?? this.touchLog,
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
