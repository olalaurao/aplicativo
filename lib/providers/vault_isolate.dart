import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../services/obsidian_service.dart';
import '../services/markdown_parser.dart';
import '../models/shared_types.dart';
import '../models/content_object.dart';
import '../models/task_model.dart';
import '../models/shopping_list_model.dart' as shopping_list_model;
import '../models/journal_entry.dart';
import '../models/habit_model.dart';
import '../models/organizer_model.dart' as organizer_model;
import '../models/goal_model.dart';
import '../models/note_model.dart';
import '../models/tracker_model.dart';
import '../models/mood_model.dart';
import '../models/analysis_model.dart';
import '../models/wellbeing_indicator_model.dart';
import '../models/resource_model.dart';
import '../models/social_post.dart';
import '../models/people_model.dart';
import '../models/project_model.dart';
import '../models/snapshot_model.dart';
import '../models/system_model.dart';

import '../models/template_model.dart';
import '../models/idea_model.dart';
import '../models/event_model.dart';
import '../models/pomodoro_session.dart';
import '../models/reminder_model.dart';

/// Data class that holds the parameters needed to parse the vault in an isolate.
class VaultIsolateParams {
  final String vaultName;
  final String vaultPath;
  final Map<String, String> folderPaths;
  final Map<String, TypeSignature> typeSignatures;
  final String dailyNoteFolder;
  final String dailyNoteIdentifier;
  final String dailyNoteDateFormat;

  VaultIsolateParams({
    required this.vaultName,
    required this.vaultPath,
    required this.folderPaths,
    required this.typeSignatures,
    required this.dailyNoteFolder,
    required this.dailyNoteIdentifier,
    required this.dailyNoteDateFormat,
  });
}

/// Data class that holds the results of parsing the vault in an isolate.
class ParsedVaultResult {
  final List<ContentObject> objects;
  final Map<String, Map<String, dynamic>> dailyMap;
  final List<String> needsRewritePaths;

  ParsedVaultResult({
    required this.objects,
    required this.dailyMap,
    required this.needsRewritePaths,
  });
}

