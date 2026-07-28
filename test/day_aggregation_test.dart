import 'package:flutter_test/flutter_test.dart';
import 'package:quartzo/models/checklist_step.dart';
import 'package:quartzo/models/content_object.dart';
import 'package:quartzo/models/day_dial_model.dart';
import 'package:quartzo/models/habit_model.dart';
import 'package:quartzo/models/organizer_model.dart';
import 'package:quartzo/models/project_model.dart';
import 'package:quartzo/models/shared_types.dart';
import 'package:quartzo/models/system_model.dart';
import 'package:quartzo/models/task_model.dart';
import 'package:quartzo/services/day_dial_aggregator.dart';
import 'package:quartzo/services/daily_schedule_service.dart';
import 'package:quartzo/services/today_aggregator_service.dart';

OrganizerReference projectRef(Project project) => OrganizerReference(
  type: 'project',
  slug: project.slug,
  title: project.title,
);

void main() {
  final office = RotationGroup(
    id: 'office',
    name: 'Office',
    periodDays: 7,
    order: 0,
  );
  final project = Project(
    id: 'home-reset',
    title: 'Home Reset',
    rotationGroups: [office],
    rotationStartDate: DateTime(2026, 7, 27),
    rotationCurrentGroupId: office.id,
    rotationCurrentPeriodStart: DateTime(2026, 7, 27),
    rotationScheduledTime: '10:00',
    rotationDurationMinutes: 45,
  );
  final rotationTask = Task(
    title: 'Dust shelves',
    organizers: [projectRef(project)],
    rotationGroupId: office.id,
    rotationFrequencyType: RotationFrequencyType.oncePerPeriod,
  );

  test('today aggregator includes systems and active rotation zone blocks', () {
    final system = SystemDefinition(
      title: 'Morning reset',
      createdAt: DateTime(2026, 7, 27, 8),
      scheduledTime: '08:30',
      estimatedMinutes: 20,
      steps: [ChecklistStep(id: 'step', title: 'Open blinds')],
    );

    final items = TodayAggregatorService().buildForDate(
      DateTime(2026, 7, 27),
      allObjects: <ContentObject>[project, rotationTask, system],
    );

    expect(items.map((item) => item.kind), contains(TodayItemKind.system));
    expect(
      items.map((item) => item.kind),
      contains(TodayItemKind.rotationZone),
    );
    expect(
      items.firstWhere((item) => item.kind == TodayItemKind.rotationZone).title,
      'Home Reset · Office',
    );
  });

  test('day dial includes active rotation zone with project schedule', () {
    final snapshot = DayDialAggregator.aggregateForDate(
      date: DateTime(2026, 7, 27),
      tasks: [rotationTask],
      habits: const <Habit>[],
      pomodoroSessions: const [],
      googleEvents: const [],
      localEvents: const [],
      reminders: const [],
      timeBlocks: const <Organizer>[],
      journalEntries: const [],
      moodCatalog: const [],
      projects: [project],
    );

    final segment = snapshot.segments.singleWhere(
      (item) => item.kind == DialSegmentKind.rotationZone,
    );
    expect(segment.start.hour, 10);
    expect(segment.end.difference(segment.start).inMinutes, 45);
  });

  test('canonical daily schedule splits timed and all-day tasks and habits', () {
    final date = DateTime(2026, 7, 27);
    final allDayTask = Task(
      title: 'All day task',
      startDate: date,
    );
    final timedTask = Task(
      title: 'Timed task',
      startDate: date,
      scheduledTime: '14:30',
      duration: 45,
    );
    final allDayHabit = Habit(
      title: 'Untimed habit',
      color: '#22C55E',
      schedulers: const [],
      slots: const [],
    );
    final timedHabit = Habit(
      title: 'Timed habit',
      color: '#22C55E',
      schedulers: const [],
      slots: [
        HabitSlot(time: DateTime(2026, 7, 27, 9, 15)),
      ],
    );

    final snapshot = DailyScheduleAggregator.buildForDate(
      date,
      allObjects: [allDayTask, timedTask, allDayHabit, timedHabit],
    );

    expect(snapshot.allDayItems.map((item) => item.title), contains('All day task'));
    expect(snapshot.allDayItems.map((item) => item.title), contains('Untimed habit'));
    expect(snapshot.timedItems.map((item) => item.title), contains('Timed task'));
    expect(snapshot.timedItems.map((item) => item.title), contains('Timed habit'));
    expect(
      snapshot.timedItems.firstWhere((item) => item.title == 'Timed task').startMinutes,
      14 * 60 + 30,
    );
    expect(
      snapshot.timedItems.firstWhere((item) => item.title == 'Timed habit').startMinutes,
      9 * 60 + 15,
    );
  });

  test('canonical daily schedule excludes archived and deleted objects globally', () {
    final date = DateTime(2026, 7, 27);
    final archivedTask = Task(
      title: 'Archived task',
      startDate: date,
      archived: true,
    );
    final deletedTask = Task(
      title: 'Deleted task',
      startDate: date,
      obsidianPath: '_deleted/deleted-task.md',
    );
    final visibleTask = Task(
      title: 'Visible task',
      startDate: date,
    );

    final snapshot = DailyScheduleAggregator.buildForDate(
      date,
      allObjects: [archivedTask, deletedTask, visibleTask],
    );

    expect(snapshot.allItems.map((item) => item.title), ['Visible task']);
  });

  test('today aggregator delegates to canonical daily schedule rules', () {
    final date = DateTime(2026, 7, 27);
    final task = Task(title: 'Canonical task', startDate: date);
    final archived = Task(title: 'Hidden task', startDate: date, archived: true);

    final items = TodayAggregatorService().buildForDate(
      date,
      allObjects: [task, archived],
    );

    expect(items.map((item) => item.title), ['Canonical task']);
  });
}
