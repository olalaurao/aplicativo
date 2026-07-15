// lib/models/people_model.dart
import 'content_object.dart';
import 'organizer_model.dart';
import 'task_model.dart'; // For TaskPriority
import 'shared_types.dart';
import 'scheduler.dart';
import 'reminder_config.dart';
import '../services/scheduler_service.dart';

class Person extends Organizer {
  String? photo;
  String? phone;
  String? email;
  String? notes;
  DateTime? lastContactDate;
  Duration? contactFrequency;
  TaskPriority contactPriority;
  /// F2.13: Scheduler for automatic contact reminders using days_after_reference_field
  @override Scheduler? scheduler;

  Person({
    super.id,
    required super.title,
    this.photo,
    this.phone,
    this.email,
    this.notes,
    this.lastContactDate,
    this.contactFrequency,
    this.contactPriority = TaskPriority.none,
    this.scheduler,
    super.reminders,
    super.parentId,
    super.startDate,
    super.endDate,
    super.color,
    super.icon,
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : super(organizerType: OrganizerType.person);

  @override
  String get type => 'person';

  /// F2.13: Check if person is due for contact using scheduler
  bool get isDueForContact {
    if (scheduler == null || lastContactDate == null) return false;
    
    // Check if any rule in the scheduler fires for today
    final today = DateTime.now();
    for (final rule in scheduler!.rules) {
      if (rule.repeatType == RepeatType.daysAfterReferenceField &&
          rule.targetType == 'person' &&
          rule.fieldName == 'last_contact_date') {
        if (SchedulerService.shouldFireReferenceFieldRule(rule, today, lastContactDate)) {
          return true;
        }
      }
    }
    return false;
  }

  /// F2.13: Generate or update scheduler from contactFrequency
  /// This creates a daysAfterReferenceField rule targeting last_contact_date
  Scheduler? get schedulerFromContactFrequency {
    if (contactFrequency == null) return null;
    
    final rule = SchedulerRule(
      repeatType: RepeatType.daysAfterReferenceField,
      interval: contactFrequency!.inDays,
      targetType: 'person',
      fieldName: 'last_contact_date',
    );
    
    return Scheduler(
      rules: [rule],
      startDate: DateTime.now(),
      itemType: ItemType.reminder,
    );
  }

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['organizer_type'] = organizerType.name;
    if (photo != null) frontmatter['photo'] = photo;
    if (phone != null) frontmatter['phone'] = phone;
    if (email != null) frontmatter['email'] = email;
    if (lastContactDate != null) {
      frontmatter['last_contact_date'] = lastContactDate!.toIso8601String();
    }
    if (contactFrequency != null) {
      frontmatter['contact_frequency_days'] = contactFrequency!.inDays;
    }
    frontmatter['contact_priority'] = contactPriority.name;
    // F2.13: Serialize scheduler
    if (scheduler != null) {
      frontmatter['scheduler'] = scheduler!.toMap();
    }

    return generateMarkdown(frontmatter, notes ?? '');
  }

  factory Person.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final person = Person(title: frontmatter['title'] as String? ?? '');
    person.loadBaseMap(frontmatter);

    person.photo = frontmatter['photo'] as String?;
    person.phone = frontmatter['phone'] as String?;
    person.email = frontmatter['email'] as String?;
    person.notes = body.trim().isEmpty ? null : body.trim();
    if (frontmatter['last_contact_date'] != null) {
      person.lastContactDate = DateTime.tryParse(
        frontmatter['last_contact_date'],
      );
    }
    if (frontmatter['contact_frequency_days'] != null) {
      person.contactFrequency = Duration(
        days: frontmatter['contact_frequency_days'] as int,
      );
    }
    if (frontmatter['contact_priority'] != null) {
      person.contactPriority = TaskPriority.values.firstWhere(
        (e) => e.name == frontmatter['contact_priority'],
        orElse: () => TaskPriority.none,
      );
    }
    // F2.13: Parse scheduler
    if (frontmatter['scheduler'] != null) {
      person.scheduler = Scheduler.fromMap(
        frontmatter['scheduler'] as Map<String, dynamic>,
      );
    }

    return person;
  }

  @override
  Person copyWith({
    String? title,
    OrganizerType? organizerType,
    String? parentId,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
    String? icon,
    String? state,
    String? priority,
    String? statement,
    List<TimeRange>? timeRanges,
    int? energyLevel,
    List<String>? daysOfWeek,
    Scheduler? scheduler,
    List<ReminderConfig>? reminders,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    String? photo,
    String? phone,
    String? email,
    String? notes,
    DateTime? lastContactDate,
    Duration? contactFrequency,
    TaskPriority? contactPriority,
  }) {
    final p = Person(
      id: id,
      title: title ?? this.title,
      photo: photo ?? this.photo,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      lastContactDate: lastContactDate ?? this.lastContactDate,
      contactFrequency: contactFrequency ?? this.contactFrequency,
      contactPriority: contactPriority ?? this.contactPriority,
      scheduler: scheduler ?? this.scheduler,
      reminders: reminders ?? this.reminders,
      parentId: parentId ?? this.parentId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
    return p;
  }
}
