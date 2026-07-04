// lib/models/reminder_model.dart
import 'content_object.dart';
import 'reminder_config.dart';
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

  ReminderConfig? get primaryReminder =>
      reminders.isEmpty ? null : reminders.first;

  void ensureCanonicalReminderConfig() {
    if (reminders.isEmpty) {
      reminders = [
        ReminderConfig(
          id: '${id}_primary',
          triggerTime: time,
          type: NotificationType.push,
        ),
      ];
      return;
    }

    final primary = reminders.first;
    if (primary.triggerTime == null) {
      reminders[0] = primary.copyWith(triggerTime: time);
    } else {
      time = primary.triggerTime!;
    }
  }

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
    super.tags,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.archived,
    super.pinned,
    super.reminders,
    super.links,
  }) : checkboxes = checkboxes ?? [] {
    ensureCanonicalReminderConfig();
  }

  @override
  String get type => 'reminder';

  @override
  bool get isIncomplete => title.trim().isEmpty || reminders.isEmpty;

  @override
  String toMarkdown() {
    ensureCanonicalReminderConfig();
    final frontmatter = toBaseMap();
    frontmatter['date'] = time.toIso8601String();
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
    final parsedTime =
        DateTime.tryParse(frontmatter['date']?.toString() ?? '') ??
        DateTime.tryParse(frontmatter['time']?.toString() ?? '') ??
        DateTime.now();
    final reminder = Reminder(
      title: frontmatter['title'] as String? ?? '',
      time: parsedTime,
    );
    reminder.loadBaseMap(frontmatter);
    reminder.time =
        reminder.primaryReminder?.triggerTime ??
        DateTime.tryParse(frontmatter['date']?.toString() ?? '') ??
        DateTime.tryParse(frontmatter['time']?.toString() ?? '') ??
        parsedTime;
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
    reminder.ensureCanonicalReminderConfig();
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
    List<ReminderConfig>? reminders,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    List<String>? links,
    bool? archived,
    bool? pinned,
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
      reminders: reminders ?? this.reminders,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      links: links ?? this.links,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
  }
}
