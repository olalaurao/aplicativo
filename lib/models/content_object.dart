// lib/models/content_object.dart
import 'package:uuid/uuid.dart';
import 'shared_types.dart';
import 'reminder_config.dart';

abstract class ContentObject {
  String id;
  String title;
  List<OrganizerReference> organizers;
  List<String> categories;
  List<String> tags;
  List<String> moc;
  DateTime createdAt;
  DateTime updatedAt;
  String obsidianPath;
  bool archived;
  bool pinned;
  List<ReminderConfig> reminders;
  int? order;
  String? snippet;

  ContentObject({
    String? id,
    required this.title,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    List<String>? moc,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.obsidianPath = '',
    this.archived = false,
    this.pinned = false,
    this.order,
    List<ReminderConfig>? reminders,
  }) : id = id ?? const Uuid().v4(),
       organizers = organizers ?? [],
       categories = categories ?? [],
       tags = tags ?? [],
       moc = moc ?? [],
       reminders = reminders ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get type; // e.g., 'task', 'habit', 'entry'
  String toMarkdown();

  Map<String, dynamic> toBaseMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'categories': categories,
      'tags': tags,
      'moc': moc,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'archived': archived,
      'pinned': pinned,
      'order': order,
      'organizers': organizers.map((o) => o.toWikiLink()).toList(),
      'reminders': reminders.map((r) => r.toMap()).toList(),
    };
  }

  void loadBaseMap(Map<String, dynamic> map, {String? fallbackId}) {
    id = map['id']?.toString() ?? fallbackId ?? id;
    title = map['title'] as String? ?? title;
    categories = List<String>.from(map['categories'] as List? ?? []);
    tags = List<String>.from(map['tags'] as List? ?? []);
    moc = List<String>.from(map['moc'] as List? ?? []);
    if (map['created_at'] != null) {
      createdAt = DateTime.tryParse(map['created_at'].toString()) ?? createdAt;
    }
    if (map['updated_at'] != null) {
      updatedAt = DateTime.tryParse(map['updated_at'].toString()) ?? updatedAt;
    }
    archived = map['archived'] as bool? ?? false;
    pinned = map['pinned'] as bool? ?? false;
    order = map['order'] as int?;
    if (map['organizers'] != null && map['organizers'] is List) {
      organizers = (map['organizers'] as List)
          .map((o) => OrganizerReference.fromWikiLink(o.toString()))
          .toList();
    }
    if (map['reminders'] != null && map['reminders'] is List) {
      reminders = (map['reminders'] as List)
          .map(
            (r) => ReminderConfig.fromMap(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    }
  }

  String get slug => title
      .toLowerCase()
      .trim()
      .replaceAll(' ', '-')
      .replaceAll(RegExp(r'[^a-z0-9-]'), '');

  String get obsidianFileName => obsidianPath.isEmpty
      ? title
      : obsidianPath.split('/').last.split('\\').last.replaceAll('.md', '');

  DateTime? get baseTime => null;

  String get displayType => type.toUpperCase();
}

String generateMarkdown(Map<String, dynamic> frontmatter, String body) {
  final buffer = StringBuffer();
  buffer.writeln('---');

  String formatYamlScalar(dynamic value) {
    if (value is String) {
      final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      return '"$escaped"';
    }
    return value.toString();
  }

  void writeYaml(String key, dynamic value, int indent) {
    final indentStr = ' ' * indent;
    if (value is Map) {
      if (key.isNotEmpty) buffer.writeln('$indentStr$key:');
      value.forEach((k, v) {
        writeYaml(k.toString(), v, key.isEmpty ? indent : indent + 2);
      });
    } else if (value is List) {
      if (key.isNotEmpty) buffer.writeln('$indentStr$key:');
      for (final item in value) {
        if (item is Map) {
          bool first = true;
          item.forEach((k, v) {
            if (first) {
              buffer.writeln('$indentStr  - $k: ${formatYamlScalar(v)}');
              first = false;
            } else {
              buffer.writeln('$indentStr    $k: ${formatYamlScalar(v)}');
            }
          });
        } else {
          buffer.writeln('$indentStr  - ${formatYamlScalar(item)}');
        }
      }
    } else if (value != null) {
      if (key.isNotEmpty) {
        buffer.writeln('$indentStr$key: ${formatYamlScalar(value)}');
      } else {
        buffer.writeln('$indentStr${formatYamlScalar(value)}');
      }
    }
  }

  writeYaml('', frontmatter, 0);

  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln(body);
  return buffer.toString();
}

class NewPagePlaceholder extends ContentObject {
  NewPagePlaceholder({required super.title});

  @override
  String get type => 'note';

  @override
  String toMarkdown() => '';
}