/// Helper that spawns the isolate and returns a [Future] of [ParsedVaultResult].
Future<ParsedVaultResult> parseVaultInIsolate(VaultIsolateParams params) async {
  return await Isolate.run(() async {
    final service = ObsidianService();
    // Initialize the vault inside the isolate using the resolved path.
    await service.initVault(params.vaultName, customPath: params.vaultPath);

    // Run migrations inside the isolate to avoid main thread CPU block
    await service.fixEntryTypeMigration();

    List<ContentObject> results = [];
    Map<String, List<Map<String, dynamic>>> dailyHabitCompletions = {};
    Map<String, List<Map<String, dynamic>>> dailyTrackerRecords = {};
    final needsRewritePaths = <String>[];

    // 1. Fetch markdown files, prioritizing user-configured object folders.
    final scannedPaths = <String>{};
    final mdFiles = <File>[];
    for (final folder in params.folderPaths.values) {
      final files = await service.getFilesInFolder(folder);
      for (final file in files) {
        final normalized = file.path.replaceAll('\\', '/');
        if (scannedPaths.add(normalized)) mdFiles.add(file);
      }
    }
    final defaultFiles = await service.getFilesInFolder('');
    for (final file in defaultFiles) {
      final normalized = file.path.replaceAll('\\', '/');
      if (scannedPaths.add(normalized) && file.path.endsWith('.md')) {
        mdFiles.add(file);
      }
    }

    // 2. Read and parse files in parallel batches (max 50 concurrent I/O ops)
    const batchSize = 50;
    final Map<String, Map<String, dynamic>> dailyMap = {};

    for (int i = 0; i < mdFiles.length; i += batchSize) {
      final end = (i + batchSize < mdFiles.length)
          ? i + batchSize
          : mdFiles.length;
      final batch = mdFiles.sublist(i, end);

      await Future.wait(
        batch.map((file) async {
          try {
            final relativePath = service.getRelativePath(file.path);
            final content = await file.readAsString();
            final frontmatter = MarkdownParser.parseFrontmatter(content);
            final body = MarkdownParser.extractBody(content);

            final isDaily = _isDailyNoteIsolate(relativePath, frontmatter, params);
            final String? literalType = frontmatter['type']?.toString();
            String? type = literalType;

            final entries = params.typeSignatures.entries.toList();
            final organizerIdx = entries.indexWhere(
              (e) => e.key == 'organizer',
            );
            if (organizerIdx != -1) {
              final orgEntry = entries.removeAt(organizerIdx);
              entries.add(orgEntry);
            }

            for (final entry in entries) {
              if (MarkdownParser.matchesSignature(
                frontmatter,
                body,
                relativePath,
                entry.value,
              )) {
                type = entry.key;
                break;
              }
            }

            final pmnMatch = RegExp(
              r'(\d{4})-(\d{2})-W(\d{2})',
            ).firstMatch(relativePath);
            final isPmnFile =
                pmnMatch != null && relativePath.split('/').contains('daily');

            if (isPmnFile) {
              final yearStr = pmnMatch.group(1)!;
              final weekStr = pmnMatch.group(3)!;
              final canonicalId = 'pmn-$yearStr-W$weekStr';
              final entry = JournalEntry(
                id: frontmatter['id']?.toString() ?? canonicalId,
                body: '',
                date:
                    DateTime.tryParse(
                      frontmatter['date_range_start']?.toString() ?? '',
                    ) ??
                    DateTime.now(),
                title: 'PMN ${frontmatter['week'] ?? weekStr}',
                entryType: JournalEntryType.pmn,
                obsidianPath: relativePath,
              );
              entry.week = frontmatter['week']?.toString();
              entry.dateRangeStart = DateTime.tryParse(
                frontmatter['date_range_start']?.toString() ?? '',
              );
              entry.dateRangeEnd = DateTime.tryParse(
                frontmatter['date_range_end']?.toString() ?? '',
              );
              entry.referencedDates =
                  (frontmatter['referenced_dates'] as List? ?? [])
                      .map((d) => DateTime.tryParse(d.toString()))
                      .whereType<DateTime>()
                      .toList();
              entry.pactRefs = (frontmatter['pact_refs'] as List? ?? [])
                  .map((p) => p.toString())
                  .toList();
              final pmnSections = MarkdownParser.parsePmnSections(body);
              entry.plus = pmnSections['plus'] ?? [];
              entry.minus = pmnSections['minus'] ?? [];
              entry.next = pmnSections['next'] ?? [];
              results.add(entry);
            } else if (isDaily || type == 'daily_note') {
              final dateMatch = RegExp(
                r'(\d{4}-\d{2}-\d{2}|\d{2}-\d{2}-\d{2})',
              ).firstMatch(relativePath);
              if (dateMatch != null) {
                final dateStr = _normalizeDailyDate(dateMatch.group(1)!);
                final entriesData = MarkdownParser.parseJournalEntries(
                  body,
                  dateStr,
                );
                final List<JournalEntry> journalEntries = [];

                for (final data in entriesData) {
                  // Resolve entry_type from inline Dataview field
                  JournalEntryType resolvedEntryType =
                      JournalEntryType.standard;
                  final rawEntryType = data['entry_type']
                      ?.toString()
                      .replaceAll('_', '')
                      .toLowerCase();
                  if (rawEntryType == 'fieldnote') {
                    resolvedEntryType = JournalEntryType.fieldNote;
                  }
                  if (rawEntryType == 'pmn') {
                    resolvedEntryType = JournalEntryType.pmn;
                  }

                  final entry = JournalEntry(
                    id: data['id'],
                    body: data['body'],
                    date: _journalEntryDateFromDaily(
                      dateStr,
                      data['time']?.toString(),
                    ),
                    timeOfDay: data['time']?.toString(),
                    title: data['title']?.toString().isNotEmpty == true
                        ? data['title']
                        : data['time'],
                    moodSlug: data['mood'],
                    obsidianPath: relativePath,
                    entryType: resolvedEntryType,
                    category: data['category']?.toString(),
                    energyValue: (() {
                      final ev = data['energy_value'] is int
                          ? data['energy_value'] as int
                          : int.tryParse(data['energy_value']?.toString() ?? '');
                      // F3.15: Clamp energy value to 0-10 range
                      return ev?.clamp(0, 10);
                    })(),
                  );
                  if (data['organizers'] != null) {
                    entry.organizers = (data['organizers'] as List)
                        .map<OrganizerReference>(
                          (o) => o is OrganizerReference
                              ? o
                              : OrganizerReference.fromWikiLink(o.toString()),
                        )
                        .toList();
                  }
                  journalEntries.add(entry);
                  results.add(entry);
                }

                final habits = MarkdownParser.parseHabitCompletions(
                  frontmatter,
                );
                if (habits.isNotEmpty) {
                  dailyHabitCompletions[dateStr] = habits.entries
                      .map((e) => {'slug': e.key, 'value': e.value})
                      .toList();
                }

                final trackers = MarkdownParser.parseTrackerRecords(
                  frontmatter,
                );
                if (trackers.isNotEmpty) {
                  dailyTrackerRecords[dateStr] = trackers.entries
                      .map((e) => {'slug': e.key, 'values': e.value})
                      .toList();
                }

                final parsedDay = DateTime.tryParse(dateStr) ?? DateTime.now();
                final pomodorosData = MarkdownParser.parsePomodoros(body);
                for (final pom in pomodorosData) {
                  final timeStr = pom['time'] as String? ?? '00:00';
                  final title = pom['title'] as String? ?? 'Focus Session';
                  final hours = int.tryParse(timeStr.split(':').first) ?? 0;
                  final minutes = int.tryParse(timeStr.split(':').last) ?? 0;
                  final sessionDate = DateTime(
                    parsedDay.year,
                    parsedDay.month,
                    parsedDay.day,
                    hours,
                    minutes,
                  );

                  final blocks =
                      int.tryParse(pom['blocks']?.toString() ?? '') ?? 0;
                  final worked =
                      int.tryParse(pom['worked']?.toString() ?? '') ?? 0;
                  final breakTime =
                      int.tryParse(pom['break']?.toString() ?? '') ?? 0;
                  final linkedItem = pom['linked_item'] as String?;

                  final session = PomodoroSession(
                    id: 'pomodoro_${dateStr}_${timeStr.replaceAll(':', '_')}',
                    taskTitle: title,
                    date: sessionDate,
                    linkedItemSlug: linkedItem,
                    blocksCompleted: blocks,
                    minutesWorked: worked,
                    minutesBreak: breakTime,
                    state: PomodoroSessionState.completed,
                  );
                  results.add(session);
                }

                // Store in dailyMap for the O(1) provider
                dailyMap[dateStr] = {
                  'entries': journalEntries,
                  'habitCompletions': habits,
                  'habits': habits,
                  'trackerRecords': trackers,
                  'frontmatter': frontmatter,
                };
              }
            } else {
              // Normal content object
              final fallbackTitle = relativePath
                  .split('/')
                  .last
                  .replaceAll('.md', '');
              final stableId = relativePath
                  .replaceAll('/', '_')
                  .replaceAll('.md', '');
              ContentObject? obj;

              if (type == 'task' && !relativePath.startsWith('organizers/')) {
                obj = Task.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'shopping_list') {
                obj = shopping_list_model.ShoppingList.fromMarkdown(
                  frontmatter,
                  body,
                )..obsidianPath = relativePath;
              } else if (type == 'habit' &&
                  !relativePath.startsWith('organizers/')) {
                obj = Habit.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'project' ||
                  (type == 'organizer' &&
                      frontmatter['organizer_type'] == 'project')) {
                obj = Project.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'person' ||
                  (type == 'organizer' &&
                      frontmatter['organizer_type'] == 'person')) {
                obj = Person.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'organizer' ||
                  type == 'area' ||
                  type == 'activity' ||
                  type == 'place' ||
                  type == 'label' ||
                  type == 'day_theme' ||
                  type == 'time_block' ||
                  (type == 'task' && relativePath.startsWith('organizers/')) ||
                  (type == 'goal' && relativePath.startsWith('organizers/')) ||
                  (type == 'habit' && relativePath.startsWith('organizers/')) ||
                  (type == 'tracker' &&
                      relativePath.startsWith('organizers/'))) {
                if (frontmatter['organizer_type'] == null &&
                    type != 'organizer') {
                  if (type == 'day_theme') {
                    frontmatter['organizer_type'] = 'dayTheme';
                  } else if (type == 'time_block') {
                    frontmatter['organizer_type'] = 'timeBlock';
                  } else {
                    frontmatter['organizer_type'] = type;
                  }
                }
                
                // Map day_theme block_ids to organizers
                if (frontmatter['organizer_type'] == 'dayTheme' && frontmatter['block_ids'] != null) {
                  final blocks = frontmatter['block_ids'] as List;
                  final mapped = blocks.map((b) => '[[time_block/$b]]').toList();
                  final existing = frontmatter['organizers'] as List? ?? [];
                  frontmatter['organizers'] = [...existing, ...mapped];
                }
                obj = organizer_model.Organizer.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'resource') {
                obj = Resource.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'event') {
                obj = Event.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'social_post') {
                obj = SocialPost.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'goal' &&
                  !relativePath.startsWith('organizers/')) {
                obj = Goal.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'entry') {
                obj = JournalEntry.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'note') {
                obj = Note.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'idea') {
                obj = IdeaDefinition.fromMarkdown(
                  frontmatter,
                  body,
                  relativePath,
                );
              } else if (type == 'tracker_definition') {
                obj = TrackerDefinition.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'mood_definition') {
                obj = MoodDefinition.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'reminder') {
                obj = Reminder.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'tracker_record') {
                obj = TrackingRecord.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'combined_analysis') {
                obj = CombinedAnalysis.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'wellbeing_indicator') {
                obj = WellbeingIndicator.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'snapshot') {
                obj = Snapshot.fromMarkdown(frontmatter, body)
                  ..obsidianPath = relativePath;
              } else if (type == 'system') {
                obj = SystemDefinition.fromMarkdown(
                  frontmatter,
                  body,
                  relativePath,
                );
              } else if (type == 'template') {
                obj = TemplateDefinition.fromMap(
                  frontmatter,
                  stableId,
                  body: body,
                )..obsidianPath = relativePath;
              } else {
                obj = Note(
                  id: stableId,
                  title: frontmatter['title'] ?? fallbackTitle,
                  body: body,
                  subtype: NoteSubtype.text,
                  organizers: const [],
                )..obsidianPath = relativePath;
              }

              obj.loadBaseMap(frontmatter, fallbackId: stableId);
              obj.literalType = literalType;
              if (literalType != null && literalType != type) {
                obj.hasTypeConflict = true;
                obj.conflictReason =
                    'Tipo no frontmatter ("$literalType") diverge do tipo detectado pela assinatura ("$type").';
              }

              if (obj.title == 'Untitled' ||
                  obj.title.toLowerCase() == 'untitled' ||
                  obj.title.isEmpty) {
                obj.title = fallbackTitle;
              }
              results.add(obj);

              // If the YAML was repaired in memory, flag it for main thread rewriting
              if (frontmatter['__needs_rewrite__'] == true) {
                needsRewritePaths.add(relativePath);
              }
                        }
          } catch (e, st) {
            debugPrint('Error processing file ${file.path}: $e\n$st');
          }
        }),
      );
    }

    // Deduplicate by ID
    final uniqueResults = <String, ContentObject>{};
    for (final r in results) {
      uniqueResults[r.id] = r;
    }
    List<ContentObject> finalResults = uniqueResults.values.toList();

    // Post-process Habits and Trackers
    for (final habit in finalResults.whereType<Habit>()) {
      // Build a map of existing completions from habit's .md file to preserve them
      final existingCompletions = <String, CompletionRecord>{};
      for (final record in habit.completionHistory) {
        final dateStr = record.date.toIso8601String().split('T').first;
        existingCompletions[dateStr] = record;
      }

      // Clear history to avoid duplicates, then rebuild
      habit.completionHistory.clear();

      // First add existing completions that aren't in daily notes (historical data)
      final dailyNoteDates = dailyHabitCompletions.keys.toSet();
      for (final entry in existingCompletions.entries) {
        if (!dailyNoteDates.contains(entry.key)) {
          habit.completionHistory.add(entry.value);
        }
      }

      // Then add daily note completions (more authoritative for current state)
      dailyHabitCompletions.forEach((dateStr, completions) {
        final completion = completions.firstWhere(
          (c) => c['slug'] == habit.slug,
          orElse: () => {},
        );
        if (completion.isNotEmpty) {
          final val = completion['value'];
          bool successful = false;
          int count = 0;
          List<bool>? slotCompletions;

          if (val is bool) {
            successful = val;
            count = val ? habit.dailyGoal : 0;
            slotCompletions = List.filled(habit.dailyGoal, val);
          } else if (val is num) {
            count = val.toInt();
            successful = count >= habit.dailyGoal;
            slotCompletions = List.generate(habit.dailyGoal, (i) => i < count);
          } else if (val is List) {
            slotCompletions = val.map((v) => v == true).toList();
            count = slotCompletions.where((v) => v).length;
            successful = count >= habit.dailyGoal;
          }

          habit.completionHistory.add(
            CompletionRecord(
              date: DateTime.parse(dateStr),
              completions: count,
              slotCompletions: slotCompletions,
              successful: successful,
            ),
          );
        }
      });
      habit.completionHistory.sort((a, b) => a.date.compareTo(b.date));
    }

    final List<TrackingRecord> newRecords = [];
    for (final dateStr in dailyTrackerRecords.keys) {
      for (final recordData in dailyTrackerRecords[dateStr]!) {
        final trackerSlug = recordData['slug'];
        final values = Map<String, dynamic>.from(recordData['values'] as Map);
        newRecords.add(
          TrackingRecord(
            title: 'Record from $dateStr',
            trackerId: trackerSlug,
            date: DateTime.parse(dateStr),
            fieldValues: values,
          )..obsidianPath = 'daily/$dateStr.md',
        );
      }
    }

    finalResults.addAll(newRecords);

    // Final deduplication just in case
    final Map<String, ContentObject> deduplicated = {};
    for (final obj in finalResults) {
      if (obj.id.isNotEmpty) {
        deduplicated[obj.id] = obj;
      }
    }
    final objects = deduplicated.values.toList()
      ..sort((a, b) {
        final updated = b.updatedAt.compareTo(a.updatedAt);
        if (updated != 0) return updated;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    return ParsedVaultResult(
      objects: objects,
      dailyMap: dailyMap,
      needsRewritePaths: needsRewritePaths,
    );
  });
}

// ── Private Helper Functions ──

DateTime _journalEntryDateFromDaily(String dateStr, String? time) {
  final base = DateTime.tryParse(dateStr) ?? DateTime.now();
  final timeParts = (time ?? '').split(':');
  final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
  final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;

  return DateTime(base.year, base.month, base.day, hour, minute);
}

bool _isDailyNoteIsolate(
  String relativePath,
  Map<String, dynamic> frontmatter,
  VaultIsolateParams params,
) {
  final normalizedPath = relativePath.replaceAll('\\', '/');
  final fileName = normalizedPath.split('/').last;
  final folder = params.dailyNoteFolder
      .trim()
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'^/+|/+$'), '');

  switch (params.dailyNoteIdentifier) {
    case 'folder':
      return folder.isNotEmpty &&
          (normalizedPath == '$folder/$fileName' ||
              normalizedPath.startsWith('$folder/'));
    case 'frontmatter_type':
      return frontmatter['type']?.toString() == 'daily_note';
    case 'filename_format':
    default:
      final pattern = params.dailyNoteDateFormat == 'yy-MM-dd'
          ? RegExp(r'^\d{2}-\d{2}-\d{2}\.md$')
          : RegExp(r'^\d{4}-\d{2}-\d{2}\.md$');
      return pattern.hasMatch(fileName);
  }
}

String _normalizeDailyDate(String raw) {
  if (RegExp(r'^\d{2}-\d{2}-\d{2}$').hasMatch(raw)) {
    return '20$raw';
  }
  return raw;
}
