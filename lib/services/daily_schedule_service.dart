import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;

import '../models/content_object.dart';
import '../models/habit_model.dart';
import '../models/pomodoro_session.dart';
import '../models/shared_types.dart';
import '../models/task_model.dart';
import '../ui/theme.dart';
import '../ui/utils/object_icons.dart';
import 'rotation_service.dart';
import 'scheduler_service.dart';
import 'timeline_aggregator_service.dart';

enum DailyScheduleKind {
  task,
  habit,
  event,
  googleCalendar,
  reminder,
  pomodoro,
  trackerRecord,
  journalEntry,
  timeBlock,
  system,
  rotationZone,
  personContact,
  goal,
}

class DailyScheduleFilter {
  final Set<DailyScheduleKind>? visibleKinds;
  final bool includeTimed;
  final bool includeAllDay;
  final bool includeCompletableOnly;
  final bool includeCompleted;

  const DailyScheduleFilter({
    this.visibleKinds,
    this.includeTimed = true,
    this.includeAllDay = true,
    this.includeCompletableOnly = false,
    this.includeCompleted = true,
  });

  static const all = DailyScheduleFilter();

  bool allows(DailyScheduleItem item) {
    if (visibleKinds != null && !visibleKinds!.contains(item.kind)) {
      return false;
    }
    if (!includeTimed && item.isTimed) return false;
    if (!includeAllDay && item.isAllDay) return false;
    if (includeCompletableOnly && !item.isCompletable) return false;
    if (!includeCompleted && item.isCompleted) return false;
    return true;
  }
}

class DailyScheduleItem {
  final String id;
  final DailyScheduleKind kind;
  final ContentObject? source;
  final google_calendar.Event? googleEvent;
  final String title;
  final IconData iconData;
  final Color color;
  final DateTime date;
  final int? startMinutes;
  final int? endMinutes;
  final int? slotIndex;
  final bool isCompletable;
  final bool isCompleted;
  final bool isPlayable;
  final String sourceLabel;
  final String? subtitle;

  const DailyScheduleItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.iconData,
    required this.color,
    required this.date,
    required this.sourceLabel,
    this.source,
    this.googleEvent,
    this.startMinutes,
    this.endMinutes,
    this.slotIndex,
    this.isCompletable = false,
    this.isCompleted = false,
    this.isPlayable = false,
    this.subtitle,
  });

  bool get isTimed => startMinutes != null;
  bool get isAllDay => !isTimed;

  String? get time {
    if (startMinutes == null) return null;
    final hour = startMinutes! ~/ 60;
    final minute = startMinutes! % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  DateTime get timestamp {
    final minutes = startMinutes;
    if (minutes == null) return DateTime(date.year, date.month, date.day);
    return DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
  }
}

class DailyScheduleSnapshot {
  final DateTime date;
  final List<DailyScheduleItem> allItems;

  const DailyScheduleSnapshot({
    required this.date,
    required this.allItems,
  });

  List<DailyScheduleItem> get timedItems =>
      allItems.where((item) => item.isTimed).toList();

  List<DailyScheduleItem> get allDayItems =>
      allItems.where((item) => item.isAllDay).toList();

  List<DailyScheduleItem> get completableItems =>
      allItems.where((item) => item.isCompletable).toList();

  DailyScheduleSnapshot apply(DailyScheduleFilter filter) {
    return DailyScheduleSnapshot(
      date: date,
      allItems: allItems.where(filter.allows).toList(),
    );
  }
}

class DailyScheduleAggregator {
  static DailyScheduleSnapshot buildForDate(
    DateTime date, {
    required List<ContentObject> allObjects,
    Map<String, TypeSignature> typeSignatures = const {},
    List<google_calendar.Event> googleEvents = const [],
  }) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final visibleObjects = allObjects.where(_isVisibleObject).toList();
    final aggregation = TimelineAggregatorService.aggregateForDate(
      dateOnly,
      visibleObjects,
    );
    final items = <DailyScheduleItem>[];

    for (final task in aggregation.allTasks) {
      if (task.isRotationTask) continue; // Rotation tasks appear only as part of rotation zone
      if (task.isCompleted) continue;
      final start = _parseTime(task.scheduledTime);
      items.add(
        DailyScheduleItem(
          id: 'task:${task.id}',
          kind: DailyScheduleKind.task,
          source: task,
          title: task.title,
          iconData: _icon(ObjectTypes.task, typeSignatures),
          color: _taskColor(task, typeSignatures),
          date: dateOnly,
          startMinutes: start,
          endMinutes: start == null
              ? null
              : start + task.duration.clamp(10, 24 * 60).toInt(),
          isCompletable: true,
          isCompleted: task.isCompleted,
          isPlayable: true,
          sourceLabel: _sourceLabel(task),
          subtitle: start == null ? null : _timeSubtitle(start, task.duration),
        ),
      );
    }

