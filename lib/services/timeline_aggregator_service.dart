// lib/services/timeline_aggregator_service.dart
import '../models/content_object.dart';
import '../models/task_model.dart';
import '../models/journal_entry.dart';
import '../models/habit_model.dart';
import '../models/goal_model.dart';
import '../models/note_model.dart';
import '../models/pillar_model.dart';
import '../models/action_menu_item_model.dart';

enum TodayItemOrigin {
  created,  // 🕐
  edited,   // ✏️
  scheduled, // 📅
  happened,  // ⚡
}

enum TodayItemKind {
  task,
  habit,
  journalEntry,
  goal,
  note,
  pillar,
  action,
  other,
}

class TodayItem {
  final String id;
  final String title;
  final DateTime date;
  final TodayItemOrigin origin;
  final TodayItemKind kind;
  final String? objectId;  // reference to actual object
  final String? subtitle;

  TodayItem({
    required this.id,
    required this.title,
    required this.date,
    required this.origin,
    required this.kind,
    this.objectId,
    this.subtitle,
  });

  String get originGlyph {
    return switch (origin) {
      TodayItemOrigin.created => '🕐',
      TodayItemOrigin.edited => '✏️',
      TodayItemOrigin.scheduled => '📅',
      TodayItemOrigin.happened => '⚡',
    };
  }
}

class TimelineWindow {
  final DateTime start;
  final DateTime end;

  TimelineWindow({required this.start, required this.end});

  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }

  static TimelineWindow today() {
    final now = DateTime.now();
    return TimelineWindow(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static TimelineWindow week() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    return TimelineWindow(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static TimelineWindow month() {
    final now = DateTime.now();
    return TimelineWindow(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }
}

class TimelineAggregatorService {
  /// Build timeline items from a list of content objects within a window
  static List<TodayItem> buildTimeline(
    List<ContentObject> objects,
    TimelineWindow window, {
    String? filterByMood,
    bool filterByPhoto = false,
    DateTime? filterByDate,
    String? searchQuery,
  }) {
    final items = <TodayItem>[];

    for (final obj in objects) {
      // Apply mood filter for journal entries
      if (filterByMood != null && obj is JournalEntry) {
        if (!_entryMatchesMood(obj, filterByMood)) continue;
      }

      // Apply photo filter for journal entries
      if (filterByPhoto && obj is JournalEntry) {
        if (!obj.body.contains('![[')) continue;
      }

      // Apply date filter
      if (filterByDate != null) {
        if (obj is JournalEntry) {
          if (!_isSameDay(obj.date, filterByDate)) continue;
        }
      }

      // Apply search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final titleMatch = obj.title.toLowerCase().contains(query);
        bool bodyMatch = false;
        
        if (obj is JournalEntry) {
          final bodyText = _getPlainTextFromBody(obj.body).toLowerCase();
          bodyMatch = bodyText.contains(query);
        }
        
        if (!titleMatch && !bodyMatch) continue;
      }

      // Created event
      if (obj.createdAt != null && window.contains(obj.createdAt!)) {
        items.add(TodayItem(
          id: '${obj.id}_created',
          title: obj.title,
          date: obj.createdAt!,
          origin: TodayItemOrigin.created,
          kind: _kindForObject(obj),
          objectId: obj.id,
        ));
      }

      // Edited event
      if (obj.updatedAt != null && 
          obj.updatedAt != obj.createdAt &&
          window.contains(obj.updatedAt!)) {
        items.add(TodayItem(
          id: '${obj.id}_edited',
          title: obj.title,
          date: obj.updatedAt!,
          origin: TodayItemOrigin.edited,
          kind: _kindForObject(obj),
          objectId: obj.id,
        ));
      }

      // Type-specific events
      if (obj is Task && obj.scheduledDate != null) {
        final scheduledDate = DateTime.parse(obj.scheduledDate!);
        if (window.contains(scheduledDate)) {
          items.add(TodayItem(
            id: '${obj.id}_scheduled',
            title: obj.title,
            date: scheduledDate,
            origin: TodayItemOrigin.scheduled,
            kind: TodayItemKind.task,
            objectId: obj.id,
            subtitle: 'Scheduled',
          ));
        }
      }

      if (obj is JournalEntry && window.contains(obj.date)) {
        items.add(TodayItem(
          id: '${obj.id}_happened',
          title: obj.title.isNotEmpty ? obj.title : 'Journal Entry',
          date: obj.date,
          origin: TodayItemOrigin.happened,
          kind: TodayItemKind.journalEntry,
          objectId: obj.id,
          subtitle: obj.body.isNotEmpty ? obj.body.substring(0, 50) : null,
        ));
      }

      if (obj is Habit) {
        for (final completion in obj.completionHistory) {
          // Apply date filter for habit completions
          if (filterByDate != null) {
            if (!_isSameDay(completion.date, filterByDate)) continue;
          }
          
          if (window.contains(completion.date)) {
            items.add(TodayItem(
              id: '${obj.id}_${completion.date.toIso8601String()}',
              title: obj.title,
              date: completion.date,
              origin: TodayItemOrigin.happened,
              kind: TodayItemKind.habit,
              objectId: obj.id,
              subtitle: 'Completed (${completion.completions}/${obj.dailyGoal})',
            ));
          }
        }
      }

      if (obj is Pillar) {
        for (final touch in obj.touchLog) {
          // Apply date filter for pillar touches
          if (filterByDate != null) {
            if (!_isSameDay(touch.date, filterByDate)) continue;
          }
          
          if (window.contains(touch.date)) {
            items.add(TodayItem(
              id: '${obj.id}_${touch.date.toIso8601String()}',
              title: obj.title,
              date: touch.date,
              origin: TodayItemOrigin.happened,
              kind: TodayItemKind.pillar,
              objectId: obj.id,
              subtitle: touch.note,
            ));
          }
        }
      }
    }

    // Sort by date descending
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _entryMatchesMood(JournalEntry entry, String moodId) {
    // Simple implementation - check if entry has mood matching the filter
    // This would need to be expanded based on actual mood matching logic
    return entry.moodSlug == moodId;
  }

  static String _getPlainTextFromBody(String body) {
    // Simple implementation - strip markdown
    return body.replaceAll(RegExp(r'!\[\[.*?\]\]'), '') // remove images
               .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // remove links
               .replaceAll(RegExp(r'[#*_`~]'), '') // remove markdown chars
               .trim();
  }

  static TodayItemKind _kindForObject(ContentObject obj) {
    if (obj is Task) return TodayItemKind.task;
    if (obj is Habit) return TodayItemKind.habit;
    if (obj is JournalEntry) return TodayItemKind.journalEntry;
    if (obj is Goal) return TodayItemKind.goal;
    if (obj is Note) return TodayItemKind.note;
    if (obj is Pillar) return TodayItemKind.pillar;
    if (obj is ActionMenuItem) return TodayItemKind.action;
    return TodayItemKind.other;
  }
}
