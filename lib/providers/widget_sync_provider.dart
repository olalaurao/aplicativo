// lib/providers/widget_sync_provider.dart
//
// Reacts to vault changes and pushes dashboard-style snapshots to Android widgets.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;

import '../models/content_object.dart';
import '../models/goal_model.dart';
import '../models/habit_model.dart';
import '../models/journal_entry.dart';
import '../models/dashboard_block.dart';
import '../models/note_model.dart';
import '../models/organizer_model.dart';
import '../models/pomodoro_session.dart';
import '../models/reminder_model.dart';
import '../models/resource_model.dart';
import '../models/task_model.dart';
import '../services/scheduler_service.dart';
import '../services/widget_service.dart';
import 'dashboard_provider.dart';
import 'pomodoro_provider.dart';
import 'vault_provider.dart';
import 'google_calendar_provider.dart';
import 'settings_provider.dart';

const _maxWidgetDayItems = 50;

class _Debouncer {
  final Duration delay;
  Timer? _timer;

  _Debouncer({required this.delay});

  void run(Future<void> Function() fn) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      fn();
    });
  }

  void dispose() => _timer?.cancel();
}

final widgetSyncProvider = Provider<void>((ref) {
  final debouncer = _Debouncer(delay: const Duration(milliseconds: 700));

  final allObjects = ref.watch(allObjectsProvider).valueOrNull;
  final pomodoro = ref.watch(pomodoroProvider);
  final blocks = ref.watch(dashboardProvider).valueOrNull ?? [];
  final settings = ref.watch(settingsProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
  final isMonthWidget = settings.calendarWidgetType == 'month';
  final googleStart = isMonthWidget
      ? DateTime(today.year, today.month, 1)
      : startOfWeek;
  final googleDays = isMonthWidget
      ? DateTime(today.year, today.month + 1, 0).day
      : 35;
  final googleEventsAsync = ref.watch(
    googleCalendarRangeEventsProvider(
      GoogleCalendarParams(startDate: googleStart, days: googleDays),
    ),
  );
  final googleEvents = googleEventsAsync.valueOrNull ?? [];

  final prefs = ref.watch(sharedPreferencesProvider);
  final offset = prefs.getInt('calendarWidgetOffset') ?? 0;

  if (allObjects != null) {
    debouncer.run(() async {
      await _updateAllWidgets(
        allObjects,
        pomodoro.history,
        blocks,
        settings,
        googleEvents,
        offset,
      );
    });
  }

  ref.onDispose(debouncer.dispose);
});

Future<void> forceWidgetSync(ProviderContainer container) async {
  try {
    final allObjects = await container.read(allObjectsProvider.future);
    final pomodoro = container.read(pomodoroProvider);
    final blocks = container.read(dashboardProvider).valueOrNull ?? [];
    final settings = container.read(settingsProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final isMonthWidget = settings.calendarWidgetType == 'month';
    final googleStart = isMonthWidget
        ? DateTime(today.year, today.month, 1)
        : startOfWeek;
    final googleDays = isMonthWidget
        ? DateTime(today.year, today.month + 1, 0).day
        : 35;

    List<calendar.Event> googleEvents = [];
    try {
      googleEvents = await container.read(
        googleCalendarRangeEventsProvider(
          GoogleCalendarParams(startDate: googleStart, days: googleDays),
        ).future,
      );
    } catch (_) {}

    final prefs = container.read(sharedPreferencesProvider);
    final offset = prefs.getInt('calendarWidgetOffset') ?? 0;

    await _updateAllWidgets(
      allObjects,
      pomodoro.history,
      blocks,
      settings,
      googleEvents,
      offset,
    );
  } catch (e, st) {
    debugPrint('[WidgetSync] forceWidgetSync failed: $e\n$st');
  }
}

Future<void> _updateAllWidgets(
  List<ContentObject> allObjects,
  List<PomodoroSession> pomodoroHistory,
  List<DashboardBlock> dashboardBlocks,
  AppSettings settings,
  List<calendar.Event> googleEvents,
  int offset,
) async {
  try {
    final calendar = _buildCalendarSnapshot(
      allObjects,
      settings,
      googleEvents,
      offset,
    );
    final filter = _buildFilterSnapshot(allObjects, dashboardBlocks, settings);
    final pomodoro = _buildPomodoroSnapshot(pomodoroHistory);
    await WidgetService.updateDashboardWidgets(
      calendar: calendar,
      filter: filter,
      pomodoro: pomodoro,
    );
  } catch (e, st) {
    debugPrint('[WidgetSync] failed: $e\n$st');
  }
}

@visibleForTesting
Map<String, dynamic> buildCalendarSnapshotForTest(
  List<ContentObject> objects,
  AppSettings settings,
  List<calendar.Event> googleEvents,
  int offset,
) {
  return _buildCalendarSnapshot(objects, settings, googleEvents, offset);
}

@visibleForTesting
Map<String, dynamic> buildFilterSnapshotForTest(
  List<ContentObject> allObjects,
  List<DashboardBlock> dashboardBlocks, [
  AppSettings? settings,
]) {
  return _buildFilterSnapshot(allObjects, dashboardBlocks, settings);
}

Map<String, dynamic> _buildCalendarSnapshot(
  List<ContentObject> objects,
  AppSettings settings,
  List<calendar.Event> googleEvents,
  int offset,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tasks = objects.whereType<Task>().toList();
  final habits = objects.whereType<Habit>().toList();
  final reminders = objects.whereType<Reminder>().toList();

  final mode = settings.calendarWidgetType; // 'day', 'week', 'month'
  const dayHeaders = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  if (mode == 'day') {
    // offset shifts by days
    final focusDay = today.add(Duration(days: offset));
    final items = _dayItems(
      focusDay,
      tasks,
      habits,
      reminders,
      googleEvents,
      settings,
    );

    return {
      'title': 'Calendário',
      'mode': 'day',
      'selectedTitle': _capitalizeWords(
        DateFormat("d 'de' MMMM", 'pt_BR').format(focusDay),
      ),
      'selectedSubtitle': DateFormat('EEEE', 'pt_BR').format(focusDay),
      'subtitle': '${items.length} ${items.length == 1 ? 'tarefa' : 'tarefas'}',
      'items': items.take(_maxWidgetDayItems).toList(),
      'days': <Map<String, dynamic>>[], // strip hidden in day mode
    };
  } else if (mode == 'week') {
    // offset shifts by weeks
    final baseMonday = today.subtract(Duration(days: today.weekday - 1));
    final focusMonday = baseMonday.add(Duration(days: offset * 7));

    // Build day strip
    final days = List.generate(7, (i) {
      final date = focusMonday.add(Duration(days: i));
      final dayItems = _dayItems(
        date,
        tasks,
        habits,
        reminders,
        googleEvents,
        settings,
      );
      return {
        'dayHeader': dayHeaders[i],
        'dayNum': '${date.day}',
        'dateStr': _dateKey(date),
        'isSelected': _isSameDay(date, today),
        'hasDots': dayItems.isNotEmpty,
        'dotCount': dayItems.length.clamp(0, 3),
        'items': dayItems.take(_maxWidgetDayItems).toList(),
      };
    });

    // Items for today (or first day of focused week if today is outside)
    final selectedDate =
        _isSameDay(focusMonday, today) ||
            (today.isAfter(focusMonday) &&
                today.isBefore(focusMonday.add(const Duration(days: 7))))
        ? today
        : focusMonday;
    final selectedItems = _dayItems(
      selectedDate,
      tasks,
      habits,
      reminders,
      googleEvents,
      settings,
    );

    final endOfWeek = focusMonday.add(const Duration(days: 6));
    final startMonth = _shortMonth(focusMonday);
    final endMonth = _shortMonth(endOfWeek);
    final rangeStr = startMonth == endMonth
        ? '${focusMonday.day} - ${endOfWeek.day} ${_capitalize(startMonth)}'
        : '${focusMonday.day} ${_capitalize(startMonth)} - ${endOfWeek.day} ${_capitalize(endMonth)}';

    return {
      'title': 'Calendário',
      'mode': 'week',
      'selectedTitle': rangeStr,
      'selectedSubtitle': '',
      'subtitle':
          'Hoje · ${selectedItems.length} ${selectedItems.length == 1 ? 'tarefa' : 'tarefas'}',
      'items': selectedItems.take(_maxWidgetDayItems).toList(),
      'days': days,
    };
  } else {
    // month mode — offset shifts by months
    final focusMonth = DateTime(today.year, today.month + offset, 1);
    // Weekday of the 1st (DateTime.sunday = 7, we want Sunday = 0)
    final firstWeekday = focusMonth.weekday % 7; // Sun=0, Mon=1, ...

    // Build 42-cell grid
    final gridStart = focusMonth.subtract(Duration(days: firstWeekday));
    final monthGrid = List.generate(42, (i) {
      final date = gridStart.add(Duration(days: i));
      final isCurrentMonth =
          date.month == focusMonth.month && date.year == focusMonth.year;
      final dayItems = isCurrentMonth
          ? _dayItems(date, tasks, habits, reminders, googleEvents, settings)
          : <Map<String, dynamic>>[];

      // Build pills (max 3) with short titles and type-based colors
      final pillItems = dayItems.take(3).map((item) {
        return {
          'title': _truncate(item['title'] as String? ?? '', 6),
          'color': _typeColor(item['type'] as String? ?? ''),
        };
      }).toList();

      final moreCount = dayItems.length > 3 ? dayItems.length - 3 : 0;

      return {
        'dayNum': '${date.day}',
        'isCurrentMonth': isCurrentMonth,
        'isToday': _isSameDay(date, today),
        'dateStr': _dateKey(date),
        'pills': pillItems,
        'items': dayItems,
        'moreCount': moreCount,
      };
    });

    // Day headers
    final dayHeadersList = List.generate(7, (i) {
      return {'dayHeader': dayHeaders[i]};
    });

    final monthName = DateFormat('MMMM yyyy', 'pt_BR').format(focusMonth);
    final titleStr = _capitalize(monthName);

    return {
      'title': 'Calendário',
      'mode': 'month',
      'selectedTitle': titleStr,
      'selectedSubtitle': '',
      'days': dayHeadersList,
      'monthGrid': monthGrid,
    };
  }
}

String _truncate(String s, int maxLen) {
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen)}…';
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

String _capitalizeWords(String s) {
  return s
      .split(' ')
      .map((part) => part.isEmpty ? part : _capitalize(part))
      .join(' ');
}

String _shortMonth(DateTime date) {
  return _capitalize(
    DateFormat('MMM', 'pt_BR').format(date).replaceAll('.', ''),
  );
}

String _typeColor(String type) {
  switch (type) {
    case 'task':
      return '#FFE0B2'; // light orange
    case 'habit':
      return '#C8E6C9'; // light green
    case 'reminder':
      return '#FFCDD2'; // light red
    case 'google_calendar':
      return '#BBDEFB'; // light blue
    default:
      return '#E0E0E0'; // light grey
  }
}

List<Map<String, dynamic>> _dayItems(
  DateTime date,
  List<Task> tasks,
  List<Habit> habits,
  List<Reminder> reminders,
  List<calendar.Event> googleEvents,
  AppSettings settings,
) {
  final items = <Map<String, dynamic>>[];

  if (settings.calendarWidgetShowTasks) {
    for (final task in tasks) {
      bool isScheduled = false;
      if (task.endDate != null && _isSameDay(task.endDate!, date)) {
        isScheduled = true;
      } else if (task.startDate != null && _isSameDay(task.startDate!, date)) {
        isScheduled = true;
      } else if (task.scheduler != null &&
          SchedulerService.shouldFire(task.scheduler!, date)) {
        isScheduled = true;
      }
      if (!isScheduled) continue;

      items.add({
        'type': 'task',
        'id': task.id,
        'title': _displayTitle(task),
        'time': task.scheduledTime ?? (task.allDay ? 'Dia inteiro' : '00:00'),
        'subtitle': _organizerLabel(task),
        'sort': _sortTime(task.scheduledTime),
        'completed': task.isCompleted,
        'linkUri': 'citrine:///detail/${task.id}',
        'toggleUri':
            'citrine://widget-toggle?type=task&id=${Uri.encodeComponent(task.id)}&date=${_dateKey(date)}',
      });
    }
  }

  for (final reminder in reminders) {
    final firesToday =
        _isSameDay(reminder.time, date) ||
        (reminder.scheduler != null &&
            SchedulerService.shouldFire(reminder.scheduler!, date));
    if (!firesToday || reminder.isCompleted) continue;
    items.add({
      'type': 'reminder',
      'id': reminder.id,
      'title': reminder.title,
      'time': DateFormat('HH:mm').format(reminder.time),
      'subtitle': _organizerLabel(reminder),
      'sort': _sortTime(DateFormat('HH:mm').format(reminder.time)),
      'linkUri': 'citrine:///detail/${reminder.id}',
    });
  }

  if (settings.calendarWidgetShowHabits) {
    for (final habit in habits) {
      if (habit.status != HabitStatus.active) continue;
      final scheduled =
          habit.schedulers.isEmpty ||
          habit.schedulers.any(
            (scheduler) => SchedulerService.shouldFire(scheduler, date),
          );
      if (!scheduled) continue;
      final slotTimes = habit.slots
          .map((slot) => slot.reminderTime ?? _timeOfDate(slot.time))
          .whereType<dynamic>()
          .toList();
      if (slotTimes.isEmpty) {
        final completed = _isHabitCompletedOn(habit, date);
        items.add({
          'type': 'habit',
          'id': habit.id,
          'title': _displayTitle(habit),
          'time': '00:00',
          'subtitle': _organizerLabel(habit),
          'sort': 0,
          'completed': completed,
          'linkUri': 'citrine:///detail/${habit.id}',
          'toggleUri':
              'citrine://widget-toggle?type=habit&id=${Uri.encodeComponent(habit.id)}&date=${_dateKey(date)}',
        });
      } else {
        for (var index = 0; index < slotTimes.length; index++) {
          final slot = slotTimes[index];
          final time =
              '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
          final completed = _isHabitCompletedOn(habit, date, slotIndex: index);
          items.add({
            'type': 'habit',
            'id': habit.id,
            'title': _displayTitle(habit),
            'time': time,
            'subtitle': _organizerLabel(habit),
            'sort': _sortTime(time),
            'completed': completed,
            'linkUri': 'citrine:///detail/${habit.id}',
            'toggleUri':
                'citrine://widget-toggle?type=habit&id=${Uri.encodeComponent(habit.id)}&date=${_dateKey(date)}&slot=$index',
          });
        }
      }
    }
  }

  if (settings.calendarWidgetShowSessions) {
    for (final event in googleEvents) {
      final start = event.start?.dateTime ?? event.start?.date;
      if (start == null) continue;
      final eventDate = DateTime(
        start.toLocal().year,
        start.toLocal().month,
        start.toLocal().day,
      );
      if (!_isSameDay(eventDate, date)) continue;

      final end = event.end?.dateTime ?? event.end?.date;
      final timeStr =
          (event.start?.dateTime != null && event.end?.dateTime != null)
          ? '${DateFormat('HH:mm').format(start.toLocal())} - ${DateFormat('HH:mm').format(end!.toLocal())}'
          : 'Dia inteiro';

      items.add({
        'type': 'google_calendar',
        'id': event.id ?? event.summary ?? '',
        'title': event.summary ?? '(Sem título)',
        'time': timeStr,
        'subtitle': 'Google Calendar',
        'sort': event.start?.dateTime != null
            ? _sortTime(DateFormat('HH:mm').format(start.toLocal()))
            : 0,
        'linkUri': 'citrine:///planner',
      });
    }
  }

  items.sort((a, b) {
    final byTime = (a['sort'] as int).compareTo(b['sort'] as int);
    if (byTime != 0) return byTime;
    return (a['title'] as String).compareTo(b['title'] as String);
  });
  return items;
}

Map<String, dynamic> _buildFilterSnapshot(
  List<ContentObject> allObjects,
  List<DashboardBlock> dashboardBlocks,
  AppSettings? settings,
) {
  final block = dashboardBlocks
      .where((item) => item.id == 'home-area')
      .firstOrNull;
  final metadata = block?.metadata ?? {};
  final rawTypes =
      settings?.universalWidgetObjectTypes ??
      metadata['filterObjectTypes'] ??
      metadata['objectTypes'];
  final selectedTypes = rawTypes is List
      ? rawTypes.map((item) => item.toString()).toSet()
      : {'task', 'habit'};
  final organizers = [
    ...allObjects.whereType<Organizer>().cast<ContentObject>(),
    ...allObjects.whereType<Goal>().cast<ContentObject>(),
  ]..sort((a, b) => a.title.compareTo(b.title));
  final configuredOrganizer = settings?.universalWidgetOrganizer;
  final organizerSlug =
      configuredOrganizer != null && configuredOrganizer.isNotEmpty
      ? configuredOrganizer
      : metadata['organizerSlug'] as String?;
  final organizer = organizerSlug == null
      ? (organizers.isNotEmpty ? organizers.first : null)
      : organizers.where((item) => item.slug == organizerSlug).firstOrNull;

  final refs =
      organizer == null
            ? <ContentObject>[]
            : allObjects.where((object) {
                if (object.id == organizer.id) return false;
                if (!selectedTypes.contains(object.type) &&
                    !(selectedTypes.contains('journal_entry') &&
                        object is JournalEntry)) {
                  return false;
                }
                return object.organizers.any(
                  (ref) => ref.matches(
                    organizer.id,
                    organizer.slug,
                    organizer.title,
                  ),
                );
              }).toList()
        ..sort((a, b) {
          final aTime = a.updatedAt;
          final bTime = b.updatedAt;
          return bTime.compareTo(aTime);
        });

  final tasks = refs.whereType<Task>().toList();
  final completedTasks = tasks.where((task) => task.isCompleted).length;
  final totalProgress = tasks.length;
  final todayKey = _dateKey(DateTime.now());
  final chips =
      <Map<String, dynamic>>[
            {'label': 'Tarefas', 'count': refs.whereType<Task>().length},
            {'label': 'Hábitos', 'count': refs.whereType<Habit>().length},
            {'label': 'Objetivos', 'count': refs.whereType<Goal>().length},
            {'label': 'Notas', 'count': refs.whereType<Note>().length},
            {'label': 'Recursos', 'count': refs.whereType<Resource>().length},
          ]
          .where(
            (chip) => (chip['count'] as int) > 0 || chip['label'] == 'Tarefas',
          )
          .toList();

  return {
    'title': 'Filtro',
    'organizer': organizer?.title ?? 'Sem filtro',
    'chips': chips,
    'progressDone': completedTasks,
    'progressTotal': totalProgress,
    'items': refs.take(8).map((item) {
      final completed = item is Task
          ? item.isCompleted
          : item is Habit
          ? _isHabitCompletedOn(item, DateTime.now())
          : false;
      final String? toggleUri = item is Task
          ? 'citrine://widget-toggle?type=task&id=${Uri.encodeComponent(item.id)}&date=$todayKey'
          : item is Habit
          ? 'citrine://widget-toggle?type=habit&id=${Uri.encodeComponent(item.id)}&date=$todayKey'
          : null;
      final row = {
        'id': item.id,
        'title': _displayTitle(item),
        'type': _displayType(item),
        'subtitle': item.organizers.isEmpty
            ? item.displayType
            : _organizerLabel(item),
        'completed': completed,
        'linkUri': 'citrine:///detail/${item.id}',
      };
      if (toggleUri != null) {
        row['toggleUri'] = toggleUri;
      }
      return row;
    }).toList(),
  };
}

Map<String, dynamic> _buildPomodoroSnapshot(List<PomodoroSession> history) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startOfWeek = today.subtract(Duration(days: now.weekday - 1));
  final sessions = history
      .where(
        (session) =>
            session.pomodoroType == PomodoroType.work &&
            !session.startTime.isBefore(startOfWeek),
      )
      .toList();
  final totalMinutes = sessions.fold<int>(
    0,
    (sum, session) => sum + session.duration.inMinutes,
  );
  final bars = List.generate(7, (index) {
    final day = startOfWeek.add(Duration(days: index));
    final minutes = sessions
        .where((session) => _isSameDay(session.startTime, day))
        .fold<int>(0, (sum, session) => sum + session.duration.inMinutes);
    return {
      'label': DateFormat('E', 'pt_BR').format(day),
      'hours': minutes / 60,
    };
  });
  return {
    'title': 'Pomodoro',
    'total': '${(totalMinutes / 60).toStringAsFixed(0)}h',
    'details': 'esta semana',
    'average':
        '~${(totalMinutes / 60 / now.weekday).toStringAsFixed(0)}h por dia',
    'bars': bars,
  };
}