    for (final habit in aggregation.habits) {
      final slotTimes = _habitSlotTimes(habit);
      if (slotTimes.isEmpty) {
        items.add(_habitItem(habit, dateOnly, typeSignatures));
      } else {
        for (var i = 0; i < slotTimes.length; i++) {
          final start = slotTimes[i];
          items.add(_habitItem(
            habit,
            dateOnly,
            typeSignatures,
            startMinutes: start,
            slotIndex: i,
          ));
        }
      }
    }

    for (final event in aggregation.events) {
      final start = _minutesOf(event.date);
      items.add(
        DailyScheduleItem(
          id: 'event:${event.id}',
          kind: DailyScheduleKind.event,
          source: event,
          title: event.title,
          iconData: _icon(event.pomodoro == null ? ObjectTypes.event : ObjectTypes.pomodoro, typeSignatures),
          color: _color(event.pomodoro == null ? ObjectTypes.event : ObjectTypes.pomodoro, typeSignatures),
          date: dateOnly,
          startMinutes: start,
          endMinutes: start + event.duration.clamp(10, 24 * 60).toInt(),
          isPlayable: event.pomodoro != null,
          sourceLabel: _sourceLabel(event),
          subtitle: _timeSubtitle(start, event.duration),
        ),
      );
    }

    for (final reminder in aggregation.reminders) {
      if (reminder.isCompleted) continue;
      final start = _minutesOf(reminder.time);
      items.add(
        DailyScheduleItem(
          id: 'reminder:${reminder.id}',
          kind: DailyScheduleKind.reminder,
          source: reminder,
          title: reminder.title,
          iconData: _icon(ObjectTypes.reminder, typeSignatures),
          color: _color(ObjectTypes.reminder, typeSignatures),
          date: dateOnly,
          startMinutes: start,
          endMinutes: start + 15,
          sourceLabel: _sourceLabel(reminder),
          subtitle: _formatTime(start),
        ),
      );
    }

    for (final record in aggregation.trackerRecords) {
      items.add(
        DailyScheduleItem(
          id: 'tracker:${record.id}',
          kind: DailyScheduleKind.trackerRecord,
          source: record,
          title: record.title.isNotEmpty ? record.title : 'Tracking Record',
          iconData: _icon(ObjectTypes.tracker, typeSignatures),
          color: _color(ObjectTypes.tracker, typeSignatures),
          date: dateOnly,
          sourceLabel: _sourceLabel(record),
        ),
      );
    }

    for (final entry in aggregation.journalEntries) {
      final start = _parseTime(entry.timeOfDay);
      items.add(
        DailyScheduleItem(
          id: 'entry:${entry.id}',
          kind: DailyScheduleKind.journalEntry,
          source: entry,
          title: entry.title.isNotEmpty ? entry.title : 'Journal Entry',
          iconData: _icon(ObjectTypes.entry, typeSignatures),
          color: _color(ObjectTypes.entry, typeSignatures),
          date: dateOnly,
          startMinutes: start,
          endMinutes: start == null ? null : start + 15,
          sourceLabel: _sourceLabel(entry),
          subtitle: start == null ? null : _formatTime(start),
        ),
      );
    }

    for (final pomodoro in aggregation.pomodoros) {
      final effectiveTime = pomodoro.occurredAt ?? pomodoro.date;
      final start = _minutesOf(effectiveTime);
      final duration = pomodoro.minutesWorked > 0 ? pomodoro.minutesWorked : pomodoro.workDuration;
      items.add(
        DailyScheduleItem(
          id: 'pomodoro:${pomodoro.id}',
          kind: DailyScheduleKind.pomodoro,
          source: pomodoro,
          title: pomodoro.title,
          iconData: _icon(ObjectTypes.pomodoro, typeSignatures),
          color: _color(ObjectTypes.pomodoro, typeSignatures),
          date: dateOnly,
          startMinutes: start,
          endMinutes: start + duration.clamp(10, 24 * 60).toInt(),
          isCompleted: pomodoro.state == PomodoroSessionState.completed,
          sourceLabel: _sourceLabel(pomodoro),
          subtitle: _timeSubtitle(start, duration),
        ),
      );
    }

