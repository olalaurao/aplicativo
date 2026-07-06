// lib/services/scheduler_service.dart
import '../models/scheduler.dart';

class SchedulerService {
  /// Returns true when a scheduled organizer/project should be considered
  /// active again for [date]. Callers own the actual state mutation so the
  /// app does not silently rewrite vault objects during read-only views.
  static bool shouldRestartScheduledProject(
    Scheduler? scheduler,
    DateTime date, {
    DateTime? lastCompletionDate,
  }) {
    if (scheduler == null) return false;
    return shouldFire(scheduler, date, lastCompletionDate: lastCompletionDate);
  }

  static bool shouldFire(
    Scheduler scheduler,
    DateTime date, {
    DateTime? lastCompletionDate,
    bool Function(String id, DateTime date)? isItemScheduled,
    bool Function(String themeId, DateTime date)? isThemeActive,
    bool Function(String blockId, DateTime date)? isBlockActive,
    DateTime? Function(String targetType, String fieldName)? referenceDateValue,
  }) {
    // 1. Check basic bounds
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(
      scheduler.startDate.year,
      scheduler.startDate.month,
      scheduler.startDate.day,
    );

    if (normalizedDate.isBefore(normalizedStart)) return false;
    if (scheduler.endDate != null) {
      final normalizedEnd = DateTime(
        scheduler.endDate!.year,
        scheduler.endDate!.month,
        scheduler.endDate!.day,
      );
      if (normalizedDate.isAfter(normalizedEnd)) return false;
    }

    // 2. Check exclusions
    for (final exclusion in scheduler.exclusions) {
      if (_ruleMatches(
        exclusion,
        date,
        scheduler.startDate,
        isItemScheduled,
        lastCompletionDate,
        isThemeActive,
        isBlockActive,
        referenceDateValue,
      )) {
        return false;
      }
    }

    // 3. Check rules (OR condition)
    if (scheduler.rules.isEmpty) return false;

    for (final rule in scheduler.rules) {
      if (_ruleMatches(
        rule,
        date,
        scheduler.startDate,
        isItemScheduled,
        lastCompletionDate,
        isThemeActive,
        isBlockActive,
        referenceDateValue,
      )) {
        return true;
      }
    }

    return false;
  }

