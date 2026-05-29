// lib/services/markdown_parser.dart
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:flutter/foundation.dart';
import '../models/shared_types.dart';
import '../models/content_object.dart';

class MarkdownParser {
  static bool matchesSignature(
    Map<String, dynamic> frontmatter,
    String body,
    String path,
    TypeSignature sig,
  ) {
    switch (sig.markerType) {
      case MarkerType.tag:
        final tags = extractTags(body);
        final fmTags = frontmatter['tags'] as List?;
        final searchTag = sig.markerValue.replaceAll('#', '');
        return tags.contains(searchTag) ||
            (fmTags != null && fmTags.contains(searchTag));
      case MarkerType.property:
        if (sig.markerValue.contains(':')) {
          final parts = sig.markerValue.split(':');
          final key = parts[0].trim();
          final value = parts[1].trim();
          return frontmatter[key]?.toString() == value;
        } else {
          // Just check if key exists or if value matches one of the values if it's a list
          final key = sig.markerValue.trim();
          final val = frontmatter[key];
          if (val == null) return false;
          if (val is List) {
            return val.contains(key); // Case of categories: [[project]]
          }
          return true;
        }
      case MarkerType.folder:
        return path.startsWith(sig.markerValue);
    }
  }

  static void applySignature(
    Map<String, dynamic> frontmatter,
    StringBuffer bodyBuffer,
    TypeSignature sig,
  ) {
    switch (sig.markerType) {
      case MarkerType.tag:
        bodyBuffer.writeln('\n${sig.markerValue}');
        break;
      case MarkerType.property:
        if (sig.markerValue.contains(':')) {
          final parts = sig.markerValue.split(':');
          frontmatter[parts[0].trim()] = parts[1].trim();
        } else {
          frontmatter[sig.markerValue.trim()] = true;
        }
        break;
      case MarkerType.folder:
        // Folder is handled by the path when saving
        break;
    }
  }

  static Map<String, dynamic> mergeFrontmatter(
    Map<String, dynamic> base,
    Map<String, dynamic> remote,
  ) {
    final result = Map<String, dynamic>.from(base);

    remote.forEach((key, value) {
      if (!result.containsKey(key)) {
        result[key] = value;
      } else {
        final baseVal = result[key];
        if (baseVal is Map && value is Map) {
          result[key] = mergeFrontmatter(
            Map<String, dynamic>.from(baseVal),
            Map<String, dynamic>.from(value),
          );
        } else if (baseVal is List && value is List) {
          // Merge lists - simple union for strings/ints
          final set = <dynamic>{...baseVal, ...value};
          result[key] = set.toList();
        } else {
          // Conflict: remote wins for simple values in this "simple merge"
          result[key] = value;
        }
      }
    });

    return result;
  }

