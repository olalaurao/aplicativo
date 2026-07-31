import 'package:flutter_test/flutter_test.dart';
import 'package:quartzo/models/scheduler.dart';
import 'package:quartzo/services/scheduler_service.dart';

void main() {
  group('SchedulerService', () {
    final DateTime baseDate = DateTime(2024, 1, 1); // Monday

    test('numberOfDays', () {
      final rule = SchedulerRule(repeatType: RepeatType.numberOfDays, interval: 3);
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      expect(SchedulerService.shouldFire(scheduler, baseDate), isTrue);
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 1))), isFalse);
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 2))), isFalse);
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 3))), isTrue); // Day 4
    });

    test('daysOfWeek', () {
      final rule = SchedulerRule(repeatType: RepeatType.daysOfWeek, daysOfWeek: ['Mon', 'Wed', 'Fri']);
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      // 2024-01-01 is Mon
      expect(SchedulerService.shouldFire(scheduler, baseDate), isTrue); // Mon
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 1))), isFalse); // Tue
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 2))), isTrue); // Wed
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 3))), isFalse); // Thu
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 4))), isTrue); // Fri
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 5))), isFalse); // Sat
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 6))), isFalse); // Sun
    });

    test('numberOfWeeks', () {
      final rule = SchedulerRule(repeatType: RepeatType.numberOfWeeks, interval: 2);
      final scheduler = Scheduler(rules: [rule], startDate: baseDate); // Start is Mon

      expect(SchedulerService.shouldFire(scheduler, baseDate), isTrue);
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 7))), isFalse); // 1 week later
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 14))), isTrue); // 2 weeks later
      // Must be on the exact same weekday
      expect(SchedulerService.shouldFire(scheduler, baseDate.add(const Duration(days: 15))), isFalse);
    });

    test('numberOfMonths', () {
      final rule = SchedulerRule(repeatType: RepeatType.numberOfMonths, interval: 1, daysOfMonth: [1, 15]);
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 1)), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 15)), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 16)), isFalse);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 2, 1)), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 2, 15)), isTrue);
    });

    test('numberOfHours', () {
      final rule = SchedulerRule(repeatType: RepeatType.numberOfHours, interval: 4);
      final scheduler = Scheduler(rules: [rule], startDate: DateTime(2024, 1, 1, 8, 0)); // Starts at 8:00

      // The rule just checks if an occurrence happens on that day.
      // So as long as the day contains an occurrence, it's true.
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 1)), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 2)), isTrue); // Every 4 hours happens every day
    });

    test('daysAfterLastStart and daysAfterLastEnd', () {
      final ruleStart = SchedulerRule(repeatType: RepeatType.daysAfterLastStart, interval: 5);
      final ruleEnd = SchedulerRule(repeatType: RepeatType.daysAfterLastEnd, interval: 5);
      
      final schedulerStart = Scheduler(rules: [ruleStart], startDate: baseDate);
      final schedulerEnd = Scheduler(rules: [ruleEnd], startDate: baseDate);
      
      final lastCompletion = DateTime(2024, 1, 10);

      expect(SchedulerService.shouldFire(schedulerStart, DateTime(2024, 1, 15), lastCompletionDate: lastCompletion), isTrue);
      expect(SchedulerService.shouldFire(schedulerStart, DateTime(2024, 1, 14), lastCompletionDate: lastCompletion), isFalse);
      
      expect(SchedulerService.shouldFire(schedulerEnd, DateTime(2024, 1, 15), lastCompletionDate: lastCompletion), isTrue);
      expect(SchedulerService.shouldFire(schedulerEnd, DateTime(2024, 1, 14), lastCompletionDate: lastCompletion), isFalse);
    });

    test('numberOfDaysPerPeriod', () {
      // 3 days per week, starting from day 0 (Mon), 2 days between occurrences (Mon, Wed, Fri)
      final rule = SchedulerRule(
        repeatType: RepeatType.numberOfDaysPerPeriod,
        period: 'week',
        countPerPeriod: 3,
        startingDayOffset: 0,
        intervalBetweenDays: 2,
      );
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      // baseDate is Monday (2024-01-01)
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 1)), isTrue); // Mon
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 2)), isFalse); // Tue
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 3)), isTrue); // Wed
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 4)), isFalse); // Thu
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 5)), isTrue); // Fri
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 6)), isFalse); // Sat
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 7)), isFalse); // Sun
    });

    test('linkedItemAppears', () {
      final rule = SchedulerRule(repeatType: RepeatType.linkedItemAppears, linkedItemId: 'task_abc');
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      bool mockIsItemScheduled(String id, DateTime date) {
        return id == 'task_abc' && date == DateTime(2024, 1, 5);
      }

      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 5), isItemScheduled: mockIsItemScheduled), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 6), isItemScheduled: mockIsItemScheduled), isFalse);
    });

    test('nDaysAfterLinkedItem', () {
      final rule = SchedulerRule(repeatType: RepeatType.nDaysAfterLinkedItem, linkedItemId: 'task_abc', interval: 2);
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      bool mockIsItemScheduled(String id, DateTime date) {
        return id == 'task_abc' && date == DateTime(2024, 1, 5);
      }

      // 2 days after 2024-01-05 is 2024-01-07
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 7), isItemScheduled: mockIsItemScheduled), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 5), isItemScheduled: mockIsItemScheduled), isFalse);
    });

    test('firstBusinessDayOfMonth', () {
      final rule = SchedulerRule(repeatType: RepeatType.firstBusinessDayOfMonth);
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      // Jan 1 2024 is Mon
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 1)), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 2)), isFalse);
      
      // Jun 1 2024 is Sat. First business day is Mon Jun 3
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 6, 1)), isFalse); // Sat
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 6, 2)), isFalse); // Sun
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 6, 3)), isTrue); // Mon
    });

    test('daysAfterReferenceField', () {
      final rule = SchedulerRule(
        repeatType: RepeatType.daysAfterReferenceField,
        targetType: 'person',
        fieldName: 'last_contact',
        interval: 3,
      );
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      DateTime? mockRefDate(String type, String field) {
        if (type == 'person' && field == 'last_contact') return DateTime(2024, 1, 10);
        return null;
      }

      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 13), referenceDateValue: mockRefDate), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 14), referenceDateValue: mockRefDate), isFalse);
    });

    test('daysOfTheme', () {
      final rule = SchedulerRule(repeatType: RepeatType.daysOfTheme, themeId: 'theme_1');
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      bool mockIsThemeActive(String id, DateTime date) {
        return id == 'theme_1' && date == DateTime(2024, 1, 10);
      }

      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 10), isThemeActive: mockIsThemeActive), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 11), isThemeActive: mockIsThemeActive), isFalse);
    });

    test('daysWithBlock', () {
      final rule = SchedulerRule(repeatType: RepeatType.daysWithBlock, blockId: 'block_1');
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);

      bool mockIsBlockActive(String id, DateTime date) {
        return id == 'block_1' && date == DateTime(2024, 1, 10);
      }

      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 10), isBlockActive: mockIsBlockActive), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 11), isBlockActive: mockIsBlockActive), isFalse);
    });

    test('shouldRestartScheduledProject', () {
      final rule = SchedulerRule(repeatType: RepeatType.numberOfDays, interval: 3);
      final scheduler = Scheduler(rules: [rule], startDate: baseDate);
      
      expect(SchedulerService.shouldRestartScheduledProject(scheduler, baseDate), isTrue);
      expect(SchedulerService.shouldRestartScheduledProject(null, baseDate), isFalse);
    });
    
    test('shouldFireReferenceFieldRule', () {
       final rule = SchedulerRule(
        repeatType: RepeatType.daysAfterReferenceField,
        targetType: 'person',
        fieldName: 'last_contact',
        interval: 3,
      );
      final refDate = DateTime(2024, 1, 10);
      
      expect(SchedulerService.shouldFireReferenceFieldRule(rule, DateTime(2024, 1, 13), refDate), isTrue);
      expect(SchedulerService.shouldFireReferenceFieldRule(rule, DateTime(2024, 1, 14), refDate), isTrue); // after
      expect(SchedulerService.shouldFireReferenceFieldRule(rule, DateTime(2024, 1, 12), refDate), isFalse); // before
    });
    
    test('exclusions prevent firing', () {
      final rule = SchedulerRule(repeatType: RepeatType.numberOfDays, interval: 1); // everyday
      final exclusion = SchedulerRule(repeatType: RepeatType.daysOfWeek, daysOfWeek: ['Sat', 'Sun']);
      
      final scheduler = Scheduler(rules: [rule], exclusions: [exclusion], startDate: baseDate); // Mon
      
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 5)), isTrue); // Fri
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 6)), isFalse); // Sat (excluded)
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 7)), isFalse); // Sun (excluded)
    });
    
    test('endDate bounds', () {
      final rule = SchedulerRule(repeatType: RepeatType.numberOfDays, interval: 1); 
      final scheduler = Scheduler(
        rules: [rule], 
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 5),
      );
      
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 4)), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 5)), isTrue);
      expect(SchedulerService.shouldFire(scheduler, DateTime(2024, 1, 6)), isFalse); // past end date
    });
  });
}
