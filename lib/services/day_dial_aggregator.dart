// lib/services/day_dial_aggregator.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/day_dial_model.dart';
import '../models/task_model.dart';
import '../models/habit_model.dart';
import '../models/pomodoro_session.dart';
import '../models/reminder_model.dart';
import '../models/organizer_model.dart';
import '../models/mood_model.dart';
import '../models/journal_entry.dart';
import '../models/event_model.dart';
import '../models/shared_types.dart';
import '../ui/utils/object_icons.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;

/// Aggregates data from multiple sources to produce a DayDialSnapshot
class DayDialAggregator {
  static DayDialSnapshot aggregateForDate({
    required DateTime date,
    required List<Task> tasks,
    required List<Habit> habits,
    required List<PomodoroSession> pomodoroSessions,
    required List<google_calendar.Event> googleEvents,
    required List<Event> localEvents,
    required List<Reminder> reminders,
    required List<Organizer> timeBlocks,
    required List<JournalEntry> journalEntries,
    required List<MoodDefinition> moodCatalog,
    Map<String, TypeSignature> typeSignatures = const {},
  }) {
    final segments = <DialSegment>[];

    // Pomodoro Completed
    for (final session in pomodoroSessions) {
      if (session.state == PomodoroSessionState.completed) {
        final effectiveDate = session.occurredAt ?? session.date;
        if (_isSameDay(effectiveDate, date)) {
          segments.add(DialSegment(
            id: 'pomodoroCompleted:${session.id}',
            kind: DialSegmentKind.pomodoroCompleted,
            start: effectiveDate,
            end: effectiveDate.add(Duration(minutes: session.minutesWorked)),
            title: session.title,
            colorHex: '#34C759', // AppColors.success
            isEditable: false,
            isResizable: false,
            sourceSlug: session.linkedItemSlug,
          ));
        }
      }
    }

    // Pomodoro Planned
    for (final session in pomodoroSessions) {
      if (session.state != PomodoroSessionState.completed) {
        if (_isSameDay(session.date, date)) {
          // De-dup
          final hasCompleted = pomodoroSessions.any((s) =>
              s.state == PomodoroSessionState.completed &&
              s.linkedItemSlug == session.linkedItemSlug &&
              _isSameDay(s.occurredAt ?? s.date, date));
          if (hasCompleted) continue;

          segments.add(DialSegment(
            id: 'pomodoroPlanned:${session.id}',
            kind: DialSegmentKind.pomodoroPlanned,
            start: session.date,
            end: session.date.add(Duration(minutes: session.workDuration)),
            title: session.title,
            colorHex: '#A69BD1',
            isEditable: true,
            isResizable: true,
            sourceSlug: session.linkedItemSlug,
          ));
        }
      }
    }

    // Planned Tasks
    for (final task in tasks) {
      if (task.scheduledTime == null) continue;
      if (task.stage == TaskStage.finalized) continue;

      final start = _parseScheduledTime(task.scheduledTime!, date);
      if (start == null) continue;
      if (!_isSameDay(start, date)) continue;

      // De-dup
      final hasSession = pomodoroSessions.any((s) =>
          s.linkedItemSlug == task.slug &&
          _isSameDay(s.occurredAt ?? s.date, date));
      if (hasSession) continue;

      final duration = task.duration;
      segments.add(DialSegment(
        id: 'taskPlanned:${task.id}',
        kind: DialSegmentKind.taskPlanned,
        start: start,
        end: start.add(Duration(minutes: duration)),
        title: task.title,
        colorHex: task.color ?? '#6B5EA8',
        isEditable: true,
        isResizable: true,
        sourceSlug: task.slug,
      ));
    }

    // Local Events
    for (final event in localEvents) {
      final start = event.startDatetime;
      if (start == null) continue;
      if (!_isSameDay(start, date)) continue;

      final end = event.endDatetime ?? start.add(const Duration(minutes: 30));
      segments.add(DialSegment(
        id: 'eventLocal:${event.id}',
        kind: DialSegmentKind.event,
        start: start,
        end: end,
        title: event.title,
        colorHex: '#007AFF', // AppColors.info
        emoji: ObjectIcons.emojiForTypeWithSignatures(ObjectTypes.event, typeSignatures),
        isEditable: true,
        isResizable: true,
        sourceSlug: event.slug,
      ));
    }

    // Google Events
    for (final event in googleEvents) {
      final start = event.start?.dateTime;
      final end = event.end?.dateTime;
      if (start == null || end == null) continue;
      
      final startTime = start.toLocal();
      final endTime = end.toLocal();

      if (!_isSameDay(startTime, date)) continue;

      segments.add(DialSegment(
        id: 'eventGoogle:${event.id}',
        kind: DialSegmentKind.event,
        start: startTime,
        end: endTime,
        title: event.summary ?? 'Busy',
        colorHex: '#007AFF',
        isEditable: false,
        isResizable: false,
      ));
    }

    // Time Blocks (Organizer)
    for (final block in timeBlocks) {
      if (block.organizerType != OrganizerType.timeBlock) continue;
      for (final range in block.timeRanges) {
        final start = DateTime(date.year, date.month, date.day, range.startHour, range.startMinute);
        var end = DateTime(date.year, date.month, date.day, range.endHour, range.endMinute);
        if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
           end = end.add(const Duration(days: 1)); // midnight spanning
        }
        segments.add(DialSegment(
          id: 'timeBlock:${block.id}:${range.hashCode}',
          kind: DialSegmentKind.timeBlock,
          start: start,
          end: end,
          title: block.title,
          colorHex: block.color ?? '#8E8E93',
          isEditable: false,
          isResizable: false,
          layer: -1,
          sourceSlug: block.slug,
        ));
      }
    }