  static bool _ruleMatches(
    SchedulerRule rule,
    DateTime date,
    DateTime startDate,
    bool Function(String, DateTime)? isItemScheduled,
    DateTime? lastCompletionDate,
    bool Function(String, DateTime)? isThemeActive,
    bool Function(String, DateTime)? isBlockActive,
    DateTime? Function(String targetType, String fieldName)? referenceDateValue,
  ) {
    switch (rule.repeatType) {
      case RepeatType.numberOfDays:
        if (rule.interval == null || rule.interval == 0) return false;
        final diff = date
            .difference(
              DateTime(startDate.year, startDate.month, startDate.day),
            )
            .inDays;
        return diff >= 0 && diff % rule.interval! == 0;

      case RepeatType.daysOfWeek:
        if (rule.daysOfWeek == null) return false;
        final weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final currentDayName = weekDayNames[date.weekday - 1];
        return rule.daysOfWeek!.contains(currentDayName);

      case RepeatType.numberOfWeeks:
        if (rule.interval == null || rule.interval == 0) return false;
        final startMonday = startDate.subtract(
          Duration(days: startDate.weekday - 1),
        );
        final targetMonday = date.subtract(Duration(days: date.weekday - 1));
        final diffWeeks = targetMonday.difference(startMonday).inDays ~/ 7;
        return diffWeeks >= 0 &&
            diffWeeks % rule.interval! == 0 &&
            date.weekday == startDate.weekday;

      case RepeatType.numberOfMonths:
        if (rule.interval == null || rule.interval == 0) return false;
        final monthDiff =
            (date.year - startDate.year) * 12 + (date.month - startDate.month);
        if (monthDiff < 0 || monthDiff % rule.interval! != 0) return false;

        if (rule.daysOfMonth != null && rule.daysOfMonth!.isNotEmpty) {
          return rule.daysOfMonth!.contains(date.day);
        }
        return date.day == startDate.day;

      case RepeatType.linkedItemAppears:
        if (rule.linkedItemId == null || isItemScheduled == null) return false;
        return isItemScheduled(rule.linkedItemId!, date);

      case RepeatType.nDaysAfterLinkedItem:
        if (rule.linkedItemId == null ||
            rule.interval == null ||
            isItemScheduled == null) {
          return false;
        }
        final targetDate = date.subtract(Duration(days: rule.interval!));
        return isItemScheduled(rule.linkedItemId!, targetDate);

      case RepeatType.firstBusinessDayOfMonth:
        if (date.day > 3) return false;
        DateTime firstDay = DateTime(date.year, date.month, 1);
        while (firstDay.weekday > 5) {
          firstDay = firstDay.add(const Duration(days: 1));
        }
        return date.day == firstDay.day;

      case RepeatType.numberOfHours:
        if (rule.interval == null || rule.interval == 0) return false;
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        // Find first 'i' such that startDate + i*interval >= startOfDay
        final diffMinutes = startOfDay.difference(startDate).inMinutes;
        int firstI = (diffMinutes / (rule.interval! * 60)).ceil();
        if (firstI < 0) firstI = 0;

        final occurrence = startDate.add(
          Duration(hours: firstI * rule.interval!),
        );
        return occurrence.isBefore(endOfDay);

      case RepeatType.daysAfterLastStart:
      case RepeatType.daysAfterLastEnd:
        if (rule.interval == null || lastCompletionDate == null) return false;
        final refDate = DateTime(
          lastCompletionDate.year,
          lastCompletionDate.month,
          lastCompletionDate.day,
        );
        final target = refDate.add(Duration(days: rule.interval!));
        return date.year == target.year &&
            date.month == target.month &&
            date.day == target.day;

      case RepeatType.numberOfDaysPerPeriod:
        if (rule.countPerPeriod == null || rule.period == null) return false;

        // Calculate period bounds
        DateTime periodStart;
        if (rule.period == 'week') {
          periodStart = date.subtract(Duration(days: date.weekday - 1));
        } else if (rule.period == 'month') {
          periodStart = DateTime(date.year, date.month, 1);
        } else {
          // year
          periodStart = DateTime(date.year, 1, 1);
        }

        // Starting day offset within period
        final actualStart = periodStart.add(
          Duration(days: rule.startingDayOffset ?? 0),
        );
        if (date.isBefore(actualStart)) return false;

        // Interval between days logic (simplified: every N days within period until count is reached)
        final daysSinceActualStart = date.difference(actualStart).inDays;
        final interval = rule.intervalBetweenDays ?? 1;

        if (daysSinceActualStart % interval != 0) return false;

        final occurrenceIndex = daysSinceActualStart ~/ interval;
        return occurrenceIndex < rule.countPerPeriod!;

      case RepeatType.daysOfTheme:
        if (rule.themeId == null || isThemeActive == null) return false;
        return isThemeActive(rule.themeId!, date);

      case RepeatType.daysWithBlock:
        if (rule.blockId == null || isBlockActive == null) return false;
        return isBlockActive(rule.blockId!, date);

      case RepeatType.daysAfterReferenceField:
        // V5: fires N days after any date-type field on any object
        // Config: { targetType, fieldName, days }
        if (rule.targetType == null || rule.fieldName == null || rule.interval == null) {
          return false;
        }
        if (referenceDateValue == null) return false;
        
        final refDate = referenceDateValue(rule.targetType!, rule.fieldName!);
        if (refDate == null) return false;
        
        final normalizedRefDate = DateTime(refDate.year, refDate.month, refDate.day);
        final normalizedDate = DateTime(date.year, date.month, date.day);
        
        final targetDate = normalizedRefDate.add(Duration(days: rule.interval!));
        return normalizedDate.isAtSameMomentAs(targetDate);
    }
  }

  /// F2.13: Check if a daysAfterReferenceField rule should fire for a specific object
  /// This is called by the consumer (e.g., Person) to evaluate the rule against
  /// the object's actual date field value.
  static bool shouldFireReferenceFieldRule(
    SchedulerRule rule,
    DateTime date,
    DateTime? referenceDateValue,
  ) {
    if (rule.repeatType != RepeatType.daysAfterReferenceField) return false;
    if (referenceDateValue == null || rule.interval == null) return false;

    final normalizedRefDate = DateTime(
      referenceDateValue.year,
      referenceDateValue.month,
      referenceDateValue.day,
    );
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final targetDate = normalizedRefDate.add(Duration(days: rule.interval!));
    return normalizedDate.isAtSameMomentAs(targetDate) || normalizedDate.isAfter(targetDate);
  }

  static DateTime? nextOccurrence(Scheduler scheduler, {DateTime? after}) {
    DateTime current = after ?? DateTime.now();
    current = DateTime(
      current.year,
      current.month,
      current.day,
    ).add(const Duration(days: 1));

    // Look ahead 2 years max to avoid infinite loops
    final maxDate = current.add(const Duration(days: 365 * 2));

    while (current.isBefore(maxDate)) {
      if (shouldFire(scheduler, current)) {
        return current;
      }
      current = current.add(const Duration(days: 1));
    }
    return null;
  }
}
