// lib/models/reminder_model.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'scheduler.dart';

class Reminder extends ContentObject {
  DateTime time;
  bool isCompleted;
  bool isCompletable;
  String? notes;
  Scheduler? scheduler;
  String? timeBlock;
  List<String> checkboxes;    // list of checkbox item titles
  bool habitReminder;         // true if this reminder belongs to a habit

  Reminder({
    super.id,
    required super.title,
    required this.time,
    this.isCompleted = false,
    this.isCompletable = true,
    this.notes,
    this.scheduler,
    this.timeBlock,
    List<String>? checkboxes,
    this.habitReminder = false,
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.reminders,
  }) : checkboxes = checkboxes ?? [];

  @override
  String get type => 'reminder';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['time'] = time.toIso8601String();
    frontmatter['is_completed'] = isCompleted;
    frontmatter['is_completable'] = isCompletable;
    if (notes != null) frontmatter['notes'] = notes;
    if (scheduler != null) frontmatter['scheduler'] = scheduler!.toMap();
    if (timeBlock != null) frontmatter['time_block'] = timeBlock;
    if (checkboxes.isNotEmpty) frontmatter['checkboxes'] = checkboxes;
    frontmatter['habit_reminder'] = habitReminder;
    return generateMarkdown(frontmatter, notes ?? '');
  }

  factory Reminder.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final reminder = Reminder(
      title: frontmatter['title'] as String? ?? '',
      time: DateTime.tryParse(frontmatter['time'] ?? '') ?? DateTime.now(),
    );
    reminder.loadBaseMap(frontmatter);
    reminder.isCompleted = frontmatter['is_completed'] as bool? ?? false;
    reminder.isCompletable = frontmatter['is_completable'] as bool? ?? true;
    reminder.notes = frontmatter['notes'] as String? ?? body;
    if (frontmatter['scheduler'] is Map) {
      reminder.scheduler = Scheduler.fromMap(
        Map<String, dynamic>.from(frontmatter['scheduler'] as Map),
      );
    }
    reminder.timeBlock = (frontmatter['time_block'] ?? frontmatter['time_block_id']) as String?;
    reminder.checkboxes = List<String>.from(frontmatter['checkboxes'] as List? ?? []);
    reminder.habitReminder = frontmatter['habit_reminder'] as bool? ?? false;
    return reminder;
  }

  Reminder copyWith({
    String? title,
    DateTime? time,
    bool? isCompleted,
    bool? isCompletable,
    String? notes,
    Scheduler? scheduler,
    String? timeBlock,
    List<String>? checkboxes,
    bool? habitReminder,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      isCompletable: isCompletable ?? this.isCompletable,
      notes: notes ?? this.notes,
      scheduler: scheduler ?? this.scheduler,
      timeBlock: timeBlock ?? this.timeBlock,
      checkboxes: checkboxes ?? this.checkboxes,
      habitReminder: habitReminder ?? this.habitReminder,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
  }
}
