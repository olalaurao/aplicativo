// lib/services/day_dial_aggregator.dart
import '../models/day_dial_model.dart';
import '../models/task_model.dart';
import '../models/habit_model.dart';
import '../models/pomodoro_session.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;

/// Aggregates data from multiple sources to produce a per-hour summary for the day dial
class DayDialAggregator {
  /// Produces exactly 24 DayDialHourState entries for a given date
  static List<DayDialHourState> aggregateForDate({
    required DateTime date,
    required List<Task> tasks,
    required List<Habit> habits,
    required List<PomodoroSession> pomodoroSessions,
    required List<google_calendar.Event> googleEvents,
  }) {
    // Initialize 24 hours with idle state
    final hourStates = List.generate(
      24,
      (hour) => DayDialHourState.idle(hour),
    );

    // Process completed Pomodoro sessions
    for (final session in pomodoroSessions) {
      if (!_isSameDay(session.date, date)) continue;
      if (session.state != PomodoroSessionState.completed) continue;

      final effectiveDate = session.occurredAt ?? session.date;
      final startHour = effectiveDate.hour;
      final startMinute = effectiveDate.minute;
      
      // Calculate fill fraction based on minutes worked
      final fillFraction = (session.minutesWorked / 60.0).clamp(0.0, 1.0);
      
      // Update the hour state
      if (startHour >= 0 && startHour < 24) {
        hourStates[startHour] = hourStates[startHour].copyWith(
          kind: DialHourKind.pomodoroCompleted,
          fillFraction: fillFraction,
        );
      }
    }

    // Process planned tasks (scheduled but no completed Pomodoro session yet)
    for (final task in tasks) {
      if (task.scheduledTime == null) continue;
      if (task.stage == TaskStage.finalized) continue;
      
      final scheduledDateTime = _parseScheduledTime(task.scheduledTime!, date);
      if (scheduledDateTime == null) continue;
      
      if (!_isSameDay(scheduledDateTime, date)) continue;
      
      // Check if this task has a completed Pomodoro session for this date
      final hasCompletedSession = pomodoroSessions.any((session) =>
        session.linkedItemSlug == task.slug &&
        _isSameDay(session.date, date) &&
        session.state == PomodoroSessionState.completed
      );
      
      if (hasCompletedSession) continue; // Skip if already has completed session
      
      final startHour = scheduledDateTime.hour;
      final duration = task.estimatedMinutes ?? task.duration;
      final fillFraction = (duration / 60.0).clamp(0.0, 1.0);
      
      if (startHour >= 0 && startHour < 24) {
        hourStates[startHour] = hourStates[startHour].copyWith(
          kind: DialHourKind.pomodoroPlanned,
          fillFraction: fillFraction,
        );
      }
    }

    // Process Google Calendar events
    for (final event in googleEvents) {
      final start = event.start?.dateTime ?? event.start?.date;
      final end = event.end?.dateTime ?? event.end?.date;
      if (start == null || end == null) continue;

      final isAllDay = event.start?.date != null;
      if (isAllDay) continue;

      final startTime = start.toLocal();
      final endTime = end.toLocal();

      if (!_isSameDay(startTime, date)) continue;

      final startHour = startTime.hour;
      final duration = endTime.difference(startTime).inMinutes;
      final fillFraction = (duration / 60.0).clamp(0.0, 1.0);

      if (startHour >= 0 && startHour < 24) {
        hourStates[startHour] = hourStates[startHour].copyWith(
          kind: DialHourKind.event,
          fillFraction: fillFraction,
        );
      }
    }

    // Process habits with fixed scheduled times
    for (final habit in habits) {
      for (int slotIndex = 0; slotIndex < habit.slots.length; slotIndex++) {
        final slot = habit.slots[slotIndex];
        if (!slot.hasReminders) continue;
        
        final reminderTime = slot.primaryReminderTime;
        if (reminderTime == null) continue;
        
        final startHour = reminderTime.hour;
        
        if (startHour >= 0 && startHour < 24) {
          // Habit icon is independent of the kind fill - they can coexist
          hourStates[startHour] = hourStates[startHour].copyWith(
            habitIconName: habit.icon,
            habitId: habit.id,
          );
        }
      }
    }

    return hourStates;
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
