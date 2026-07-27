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
}
