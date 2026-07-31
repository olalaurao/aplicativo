import 'package:flutter_test/flutter_test.dart';
import 'package:quartzo/models/task_model.dart';
import 'package:quartzo/models/habit_model.dart';
import 'package:quartzo/models/event_model.dart';
import 'package:quartzo/models/reminder_model.dart';
import 'package:quartzo/models/shared_types.dart';
import 'package:quartzo/services/daily_schedule_service.dart';

void main() {
  group('DailyScheduleAggregation - Archived/Deleted Exclusions', () {
    test('excludes archived tasks from daily schedule', () {
      final date = DateTime(2024, 1, 15);
      final archivedTask = Task(
        id: 'archived-1',
        title: 'Archived Task',
        startDate: date,
        endDate: date,
        archived: true,
      );
      final normalTask = Task(
        id: 'normal-1',
        title: 'Normal Task',
        startDate: date,
        endDate: date,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [archivedTask, normalTask],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.allItems.length, 1);
      expect(snapshot.allItems.first.source?.id, 'normal-1');
      expect(snapshot.allItems.any((item) => item.source?.id == 'archived-1'), false);
    });

    test('excludes tasks with _deleted path from daily schedule', () {
      final date = DateTime(2024, 1, 15);
      final deletedTask = Task(
        id: 'deleted-1',
        title: 'Deleted Task',
        startDate: date,
        endDate: date,
        obsidianPath: '_deleted/deleted-task.md',
      );
      final normalTask = Task(
        id: 'normal-1',
        title: 'Normal Task',
        startDate: date,
        endDate: date,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [deletedTask, normalTask],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.allItems.length, 1);
      expect(snapshot.allItems.first.source?.id, 'normal-1');
      expect(snapshot.allItems.any((item) => item.source?.id == 'deleted-1'), false);
    });

    test('excludes archived habits from daily schedule', () {
      final date = DateTime(2024, 1, 15);
      final archivedHabit = Habit(
        id: 'archived-habit-1',
        title: 'Archived Habit',
        color: '#000000',
        archived: true,
      );
      final normalHabit = Habit(
        id: 'normal-habit-1',
        title: 'Normal Habit',
        color: '#000000',
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [archivedHabit, normalHabit],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.allItems.length, 1);
      expect(snapshot.allItems.first.source?.id, 'normal-habit-1');
      expect(snapshot.allItems.any((item) => item.source?.id == 'archived-habit-1'), false);
    });

    test('excludes archived events from daily schedule', () {
      final date = DateTime(2024, 1, 15);
      final archivedEvent = Event(
        id: 'archived-event-1',
        title: 'Archived Event',
        date: date,
        archived: true,
      );
      final normalEvent = Event(
        id: 'normal-event-1',
        title: 'Normal Event',
        date: date,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [archivedEvent, normalEvent],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.allItems.length, 1);
      expect(snapshot.allItems.first.source?.id, 'normal-event-1');
      expect(snapshot.allItems.any((item) => item.source?.id == 'archived-event-1'), false);
    });

    test('excludes archived reminders from daily schedule', () {
      final date = DateTime(2024, 1, 15);
      final archivedReminder = Reminder(
        id: 'archived-reminder-1',
        title: 'Archived Reminder',
        time: date,
        archived: true,
      );
      final normalReminder = Reminder(
        id: 'normal-reminder-1',
        title: 'Normal Reminder',
        time: date,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [archivedReminder, normalReminder],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.allItems.length, 1);
      expect(snapshot.allItems.first.source?.id, 'normal-reminder-1');
      expect(snapshot.allItems.any((item) => item.source?.id == 'archived-reminder-1'), false);
    });
  });

  group('DailyScheduleFilter - Filter Behavior', () {
    test('filters by visible kinds', () {
      final date = DateTime(2024, 1, 15);
      final task = Task(
        id: 'task-1',
        title: 'Task',
        startDate: date,
        endDate: date,
      );
      final habit = Habit(
        id: 'habit-1',
        title: 'Habit',
        color: '#000000',
      );
      final event = Event(
        id: 'event-1',
        title: 'Event',
        date: date,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [task, habit, event],
        googleEvents: [],
        typeSignatures: {},
      );

      final filter = DailyScheduleFilter(
        visibleKinds: {DailyScheduleKind.task, DailyScheduleKind.habit},
      );
      final filtered = snapshot.apply(filter);

      expect(filtered.allItems.length, 2);
      expect(filtered.allItems.any((item) => item.kind == DailyScheduleKind.task), true);
      expect(filtered.allItems.any((item) => item.kind == DailyScheduleKind.habit), true);
      expect(filtered.allItems.any((item) => item.kind == DailyScheduleKind.event), false);
    });

    test('filters by completable flag', () {
      final date = DateTime(2024, 1, 15);
      final task = Task(
        id: 'task-1',
        title: 'Task',
        startDate: date,
        endDate: date,
      );
      final event = Event(
        id: 'event-1',
        title: 'Event',
        date: date,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [task, event],
        googleEvents: [],
        typeSignatures: {},
      );

      final filter = DailyScheduleFilter(includeCompletableOnly: true);
      final filtered = snapshot.apply(filter);

      expect(filtered.completableItems.length, 1);
      expect(filtered.completableItems.first.kind, DailyScheduleKind.task);
    });

    test('filters by all-day flag', () {
      final date = DateTime(2024, 1, 15);
      final allDayTask = Task(
        id: 'all-day-task-1',
        title: 'All Day Task',
        startDate: date,
        endDate: date,
        scheduledTime: null,
      );
      final timedTask = Task(
        id: 'timed-task-1',
        title: 'Timed Task',
        startDate: date,
        endDate: date,
        scheduledTime: '10:00',
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [allDayTask, timedTask],
        googleEvents: [],
        typeSignatures: {},
      );

      final filter = DailyScheduleFilter(includeTimed: false);
      final filtered = snapshot.apply(filter);

      expect(filtered.allDayItems.length, 1);
      expect(filtered.allDayItems.first.source?.id, 'all-day-task-1');
    });

    test('combines multiple filter criteria', () {
      final date = DateTime(2024, 1, 15);
      final task1 = Task(
        id: 'task-1',
        title: 'Task 1',
        startDate: date,
        endDate: date,
      );
      final task2 = Task(
        id: 'task-2',
        title: 'Task 2',
        startDate: date,
        endDate: date,
        scheduledTime: '10:00',
      );
      final habit = Habit(
        id: 'habit-1',
        title: 'Habit',
        color: '#000000',
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [task1, task2, habit],
        googleEvents: [],
        typeSignatures: {},
      );

      final filter = DailyScheduleFilter(
        visibleKinds: {DailyScheduleKind.task},
        includeTimed: false,
      );
      final filtered = snapshot.apply(filter);

      expect(filtered.allItems.length, 1);
      expect(filtered.allItems.first.source?.id, 'task-1');
    });
  });

  group('DailyScheduleSnapshot - Completable Items', () {
    test('identifies tasks as completable', () {
      final date = DateTime(2024, 1, 15);
      final task = Task(
        id: 'task-1',
        title: 'Task',
        startDate: date,
        endDate: date,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [task],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.completableItems.length, 1);
      expect(snapshot.completableItems.first.isCompletable, true);
    });

    test('identifies habits as completable', () {
      final date = DateTime(2024, 1, 15);
      final habit = Habit(
        id: 'habit-1',
        title: 'Habit',
        color: '#000000',
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [habit],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.completableItems.length, 1);
      expect(snapshot.completableItems.first.isCompletable, true);
    });

    test('does not identify events as completable', () {
      final date = DateTime(2024, 1, 15);
      final event = Event(
        id: 'event-1',
        title: 'Event',
        date: date,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [event],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.completableItems.length, 0);
    });
  });

  group('DailyScheduleSnapshot - All-Day Items', () {
    test('identifies all-day tasks', () {
      final date = DateTime(2024, 1, 15);
      final allDayTask = Task(
        id: 'all-day-task-1',
        title: 'All Day Task',
        startDate: date,
        endDate: date,
        scheduledTime: null,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [allDayTask],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.allDayItems.length, 1);
      expect(snapshot.allDayItems.first.isAllDay, true);
    });

    test('identifies all-day events', () {
      final date = DateTime(2024, 1, 15);
      final allDayEvent = Event(
        id: 'all-day-event-1',
        title: 'All Day Event',
        date: date,
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [allDayEvent],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.allDayItems.length, 1);
      expect(snapshot.allDayItems.first.isAllDay, true);
    });

    test('excludes timed items from all-day list', () {
      final date = DateTime(2024, 1, 15);
      final timedTask = Task(
        id: 'timed-task-1',
        title: 'Timed Task',
        startDate: date,
        endDate: date,
        scheduledTime: '10:00',
      );

      final snapshot = DailyScheduleAggregator.buildForDate(
        date,
        allObjects: [timedTask],
        googleEvents: [],
        typeSignatures: {},
      );

      expect(snapshot.allDayItems.length, 0);
    });
  });
}
