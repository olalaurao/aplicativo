// lib/models/content_object.dart
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'shared_types.dart';
import 'reminder_config.dart';

abstract class ContentObject {
  String id;
  String title;
  List<OrganizerReference> organizers;
  List<String> categories;
  List<String> tags;
  List<String> aliases;
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
    List<String>? aliases,
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
       aliases = aliases ?? [],
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
      'aliases': aliases,
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
    aliases = List<String>.from(map['aliases'] as List? ?? []);
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

  String get displayTitle {
    final candidates = <String>[title, ...aliases, obsidianFileName];
    for (final candidate in candidates) {
      final resolved = displayTitleFromValue(candidate, id: id);
      if (resolved != null) return resolved;
    }
    return 'Sem título';
  }

  DateTime? get baseTime => null;

  String get displayType => type.toUpperCase();
}

String? displayTitleFromValue(String? value, {String? id}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (id != null && trimmed == id) return null;
  if (looksLikeTechnicalId(trimmed)) return null;
  if (RegExp(r'^[a-z0-9]+([-_][a-z0-9]+)+$').hasMatch(trimmed) &&
      RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
    return trimmed
        .split(RegExp(r'[-_]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
  return trimmed;
}

bool looksLikeTechnicalId(String value) {
  final trimmed = value.trim();
  return RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(trimmed) ||
      RegExp(r'^[0-9a-fA-F]{24,64}$').hasMatch(trimmed) ||
      RegExp(r'^\d{10,}$').hasMatch(trimmed) ||
      RegExp(
        r'^(tasks|habits|goals|notes|resources|organizers|daily|moods|trackers)[_-].+',
      ).hasMatch(trimmed);
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
          if (item.isEmpty) {
            buffer.writeln('$indentStr  - {}');
            continue;
          }

          var first = true;
          item.forEach((k, v) {
            final itemIndent = first ? '$indentStr  - ' : '$indentStr    ';
            first = false;
            if (v is Map || v is List) {
              buffer.writeln('$itemIndent$k:');
              writeYaml('', v, indent + 4);
            } else if (v != null) {
              buffer.writeln('$itemIndent$k: ${formatYamlScalar(v)}');
            } else {
              buffer.writeln('$itemIndent$k:');
            }
          });
        } else if (item is List) {
          buffer.writeln('$indentStr  -');
          writeYaml('', item, indent + 4);
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

String normalizeRichTextBodyForMarkdown(String body) {
  final ops = _tryParseDeltaOps(body);
  if (ops == null) return body;
  return _deltaOpsToMarkdown(ops);
}

List<Map<String, dynamic>>? _tryParseDeltaOps(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) return null;
  if (!trimmed.contains('"insert"') && !trimmed.contains("'insert'")) {
    return null;
  }

  try {
    final decoded = jsonDecode(trimmed);
    final rawOps = decoded is Map ? decoded['ops'] : decoded;
    if (rawOps is! List) return null;
    return rawOps
        .whereType<Map>()
        .map((op) => Map<String, dynamic>.from(op))
        .toList();
  } catch (_) {
    return null;
  }
}

String _deltaOpsToMarkdown(List<Map<String, dynamic>> ops) {
  final lines = <String>[];
  final current = StringBuffer();
  var orderedIndex = 1;

  String formatInline(String text, Map<String, dynamic> attributes) {
    var result = text;
    if (attributes['code'] == true) result = '`$result`';
    if (attributes['bold'] == true) result = '**$result**';
    if (attributes['italic'] == true) result = '*$result*';
    if (attributes['link'] != null) {
      result = '[$result](${attributes['link']})';
    }
    return result;
  }

  void flush(Map<String, dynamic> attributes) {
    final text = current.toString();
    current.clear();

    final listType = attributes['list']?.toString();
    if (listType == 'bullet') {
      lines.add('- $text');
    } else if (listType == 'ordered') {
      lines.add('${orderedIndex++}. $text');
    } else if (listType == 'checked' || listType == 'unchecked') {
      lines.add('- [${listType == 'checked' ? 'x' : ' '}] $text');
    } else if (attributes['blockquote'] == true) {
      lines.add('> $text');
    } else if (attributes['header'] != null) {
      final level = int.tryParse(attributes['header'].toString()) ?? 1;
      lines.add('${'#' * level.clamp(1, 6)} $text');
    } else {
      orderedIndex = 1;
      lines.add(text);
    }
  }

  for (final op in ops) {
    final insert = op['insert'];
    final attributes = op['attributes'] is Map
        ? Map<String, dynamic>.from(op['attributes'] as Map)
        : <String, dynamic>{};

    if (insert is Map) {
      final image = insert['image']?.toString();
      if (image != null && image.isNotEmpty) {
        if (current.isNotEmpty) flush(const {});
        lines.add('![[$image]]');
      }
      continue;
    }

    if (insert is! String) continue;
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        current.write(formatInline(parts[i], attributes));
      }
      if (i < parts.length - 1) {
        flush(attributes);
      }
    }
  }

  if (current.isNotEmpty) flush(const {});
  return lines.join('\n').trim();
}

class NewPagePlaceholder extends ContentObject {
  NewPagePlaceholder({required super.title});

  @override
  String get type => 'note';

  @override
  String toMarkdown() => '';
}
