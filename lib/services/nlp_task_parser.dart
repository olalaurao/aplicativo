import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/scheduler.dart';

class ParsedNlpTask {
  final String cleanTitle;
  final TaskPriority? priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? scheduledTime;
  final Scheduler? scheduler;

  ParsedNlpTask({
    required this.cleanTitle,
    this.priority,
    this.startDate,
    this.endDate,
    this.scheduledTime,
    this.scheduler,
  });

  bool get hasAnyDetection =>
      priority != null ||
      startDate != null ||
      endDate != null ||
      scheduledTime != null ||
      scheduler != null;
}

class NlpTaskParser {
  // Static regex patterns - compiled once per app lifetime
  static final RegExp _highPriorityRegex = RegExp(
      r'(?<=^|\s|[.,!?;])(alta prioridade|prioridade alta|prio alta|high priority|!high|!alta)(?=$|\s|[.,!?;])',
      caseSensitive: false);
  static final RegExp _mediumPriorityRegex = RegExp(
      r'(?<=^|\s|[.,!?;])(m[eé]dia prioridade|prioridade m[eé]dia|prio m[eé]dia|medium priority|!medium|!media)(?=$|\s|[.,!?;])',
      caseSensitive: false);
  static final RegExp _lowPriorityRegex = RegExp(
      r'(?<=^|\s|[.,!?;])(baixa prioridade|prioridade baixa|prio baixa|low priority|!low|!baixa)(?=$|\s|[.,!?;])',
      caseSensitive: false);
  static final RegExp _timeRegex = RegExp(
      r'(?<=^|\s|[.,!?;])(às|as|at)\s+(\d{1,2})[:h](\d{2})?(?=$|\s|[.,!?;])',
      caseSensitive: false);
  static final RegExp _timeRegexOnlyHour = RegExp(
      r'(?<=^|\s|[.,!?;])(às|as|at)\s+(\d{1,2})\s*h(?=$|\s|[.,!?;])',
      caseSensitive: false);
  static final RegExp _everyDayRegex = RegExp(
      r'(?<=^|\s|[.,!?;])(todo dia|todos os dias|diariamente|every day|daily)(?=$|\s|[.,!?;])',
      caseSensitive: false);
  static final RegExp _everyWeekRegex = RegExp(
      r'(?<=^|\s|[.,!?;])(toda semana|semanalmente|every week|weekly)(?=$|\s|[.,!?;])',
      caseSensitive: false);
  static final RegExp _everyMonthRegex = RegExp(
      r'(?<=^|\s|[.,!?;])(todo m[eê]s|mensalmente|every month|monthly)(?=$|\s|[.,!?;])',
      caseSensitive: false);
  static final RegExp _segRegex = RegExp(r'(?<=^|\s|[.,!?;])(toda segunda|todas as segundas|every monday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _terRegex = RegExp(r'(?<=^|\s|[.,!?;])(toda ter[cç]a|todas as ter[cç]as|every tuesday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _quaRegex = RegExp(r'(?<=^|\s|[.,!?;])(toda quarta|todas as quartas|every wednesday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _quiRegex = RegExp(r'(?<=^|\s|[.,!?;])(toda quinta|todas as quintas|every thursday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _sexRegex = RegExp(r'(?<=^|\s|[.,!?;])(toda sexta|todas as sextas|every friday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _sabRegex = RegExp(r'(?<=^|\s|[.,!?;])(todo s[aá]bado|todos os s[aá]bados|every saturday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _domRegex = RegExp(r'(?<=^|\s|[.,!?;])(todo domingo|todos os domingos|every sunday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _todayRegex = RegExp(r'(?<=^|\s|[.,!?;])(hoje|today)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _tomorrowRegex = RegExp(r'(?<=^|\s|[.,!?;])(amanh[aã]|tomorrow)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _afterTomorrowRegex = RegExp(r'(?<=^|\s|[.,!?;])(depois de amanh[aã]|day after tomorrow)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _segSingle = RegExp(r'(?<=^|\s|[.,!?;])(segunda-feira|segunda|monday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _terSingle = RegExp(r'(?<=^|\s|[.,!?;])(ter[cç]a-feira|ter[cç]a|tuesday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _quaSingle = RegExp(r'(?<=^|\s|[.,!?;])(quarta-feira|quarta|wednesday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _quiSingle = RegExp(r'(?<=^|\s|[.,!?;])(quinta-feira|quinta|thursday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _sexSingle = RegExp(r'(?<=^|\s|[.,!?;])(sexta-feira|sexta|friday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _sabSingle = RegExp(r'(?<=^|\s|[.,!?;])(s[aá]bado|saturday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _domSingle = RegExp(r'(?<=^|\s|[.,!?;])(domingo|sunday)(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _slashDateRegex = RegExp(r'(?<=^|\s|[.,!?;])(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?(?=$|\s|[.,!?;])');
  static final RegExp _dayXRegex = RegExp(r'(?<=^|\s|[.,!?;])(?:dia|day)\s+(\d{1,2})(?=$|\s|[.,!?;])', caseSensitive: false);
  static final RegExp _whitespaceRegex = RegExp(r'\s+');
  static final RegExp _trailingPrepositionRegex = RegExp(r'\b(para|para o|pro|pra|para a|at|on|for|in|no|na|em|de|do|da|com|at[eé]|com)\s*$');

  static ParsedNlpTask parse(String text) {
    if (text.trim().isEmpty) {
      return ParsedNlpTask(cleanTitle: text);
    }

    String workingText = text;

    // 1. Detect Priority
    TaskPriority? detectedPriority;

    if (_highPriorityRegex.hasMatch(workingText)) {
      detectedPriority = TaskPriority.high;
      workingText = workingText.replaceAll(_highPriorityRegex, '');
    } else if (_mediumPriorityRegex.hasMatch(workingText)) {
      detectedPriority = TaskPriority.medium;
      workingText = workingText.replaceAll(_mediumPriorityRegex, '');
    } else if (_lowPriorityRegex.hasMatch(workingText)) {
      detectedPriority = TaskPriority.low;
      workingText = workingText.replaceAll(_lowPriorityRegex, '');
    }

    // 2. Detect Scheduled Time
    TimeOfDay? detectedTime;

    var timeMatch = _timeRegex.firstMatch(workingText);
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(2) ?? '');
      final minute = int.tryParse(timeMatch.group(3) ?? '') ?? 0;
      if (hour != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        detectedTime = TimeOfDay(hour: hour, minute: minute);
        workingText = workingText.replaceAll(timeMatch.group(0)!, '');
      }
    } else {
      timeMatch = _timeRegexOnlyHour.firstMatch(workingText);
      if (timeMatch != null) {
        final hour = int.tryParse(timeMatch.group(2) ?? '');
        if (hour != null && hour >= 0 && hour < 24) {
          detectedTime = TimeOfDay(hour: hour, minute: 0);
          workingText = workingText.replaceAll(timeMatch.group(0)!, '');
        }
      }
    }

    // 3. Detect Recurrence/Scheduler
    Scheduler? detectedScheduler;

    if (_everyDayRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.numberOfDays,
            interval: 1,
          ),
        ],
      );
      workingText = workingText.replaceAll(_everyDayRegex, '');
    } else if (_everyWeekRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.numberOfWeeks,
            interval: 1,
          ),
        ],
      );
      workingText = workingText.replaceAll(_everyWeekRegex, '');
    } else if (_everyMonthRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.numberOfMonths,
            interval: 1,
          ),
        ],
      );
      workingText = workingText.replaceAll(_everyMonthRegex, '');
    } else if (_segRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.daysOfWeek,
            daysOfWeek: ['Mon'],
          ),
        ],
      );
      workingText = workingText.replaceAll(_segRegex, '');
    } else if (_terRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.daysOfWeek,
            daysOfWeek: ['Tue'],
          ),
        ],
      );
      workingText = workingText.replaceAll(_terRegex, '');
    } else if (_quaRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.daysOfWeek,
            daysOfWeek: ['Wed'],
          ),
        ],
      );
      workingText = workingText.replaceAll(_quaRegex, '');
    } else if (_quiRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.daysOfWeek,
            daysOfWeek: ['Thu'],
          ),
        ],
      );
      workingText = workingText.replaceAll(_quiRegex, '');
    } else if (_sexRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.daysOfWeek,
            daysOfWeek: ['Fri'],
          ),
        ],
      );
      workingText = workingText.replaceAll(_sexRegex, '');
    } else if (_sabRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.daysOfWeek,
            daysOfWeek: ['Sat'],
          ),
        ],
      );
      workingText = workingText.replaceAll(_sabRegex, '');
    } else if (_domRegex.hasMatch(workingText)) {
      detectedScheduler = Scheduler(
        startDate: DateTime.now(),
        rules: [
          SchedulerRule(
            repeatType: RepeatType.daysOfWeek,
            daysOfWeek: ['Sun'],
          ),
        ],
      );
      workingText = workingText.replaceAll(_domRegex, '');
    }

    // 4. Detect Date
    DateTime? detectedDate;
    final now = DateTime.now();

    if (_afterTomorrowRegex.hasMatch(workingText)) {
      detectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));
      workingText = workingText.replaceAll(_afterTomorrowRegex, '');
    } else if (_tomorrowRegex.hasMatch(workingText)) {
      detectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      workingText = workingText.replaceAll(_tomorrowRegex, '');
    } else if (_todayRegex.hasMatch(workingText)) {
      detectedDate = DateTime(now.year, now.month, now.day);
      workingText = workingText.replaceAll(_todayRegex, '');
    } else {
      var slashMatch = _slashDateRegex.firstMatch(workingText);
      if (slashMatch != null) {
        final day = int.tryParse(slashMatch.group(1) ?? '');
        final month = int.tryParse(slashMatch.group(2) ?? '');
        var year = int.tryParse(slashMatch.group(3) ?? '') ?? now.year;
        if (year < 100) year += 2000; // Handle 2-digit years
        if (day != null && month != null && day >= 1 && day <= 31 && month >= 1 && month <= 12) {
          detectedDate = DateTime(year, month, day);
          workingText = workingText.replaceAll(slashMatch.group(0)!, '');
        }
      } else {
        // Specific day of week match (upcoming week)
        int? targetWeekday;
        RegExp? matchedRegex;
        if (_segSingle.hasMatch(workingText)) { targetWeekday = 1; matchedRegex = _segSingle; }
        else if (_terSingle.hasMatch(workingText)) { targetWeekday = 2; matchedRegex = _terSingle; }
        else if (_quaSingle.hasMatch(workingText)) { targetWeekday = 3; matchedRegex = _quaSingle; }
        else if (_quiSingle.hasMatch(workingText)) { targetWeekday = 4; matchedRegex = _quiSingle; }
        else if (_sexSingle.hasMatch(workingText)) { targetWeekday = 5; matchedRegex = _sexSingle; }
        else if (_sabSingle.hasMatch(workingText)) { targetWeekday = 6; matchedRegex = _sabSingle; }
        else if (_domSingle.hasMatch(workingText)) { targetWeekday = 7; matchedRegex = _domSingle; }

        if (targetWeekday != null && matchedRegex != null) {
          int daysToAdd = targetWeekday - now.weekday;
          if (daysToAdd <= 0) daysToAdd += 7; // Next week's instance
          detectedDate = DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
          workingText = workingText.replaceAll(matchedRegex, '');
        } else {
          final dayXMatch = _dayXRegex.firstMatch(workingText);
          if (dayXMatch != null) {
            final day = int.tryParse(dayXMatch.group(1) ?? '');
            if (day != null && day >= 1 && day <= 31) {
              // If day has passed in this month, assume next month
              var targetMonth = now.month;
              var targetYear = now.year;
              if (day < now.day) {
                targetMonth++;
                if (targetMonth > 12) {
                  targetMonth = 1;
                  targetYear++;
                }
              }
              detectedDate = DateTime(targetYear, targetMonth, day);
              workingText = workingText.replaceAll(dayXMatch.group(0)!, '');
            }
          }
        }
      }
    }

    // Clean up title text by removing double spaces, trailing prepositions, and trim
    String cleanTitle = workingText
        .replaceAll(_whitespaceRegex, ' ')
        .replaceAll(_trailingPrepositionRegex, '')
        .trim();

    if (cleanTitle.isEmpty) {
      cleanTitle = text.trim();
    }

    return ParsedNlpTask(
      cleanTitle: cleanTitle,
      priority: detectedPriority,
      startDate: detectedDate,
      endDate: detectedDate, // Default endDate to match startDate
      scheduledTime: detectedTime,
      scheduler: detectedScheduler,
    );
  }
}