    for (final block in aggregation.timeBlocks) {
      for (final range in block.timeRanges) {
        final start = range.startHour * 60 + range.startMinute;
        final end = range.endHour * 60 + range.endMinute;
        items.add(
          DailyScheduleItem(
            id: 'time_block:${block.id}:$start',
            kind: DailyScheduleKind.timeBlock,
            source: block,
            title: block.title,
            iconData: _icon(ObjectTypes.timeBlock, typeSignatures),
            color: _color(ObjectTypes.timeBlock, typeSignatures),
            date: dateOnly,
            startMinutes: start,
            endMinutes: end > start ? end : start + 60,
            sourceLabel: _sourceLabel(block),
            subtitle: '${_formatTime(start)} - ${_formatTime(end)}',
          ),
        );
      }
    }

    for (final system in aggregation.systems) {
      final shouldShow = system.scheduler == null ||
          SchedulerService.shouldFire(system.scheduler!, dateOnly);
      if (!shouldShow) continue;
      final start = _parseTime(system.scheduledTime);
      items.add(
        DailyScheduleItem(
          id: 'system:${system.id}',
          kind: DailyScheduleKind.system,
          source: system,
          title: system.title,
          iconData: _icon(ObjectTypes.system, typeSignatures),
          color: _color(ObjectTypes.system, typeSignatures),
          date: dateOnly,
          startMinutes: start,
          endMinutes: start == null
              ? null
              : start + system.estimatedMinutes.clamp(10, 24 * 60).toInt(),
          sourceLabel: _sourceLabel(system),
          subtitle: start == null ? null : _timeSubtitle(start, system.estimatedMinutes),
        ),
      );
    }

    for (final project in aggregation.rotationProjects) {
      final status = RotationService.computeActiveStatus(project, now: dateOnly);
      if (status == null) continue;
      final schedule = RotationService.scheduleForStatus(project, status, dateOnly);
      final start = _parseTime(schedule.time) ?? 9 * 60;
      items.add(
        DailyScheduleItem(
          id: 'rotation:${project.id}:${status.group.id}',
          kind: DailyScheduleKind.rotationZone,
          source: project,
          title: '${project.title} · ${status.group.name}',
          iconData: _icon(ObjectTypes.project, typeSignatures),
          color: _parseHex(status.group.colorHex) ?? _color(ObjectTypes.project, typeSignatures),
          date: dateOnly,
          startMinutes: start,
          endMinutes: start + schedule.durationMinutes.clamp(10, 24 * 60).toInt(),
          sourceLabel: 'project:${project.id}:rotation:${status.group.id}',
          subtitle: _timeSubtitle(start, schedule.durationMinutes),
        ),
      );
    }

    for (final goal in aggregation.goals) {
      items.add(
        DailyScheduleItem(
          id: 'goal:${goal.id}',
          kind: DailyScheduleKind.goal,
          source: goal,
          title: goal.title,
          iconData: _icon(ObjectTypes.goal, typeSignatures),
          color: _color(ObjectTypes.goal, typeSignatures),
          date: dateOnly,
          sourceLabel: _sourceLabel(goal),
        ),
      );
    }

    for (final person in aggregation.peopleToContact) {
      items.add(
        DailyScheduleItem(
          id: 'person_contact:${person.id}',
          kind: DailyScheduleKind.personContact,
          source: person,
          title: person.title,
          iconData: _icon(ObjectTypes.person, typeSignatures),
          color: _color(ObjectTypes.person, typeSignatures),
          date: dateOnly,
          sourceLabel: _sourceLabel(person),
          subtitle: 'Contact due',
        ),
      );
    }

    for (final event in googleEvents) {
      final start = event.start?.dateTime ?? event.start?.date;
      if (start == null) continue;
      final localStart = start.toLocal();
      if (!_isSameDay(localStart, dateOnly)) continue;
      final localEnd = (event.end?.dateTime ?? event.end?.date)?.toLocal();
      final isAllDay = event.start?.date != null;
      final startMinutes = isAllDay ? null : _minutesOf(localStart);
      final duration = localEnd == null
          ? 30
          : localEnd.difference(localStart).inMinutes.clamp(10, 24 * 60).toInt();
      items.add(
        DailyScheduleItem(
          id: 'google_calendar:${event.id ?? event.summary ?? event.hashCode}',
          kind: DailyScheduleKind.googleCalendar,
          googleEvent: event,
          title: event.summary ?? '(Untitled)',
          iconData: Icons.calendar_today_rounded,
          color: _color(ObjectTypes.event, typeSignatures),
          date: dateOnly,
          startMinutes: startMinutes,
          endMinutes: startMinutes == null ? null : startMinutes + duration,
          sourceLabel: 'google_calendar:${event.id ?? ''}',
          subtitle: isAllDay ? 'All day' : _timeSubtitle(startMinutes!, duration),
        ),
      );
    }

