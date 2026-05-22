// lib/models/reminder_model.dart
import 'content_object.dart';
import 'scheduler.dart';

class Reminder extends ContentObject {
  DateTime time;
  bool isCompleted;
  bool isCompletable;
  String? notes;
  Scheduler? scheduler;
  String? timeBlockId;

  Reminder({
    super.id,
    required super.title,
    required this.time,
    this.isCompleted = false,
    this.isCompletable = true,
    this.notes,
    this.scheduler,
    this.timeBlockId,
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.reminders,
  });

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
    if (timeBlockId != null) frontmatter['time_block_id'] = timeBlockId;
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
    reminder.timeBlockId = frontmatter['time_block_id'] as String?;
    return reminder;
  }
}
