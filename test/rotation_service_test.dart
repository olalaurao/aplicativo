import 'package:flutter_test/flutter_test.dart';
import 'package:quartzo/models/project_model.dart';
import 'package:quartzo/models/shared_types.dart';
import 'package:quartzo/models/task_model.dart';
import 'package:quartzo/services/kpi_engine.dart';
import 'package:quartzo/services/project_progress_cache.dart';
import 'package:quartzo/services/rotation_service.dart';

OrganizerReference projectRef(Project project) => OrganizerReference(
  type: 'project',
  slug: project.slug,
  title: project.title,
);

void main() {
  group('RotationService task filtering', () {
    final office = RotationGroup(
      id: 'office',
      name: 'Escritório',
      periodDays: 7,
      order: 0,
    );
    final kitchen = RotationGroup(
      id: 'kitchen',
      name: 'Cozinha',
      periodDays: 7,
      order: 1,
    );
    final project = Project(
      id: 'flylady-project',
      title: 'Limpeza da Casa',
      rotationGroups: [office, kitchen],
      rotationStartDate: DateTime(2026, 7, 23),
    );
    final otherProject = Project(
      id: 'other-project',
      title: 'Outro Projeto',
      rotationGroups: [office],
      rotationStartDate: DateTime(2026, 7, 23),
    );

    test('includes project-linked tasks for the matching zone', () {
      final task = Task(
        title: 'Limpar escrivaninha',
        organizers: [projectRef(project)],
        rotationGroupId: office.id,
        rotationFrequencyType: RotationFrequencyType.oncePerPeriod,
      );

      final result = RotationService.rotationTasksForGroup(project, office, [
        task,
      ]);

      expect(result, [task]);
    });

    test('keeps legacy untyped project wikilinks linked after reload', () {
      final legacyRef = OrganizerReference.fromWikiLink('[[${project.slug}]]');
      final task = Task(
        title: 'Limpar armário',
        organizers: [legacyRef],
        rotationGroupId: office.id,
        rotationFrequencyType: RotationFrequencyType.oncePerPeriod,
      );

      expect(legacyRef.type, 'label');
      expect(RotationService.rotationTasksForGroup(project, office, [task]), [
        task,
      ]);
    });

    test('includes all-zone tasks in every project zone', () {
      final task = Task(
        title: 'Tirar o lixo',
        organizers: [projectRef(project)],
        rotationGroupId: 'all',
        rotationFrequencyType: RotationFrequencyType.daily,
      );

      expect(RotationService.rotationTasksForGroup(project, office, [task]), [
        task,
      ]);
      expect(RotationService.rotationTasksForGroup(project, kitchen, [task]), [
        task,
      ]);
    });

    test('excludes rotation tasks linked to another project', () {
      final task = Task(
        title: 'Limpar bancada',
        organizers: [projectRef(otherProject)],
        rotationGroupId: office.id,
        rotationFrequencyType: RotationFrequencyType.oncePerPeriod,
      );

      final result = RotationService.rotationTasksForGroup(project, office, [
        task,
      ]);

      expect(result, isEmpty);
    });

    test('returns due tasks by frequency for the active status', () {
      final status = RotationStatus(
        group: office,
        dayOfPeriod: 3,
        periodStart: DateTime(2026, 7, 23),
        periodEnd: DateTime(2026, 7, 29),
        occurrenceNumber: 3,
      );
      final daily = Task(
        title: 'Arrumar mesa',
        organizers: [projectRef(project)],
        rotationGroupId: office.id,
        rotationFrequencyType: RotationFrequencyType.daily,
      );
      final onceDone = Task(
        title: 'Limpar gavetas',
        organizers: [projectRef(project)],
        rotationGroupId: office.id,
        rotationFrequencyType: RotationFrequencyType.oncePerPeriod,
        rotationLastCompletedAtOccurrence: 3,
      );
      final everyNDue = Task(
        title: 'Limpar janelas',
        organizers: [projectRef(project)],
        rotationGroupId: office.id,
        rotationFrequencyType: RotationFrequencyType.everyNRotations,
        rotationEveryN: 2,
        rotationLastCompletedAtOccurrence: 1,
      );

      final result = RotationService.dueRotationTasksForStatus(
        project,
        status,
        [daily, onceDone, everyNDue],
      );

      expect(result, containsAll([daily, everyNDue]));
      expect(result, isNot(contains(onceDone)));
    });

    test('computes every-N next due date for current, future and next-cycle zones', () {
      final projectWithState = project.copyProjectWith(
        rotationCurrentGroupId: office.id,
        rotationCurrentPeriodStart: DateTime(2026, 7, 23),
        rotationCycleNumber: 3,
      );
      final currentZoneTask = Task(
        title: 'Current zone',
        organizers: [projectRef(project)],
        rotationGroupId: office.id,
        rotationFrequencyType: RotationFrequencyType.everyNRotations,
        rotationEveryN: 2,
        rotationLastCompletedAtOccurrence: 1,
      );
      final futureZoneTask = Task(
        title: 'Future zone',
        organizers: [projectRef(project)],
        rotationGroupId: kitchen.id,
        rotationFrequencyType: RotationFrequencyType.everyNRotations,
        rotationEveryN: 2,
        rotationLastCompletedAtOccurrence: 1,
      );

      expect(
        RotationService.nextDueDateForEveryN(
          currentZoneTask,
          projectWithState,
          now: DateTime(2026, 7, 25),
        ),
        DateTime(2026, 7, 23),
      );
      expect(
        RotationService.nextDueDateForEveryN(
          futureZoneTask,
          projectWithState,
          now: DateTime(2026, 7, 25),
        ),
        DateTime(2026, 7, 30),
      );

      final kitchenActive = project.copyProjectWith(
        rotationCurrentGroupId: kitchen.id,
        rotationCurrentPeriodStart: DateTime(2026, 7, 30),
        rotationCycleNumber: 3,
      );
      expect(
        RotationService.nextDueDateForEveryN(
          currentZoneTask,
          kitchenActive,
          now: DateTime(2026, 8, 1),
        ),
        DateTime(2026, 8, 6),
      );
    });

    test('stores rotation schedule overrides by day, occurrence, and future default', () {
      final status = RotationStatus(
        group: office,
        dayOfPeriod: 1,
        periodStart: DateTime(2026, 7, 23),
        periodEnd: DateTime(2026, 7, 29),
        occurrenceNumber: 4,
      );

      final future = RotationService.applyScheduleOverride(
        project,
        status: status,
        date: DateTime(2026, 7, 23),
        time: '10:30',
        durationMinutes: 75,
        scope: 'future',
      );
      expect(RotationService.scheduleForStatus(future, status, DateTime(2026, 7, 23)).time, '10:30');

      final day = RotationService.applyScheduleOverride(
        future,
        status: status,
        date: DateTime(2026, 7, 24),
        time: '14:00',
        durationMinutes: 30,
        scope: 'day',
      );
      expect(RotationService.scheduleForStatus(day, status, DateTime(2026, 7, 24)).durationMinutes, 30);
      expect(RotationService.scheduleForStatus(day, status, DateTime(2026, 7, 25)).time, '10:30');

      final occurrence = RotationService.applyScheduleOverride(
        future,
        status: status,
        date: DateTime(2026, 7, 24),
        time: '16:00',
        durationMinutes: 45,
        scope: 'occurrence',
      );
      expect(RotationService.scheduleForStatus(occurrence, status, DateTime(2026, 7, 25)).time, '16:00');
    });
  });

  group('project progress', () {
    test('counts organizer-linked tasks', () {
      final project = Project(id: 'project-1', title: 'Launch');
      final done = Task(
        title: 'Done',
        stage: TaskStage.finalized,
        organizers: [projectRef(project)],
      );
      final todo = Task(
        title: 'Todo',
        stage: TaskStage.todo,
        organizers: [projectRef(project)],
      );

      ProjectProgressCache.clearCache();

      expect(
        ProjectProgressCache.getLinkedTaskCount(project.id, project, [
          done,
          todo,
        ]),
        2,
      );
      expect(
        ProjectProgressCache.getCompletedTaskCount(project.id, project, [
          done,
          todo,
        ]),
        1,
      );
      expect(KPIEngine.calculateProjectProgress(project, [done, todo]), 0.5);
    });

    test('keeps explicit task links working', () {
      final linked = Task(
        id: 'task-a',
        title: 'Linked',
        stage: TaskStage.finalized,
      );
      final project = Project(
        id: 'project-2',
        title: 'Launch',
        taskLinks: [linked.id],
      );

      ProjectProgressCache.clearCache();

      expect(
        ProjectProgressCache.getLinkedTaskCount(project.id, project, [linked]),
        1,
      );
      expect(KPIEngine.calculateProjectProgress(project, [linked]), 1.0);
    });
  });
}
