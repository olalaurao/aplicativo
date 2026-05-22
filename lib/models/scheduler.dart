// lib/models/scheduler.dart

enum RepeatType {
  numberOfDays,
  daysOfWeek,
  numberOfWeeks,
  numberOfMonths,
  numberOfHours,
  daysAfterLastStart,
  daysAfterLastEnd,
  numberOfDaysPerPeriod,
  linkedItemAppears,
  nDaysAfterLinkedItem,
  firstBusinessDayOfMonth,
  daysOfTheme,
  daysWithBlock,
}

enum OverduePolicy { skip, keep, prompt }

enum ItemType { reminder, habitReminder }

class SchedulerRule {
  RepeatType repeatType;
  int? interval; // For number_of_days, etc.
  List<String>? daysOfWeek; // For days_of_week
  List<int>? daysOfMonth; // For number_of_months
  String? linkedItemId; // For linked_item_appears, etc.
  int? countPerPeriod; // For number_of_days_per_period
  String? period; // week, month, year
  int? startingDayOffset;
  int? intervalBetweenDays;
  String? themeId;
  String? blockId;

  SchedulerRule({
    required this.repeatType,
    this.interval,
    this.daysOfWeek,
    this.daysOfMonth,
    this.linkedItemId,
    this.countPerPeriod,
    this.period,
    this.startingDayOffset,
    this.intervalBetweenDays,
    this.themeId,
    this.blockId,
  });

  Map<String, dynamic> toMap() {
    return {
      'repeat_type': repeatType.name,
      'interval': interval,
      'days_of_week': daysOfWeek,
      'days_of_month': daysOfMonth,
      'linked_item_id': linkedItemId,
      'count_per_period': countPerPeriod,
      'period': period,
      'starting_day_offset': startingDayOffset,
      'interval_between_days': intervalBetweenDays,
      'theme_id': themeId,
      'block_id': blockId,
    };
  }

  factory SchedulerRule.fromMap(Map<String, dynamic> map) {
    return SchedulerRule(
      repeatType: RepeatType.values.firstWhere(
        (e) => e.name == map['repeat_type'],
        orElse: () => RepeatType.numberOfDays,
      ),
      interval: map['interval'] as int?,
      daysOfWeek: map['days_of_week'] != null
          ? List<String>.from(map['days_of_week'])
          : null,
      daysOfMonth: map['days_of_month'] != null
          ? List<int>.from(map['days_of_month'])
          : null,
      linkedItemId: map['linked_item_id'] as String?,
      countPerPeriod: map['count_per_period'] as int?,
      period: map['period'] as String?,
      startingDayOffset: map['starting_day_offset'] as int?,
      intervalBetweenDays: map['interval_between_days'] as int?,
      themeId: map['theme_id'] as String?,
      blockId: map['block_id'] as String?,
    );
  }
}

class Scheduler {
  List<SchedulerRule> rules;
  List<SchedulerRule> exclusions;
  DateTime startDate;
  DateTime? endDate;
  DateTime? nextInstanceDate;
  int? maxOccurrences;
  OverduePolicy overduePolicy;
  String? timeBlock;
  DateTime? exactTime;
  ItemType itemType;

  Scheduler({
    required this.rules,
    this.exclusions = const [],
    required this.startDate,
    this.endDate,
    this.nextInstanceDate,
    this.maxOccurrences,
    this.overduePolicy = OverduePolicy.keep,
    this.timeBlock,
    this.exactTime,
    this.itemType = ItemType.reminder,
  });

  Map<String, dynamic> toMap() {
    return {
      'rules': rules.map((e) => e.toMap()).toList(),
      'exclusions': exclusions.map((e) => e.toMap()).toList(),
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'next_instance_date': nextInstanceDate?.toIso8601String(),
      'max_occurrences': maxOccurrences,
      'overdue_policy': overduePolicy.name,
      'time_block': timeBlock,
      'exact_time': exactTime?.toIso8601String(),
      'item_type': itemType.name,
    };
  }

  factory Scheduler.fromMap(Map<String, dynamic> map) {
    return Scheduler(
      rules: map['rules'] != null
          ? (map['rules'] as List)
                .map((e) => SchedulerRule.fromMap(e as Map<String, dynamic>))
                .toList()
          : [],
      exclusions: map['exclusions'] != null
          ? (map['exclusions'] as List)
                .map((e) => SchedulerRule.fromMap(e as Map<String, dynamic>))
                .toList()
          : [],
      startDate: DateTime.tryParse(map['start_date'] ?? '') ?? DateTime.now(),
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'])
          : null,
      nextInstanceDate: map['next_instance_date'] != null
          ? DateTime.tryParse(map['next_instance_date'])
          : null,
      maxOccurrences: map['max_occurrences'] as int?,
      overduePolicy: OverduePolicy.values.firstWhere(
        (e) => e.name == map['overdue_policy'],
        orElse: () => OverduePolicy.keep,
      ),
      timeBlock: map['time_block'] as String?,
      exactTime: map['exact_time'] != null
          ? DateTime.tryParse(map['exact_time'])
          : null,
      itemType: ItemType.values.firstWhere(
        (e) => e.name == map['item_type'],
        orElse: () => ItemType.reminder,
      ),
    );
  }
}