    // Habit Slots
    for (final habit in habits) {
      for (int i = 0; i < habit.slots.length; i++) {
        final slot = habit.slots[i];
        if (!slot.hasReminders || slot.primaryReminderTime == null) continue;
        final time = slot.primaryReminderTime!;
        final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        segments.add(DialSegment(
          id: 'habitSlot:${habit.id}:$i',
          kind: DialSegmentKind.habitSlot,
          start: start,
          end: start.add(const Duration(minutes: 12)),
          title: habit.title,
          colorHex: habit.color ?? '#FF9500',
          emoji: habit.icon ?? ObjectIcons.emojiForTypeWithSignatures(ObjectTypes.habit, typeSignatures),
          isEditable: true,
          isResizable: false,
          sourceSlug: habit.slug,
        ));
      }
    }

    // Reminders
    for (final reminder in reminders) {
      if (reminder.isCompleted || reminder.habitReminder) continue;
      if (!_isSameDay(reminder.time, date)) continue;

      segments.add(DialSegment(
        id: 'reminder:${reminder.id}',
        kind: DialSegmentKind.reminder,
        start: reminder.time,
        end: reminder.time.add(const Duration(minutes: 12)),
        title: reminder.title,
        colorHex: '#FFCC00',
        emoji: ObjectIcons.emojiForTypeWithSignatures(ObjectTypes.reminder, typeSignatures),
        isEditable: true,
        isResizable: false,
        sourceSlug: reminder.id,
      ));
    }

    _assignLayers(segments);

    // Sort segments chronologically by start time
    segments.sort((a, b) => a.start.compareTo(b.start));

    final moodMarkers = _buildMoodMarkers(journalEntries, moodCatalog, date);
    final next = _findNextUpcoming(segments, date);

    return DayDialSnapshot(
      date: date,
      segments: segments,
      moodMarkers: moodMarkers,
      maxLayer: segments.isEmpty ? 0 : segments.map((s) => s.layer).reduce(max),
      nextUpcoming: next,
    );
  }

  static void _assignLayers(List<DialSegment> segments) {
    final pointInTime = segments.where((s) => s.kind == DialSegmentKind.habitSlot || s.kind == DialSegmentKind.reminder).toList();
    final durationSegments = segments.where((s) => 
        s.kind != DialSegmentKind.timeBlock && 
        s.kind != DialSegmentKind.habitSlot && 
        s.kind != DialSegmentKind.reminder).toList();

    durationSegments.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      final durA = a.end.difference(a.start);
      final durB = b.end.difference(b.start);
      return durB.compareTo(durA);
    });

    final layerEndTimes = <DateTime>[];

    for (final s in durationSegments) {
      bool placed = false;
      for (int i = 0; i < layerEndTimes.length; i++) {
        if (s.start.isAfter(layerEndTimes[i]) || s.start.isAtSameMomentAs(layerEndTimes[i])) {
          s.layer = i;
          layerEndTimes[i] = s.end;
          placed = true;
          break;
        }
      }
      if (!placed) {
        s.layer = layerEndTimes.length;
        layerEndTimes.add(s.end);
      }
    }

    pointInTime.sort((a, b) => a.start.compareTo(b.start));
    for (final s in pointInTime) {
      bool placed = false;
      for (int i = 0; i < layerEndTimes.length; i++) {
        if (s.start.isAfter(layerEndTimes[i]) || s.start.isAtSameMomentAs(layerEndTimes[i])) {
          s.layer = i;
          layerEndTimes[i] = s.end;
          placed = true;
          break;
        }
      }
      if (!placed) {
        s.layer = layerEndTimes.length;
        layerEndTimes.add(s.end);
      }
    }

    for (final s in segments) {
      if (s.layer >= 4) {
        s.layer = 3;
      }
    }
  }

  static List<DialPointMarker> _buildMoodMarkers(
    List<JournalEntry> entries,
    List<MoodDefinition> catalog,
    DateTime date,
  ) {
    final markers = <DialPointMarker>[];
    final allDefs = [...MoodDefinition.systemMoods, ...catalog];
    for (final entry in entries) {
      if (!_isSameDay(entry.date, date)) continue;
      for (final moodEntry in entry.moodEntries) {
        if (!_isSameDay(moodEntry.timestamp, date)) continue;
        final def = allDefs.firstWhere(
          (d) => d.id == moodEntry.moodSlug,
          orElse: () => allDefs.first,
        );
        markers.add(DialPointMarker(
          id: '${entry.slug}:${moodEntry.timestamp.toIso8601String()}',
          timestamp: moodEntry.timestamp,
          emoji: def.emoji,
          label: def.label,
          sourceSlug: entry.slug,
        ));
      }
    }
    return markers;
  }

  static DialSegment? _findNextUpcoming(List<DialSegment> segments, DateTime date) {
    final now = DateTime.now();
    if (!_isSameDay(now, date)) return null;
    
    final upcoming = segments.where((s) => s.start.isAfter(now) && s.kind != DialSegmentKind.timeBlock).toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.start.compareTo(b.start));
    return upcoming.first;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime? _parseScheduledTime(String timeStr, DateTime date) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
