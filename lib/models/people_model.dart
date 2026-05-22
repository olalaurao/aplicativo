// lib/models/people_model.dart
import 'content_object.dart';
import 'organizer_model.dart';
import 'task_model.dart'; // For TaskPriority

class Person extends Organizer {
  String? photo;
  String? phone;
  String? email;
  DateTime? lastContactDate;
  Duration? contactFrequency;
  TaskPriority contactPriority;

  Person({
    super.id,
    required super.title,
    this.photo,
    this.phone,
    this.email,
    this.lastContactDate,
    this.contactFrequency,
    this.contactPriority = TaskPriority.none,
    super.parentId,
    super.startDate,
    super.endDate,
    super.color,
    super.icon,
    super.organizers,
    super.categories,
    super.moc,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : super(organizerType: OrganizerType.person);

  @override
  String get type => 'person';

  bool get isDueForContact {
    if (lastContactDate == null || contactFrequency == null) return false;
    final dueDate = lastContactDate!.add(contactFrequency!);
    return DateTime.now().isAfter(dueDate);
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

    return generateMarkdown(frontmatter, '');
  }

  factory Person.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final person = Person(title: frontmatter['title'] as String? ?? '');
    person.loadBaseMap(frontmatter);

    person.photo = frontmatter['photo'] as String?;
    person.phone = frontmatter['phone'] as String?;
    person.email = frontmatter['email'] as String?;
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

    return person;
  }

  Person copyWith({
    String? title,
    String? photo,
    String? phone,
    String? email,
    DateTime? lastContactDate,
    Duration? contactFrequency,
    TaskPriority? contactPriority,
    String? obsidianPath,
  }) {
    final p = Person(
      id: id,
      title: title ?? this.title,
      photo: photo ?? this.photo,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      lastContactDate: lastContactDate ?? this.lastContactDate,
      contactFrequency: contactFrequency ?? this.contactFrequency,
      contactPriority: contactPriority ?? this.contactPriority,
      organizers: organizers,
      categories: categories,
      moc: moc,
      createdAt: createdAt,
      updatedAt: updatedAt,
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
    return p;
  }
}