String _organizerLabel(ContentObject object) {
  return object.organizers.isEmpty ? 'Sem área' : object.organizers.first.title;
}

String _displayType(ContentObject item) {
  return switch (item.type) {
    'task' => 'Tarefa',
    'habit' => 'Hábito',
    'goal' => 'Objetivo',
    'note' => 'Nota',
    'journal_entry' => 'Diário',
    'resource' => 'Recurso',
    'person' => 'Pessoa',
    _ => item.displayType,
  };
}

String _displayTitle(ContentObject item) {
  final title = item.title.trim();
  if (title.isNotEmpty && title != item.id && !_looksLikeTechnicalId(title)) {
    return title;
  }
  final fileName = item.obsidianFileName.trim();
  if (fileName.isNotEmpty &&
      fileName != item.id &&
      !_looksLikeTechnicalId(fileName)) {
    return fileName;
  }
  if (item.aliases.isNotEmpty && item.aliases.first.trim().isNotEmpty) {
    return item.aliases.first.trim();
  }
  return 'Sem título';
}

bool _looksLikeTechnicalId(String value) {
  final trimmed = value.trim();
  return RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(trimmed) ||
      RegExp(r'^\d{10,}$').hasMatch(trimmed);
}

String _dateKey(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isHabitCompletedOn(Habit habit, DateTime date, {int? slotIndex}) {
  final record = habit.completionHistory
      .where((item) => _isSameDay(item.date, date))
      .firstOrNull;
  if (record == null) return false;
  if (slotIndex != null && record.slotCompletions != null) {
    return slotIndex < record.slotCompletions!.length &&
        record.slotCompletions![slotIndex] == true;
  }
  return record.successful;
}

int _sortTime(String? value) {
  if (value == null || !RegExp(r'^\d{1,2}:\d{2}').hasMatch(value)) return 9999;
  final parts = value.split(':');
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

dynamic _timeOfDate(DateTime? date) {
  if (date == null) return null;
  return _SimpleTime(date.hour, date.minute);
}

class _SimpleTime {
  final int hour;
  final int minute;

  _SimpleTime(this.hour, this.minute);
}
