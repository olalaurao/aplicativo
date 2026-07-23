import 'package:uuid/uuid.dart';
import 'reminder_config.dart';

class ChecklistStep {
  final String id;
  final String title;
  final List<String> substeps;

  // Item linking
  final String kind;                 // 'plain' | 'habit' | 'task' | 'tracker_entry' | 'pomodoro'
  final String? linkedObjectSlug;    // Habit / Task / TrackerDefinition slug
  final String? trackerFieldId;      // only for kind == 'tracker_entry'
  final String? attachedCollectionSlug; // Note slug (subtype == collection), optional
  final ReminderConfig? reminderConfig; // Notification config for 'plain' (reminder) kind

  ChecklistStep({
    String? id,
    required this.title,
    this.substeps = const [],
    this.kind = 'plain',
    this.linkedObjectSlug,
    this.trackerFieldId,
    this.attachedCollectionSlug,
    this.reminderConfig,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'substeps': substeps,
      'kind': kind,
      if (linkedObjectSlug != null) 'linked_object_slug': linkedObjectSlug,
      if (trackerFieldId != null) 'tracker_field_id': trackerFieldId,
      if (attachedCollectionSlug != null) 'attached_collection_slug': attachedCollectionSlug,
      if (reminderConfig != null) 'reminder_config': reminderConfig!.toMap(),
    };
  }

  factory ChecklistStep.fromMap(Map<String, dynamic> map) {
    final rawSubsteps = map['substeps'];
    ReminderConfig? parsedReminderConfig;
    if (map['reminder_config'] is Map) {
      parsedReminderConfig = ReminderConfig.fromMap(Map<String, dynamic>.from(map['reminder_config'] as Map));
    }
    
    return ChecklistStep(
      id: map['id']?.toString(),
      title: map['title']?.toString() ?? 'Untitled',
      substeps: rawSubsteps is Iterable
          ? rawSubsteps.map((item) => item.toString()).toList()
          : const [],
      kind: map['kind']?.toString() ?? 'plain',
      linkedObjectSlug: map['linked_object_slug']?.toString(),
      trackerFieldId: map['tracker_field_id']?.toString(),
      attachedCollectionSlug: map['attached_collection_slug']?.toString(),
      reminderConfig: parsedReminderConfig,
    );
  }

  ChecklistStep copyWith({
    String? title,
    List<String>? substeps,
    String? kind,
    String? linkedObjectSlug,
    String? trackerFieldId,
    String? attachedCollectionSlug,
    ReminderConfig? reminderConfig,
  }) {
    return ChecklistStep(
      id: id,
      title: title ?? this.title,
      substeps: substeps ?? this.substeps,
      kind: kind ?? this.kind,
      linkedObjectSlug: linkedObjectSlug ?? this.linkedObjectSlug,
      trackerFieldId: trackerFieldId ?? this.trackerFieldId,
      attachedCollectionSlug: attachedCollectionSlug ?? this.attachedCollectionSlug,
      reminderConfig: reminderConfig ?? this.reminderConfig,
    );
  }
}
