// lib/services/markdown_parser.dart
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:flutter/foundation.dart';
import '../models/shared_types.dart';
import '../models/content_object.dart';

// ---------------------------------------------------------------------------
// A3 — HighlightItem: represents a single blockquote/highlight extracted
//       from a Resource synopsis or Note body.
// ---------------------------------------------------------------------------
class HighlightItem {
  final String text;
  final String? tag; // extracted from '#word' at end of line
  final String? date; // extracted from 'YYYY-MM-DD' if present

  const HighlightItem({required this.text, this.tag, this.date});
}

class OcrBlock {
  final String? sourceImage;
  final String text;

  const OcrBlock({this.sourceImage, required this.text});
}

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
          final value = parts.sublist(1).join(':').trim();
          return _frontmatterValueMatches(frontmatter[key], value);
        } else {
          final key = sig.markerValue.trim();
          final val = frontmatter[key];
          if (val == null) return false;
          if (val is List) {
            return _frontmatterValueMatches(val, key);
          }
          return true;
        }
      case MarkerType.folder:
        final folder = _normalizeFolder(sig.markerValue);
        final normalizedPath = path.replaceAll('\\', '/');
        return normalizedPath == folder ||
            normalizedPath.startsWith('$folder/');
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

  static bool _frontmatterValueMatches(dynamic actual, String expected) {
    final normalizedExpected = _normalizePropertyValue(expected);
    if (actual is List) {
      return actual.any(
        (item) =>
            _normalizePropertyValue(item.toString()) == normalizedExpected,
      );
    }
    return _normalizePropertyValue(actual?.toString() ?? '') ==
        normalizedExpected;
  }

  static String _normalizePropertyValue(String value) {
    var normalized = value.trim();
    if (normalized.startsWith('"') && normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    if (normalized.startsWith("'") && normalized.endsWith("'")) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    final wikiMatch = RegExp(r'^\[\[(.*)\]\]$').firstMatch(normalized);
    if (wikiMatch != null) {
      normalized = wikiMatch.group(1)!.trim();
    }
    return normalized.toLowerCase();
  }

  static String _normalizeFolder(String folder) {
    return folder
        .trim()
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+|/+$'), '');
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

  static Map<String, dynamic> parseFrontmatter(String content, {String? filePath}) {
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
      // Try repairing special characters (like @ symbols)
      final repaired = _repairSpecialCharactersInYaml(yamlStr);
      if (repaired != yamlStr) {
        try {
          final doc = loadYaml(repaired);
          if (doc is YamlMap) {
            debugPrint(
              'Repaired YAML with special characters after parse error: $e',
            );
            final result = _convertNode(doc) as Map<String, dynamic>;
            // Signal to the vault loader that this file needs to be rewritten
            result['__needs_rewrite__'] = true;
            return result;
          }
        } catch (_) {
          // Fall through to legacy repair
        }
      }
      
      // Try legacy repair for inline analysis YAML
      final legacyRepaired = _repairLegacyInlineAnalysisYaml(yamlStr);
      if (legacyRepaired != yamlStr) {
        try {
          final doc = loadYaml(legacyRepaired);
          if (doc is YamlMap) {
            debugPrint(
              'Repaired legacy YAML frontmatter after parse error: $e',
            );
            final result = _convertNode(doc) as Map<String, dynamic>;
            // Signal to the vault loader that this file needs to be rewritten
            result['__needs_rewrite__'] = true;
            return result;
          }
        } catch (_) {
          // Fall through to the original error log below.
        }
      }
      debugPrint('Error parsing YAML: $e');
      // Return error information for UI display
      return {
        '__yaml_error__': true,
        '__yaml_error_message__': e.toString(),
        '__yaml_error_file__': filePath ?? 'unknown',
      };
    }
    return {};
  }

  static String _repairLegacyInlineAnalysisYaml(String yamlStr) {
    if (!yamlStr.contains('sources: [{') &&
        !yamlStr.contains('data_sources: [{')) {
      return yamlStr;
    }

    String quoteFlowValue(String input, String key) {
      return input.replaceAllMapped(RegExp('($key:\\s*)([^,}\\]\\n]+)'), (
        match,
      ) {
        final prefix = match.group(1)!;
        final raw = match.group(2)!.trim();
        if (raw.isEmpty ||
            raw.startsWith('"') ||
            raw.startsWith("'") ||
            raw == 'true' ||
            raw == 'false' ||
            num.tryParse(raw) != null) {
          return '$prefix$raw';
        }
        final escaped = raw.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
        return '$prefix"$escaped"';
      });
    }

    var repaired = yamlStr;
    for (final key in const ['label', 'color']) {
      repaired = quoteFlowValue(repaired, key);
    }
    return repaired;
  }

  static String _repairSpecialCharactersInYaml(String yamlStr) {
    // Repair values that start with @ or contain special characters that break YAML parsing
    String quoteProblematicValues(String input) {
      // First handle @ symbols at start of values
      var result = input.replaceAllMapped(RegExp(r'^(\w+):\s*(@\S+)$', multiLine: true), (match) {
        final key = match.group(1)!;
        final value = match.group(2)!;
        final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
        return '$key: "$escaped"';
      });

      // Then handle long text values that contain special characters (colons, dashes, etc.)
      // This fixes issues with caption, transcription, and other long text fields
      result = result.replaceAllMapped(RegExp(r'^(\w+):\s*(.+)$', multiLine: true), (match) {
        final key = match.group(1)!;
        final value = match.group(2)!.trim();
        
        // Skip if already quoted
        if ((value.startsWith('"') && value.endsWith('"')) || 
            (value.startsWith("'") && value.endsWith("'"))) {
          return match.group(0)!;
        }
        
        // Skip if it's a boolean, number, or simple value
        if (value == 'true' || value == 'false' || value == 'null' ||
            num.tryParse(value) != null ||
            RegExp(r'^[\w-]+$').hasMatch(value)) {
          return match.group(0)!;
        }
        
        // Quote values that contain special characters or are long text
        if (value.contains(':') && !value.startsWith('http')) {
          final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
          return '$key: "$escaped"';
        }
        
        return match.group(0)!;
      });

      return result;
    }

    var repaired = quoteProblematicValues(yamlStr);
    return repaired;
  }

  static Future<Map<String, dynamic>> asyncParseFrontmatter(
    String content, {
    String? filePath,
  }) async {
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
      folder = _normalizeFolder(sig.markerValue);
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
    if (object.type == 'tracker_record' || object.type == 'combined_analysis') {
      final suffix = object.id.length > 8
          ? object.id.substring(0, 8)
          : object.id;
      filename = filename.isEmpty ? suffix : '$filename-$suffix';
    }
    if (filename.isEmpty) filename = object.id;

    String path = '$folder/$filename.md';

    if (sig != null) {
      final frontmatter = parseFrontmatter(markdown);
      final body = extractBody(markdown);
      final bodyBuffer = StringBuffer(body);

      applySignature(frontmatter, bodyBuffer, sig);
      markdown = generateMarkdown(frontmatter, bodyBuffer.toString());

      if (sig.markerType == MarkerType.folder) {
        final sigFolder = _normalizeFolder(sig.markerValue);
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

  // ---------------------------------------------------------------------------
  // A3 — extractHighlights
  // ---------------------------------------------------------------------------

  /// Extracts highlighted / quoted passages from markdown or Quill Delta body.
  static List<HighlightItem> extractHighlights(String markdown) {
    if (markdown.isEmpty) return [];
    final highlights = <HighlightItem>[];

    // Try Quill Delta first (blockquote attribute)
    final ops = tryParseDeltaOps(markdown);
    if (ops != null) {
      for (final op in ops) {
        final insert = op['insert'];
        final attrs = op['attributes'];
        if (insert is String &&
            attrs is Map &&
            (attrs['blockquote'] == true || attrs['quote'] == true)) {
          final text = insert.trim();
          if (text.isNotEmpty) highlights.add(HighlightItem(text: text));
        }
      }
      return highlights;
    }

    // Plain markdown: lines starting with '>'
    final lines = markdown.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('>')) continue;

      var text = line.replaceFirst(RegExp(r'^>\s*(\[!\w+\]\s*)?'), '').trim();
      if (text.isEmpty) continue;

      // Extract inline tag: '…texto #tag' → tag separated
      String? tag;
      final tagMatch = RegExp(r'#(\w+)\s*$').firstMatch(text);
      if (tagMatch != null) {
        tag = tagMatch.group(1);
        text = text.substring(0, tagMatch.start).trim();
      }

      // Extract YYYY-MM-DD date if present
      String? date;
      final dateMatch = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(text);
      if (dateMatch != null) date = dateMatch.group(0);

      // Multi-line blockquote continuation
      while (i + 1 < lines.length && lines[i + 1].trim().startsWith('>')) {
        i++;
        final cont = lines[i].trim().replaceFirst(RegExp(r'^>\s*'), '').trim();
        if (cont.isNotEmpty) text += ' $cont';
      }

      if (text.length > 5) {
        highlights.add(HighlightItem(text: text, tag: tag, date: date));
      }
    }
    return highlights;
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
          if (line.startsWith('mood::') ||
              line.startsWith('organizers::') ||
              line.startsWith('entry_type::') ||
              line.startsWith('category::') ||
              line.startsWith('energy_value::')) {
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

        // Parse entry_type, category, energy_value inline Dataview fields
        final entryTypeMatch = RegExp(
          r'^entry_type::\s*(.*)$',
          multiLine: true,
        ).firstMatch(section);
        final entryTypeStr = entryTypeMatch?.group(1)?.trim();

        final categoryMatch = RegExp(
          r'^category::\s*(.*)$',
          multiLine: true,
        ).firstMatch(section);
        final categoryStr = categoryMatch?.group(1)?.trim();

        final energyMatch = RegExp(
          r'^energy_value::\s*(\d+)',
          multiLine: true,
        ).firstMatch(section);
        final energyValue = energyMatch != null
            ? int.tryParse(energyMatch.group(1)!)
            : null;
        // F3.15: Clamp energy value to 0-10 range
        final clampedEnergyValue = energyValue?.clamp(0, 10);

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

        final entryData = <String, dynamic>{
          'time': time,
          'title': title,
          'body': entryBody,
          'mood': moodSlug,
          'organizers': orgsList,
          'hashtags': hashtags,
          'date': entryDate,
        };
        if (entryTypeStr != null) entryData['entry_type'] = entryTypeStr;
        if (categoryStr != null) entryData['category'] = categoryStr;
        if (clampedEnergyValue != null) entryData['energy_value'] = clampedEnergyValue;
        entries.add(entryData);
      }
    }
    return entries;
  }

  static Map<String, dynamic> parseHabitCompletions(
    Map<String, dynamic> frontmatter,
  ) {
    // Legacy support: check for explicit nested 'habits' map first
    if (frontmatter['habits'] is Map) {
      return Map<String, dynamic>.from(frontmatter['habits']);
    }

    // Modern flat format: collect top-level keys that look like habits
    // (boolean or numeric values) excluding known system keys
    final habits = <String, dynamic>{};
    // All known daily-note metadata keys that are NOT habit slugs
    const systemKeys = {
      'date',
      'tags',
      'type',
      'id',
      'slug',
      'title',
      'trackers',
      'habit_completions',
      'target',
      'status',
      'priority',
      'archived',
      'day_theme',
      'created_at',
      'updated_at',
      'organizers',
      'categories',
      'reminders',
      'week',
      'date_range_start',
      'date_range_end',
      'referenced_dates',
      'pact_refs',
      'entry_type',
      'category',
      'energy_value',
      'mood_entries',
      'mood_pleasantness',
      'mood_energy',
      'mood_label',
      'mood_emoji',
      'habits',
      'body',
      '__needs_rewrite__',
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

  static Map<String, List<String>> parsePmnSections(String body) {
    final result = {
      'plus': <String>[],
      'minus': <String>[],
      'next': <String>[],
    };
    final sectionRegex = RegExp(
      r'^##\s*(Plus|Minus|Next)\s*$',
      multiLine: true,
      caseSensitive: false,
    );
    final matches = sectionRegex.allMatches(body).toList();
    for (var i = 0; i < matches.length; i++) {
      final key = matches[i].group(1)!.toLowerCase();
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : body.length;
      final sectionText = body.substring(start, end);
      final bullets = RegExp(r'^-\s*(.+)$', multiLine: true)
          .allMatches(sectionText)
          .map((m) => m.group(1)!.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      result[key] = bullets;
    }
    return result;
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
        final Map<String, dynamic> pom = {'time': time, 'title': title};

        for (final line in lines.sublist(1)) {
          final trimmed = line.trim();
          if (trimmed.contains('Duration:')) {
            pom['worked'] =
                RegExp(r'Duration:\s*(\d+)').firstMatch(trimmed)?.group(1) ??
                '';
          } else if (trimmed.contains('Blocks:')) {
            pom['blocks'] =
                RegExp(r'Blocks:\s*(\d+)').firstMatch(trimmed)?.group(1) ?? '';
          } else if (trimmed.contains('- Linked:')) {
            final linkMatch = RegExp(r'\[\[(.*?)\]\]').firstMatch(trimmed);
            if (linkMatch != null) {
              pom['linked_item'] = linkMatch.group(1);
            }
          } else if (trimmed.contains('- Blocos:')) {
            pom['blocks'] =
                RegExp(r'Blocos:\s*(\d+)').firstMatch(trimmed)?.group(1) ?? '';
          } else if (trimmed.contains('- Tempo trabalhado:') ||
              trimmed.contains('- Tempo:')) {
            pom['worked'] =
                RegExp(
                  r'(?:trabalhado|Tempo):\s*(\d+)',
                ).firstMatch(trimmed)?.group(1) ??
                '';
          } else if (trimmed.contains('- Tempo de pausa:') ||
              trimmed.contains('- Pausas:')) {
            pom['break'] =
                RegExp(
                  r'(?:pausa|Pausas):\s*(\d+)',
                ).firstMatch(trimmed)?.group(1) ??
                '';
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
    Map<String, String> habitLabels = const {},
    Set<String> pactHabitSlugs = const {},
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
        if (entry['entry_type'] != null) {
          buffer.writeln('entry_type:: ${entry['entry_type']}');
        }
        if (entry['category'] != null) {
          buffer.writeln('category:: ${entry['category']}');
        }
        if (entry['energy_value'] != null) {
          buffer.writeln('energy_value:: ${entry['energy_value']}');
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
        final title = habitLabels[slug] ?? slug.toString();
        final pactSuffix = pactHabitSlugs.contains(slug.toString())
            ? ' ← pact'
            : '';
        buffer.writeln('- $status $title$details$pactSuffix');
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
        final linked = pom['linked_item'] ?? pom['linked'];
        if (linked != null) {
          buffer.writeln('- Linked: [[$linked]]');
        }
        final blocks = pom['blocks'] ?? '0';
        final worked = pom['worked'] ?? pom['duration'] ?? '0';
        final breakTime = pom['break'] ?? '0';
        buffer.writeln('- Blocos: $blocks');
        buffer.writeln('- Tempo trabalhado: $worked min');
        buffer.writeln('- Tempo de pausa: $breakTime min');
        buffer.writeln();
      }
    }

    return buffer.toString().trim();
  }

  static List<OcrBlock> parseOcrSections(String body) {
    final sectionRegex = RegExp(
      r'^##\s*📝\s*Texto Extraído \(OCR\)\s*$',
      multiLine: true,
    );
    final sourceRegex = RegExp(r'<!--\s*ocr-source:\s*(.+?)\s*-->');
    final matches = sectionRegex.allMatches(body).toList();
    final blocks = <OcrBlock>[];
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : body.length;
      final sectionText = body.substring(start, end).trim();
      final sourceMatch = sourceRegex.firstMatch(sectionText);
      final text = sourceMatch != null
          ? sectionText.substring(sourceMatch.end).trim()
          : sectionText;
      blocks.add(OcrBlock(sourceImage: sourceMatch?.group(1), text: text));
    }
    return blocks;
  }

  static String upsertOcrSection(
    String body,
    String sourceImage,
    String newText,
  ) {
    final newBlock =
        '## 📝 Texto Extraído (OCR)\n<!-- ocr-source: $sourceImage -->\n$newText';
    final sectionRegex = RegExp(
      r'^##\s*📝\s*Texto Extraído \(OCR\)\s*\n<!--\s*ocr-source:\s*' +
          RegExp.escape(sourceImage) +
          r'\s*-->\n(.*?)(?=\n##\s|\z)',
      multiLine: true,
      dotAll: true,
    );
    final match = sectionRegex.firstMatch(body);
    if (match == null) return '${body.trimRight()}\n\n$newBlock\n';
    return body.replaceRange(match.start, match.end, newBlock);
  }
}
