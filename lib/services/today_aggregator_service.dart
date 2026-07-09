import 'package:flutter/material.dart';
import '../models/content_object.dart';
import '../models/journal_entry.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';
import '../models/habit_model.dart';
import '../models/pomodoro_session.dart';
import '../models/reminder_model.dart';
import '../services/scheduler_service.dart';
import '../ui/theme.dart';

enum TodayItemKind { entry, task, event, habitSlot, pomodoro, trackerRecord, reminder }
enum TodayItemOrigin { created, scheduled }

class TodayItem {
  final String id;
  final TodayItemKind kind;
  final TodayItemOrigin origin;
  final DateTime timestamp;
  final String title;
  final String emoji;
  final Color color;
  final bool isCompletable;
  final bool isCompleted;
  final bool isPlayable;
  final ContentObject source;

  TodayItem({
    required this.id,
    required this.kind,
    required this.origin,
    required this.timestamp,
    required this.title,
    required this.emoji,
    required this.color,
    required this.isCompletable,
    required this.isCompleted,
    required this.isPlayable,
    required this.source,
  });
}

class TodayAggregatorService {
  List<TodayItem> buildForDate(DateTime date, {required List<ContentObject> allObjects}) {
    final List<TodayItem> items = [];

    for (final obj in allObjects) {
      if (obj is JournalEntry) {
        if (obj.date != null && obj.date!.year == date.year && obj.date!.month == date.month && obj.date!.day == date.day) {
          DateTime ts = obj.date!;
          if (obj.timeOfDay != null) {
            final parts = obj.timeOfDay!.split(':');
            if (parts.length == 2) {
              ts = DateTime(date.year, date.month, date.day, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
            }
          }
          items.add(TodayItem(
            id: obj.id,
            kind: TodayItemKind.entry,
            origin: TodayItemOrigin.created,
            timestamp: ts,
            title: obj.title.isNotEmpty ? obj.title : 'Journal Entry',
            emoji: '📝',
            color: AppColors.textPrimary,
            isCompletable: false,
            isCompleted: false,
            isPlayable: false,
            source: obj,
          ));
        }
      } else if (obj is Task) {
        final bool startsToday = obj.startDate != null && obj.startDate!.year == date.year && obj.startDate!.month == date.month && obj.startDate!.day == date.day;
        final bool endsToday = obj.endDate != null && obj.endDate!.year == date.year && obj.endDate!.month == date.month && obj.endDate!.day == date.day;
        
        if (startsToday || endsToday) {
          DateTime ts = DateTime(date.year, date.month, date.day);
          if (obj.scheduledTime != null) {
            final parts = obj.scheduledTime!.split(':');
            if (parts.length == 2) {
              ts = DateTime(date.year, date.month, date.day, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
            }
          }
          items.add(TodayItem(
            id: obj.id,
            kind: TodayItemKind.task,
            origin: TodayItemOrigin.scheduled,
            timestamp: ts,
            title: obj.title,
            emoji: '✅',
            color: _getTaskColor(obj),
            isCompletable: true,
            isCompleted: obj.isCompleted,
            isPlayable: true,
            source: obj,
          ));
        }
      } else if (obj is Event) {
        final bool isToday = obj.date.year == date.year && obj.date.month == date.month && obj.date.day == date.day;
        if (isToday) {
          DateTime ts = DateTime(date.year, date.month, date.day);
          if (obj.timeOfDay != null) {
            final parts = obj.timeOfDay!.split(':');
            if (parts.length == 2) {
              ts = DateTime(date.year, date.month, date.day, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
            }
          }
          items.add(TodayItem(
            id: obj.id,
            kind: TodayItemKind.event,
            origin: TodayItemOrigin.scheduled,
            timestamp: ts,
            title: obj.title,
            emoji: '📅',
            color: AppColors.accent,
            isCompletable: false,
            isCompleted: false,
            isPlayable: obj.pomodoro != null,
            source: obj,
          ));
        }
      } else if (obj is Habit) {
        if (obj.status == HabitStatus.active && !obj.isNegative) {
          bool firesToday = false;
          for (final s in obj.schedulers) {
            if (SchedulerService.shouldFire(s, date)) {
              firesToday = true;
              break;
            }
          }
          
          if (firesToday) {
            final isCompleted = obj.completionHistory.any((c) => c.date.year == date.year && c.date.month == date.month && c.date.day == date.day);
            
            DateTime ts = DateTime(date.year, date.month, date.day);
            if (obj.slots.isNotEmpty && obj.slots.first.time != null) {
              ts = DateTime(date.year, date.month, date.day,
                obj.slots.first.time!.hour, obj.slots.first.time!.minute);
            }

            items.add(TodayItem(
              id: obj.id,
              kind: TodayItemKind.habitSlot,
              origin: TodayItemOrigin.scheduled,
              timestamp: ts,
              title: obj.title,
              emoji: obj.icon ?? '🔄',
              color: AppColors.accent,
              isCompletable: true,
              isCompleted: isCompleted,
              isPlayable: false,
              source: obj,
            ));
          }
        }
      } else if (obj is PomodoroSession) {
        final DateTime effectiveTime = obj.occurredAt ?? obj.date;
        final bool isToday = effectiveTime.year == date.year && effectiveTime.month == date.month && effectiveTime.day == date.day;
        if (isToday) {
          items.add(TodayItem(
            id: obj.id,
            kind: TodayItemKind.pomodoro,
            origin: TodayItemOrigin.created,
            timestamp: effectiveTime,
            title: obj.title,
            emoji: '🍅',
            color: AppColors.accent,
            isCompletable: false,
            isCompleted: false,
            isPlayable: false,
            source: obj,
          ));
        }
      } else if (obj is Reminder) {
        final bool isToday = obj.time.year == date.year && obj.time.month == date.month && obj.time.day == date.day;
        if (isToday) {
          items.add(TodayItem(
            id: obj.id,
            kind: TodayItemKind.reminder,
            origin: TodayItemOrigin.scheduled,
            timestamp: obj.time,
            title: obj.title,
            emoji: '⏰',
            color: AppColors.warning,
            isCompletable: false,
            isCompleted: false,
            isPlayable: false,
            source: obj,
          ));
        }
      }
    }

    items.sort((a, b) {
      final aIsUntimed = a.timestamp.hour == 0 && a.timestamp.minute == 0 && a.timestamp.second == 0;
      final bIsUntimed = b.timestamp.hour == 0 && b.timestamp.minute == 0 && b.timestamp.second == 0;
      
      if (aIsUntimed && !bIsUntimed) return -1;
      if (!aIsUntimed && bIsUntimed) return 1;
      if (aIsUntimed && bIsUntimed) return a.title.compareTo(b.title);
      
      return a.timestamp.compareTo(b.timestamp);
    });

    return items;
  }

  Color _getTaskColor(Task task) {
    if (task.stage == TaskStage.finalized) return AppColors.success;
    switch (task.priority) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
      default:
        return AppColors.textMuted;
    }
  }
}
