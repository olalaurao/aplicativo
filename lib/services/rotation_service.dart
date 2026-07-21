import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../ui/theme.dart';

class RotationStatus {
  final RotationGroup group;
  final int dayOfPeriod;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int occurrenceNumber;

  const RotationStatus({
    required this.group,
    required this.dayOfPeriod,
    required this.periodStart,
    required this.periodEnd,
    required this.occurrenceNumber,
  });
}

class RotationService {
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String dateKey(DateTime d) => _dateKey(d);

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static RotationStatus? computeActiveStatus(Project project, {DateTime? now}) {
    if (!project.hasRotation) return null;
    final today = _dateOnly(now ?? DateTime.now());
    
    // Bootstrap: first evaluation, set initial state
    if (project.rotationCurrentGroupId == null) {
      final groups = [...project.rotationGroups]..sort((a, b) => a.order.compareTo(b.order));
      if (groups.isEmpty) return null;
      final firstGroup = groups.first;
      final start = _dateOnly(project.rotationStartDate!);
      return RotationStatus(
        group: firstGroup,
        dayOfPeriod: today.difference(start).inDays + 1,
        periodStart: start,
        periodEnd: start.add(Duration(days: firstGroup.periodDays - 1)),
        occurrenceNumber: 1,
      );
    }
    
    // Use persisted state
    final currentGroupId = project.rotationCurrentGroupId!;
    final periodStart = _dateOnly(project.rotationCurrentPeriodStart!);
    final currentGroup = project.rotationGroups.firstWhere((g) => g.id == currentGroupId);
    final dayOfPeriod = today.difference(periodStart).inDays + 1;
    final periodEnd = periodStart.add(Duration(days: currentGroup.periodDays - 1));
    
    return RotationStatus(
      group: currentGroup,
      dayOfPeriod: dayOfPeriod,
      periodStart: periodStart,
      periodEnd: periodEnd,
      occurrenceNumber: project.rotationCycleNumber,
    );
  }

  static ({Project updated, bool advanced, RotationGroup? nextGroup}) checkAndAdvanceZone(
    Project project,
    List<Task> allTasks, {
    DateTime? now,
  }) {
    if (!project.hasRotation) return (updated: project, advanced: false, nextGroup: null);
    
    final today = _dateOnly(now ?? DateTime.now());
    final groups = [...project.rotationGroups]..sort((a, b) => a.order.compareTo(b.order));
    if (groups.isEmpty) return (updated: project, advanced: false, nextGroup: null);
    
    // Bootstrap if needed
    var currentGroupId = project.rotationCurrentGroupId;
    var periodStart = project.rotationCurrentPeriodStart;
    var cycleNumber = project.rotationCycleNumber;
    
    if (currentGroupId == null) {
      currentGroupId = groups.first.id;
      periodStart = _dateOnly(project.rotationStartDate!);
      cycleNumber = 1;
    }
    
    final currentGroup = groups.firstWhere((g) => g.id == currentGroupId);
    final periodEnd = _dateOnly(periodStart!).add(Duration(days: currentGroup.periodDays - 1));
    
    // Check for early completion
    bool isZoneComplete = false;
    final zoneTasks = allTasks.where((t) => t.rotationGroupId == currentGroupId && t.isRotationTask).toList();
    
    final oncePerPeriodTasks = zoneTasks
        .where((t) => t.rotationFrequencyType == RotationFrequencyType.oncePerPeriod)
        .toList();
    final everyNTasks = zoneTasks
        .where((t) => t.rotationFrequencyType == RotationFrequencyType.everyNRotations)
        .toList();
    
    // Only check completion if there are relevant tasks
    if (oncePerPeriodTasks.isNotEmpty || everyNTasks.isNotEmpty) {
      final currentStatus = RotationStatus(
        group: currentGroup,
        dayOfPeriod: today.difference(periodStart).inDays + 1,
        periodStart: periodStart,
        periodEnd: periodEnd,
        occurrenceNumber: cycleNumber,
      );
      
      final allOnceDone = oncePerPeriodTasks.every((t) => isDoneThisOccurrence(t, currentStatus));
      final allEveryNDone = everyNTasks.every((t) => !isDueNow(t, currentStatus) || isDoneThisOccurrence(t, currentStatus));
      
      isZoneComplete = allOnceDone && allEveryNDone;
    }
    
    // Check for timeout
    final isTimeout = today.isAfter(periodEnd);
    
    if (isZoneComplete || isTimeout) {
      // Advance to next zone
      final currentIdx = groups.indexWhere((g) => g.id == currentGroupId);
      final nextIdx = (currentIdx + 1) % groups.length;
      final nextGroup = groups[nextIdx];
      
      // Increment cycle number if we wrapped around
      if (nextIdx == 0) {
        cycleNumber++;
      }
      
      return (
        updated: project.copyProjectWith(
          rotationCurrentGroupId: nextGroup.id,
          rotationCurrentPeriodStart: periodEnd.add(const Duration(days: 1)),
          rotationCycleNumber: cycleNumber,
        ),
        advanced: true,
        nextGroup: nextGroup,
      );
    }
    
    return (updated: project, advanced: false, nextGroup: null);
  }