  static Map<String, dynamic> parseFrontmatter(String content) {
    if (!content.startsWith('---')) return {};
    final endIdx = content.indexOf('---', 3);
    if (endIdx == -1) return {};

    final yamlStr = content.substring(3, endIdx).trim();
    if (yamlStr.isEmpty) return {};

    try {
      final doc = loadYaml(yamlStr);
      if (doc is YamlMap) {
        return _convertNode(doc) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error parsing YAML: $e');
    }
    return {};
  }

  static Future<Map<String, dynamic>> asyncParseFrontmatter(
    String content,
  ) async {
    return compute(parseFrontmatter, content);
  }

  static dynamic _convertNode(dynamic v) {
    if (v is YamlMap) {
      return v.map(
        (key, value) => MapEntry(key.toString(), _convertNode(value)),
      );
    } else if (v is YamlList) {
      return v.map((e) => _convertNode(e)).toList();
    }
    return v;
  }

  static Map<String, String> prepareForSave(
    ContentObject object,
    TypeSignature? sig, {
    required String defaultFolder,
  }) {
    String markdown = object.toMarkdown();

    // Determine folder
    String folder = defaultFolder;
    if (sig != null && sig.markerType == MarkerType.folder) {
      folder = sig.markerValue.endsWith('/')
          ? sig.markerValue.substring(0, sig.markerValue.length - 1)
          : sig.markerValue;
    } else if (object.obsidianPath.isNotEmpty) {
      final parts = object.obsidianPath.split('/');
      if (parts.length > 1) {
        folder = parts.sublist(0, parts.length - 1).join('/');
      }
    }

    // Resources are user-facing library cards, so keep the vault filename
    // aligned with the visible card title for easier Obsidian browsing.
    String filename = object.type == 'resource'
        ? _sanitizeFileName(object.title)
        : object.slug;
    if (filename.isEmpty) filename = object.id;

    String path = '$folder/$filename.md';

    if (sig != null) {
      final frontmatter = parseFrontmatter(markdown);
      final body = extractBody(markdown);
      final bodyBuffer = StringBuffer(body);

      applySignature(frontmatter, bodyBuffer, sig);
      markdown = generateMarkdown(frontmatter, bodyBuffer.toString());

      if (sig.markerType == MarkerType.folder) {
        final sigFolder = sig.markerValue.endsWith('/')
            ? sig.markerValue.substring(0, sig.markerValue.length - 1)
            : sig.markerValue;
        path = '$sigFolder/$filename.md';
      }
    }

    return {'markdown': markdown, 'path': path};
  }

  static String _sanitizeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');
  }

  static String extractBody(String content) {
    final lines = content.split('\n');
    final firstSeparator = lines.indexOf('---');
    if (firstSeparator == -1) return content;
    final secondSeparator = lines.indexOf('---', firstSeparator + 1);
    if (secondSeparator == -1) return content;
    return lines.sublist(secondSeparator + 1).join('\n').trim();
  }

  static final _wikiLinkRegex = RegExp(r'\[\[(.*?)\]\]');
  static final _tagRegex = RegExp(r'#(\w+)');
  static final _mentionRegex = RegExp(r'@(\w+)');
  static final _subtaskRegex = RegExp(r'^\s*-\s*\[([ xX])\]\s*(.*)$');
  static final _orgsRegex = RegExp(r'organizers::\s*(.*)');
  static final _pomodoroHeaderRegex = RegExp(r'^(\d{2}:\d{2})\s*[—-]\s*(.*)');

  /// Extracts [[WikiLinks]] and @mentions from a string.
  static List<String> extractLinks(String content) {
    final links = <String>[];

    for (final match in _wikiLinkRegex.allMatches(content)) {
      links.add(match.group(1)!);
    }

    for (final match in _mentionRegex.allMatches(content)) {
      links.add(match.group(1)!);
    }

    return links.toSet().toList(); // Unique links
  }

  static List<String> extractWikiLinks(String text) {
    return _wikiLinkRegex.allMatches(text).map((m) => m.group(1)!).toList();
  }

  static List<String> extractTags(String text) {
    return _tagRegex.allMatches(text).map((m) => m.group(1)!).toList();
  }

