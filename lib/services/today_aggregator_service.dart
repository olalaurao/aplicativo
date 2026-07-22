import 'package:flutter/material.dart';
import '../models/content_object.dart';
import '../models/journal_entry.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';
import '../models/habit_model.dart';
import '../models/pomodoro_session.dart';
import '../models/reminder_model.dart';
import '../models/organizer_model.dart';
import '../models/shared_types.dart';
import '../services/scheduler_service.dart';
import '../ui/theme.dart';
import '../ui/utils/object_icons.dart';

enum TodayItemKind { entry, task, event, habitSlot, pomodoro, trackerRecord, reminder, timeBlock }
enum TodayItemOrigin { created, scheduled }

class TodayItem {
  final String id;
  final TodayItemKind kind;
  final TodayItemOrigin origin;
  final DateTime timestamp;
  final String title;
  final IconData iconData;
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
    required this.iconData,
    required this.color,
    required this.isCompletable,
    required this.isCompleted,
    required this.isPlayable,
    required this.source,
  });
}

class TodayAggregatorService {
  List<TodayItem> buildForDate(DateTime date, {required List<ContentObject> allObjects, Map<String, TypeSignature> typeSignatures = const {}}) {
    final List<TodayItem> items = [];

    for (final obj in allObjects) {
      // Filter out archived and deleted items
      if (obj.archived) continue;
      if (obj.obsidianPath.contains('_deleted')) continue;
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
            iconData: ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.entry, typeSignatures) ?? Icons.menu_book,
            color: ObjectIcons.colorForTypeWithSignatures(ObjectTypes.entry, typeSignatures),
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
            iconData: ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.task, typeSignatures) ?? Icons.check_circle_outline,
            color: _getTaskColor(obj, typeSignatures),
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
            iconData: ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.event, typeSignatures) ?? Icons.calendar_today,
            color: ObjectIcons.colorForTypeWithSignatures(ObjectTypes.event, typeSignatures),
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
              iconData: ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.habit, typeSignatures) ?? Icons.refresh,
              color: ObjectIcons.colorForTypeWithSignatures(ObjectTypes.habit, typeSignatures),
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
            iconData: Icons.timer,
            color: ObjectIcons.colorForTypeWithSignatures(ObjectTypes.timeBlock, typeSignatures),
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
            iconData: ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.reminder, typeSignatures) ?? Icons.notifications,
            color: ObjectIcons.colorForTypeWithSignatures(ObjectTypes.reminder, typeSignatures),
            isCompletable: false,
            isCompleted: false,
            isPlayable: false,
            source: obj,
          ));
        }
      } else if (obj is Organizer && obj.organizerType == OrganizerType.timeBlock) {
        const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayName = weekDayNames[date.weekday - 1];
        
        if (obj.daysOfWeek.contains(dayName) && obj.timeRanges.isNotEmpty) {
          final range = obj.timeRanges.first;
          final ts = DateTime(date.year, date.month, date.day, range.startHour, range.startMinute);
          
          final color = obj.color != null && obj.color!.startsWith('#')
              ? Color(int.parse(obj.color!.replaceAll('#', '0xFF')))
              : AppColors.info;
          
          items.add(TodayItem(
            id: obj.id,
            kind: TodayItemKind.timeBlock,
            origin: TodayItemOrigin.scheduled,
            timestamp: ts,
            title: obj.title,
            iconData: ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.timeBlock, typeSignatures) ?? Icons.access_time,
            color: color,
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

  Color _getTaskColor(Task task, Map<String, TypeSignature> typeSignatures) {
    // If user has configured a custom task color, use it for all priorities.
    final sig = typeSignatures[ObjectTypes.task];
    if (sig != null && sig.colorHex != null && sig.colorHex!.isNotEmpty) {
      return ObjectIcons.colorForTypeWithSignatures(ObjectTypes.task, typeSignatures);
    }
    // Otherwise fall back to priority-based colors.
    if (task.stage == TaskStage.finalized) return AppColors.success;
    switch (task.priority) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
      default:
        return ObjectIcons.defaultColorForType(ObjectTypes.task);
    }
  }
}