    items.sort(_compareItems);
    return DailyScheduleSnapshot(date: dateOnly, allItems: items);
  }

  static bool _isVisibleObject(ContentObject object) {
    if (object.archived) return false;
    return !object.obsidianPath.replaceAll('\\', '/').contains('/_deleted/') &&
        !object.obsidianPath.replaceAll('\\', '/').startsWith('_deleted/');
  }

  static DailyScheduleItem _habitItem(
    Habit habit,
    DateTime date,
    Map<String, TypeSignature> typeSignatures, {
    int? startMinutes,
    int? slotIndex,
  }) {
    final completed = _isHabitCompletedOn(habit, date, slotIndex: slotIndex);
    return DailyScheduleItem(
      id: slotIndex == null ? 'habit:${habit.id}' : 'habit:${habit.id}:slot:$slotIndex',
      kind: DailyScheduleKind.habit,
      source: habit,
      title: habit.displayTitle,
      iconData: _icon(ObjectTypes.habit, typeSignatures),
      color: _color(ObjectTypes.habit, typeSignatures),
      date: date,
      startMinutes: startMinutes,
      endMinutes: startMinutes == null ? null : startMinutes + 30,
      slotIndex: slotIndex,
      isCompletable: true,
      isCompleted: completed,
      sourceLabel: _sourceLabel(habit),
      subtitle: startMinutes == null ? null : _formatTime(startMinutes),
    );
  }

  static List<int> _habitSlotTimes(Habit habit) {
    final result = <int>[];
    for (final slot in habit.slots) {
      final reminderTime = slot.primaryReminderTime;
      if (reminderTime != null) {
        result.add(reminderTime.hour * 60 + reminderTime.minute);
        continue;
      }
      final time = slot.time;
      if (time != null) result.add(time.hour * 60 + time.minute);
    }
    return result;
  }

  static bool _isHabitCompletedOn(Habit habit, DateTime date, {int? slotIndex}) {
    return habit.completionHistory.any((record) {
      final sameDay = _isSameDay(record.date, date) && record.successful;
      if (!sameDay) return false;
      if (slotIndex == null) return true;
      final slotCompletions = record.slotCompletions;
      return slotCompletions == null ||
          (slotIndex < slotCompletions.length && slotCompletions[slotIndex]);
    });
  }

  static int? _parseTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour.clamp(0, 23) * 60) + minute.clamp(0, 59);
  }

  static int _minutesOf(DateTime date) => date.hour * 60 + date.minute;

  static String _formatTime(int minutes) {
    final hour = (minutes ~/ 60).clamp(0, 23);
    final minute = (minutes % 60).clamp(0, 59);
    final hourText = hour.toString().padLeft(2, '0');
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hourText:$minuteText';
  }

  static String _timeSubtitle(int startMinutes, int duration) =>
      '${_formatTime(startMinutes)} · $duration min';

  static IconData _icon(String type, Map<String, TypeSignature> signatures) =>
      ObjectIcons.iconDataForTypeWithSignatures(type, signatures) ??
      ObjectIcons.defaultIconDataForType(type);

  static Color _color(String type, Map<String, TypeSignature> signatures) =>
      ObjectIcons.colorForTypeWithSignatures(type, signatures);

  static Color _taskColor(Task task, Map<String, TypeSignature> signatures) {
    final sig = signatures[ObjectTypes.task];
    if (sig?.colorHex?.isNotEmpty == true) {
      return ObjectIcons.colorForTypeWithSignatures(ObjectTypes.task, signatures);
    }
    if (task.stage == TaskStage.finalized) return AppColors.success;
    return AppTheme.priorityColor(task.priority);
  }

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    final clean = hex.replaceAll('#', '').trim();
    try {
      if (clean.length == 6) return Color(int.parse('0xFF$clean'));
      if (clean.length == 8) return Color(int.parse('0x$clean'));
    } catch (_) {
      return null;
    }
    return null;
  }

  static String _sourceLabel(ContentObject object) =>
      '${object.type}:${object.id}:${object.obsidianPath}';

  static int _compareItems(DailyScheduleItem a, DailyScheduleItem b) {
    if (a.isAllDay && !b.isAllDay) return -1;
    if (!a.isAllDay && b.isAllDay) return 1;
    final timeCompare = (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0);
    if (timeCompare != 0) return timeCompare;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
