// lib/models/journal_entry.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'reminder_config.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'alignment_log_entry.dart';

enum JournalEntryType { standard, fieldNote, pmn }

class JournalEntry extends ContentObject {
  String body;
  DateTime date;
  String? timeOfDay;
  String? moodSlug; // Reference to MoodDefinition.id
  List<AlignmentLogEntry> alignmentLogEntries; // RA-P1-2: Alignment tracking logs
  List<String> photos;
  String? location;
  String? templateId;
  List<Comment> comments;
  Map<String, dynamic>? weather;

  JournalEntryType entryType;
  String? feelings;

  // field_note specific
  String? category;
  int? energyValue;
  String? text;

  // pmn specific
  String? week;
  DateTime? dateRangeStart;
  DateTime? dateRangeEnd;
  List<DateTime> referencedDates;
  List<String> pactRefs;
  List<String> plus;
  List<String> minus;
  List<String> next;

  JournalEntry({
    super.id,
    String? title,
    required this.body,
    required this.date,
    this.timeOfDay,
    this.moodSlug,
    this.alignmentLogEntries = const [],
    this.photos = const [],
    this.location,
    this.templateId,
    this.comments = const [],
    this.weather,
    this.entryType = JournalEntryType.standard,
    this.feelings,
    this.category,
    this.energyValue,
    this.text,
    this.week,
    this.dateRangeStart,
    this.dateRangeEnd,
    this.referencedDates = const [],
    this.pactRefs = const [],
    this.plus = const [],
    this.minus = const [],
    this.next = const [],
    super.organizers,
    super.categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.obsidianPath,
  }) : super(
         title: title ?? '',
         createdAt: createdAt ?? date,
         updatedAt: updatedAt ?? createdAt ?? date,
       );

  static String entryTypeToString(JournalEntryType t) => switch (t) {
    JournalEntryType.standard => 'standard',
    JournalEntryType.fieldNote => 'field_note',
    JournalEntryType.pmn => 'pmn',
  };