  static List<Map<String, dynamic>> parseSubtasks(String content) {
    final subtasks = <Map<String, dynamic>>[];
    final lines = content.split('\n');

    int subtasksIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().toLowerCase().contains('subtasks')) {
        subtasksIdx = i;
        break;
      }
    }

    int startIdx = subtasksIdx == -1 ? 0 : subtasksIdx + 1;
    for (int i = startIdx; i < lines.length; i++) {
      final line = lines[i];
      if (subtasksIdx != -1 && line.startsWith('## ')) break; // Next section

      final match = _subtaskRegex.firstMatch(line);
      if (match != null) {
        final isCompleted = match.group(1)!.toLowerCase() == 'x';
        final title = match.group(2)!.trim();
        subtasks.add({'title': title, 'completed': isCompleted});
      }
    }

    return subtasks;
  }

  static String getPlainTextFromBody(String body) {
    if (body.isEmpty) return '';
    final ops = tryParseDeltaOps(body);
    if (ops != null) {
      final text = ops
          .map((op) {
            final insert = op['insert'];
            if (insert is String) return insert;
            if (insert is Map) {
              if (insert['image'] != null) return '[imagem]';
              if (insert['video'] != null) return '[video]';
              return '[midia]';
            }
            return '';
          })
          .join('');
      return text.trim();
    }
    return body;
  }

  static List<Map<String, dynamic>>? tryParseDeltaOps(String body) {
    var trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    // Handle common smart quote issues if they somehow slipped in
    // Moving this to the top ensures we catch them before any checks
    if (trimmed.contains('“') ||
        trimmed.contains('”') ||
        trimmed.contains('‘') ||
        trimmed.contains('’')) {
      trimmed = trimmed
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .replaceAll('‘', "'")
          .replaceAll('’', "'");
    }

    // A more robust check for Quill Delta format
    // It can be a list or a map with an 'ops' key
    final isProbablyJson =
        (trimmed.startsWith('{') || trimmed.startsWith('[')) &&
        (trimmed.contains('"insert"') || trimmed.contains("'insert'"));

    if (!isProbablyJson) return null;

    try {
      final data = jsonDecode(trimmed);
      final dynamic rawOps = data is Map ? data['ops'] : data;
      if (rawOps is! List) return null;
      return rawOps
          .whereType<Map>()
          .map((op) => Map<String, dynamic>.from(op))
          .toList();
    } catch (_) {
      // If it looks like JSON but failed, try cleaning it further
      try {
        // Fix common JSON errors like trailing commas
        final cleaned = trimmed.replaceAll(RegExp(r',\s*([\]}])'), r'$1');
        final data = jsonDecode(cleaned);
        final dynamic rawOps = data is Map ? data['ops'] : data;
        if (rawOps is List) {
          return rawOps
              .whereType<Map>()
              .map((op) => Map<String, dynamic>.from(op))
              .toList();
        }
      } catch (__) {}
      return null;
    }
  }

  static List<Map<String, dynamic>> parseJournalEntries(
    String body,
    String dateStr,
  ) {
    if (body.isEmpty) return [];
    final parsedDay = DateTime.tryParse(dateStr);
    if (parsedDay == null) {
      debugPrint('Invalid daily note date for journal parsing: $dateStr');
    }

    final entries = <Map<String, dynamic>>[];
    final journalSections = body.split(
      RegExp(r'^## Journal Entries', multiLine: true),
    );
    final journalBody = journalSections.length < 2
        ? body
        : journalSections[1].split(RegExp(r'^## ', multiLine: true))[0];
    // Split by level 3 headers (### HH:MM)
    final sections = journalBody.split(RegExp(r'^### ', multiLine: true));

    for (final section in sections) {
      if (section.trim().isEmpty) continue;
      final lines = section.split('\n');
      final header = lines[0].trim();

      // Match HH:MM or HH:MM - Title
      final timeMatch = RegExp(
        r'^(\d{1,2}:\d{2})(?:\s*-\s*(.*))?',
      ).firstMatch(header);
      if (timeMatch != null) {
        final time = timeMatch.group(1)!;
        final title = timeMatch.group(2)?.trim() ?? '';

        // Extract content until the next header or end of section
        // We need to be careful with the body extraction
        final entryBodyLines = <String>[];
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i];
          if (line.startsWith('mood::') || line.startsWith('organizers::')) {
            continue;
          }
          if (line.trim() == '---') continue;
          entryBodyLines.add(line);
        }

        final entryBody = entryBodyLines.join('\n').trim();

        // Extract inline dataview fields like mood:: [[good]], [[calm]]
        final moodLineMatch = RegExp(
          r'^mood::\s*(.*)$',
          multiLine: true,
        ).firstMatch(section);
        final moodLinks = moodLineMatch == null
            ? const <String>[]
            : extractWikiLinks(moodLineMatch.group(1)!);
        final moodSlug = moodLinks.isEmpty ? null : moodLinks.join(', ');

        final orgsMatch = _orgsRegex.firstMatch(section);
        final orgsList = <OrganizerReference>[];
        if (orgsMatch != null) {
          final orgsText = orgsMatch.group(1)!;
          final wikiLinks = extractWikiLinks(orgsText);
          orgsList.addAll(
            wikiLinks.map((link) => OrganizerReference.fromWikiLink(link)),
          );
        }

        final hashtags = extractTags(entryBody);

        final entryDate = parsedDay == null
            ? dateStr
            : DateTime(
                parsedDay.year,
                parsedDay.month,
                parsedDay.day,
                int.tryParse(time.split(':').first) ?? 0,
                int.tryParse(time.split(':').last) ?? 0,
              ).toIso8601String();

        entries.add({
          'time': time,
          'title': title,
          'body': entryBody,
          'mood': moodSlug,
          'organizers': orgsList,
          'hashtags': hashtags,
          'date': entryDate,
        });
      }
    }
    return entries;
  }

  static Map<String, dynamic> parseHabitCompletions(
    Map<String, dynamic> frontmatter,
  ) {
    // Check for explicit 'habits' map first (modern Citrine format)
    if (frontmatter['habits'] is Map) {
      return Map<String, dynamic>.from(frontmatter['habits']);
    }

    // Fallback: collect top-level keys that look like habits (boolean or numeric values)
    // excluding known system keys
    final habits = <String, dynamic>{};
    final systemKeys = {
      'date',
      'tags',
      'type',
      'id',
      'title',
      'trackers',
      'habit_completions',
      'target',
      'status',
      'priority',
      'archived',
    };

    frontmatter.forEach((key, value) {
      if (!systemKeys.contains(key)) {
        if (value is bool || value is num || value is List) {
          habits[key] = value;
        }
      }
    });

    return habits;
  }

  static Map<String, dynamic> parseTrackerRecords(
    Map<String, dynamic> frontmatter,
  ) {
    if (frontmatter['trackers'] == null) return {};
    if (frontmatter['trackers'] is Map) {
      return Map<String, dynamic>.from(frontmatter['trackers']);
    }
    return {};
  }

  static List<Map<String, dynamic>> parsePomodoros(String body) {
    final pomodoros = <Map<String, dynamic>>[];
    final sections = body.split(RegExp(r'^## Pomodoros', multiLine: true));
    if (sections.length < 2) return [];

    final pomsSection = sections[1].split(RegExp(r'^## ', multiLine: true))[0];
    final subSections = pomsSection.split(RegExp(r'^### ', multiLine: true));

    for (final section in subSections) {
      if (section.trim().isEmpty) continue;
      final lines = section.split('\n');
      final header = lines[0].trim();

      final match = _pomodoroHeaderRegex.firstMatch(header);
      if (match != null) {
        final time = match.group(1)!;
        final title = match.group(2)!;
        final pom = {'time': time, 'title': title};

        for (final line in lines.sublist(1)) {
          if (line.contains('Duration:')) {
            pom['duration'] =
                RegExp(r'Duration:\s*(\d+)').firstMatch(line)?.group(1) ?? '';
          } else if (line.contains('Blocks:')) {
            pom['blocks'] =
                RegExp(r'Blocks:\s*(\d+)').firstMatch(line)?.group(1) ?? '';
          }
        }
        pomodoros.add(pom);
      }
    }
    return pomodoros;
  }

  static List<Map<String, dynamic>> parseTasksFromDailyNote(String body) {
    final tasks = <Map<String, dynamic>>[];
    final sections = body.split(RegExp(r'^## Tasks', multiLine: true));
    if (sections.length < 2) return [];

    final tasksSection = sections[1].split(RegExp(r'^## ', multiLine: true))[0];
    final lines = tasksSection.split('\n');

    for (final line in lines) {
      final match = _subtaskRegex.firstMatch(line);
      if (match != null) {
        tasks.add({
          'completed': match.group(1)!.toLowerCase() == 'x',
          'title': match.group(2)!.trim(),
        });
      }
    }
    return tasks;
  }

  static String generateDailyNoteBody({
    required List<Map<String, dynamic>> entries,
    List<Map<String, dynamic>> tasks = const [],
    Map<String, dynamic> habits = const {},
    Map<String, dynamic> trackers = const {},
    List<Map<String, dynamic>> pomodoros = const [],
  }) {
    final buffer = StringBuffer();

    if (entries.isNotEmpty) {
      buffer.writeln('## Journal Entries');
      buffer.writeln();
      for (final entry in entries) {
        final title =
            entry['title'] != null && (entry['title'] as String).isNotEmpty
            ? ' - ${entry['title']}'
            : '';
        buffer.writeln('### ${entry['time']}$title');
        buffer.writeln();
        buffer.writeln(entry['body'].toString().trim());
        buffer.writeln();
        if (entry['mood'] != null) {
          final moods = entry['mood']
              .toString()
              .split(RegExp(r'[,;|]'))
              .map((mood) => mood.trim())
              .where((mood) => mood.isNotEmpty)
              .map((mood) => mood.startsWith('[[') ? mood : '[[$mood]]')
              .join(', ');
          if (moods.isNotEmpty) buffer.writeln('mood:: $moods');
        }
        if (entry['organizers'] != null &&
            (entry['organizers'] as List).isNotEmpty) {
          final orgs = (entry['organizers'] as List)
              .map((o) {
                if (o is OrganizerReference) return o.toWikiLink();
                return '[[$o]]';
              })
              .join(', ');
          buffer.writeln('organizers:: $orgs');
        }
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    if (habits.isNotEmpty) {
      buffer.writeln('## Habits');
      buffer.writeln();
      habits.forEach((slug, val) {
        String status = '[ ]';
        String details = '';
        if (val is bool) {
          status = val ? '[x]' : '[ ]';
        } else if (val is num) {
          status = val > 0 ? '[x]' : '[ ]';
          details = ' ($val)';
        } else if (val is List) {
          final complete = val.every((v) => v == true);
          status = complete ? '[x]' : '[ ]';
          final count = val.where((v) => v == true).length;
          details = ' ($count/${val.length})';
        }
        buffer.writeln('- $status [[$slug]]$details');
      });
      buffer.writeln();
    }

    if (trackers.isNotEmpty) {
      buffer.writeln('## Trackers');
      buffer.writeln();
      trackers.forEach((slug, values) {
        buffer.writeln('### [[$slug]]');
        if (values is Map) {
          values.forEach((k, v) {
            buffer.writeln('- $k: $v');
          });
        }
        buffer.writeln();
      });
    }

    if (tasks.isNotEmpty) {
      buffer.writeln('## Tasks');
      buffer.writeln();
      for (final task in tasks) {
        final status = (task['completed'] ?? false) ? 'x' : ' ';
        buffer.writeln('- [$status] ${task['title']}');
      }
      buffer.writeln();
    }

    if (pomodoros.isNotEmpty) {
      buffer.writeln('## Pomodoros');
      buffer.writeln();
      for (final pom in pomodoros) {
        final time = pom['time'] ?? '00:00';
        final title = pom['title'] ?? 'Session';
        buffer.writeln('### $time — $title');
        buffer.writeln('- Duration: ${pom['duration']} min');
        if (pom['linked'] != null) {
          buffer.writeln('- Linked: [[${pom['linked']}]]');
        }
        if (pom['blocks'] != null) buffer.writeln('- Blocks: ${pom['blocks']}');
        if (pom['type'] != null) buffer.writeln('- Type: ${pom['type']}');
        buffer.writeln();
      }
    }

    return buffer.toString().trim();
  }
}