  static List<({RotationGroup group, DateTime startsAt, DateTime endsAt})>
      upcomingGroups(Project project, {DateTime? now, int? count}) {
    final status = computeActiveStatus(project, now: now);
    if (status == null) return [];
    final groups = [...project.rotationGroups]..sort((a, b) => a.order.compareTo(b.order));
    final currentIdx = groups.indexWhere((g) => g.id == status.group.id);
    if (currentIdx < 0) return [];
    final n = count ?? groups.length - 1;
    final result = <({RotationGroup group, DateTime startsAt, DateTime endsAt})>[];
    var cursor = status.periodEnd.add(const Duration(days: 1));
    for (var i = 1; i <= n; i++) {
      final g = groups[(currentIdx + i) % groups.length];
      final endsAt = cursor.add(Duration(days: g.periodDays - 1));
      result.add((group: g, startsAt: cursor, endsAt: endsAt));
      cursor = endsAt.add(const Duration(days: 1));
    }
    return result;
  }

  static Task toggleDailyCompletion(Task task, DateTime date) {
    final key = _dateKey(date);
    final updated = Map<String, bool>.from(task.rotationDailyCompletions);
    updated[key] = !(updated[key] ?? false);
    return task.copyWith(rotationDailyCompletions: updated);
  }

  static (int done, int total) dailyProgressForPeriod(Task task, RotationStatus status) {
    var done = 0;
    for (var d = status.periodStart; !d.isAfter(status.periodEnd); d = d.add(const Duration(days: 1))) {
      if (task.rotationDailyCompletions[_dateKey(d)] == true) done++;
    }
    return (done, status.group.periodDays);
  }

  static bool isDoneThisOccurrence(Task task, RotationStatus status) =>
      task.rotationLastCompletedAtOccurrence == status.occurrenceNumber;

  static Task toggleOncePerPeriod(Task task, RotationStatus status) {
    final done = isDoneThisOccurrence(task, status);
    return task.copyWith(
      rotationLastCompletedAtOccurrence: done ? null : status.occurrenceNumber,
    );
  }

  static bool isDueNow(Task task, RotationStatus status) {
    if (task.rotationLastCompletedAtOccurrence == null) return true;
    return (status.occurrenceNumber - task.rotationLastCompletedAtOccurrence!) >=
        (task.rotationEveryN ?? 1);
  }

  static Task toggleEveryNRotations(Task task, RotationStatus status) {
    final wasDue = isDueNow(task, status);
    return task.copyWith(
      rotationLastCompletedAtOccurrence:
          wasDue ? status.occurrenceNumber : task.rotationLastCompletedAtOccurrence,
    );
  }

  static DateTime? nextDueDateForEveryN(Task task, Project project, {DateTime? now}) {
    if (task.rotationGroupId == null) return null;
    RotationGroup? group;
    for (final g in project.rotationGroups) {
      if (g.id == task.rotationGroupId) {
        group = g;
        break;
      }
    }
    if (group == null) return null;
    final lastDone = task.rotationLastCompletedAtOccurrence ?? 0;
    final n = task.rotationEveryN ?? 1;
    final targetOccurrence = lastDone + n;
    final cycleLen = project.rotationCycleLengthDays;
    final current = computeActiveStatus(project, now: now);
    if (current == null) return null;
    final occAhead = targetOccurrence - current.occurrenceNumber;
    if (occAhead <= 0 && group.id == current.group.id) return current.periodStart;
    return current.periodStart.add(Duration(days: occAhead * cycleLen));
  }
}

Color rotationFrequencyColor(RotationFrequencyType type, BuildContext ctx) =>
    switch (type) {
      RotationFrequencyType.daily => const Color(0xFF8B5CF6),
      RotationFrequencyType.oncePerPeriod => AppColors.habitOrange,
      RotationFrequencyType.everyNRotations =>
        Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
      RotationFrequencyType.none => Colors.transparent,
    };