  static int isoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    final weekday = date.weekday;
    return ((dayOfYear - weekday + 10) / 7).floor();
  }

  static String pmnIdFromDate(DateTime startDate) {
    final weekNumber = isoWeekNumber(startDate);
    return 'pmn-${startDate.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  @override
  String get type => 'entry';

  @override
  bool get isIncomplete {
    if (entryType == JournalEntryType.fieldNote) {
      return category == null || category!.trim().isEmpty || text == null || text!.trim().isEmpty;
    }
    if (entryType == JournalEntryType.pmn) {
      return week == null || week!.trim().isEmpty || dateRangeStart == null || dateRangeEnd == null;
    }
    return false;
  }

  @override
  DateTime? get baseTime => date;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['date'] =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final resolvedTime =
        timeOfDay ??
        ((date.hour != 0 || date.minute != 0)
            ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
            : null);
    if (resolvedTime != null) frontmatter['time_of_day'] = resolvedTime;
    if (location != null) frontmatter['location'] = location;
    if (templateId != null) frontmatter['template_id'] = templateId;
    if (photos.isNotEmpty) frontmatter['photos'] = photos;
    if (feelings != null) frontmatter['feelings'] = feelings;

    frontmatter['entry_type'] = entryTypeToString(entryType);

    if (entryType == JournalEntryType.fieldNote) {
      if (category != null) frontmatter['category'] = category;
      if (energyValue != null) frontmatter['energy_value'] = energyValue;
      if (text != null) frontmatter['text'] = text;
    } else if (entryType == JournalEntryType.pmn) {
      if (week != null) frontmatter['week'] = week;
      if (dateRangeStart != null) {
        frontmatter['date_range_start'] = dateRangeStart
            ?.toIso8601String()
            .split('T')
            .first;
      }
      if (dateRangeEnd != null) {
        frontmatter['date_range_end'] = dateRangeEnd
            ?.toIso8601String()
            .split('T')
            .first;
      }

      final Set<String> refDatesStr = {};
      if (referencedDates.isNotEmpty) {
        refDatesStr.addAll(
          referencedDates.map((d) => d.toIso8601String().split('T').first),
        );
      }
      if (dateRangeStart != null && dateRangeEnd != null) {
        var curr = dateRangeStart!;
        final end = dateRangeEnd!;
        while (curr.isBefore(end) || curr.isAtSameMomentAs(end)) {
          refDatesStr.add(curr.toIso8601String().split('T').first);
          curr = curr.add(const Duration(days: 1));
        }
      }
      if (refDatesStr.isNotEmpty) {
        frontmatter['referenced_dates'] = refDatesStr.toList()..sort();
      }

      if (pactRefs.isNotEmpty) frontmatter['pact_refs'] = pactRefs;
    }

    String finalBody = body;
    if (entryType == JournalEntryType.pmn) {
      final buffer = StringBuffer();
      if (plus.isNotEmpty) {
        buffer.writeln('## Plus');
        for (var item in plus) {
          buffer.writeln('- $item');
        }
        buffer.writeln();
      }
      if (minus.isNotEmpty) {
        buffer.writeln('## Minus');
        for (var item in minus) {
          buffer.writeln('- $item');
        }
        buffer.writeln();
      }
      if (next.isNotEmpty) {
        buffer.writeln('## Next');
        for (var item in next) {
          buffer.writeln('- $item');
        }
        buffer.writeln();
      }
      finalBody = buffer.toString().trim();
    }

    if (moodSlug != null) {
      finalBody = '${finalBody.trimRight()}\n\nmood:: [[$moodSlug]]';
    }

    // RA-P1-2: Serialize alignment_log_entries array
    if (alignmentLogEntries.isNotEmpty) {
      frontmatter['alignment_log_entries'] = alignmentLogEntries.map((e) => e.toMap()).toList();
    }

    return generateMarkdown(
      frontmatter,
      normalizeRichTextBodyForMarkdown(finalBody),
    );
  }

  factory JournalEntry.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final rawDate = frontmatter['date']?.toString() ?? '';
    var parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    final rawTime =
        frontmatter['time_of_day']?.toString() ??
        frontmatter['timeOfDay']?.toString() ??
        frontmatter['time']?.toString() ??
        '';
    if (rawTime.isNotEmpty) {
      final parts = rawTime.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        parsedDate = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
          hour,
          minute,
        );
      }
    }
    if (rawDate.isNotEmpty && DateTime.tryParse(rawDate) == null) {
      debugPrint('Invalid journal entry date in frontmatter: $rawDate');
    }

    final entryTypeStr = frontmatter['entry_type']
        ?.toString()
        .replaceAll('_', '')
        .toLowerCase();
    JournalEntryType type = JournalEntryType.standard;
    if (entryTypeStr == 'fieldnote') type = JournalEntryType.fieldNote;
    if (entryTypeStr == 'pmn') type = JournalEntryType.pmn;

    final entry = JournalEntry(
      title: frontmatter['title'] as String?,
      body: body,
      date: parsedDate,
      timeOfDay: rawTime.isEmpty ? null : rawTime,
      entryType: type,
    );
    entry.loadBaseMap(frontmatter);

    if (type == JournalEntryType.pmn && frontmatter['id'] == null) {
      final startStr = frontmatter['date_range_start']?.toString();
      final startDate = startStr != null ? DateTime.tryParse(startStr) : null;
      if (startDate != null) {
        entry.id = pmnIdFromDate(startDate);
      } else {
        final weekStr = frontmatter['week']?.toString() ?? '';
        final weekNum =
            int.tryParse(weekStr) ??
            int.tryParse(
              RegExp(r'W(\d{2})').firstMatch(weekStr)?.group(1) ?? '',
            );
        final year = entry.date.year;
        if (weekNum != null) {
          entry.id = 'pmn-$year-W${weekNum.toString().padLeft(2, '0')}';
        }
      }
    }

    final moodLineMatch = RegExp(
      r'^mood::\s*(.*)$',
      multiLine: true,
    ).firstMatch(body);
    if (moodLineMatch != null) {
      final val = moodLineMatch.group(1)!;
      final wikiMatch = RegExp(
        r'\[\[(.*?)\]\]',
      ).allMatches(val).map((m) => m.group(1)!).toList();
      entry.moodSlug = wikiMatch.isEmpty ? null : wikiMatch.join(', ');
    } else {
      entry.moodSlug = frontmatter['mood']?.toString();
    }

    // RA-P1-2: Parse alignment_log_entries array
    final alignmentLogData = frontmatter['alignment_log_entries'];
    if (alignmentLogData is List) {
      entry.alignmentLogEntries = alignmentLogData
          .map((e) => AlignmentLogEntry.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    entry.feelings = frontmatter['feelings'] as String?;
    entry.location = frontmatter['location'] as String?;
    entry.templateId = frontmatter['template_id'] as String?;
    final rawPhotos = frontmatter['photos'];
    if (rawPhotos is List) {
      entry.photos = rawPhotos.map((item) => item.toString()).toList();
    } else if (rawPhotos is String && rawPhotos.trim().isNotEmpty) {
      entry.photos = [rawPhotos.trim()];
    }

    if (type == JournalEntryType.fieldNote) {
      entry.category = frontmatter['category']?.toString();
      final ev = frontmatter['energy_value'];
      if (ev != null) {
        final parsed = ev is int ? ev : int.tryParse(ev.toString());
        // F3.15: Clamp energy value to 0-10 range
        entry.energyValue = parsed?.clamp(0, 10);
      }
      entry.text = frontmatter['text']?.toString();
    } else if (type == JournalEntryType.pmn) {
      entry.week = frontmatter['week']?.toString();
      final start = frontmatter['date_range_start']?.toString();
      if (start != null) entry.dateRangeStart = DateTime.tryParse(start);
      final end = frontmatter['date_range_end']?.toString();
      if (end != null) entry.dateRangeEnd = DateTime.tryParse(end);

      final refDates = frontmatter['referenced_dates'];
      if (refDates is List) {
        entry.referencedDates = refDates
            .map((d) => DateTime.tryParse(d.toString()))
            .whereType<DateTime>()
            .toList();
      }

      final pRefs = frontmatter['pact_refs'];
      if (pRefs is List) {
        entry.pactRefs = pRefs.map((r) => r.toString()).toList();
      }

      // Parse lists from body
      entry.plus = _extractListFromBody(body, 'Plus');
      entry.minus = _extractListFromBody(body, 'Minus');
      entry.next = _extractListFromBody(body, 'Next');
    }

    return entry;
  }

  static List<String> _extractListFromBody(String body, String section) {
    final list = <String>[];
    final sections = body.split(RegExp('^## ', multiLine: true));
    for (var s in sections) {
      if (s.trimLeft().startsWith(section)) {
        final lines = s.split('\n').skip(1);
        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('- ')) {
            list.add(trimmed.substring(2).trim());
          }
        }
        break;
      }
    }
    return list;
  }

  JournalEntry copyWith({
    String? id,
    String? body,
    DateTime? date,
    String? timeOfDay,
    String? moodSlug,
    List<AlignmentLogEntry>? alignmentLogEntries,
    List<String>? photos,
    String? location,
    String? templateId,
    List<Comment>? comments,
    Map<String, dynamic>? weather,
    String? title,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<ReminderConfig>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    JournalEntryType? entryType,
    String? feelings,
    String? category,
    int? energyValue,
    String? text,
    String? week,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    List<DateTime>? referencedDates,
    List<String>? pactRefs,
    List<String>? plus,
    List<String>? minus,
    List<String>? next,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      date: date ?? this.date,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      moodSlug: moodSlug ?? this.moodSlug,
      alignmentLogEntries: alignmentLogEntries ?? this.alignmentLogEntries,
      photos: photos ?? this.photos,
      location: location ?? this.location,
      templateId: templateId ?? this.templateId,
      comments: comments ?? this.comments,
      weather: weather ?? this.weather,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
      entryType: entryType ?? this.entryType,
      feelings: feelings ?? this.feelings,
      category: category ?? this.category,
      energyValue: energyValue ?? this.energyValue,
      text: text ?? this.text,
      week: week ?? this.week,
      dateRangeStart: dateRangeStart ?? this.dateRangeStart,
      dateRangeEnd: dateRangeEnd ?? this.dateRangeEnd,
      referencedDates: referencedDates ?? this.referencedDates,
      pactRefs: pactRefs ?? this.pactRefs,
      plus: plus ?? this.plus,
      minus: minus ?? this.minus,
      next: next ?? this.next,
    )..reminders = reminders ?? this.reminders;
  }
}
