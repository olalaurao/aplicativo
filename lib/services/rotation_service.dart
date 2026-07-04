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
    final start = _dateOnly(project.rotationStartDate!);
    final daysSince = today.difference(start).inDays;
    if (daysSince < 0) return null;
    final cycleLen = project.rotationCycleLengthDays;
    if (cycleLen == 0) return null;
    final fullCycles = daysSince ~/ cycleLen;
    final posInCycle = daysSince % cycleLen;
    final groups = [...project.rotationGroups]..sort((a, b) => a.order.compareTo(b.order));
    var cum = 0;
    for (final g in groups) {
      if (posInCycle < cum + g.periodDays) {
        final dayOfPeriod = posInCycle - cum + 1;
        final periodStart = start.add(Duration(days: fullCycles * cycleLen + cum));
        final periodEnd = periodStart.add(Duration(days: g.periodDays - 1));
        return RotationStatus(
          group: g,
          dayOfPeriod: dayOfPeriod,
          periodStart: periodStart,
          periodEnd: periodEnd,
          occurrenceNumber: fullCycles + 1,
        );
      }
      cum += g.periodDays;
    }
    return null;
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
