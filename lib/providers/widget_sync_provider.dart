// lib/providers/widget_sync_provider.dart
//
// Reacts to vault changes and pushes dashboard-style snapshots to Android widgets.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

import 'overdue_provider.dart';
import '../models/content_object.dart';
import '../models/goal_model.dart';
import '../models/habit_model.dart';
import '../models/mood_model.dart';
import '../models/dashboard_block.dart';
import '../models/organizer_model.dart';
import '../models/pomodoro_session.dart';
import '../models/reminder_model.dart';
import '../models/task_model.dart';
import '../models/shopping_list_model.dart' as shopping_list_model;
import '../models/journal_entry.dart';
import '../models/note_model.dart';
import '../models/resource_model.dart';
import '../models/day_dial_model.dart';
import '../models/event_model.dart';
import '../models/shared_types.dart';
import '../services/widget_service.dart';
import '../services/day_dial_aggregator.dart';
import '../services/daily_schedule_service.dart';
import 'dashboard_provider.dart';
import 'pomodoro_provider.dart';
import 'vault_provider.dart';
import 'google_calendar_provider.dart';
import 'settings_provider.dart';

const _maxWidgetDayItems = 50;

// Simple cache to avoid unnecessary widget updates
class _WidgetDataCache {
  String? _lastHash;
  DateTime? _lastUpdateTime;
  static const _cacheValidDuration = Duration(seconds: 30);

  bool shouldUpdate(String currentHash) {
    final now = DateTime.now();
    if (_lastHash == null || _lastHash != currentHash) {
      return true;
    }
    if (_lastUpdateTime != null && 
        now.difference(_lastUpdateTime!) > _cacheValidDuration) {
      return true;
    }
    return false;
  }

  void update(String hash) {
    _lastHash = hash;
    _lastUpdateTime = DateTime.now();
  }

  void invalidate() {
    _lastHash = null;
    _lastUpdateTime = null;
  }
}

final _widgetDataCache = _WidgetDataCache();

// Create a simple hash from data lengths to detect changes
String _createDataHash(int objectsCount, int pomodoroCount, int blocksCount, int eventsCount, int overdueCount) {
  final data = '$objectsCount|$pomodoroCount|$blocksCount|$eventsCount|$overdueCount';
  final bytes = utf8.encode(data);
  final hash = sha256.convert(bytes);
  return hash.toString();
}

class _Debouncer {
  final Duration delay;
  Timer? _timer;
  bool _isRunning = false;

  _Debouncer({required this.delay});

  void run(Future<void> Function() fn) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (_isRunning) return;
      _isRunning = true;
      fn().whenComplete(() {
        _isRunning = false;
      });
    });
  }

  void dispose() => _timer?.cancel();
}

final widgetSyncProvider = Provider<void>((ref) {
  final debouncer = _Debouncer(delay: const Duration(milliseconds: 10000));

  // Use select to only watch specific data that affects widgets, not entire vault
  final allObjects = ref.watch(allObjectsProvider.select((data) => data.valueOrNull));
  final pomodoro = ref.watch(pomodoroProvider.select((data) => data));
  final blocks = ref.watch(dashboardProvider.select((data) => data.valueOrNull ?? []));
  final settings = ref.watch(settingsProvider.select((data) => data));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
  final googleStart = startOfWeek;
  const googleDays = 7;
  final googleEventsAsync = ref.watch(
    googleCalendarRangeEventsProvider(
      GoogleCalendarParams(startDate: googleStart, days: googleDays),
    ).select((data) => data.valueOrNull ?? []),
  );
  final googleEvents = googleEventsAsync;

  final sharedPrefs = ref.watch(sharedPreferencesProvider.select((data) => data));
  final prefs = sharedPrefs.getInt('calendarWidgetOffset') ?? 0;
  final offset = prefs;
  final overdueItems = ref.watch(overdueProvider.select((data) => data));

  if (allObjects != null) {
    debouncer.run(() async {
      // Create a simple hash of the data to check if it changed
      final dataHash = _createDataHash(
        allObjects.length,
        pomodoro.history.length,
        blocks.length,
        googleEvents.length,
        overdueItems.length,
      );
      
      // Skip update if data hasn't changed and cache is still valid
      if (!_widgetDataCache.shouldUpdate(dataHash)) {
        debugPrint('[WidgetSync] Skipping update - data unchanged and cache valid');
        return;
      }
      
      debugPrint('[WidgetSync] Updating widgets - data changed or cache expired');
      await _updateAllWidgets(
        allObjects,
        pomodoro.history,
        blocks,
        settings,
        googleEvents,
        offset,
        overdueItems,
        sharedPrefs,
      );
      
      _widgetDataCache.update(dataHash);
    });
  }

  ref.onDispose(debouncer.dispose);
});

Future<void> forceWidgetSync(ProviderContainer container) async {
  try {
    // Invalidate cache to force update
    _widgetDataCache.invalidate();
    debugPrint('[WidgetSync] Force sync - cache invalidated');
    
    final allObjects = await container.read(allObjectsProvider.future);
    final pomodoro = container.read(pomodoroProvider);
    final blocks = container.read(dashboardProvider).valueOrNull ?? [];
    final settings = container.read(settingsProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final googleStart = startOfWeek;
    const googleDays = 7;

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
    final overdueItems = container.read(overdueProvider);

    await _updateAllWidgets(
      allObjects,
      pomodoro.history,
      blocks,
      settings,
      googleEvents,
      offset,
      overdueItems,
      prefs,
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
  int offset, [
  List<OverdueItem> overdueItems = const [],
  SharedPreferences? prefs,
]) async {
  try {
    final calendar = _buildCalendarSnapshot(
      allObjects,
      settings,
      googleEvents,
      offset,
      overdueItems,
    );
    final monthSnapshot = _buildMonthSnapshot(
      allObjects,
      settings,
      googleEvents,
      prefs?.getInt('monthWidgetOffset') ?? 0,
      prefs?.getInt('monthWidgetMaxChips') ?? 3,
      prefs?.getStringList('monthWidgetVisibleKinds') ?? ['task', 'habit', 'reminder', 'google_calendar', 'time_block'],
    );
    final shopping = _buildShoppingSnapshot(allObjects);
    final pomodoro = _buildPomodoroSnapshot(pomodoroHistory);
    final tasks = _buildTasksSnapshot(allObjects, settings);
    
    try {
      await WidgetService.updateDashboardWidgets(
        calendar: calendar,
        shopping: shopping,
        pomodoro: pomodoro,
        tasks: tasks,
      );
    } catch (e) {
      debugPrint('[WidgetSync] Failed to update dashboard widgets: $e');
    }
    
    try {
      await WidgetService.updateMonthWidget(
        title: monthSnapshot['selectedTitle'] as String,
        subtitle: monthSnapshot['selectedSubtitle'] as String,
        days: (monthSnapshot['days'] as List).cast<Map<String, String>>(),
        monthGrid: (monthSnapshot['monthGrid'] as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      debugPrint('[WidgetSync] Failed to update month widget: $e');
    }
    
    // Update note widget with pinned note
    try {
      await _updateNoteWidget(allObjects);
    } catch (e) {
      debugPrint('[WidgetSync] Failed to update note widget: $e');
    }
    
    // Update quick add widget
    try {
      await WidgetService.updateQuickAddLabels();
    } catch (e) {
      debugPrint('[WidgetSync] Failed to update quick add labels: $e');
    }
    
    // Update day dial widget
    try {
      await _updateDayDialWidget(allObjects, pomodoroHistory, googleEvents, settings.typeSignatures);
    } catch (e) {
      debugPrint('[WidgetSync] Failed to update day dial widget: $e');
    }
  } catch (e, st) {
    debugPrint('[WidgetSync] Failed to build widget snapshots: $e\n$st');
  }
}

@visibleForTesting
Map<String, dynamic> buildCalendarSnapshotForTest(
  List<ContentObject> objects,
  AppSettings settings,
  List<calendar.Event> googleEvents,
  int offset, [
  List<OverdueItem> overdueItems = const [],
]) {
  return _buildCalendarSnapshot(
    objects,
    settings,
    googleEvents,
    offset,
    overdueItems,
  );
}

@visibleForTesting
Map<String, dynamic> buildShoppingSnapshotForTest(
  List<ContentObject> allObjects,
) {
  return _buildShoppingSnapshot(allObjects);
}

@visibleForTesting
Map<String, dynamic> buildFilterSnapshotForTest(
  List<ContentObject> objects,
  List<DashboardBlock> blocks, [
  AppSettings? settings,
]) {
  return _buildFilterSnapshot(objects, blocks, settings);
}

Map<String, dynamic> _buildCalendarSnapshot(
  List<ContentObject> objects,
  AppSettings settings,
  List<calendar.Event> googleEvents,
  int offset, [
  List<OverdueItem> overdueItems = const [],
]) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  const mode = 'week';
  const dayHeaders = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
  final overdueSnapshot = _overdueSnapshot(overdueItems);

  if (mode == 'day') {
    // offset shifts by days
    final focusDay = today.add(Duration(days: offset));
    final items = _dayItems(
      focusDay,
      objects,
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
      ...overdueSnapshot,
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
        objects,
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
      objects,
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
      ...overdueSnapshot,
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
          ? _dayItems(
              date,
              objects,
              googleEvents,
              settings,
            )
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

Map<String, dynamic> _buildMonthSnapshot(
  List<ContentObject> objects,
  AppSettings settings,
  List<calendar.Event> googleEvents,
  int offset,
  int maxChips,
  List<String> visibleKinds,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final organizerObjects = objects
      .where(
        (object) =>
            object is Organizer ||
            object is Goal ||
            object.type == 'project' ||
            object.type == 'person',
      )
      .toList();

  final dayThemes = organizerObjects
      .where((o) => (o is Organizer) && o.organizerType == OrganizerType.dayTheme)
      .toList();

  const dayHeaders = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
  const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final focusMonth = DateTime(today.year, today.month + offset, 1);
  final firstWeekday = focusMonth.weekday % 7; 

  final gridStart = focusMonth.subtract(Duration(days: firstWeekday));
  final monthGrid = List.generate(42, (i) {
    final date = gridStart.add(Duration(days: i));
    final isCurrentMonth = date.month == focusMonth.month && date.year == focusMonth.year;
    
    var dayItems = isCurrentMonth
        ? _dayItems(
            date,
            objects,
            googleEvents,
            settings,
          )
        : <Map<String, dynamic>>[];

    // Filter by visibleKinds
    dayItems = dayItems.where((item) {
      final type = item['type'] as String? ?? '';
      // Exclude rotation zone items - they should only appear as time blocks
      if (type == 'project') return false;
      return visibleKinds.contains(type);
    }).toList();

    final pillItems = dayItems.take(maxChips).map((item) {
      return {
        'title': _truncate(item['title'] as String? ?? '', 6),
        'color': _typeColor(item['type'] as String? ?? ''),
      };
    }).toList();

    final moreCount = dayItems.length > maxChips ? dayItems.length - maxChips : 0;

    String themeIcon = '';
    if (isCurrentMonth) {
      final dayName = weekDayNames[date.weekday - 1];
      final activeTheme = dayThemes.cast<Organizer?>().firstWhere(
        (theme) => theme != null && theme.daysOfWeek.contains(dayName),
        orElse: () => null,
      );
      if (activeTheme != null) {
        themeIcon = activeTheme.icon ?? '📅';
      }
    }

    return {
      'dayNum': '${date.day}',
      'isCurrentMonth': isCurrentMonth,
      'isToday': _isSameDay(date, today),
      'dateStr': _dateKey(date),
      'themeIcon': themeIcon,
      'pills': pillItems,
      'items': dayItems,
      'moreCount': moreCount,
    };
  });

  final dayHeadersList = List.generate(7, (i) {
    return {'dayHeader': dayHeaders[i]};
  });

  final monthName = DateFormat('MMMM yyyy', 'pt_BR').format(focusMonth);
  final titleStr = _capitalize(monthName);

  return {
    'title': 'Mês',
    'selectedTitle': titleStr,
    'selectedSubtitle': '',
    'days': dayHeadersList,
    'monthGrid': monthGrid,
  };
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
  List<ContentObject> allObjects,
  List<calendar.Event> googleEvents,
  AppSettings settings,
) {
  // Use new visibleKinds if set, otherwise migrate from old boolean settings
  final visibleKinds = settings.calendarWidgetVisibleKinds ?? <DailyScheduleKind>{
    DailyScheduleKind.reminder,
    if (settings.calendarWidgetShowTasks) ...{
      DailyScheduleKind.task,
      DailyScheduleKind.rotationZone,
    },
    if (settings.calendarWidgetShowHabits) DailyScheduleKind.habit,
    if (settings.calendarWidgetShowSessions) ...{
      DailyScheduleKind.event,
      DailyScheduleKind.googleCalendar,
      DailyScheduleKind.pomodoro,
      DailyScheduleKind.timeBlock,
    },
  };

  final snapshot = DailyScheduleAggregator.buildForDate(
    date,
    allObjects: allObjects,
    googleEvents: googleEvents,
    typeSignatures: settings.typeSignatures,
  ).apply(DailyScheduleFilter(visibleKinds: visibleKinds));

  final items = snapshot.allItems.where((item) {
    // Exclude rotation zone items - they should only appear as time blocks
    return item.kind != DailyScheduleKind.rotationZone;
  }).map((item) {
    final source = item.source;
    final type = _widgetTypeForScheduleKind(item.kind);
    final sourceId = source?.id ?? item.id;
    final row = <String, dynamic>{
      'type': type,
      'id': sourceId,
      'title': _userFacingText(item.title),
      'time': item.isAllDay ? 'All day' : _formatMinutes(item.startMinutes!),
      'subtitle': source == null ? item.subtitle ?? item.sourceLabel : _organizerLabel(source, allObjects),
      'sort': item.startMinutes ?? 0,
      'completed': item.isCompleted,
      'linkUri': source == null ? 'Quartzo:///planner' : 'Quartzo:///detail/${source.id}',
      'sourceLabel': item.sourceLabel,
    };
    if (item.kind == DailyScheduleKind.task && source != null) {
      row['toggleUri'] =
          'Quartzo://widget-toggle?type=task&id=${Uri.encodeComponent(source.id)}&date=${_dateKey(date)}';
    } else if (item.kind == DailyScheduleKind.habit && source != null) {
      final slot = item.slotIndex == null ? '' : '&slot=${item.slotIndex}';
      row['toggleUri'] =
          'Quartzo://widget-toggle?type=habit&id=${Uri.encodeComponent(source.id)}&date=${_dateKey(date)}$slot';
    }
    return row;
  }).toList();

  items.sort((a, b) {
    final byTime = (a['sort'] as int).compareTo(b['sort'] as int);
    if (byTime != 0) return byTime;
    return (a['title'] as String).compareTo(b['title'] as String);
  });
  return items;
}

String _widgetTypeForScheduleKind(DailyScheduleKind kind) {
  return switch (kind) {
    DailyScheduleKind.task => 'task',
    DailyScheduleKind.habit => 'habit',
    DailyScheduleKind.event => 'event',
    DailyScheduleKind.googleCalendar => 'google_calendar',
    DailyScheduleKind.reminder => 'reminder',
    DailyScheduleKind.pomodoro => 'pomodoro',
    DailyScheduleKind.trackerRecord => 'tracker',
    DailyScheduleKind.journalEntry => 'entry',
    DailyScheduleKind.timeBlock => 'time_block',
    DailyScheduleKind.system => 'system',
    DailyScheduleKind.rotationZone => 'project',
    DailyScheduleKind.personContact => 'person',
    DailyScheduleKind.goal => 'goal',
  };
}

String _formatMinutes(int minutes) {
  final hour = (minutes ~/ 60).clamp(0, 23);
  final minute = (minutes % 60).clamp(0, 59);
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _buildShoppingSnapshot(
  List<ContentObject> allObjects,
) {
  final shoppingLists = allObjects
      .whereType<shopping_list_model.ShoppingList>()
      .where((list) => !list.archived)
      .toList();

  final List<Map<String, dynamic>> items = [];
  for (final list in shoppingLists) {
    for (final item in list.activeItems) {
      items.add({
        'id': '${list.id}/${item.id}',
        'title': item.name,
        'type': 'shopping_item',
        'completed': false,
        'toggleUri': 'Quartzo://widget-toggle?type=shopping_list_item&listId=${Uri.encodeComponent(list.id)}&itemId=${Uri.encodeComponent(item.id)}',
      });
    }
  }

  return {
    'title': 'Lista de Mercado',
    'subtitle': '${items.length} pendentes',
    'items': items.take(15).toList(),
  };
}

Map<String, dynamic> _buildFilterSnapshot(
  List<ContentObject> allObjects,
  List<DashboardBlock> dashboardBlocks, [
  AppSettings? settings,
]) {
  final block = dashboardBlocks
      .where((item) => item.id == 'home-area')
      .firstOrNull;
  final metadata = block?.metadata ?? {};
  
  final organizerSlug = settings?.universalWidgetOrganizer ?? metadata['organizerSlug'] as String?;
  final rawTypes = settings?.universalWidgetObjectTypes ?? metadata['filterObjectTypes'] ?? metadata['objectTypes'];
  final selectedTypes = rawTypes is List
      ? rawTypes.map((item) => item.toString()).toSet()
      : {'task', 'habit'};
      
  final organizers = [
    ...allObjects.whereType<Organizer>().cast<ContentObject>(),
    ...allObjects.whereType<Goal>().cast<ContentObject>(),
  ].where((object) => 
    object is Organizer ||
    object is Goal ||
    object.type == 'project' ||
    object.type == 'person'
  ).toList()..sort((a, b) => a.title.compareTo(b.title));
  
  final organizer = organizerSlug == null
      ? (organizers.isNotEmpty ? organizers.first : null)
      : organizers.where((item) => item.slug == organizerSlug || item.id == organizerSlug).firstOrNull;

  final refs =
      organizer == null
            ? <ContentObject>[]
            : allObjects.where((object) {
                if (object.id == organizer.id) return false;
                if (!selectedTypes.contains(object.type) &&
                    !(selectedTypes.contains('entry') &&
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
            {'label': 'Habitos', 'count': refs.whereType<Habit>().length},
            {'label': 'Goals', 'count': refs.whereType<Goal>().length},
            {'label': 'Notas', 'count': refs.whereType<Note>().length},
            {'label': 'Recursos', 'count': refs.whereType<Resource>().length},
          ]
          .where(
            (chip) => (chip['count'] as int) > 0 || chip['label'] == 'Tarefas',
          )
          .toList();

  return {
    'title': 'Filtro',
    'organizer': organizer == null ? 'Sem filtro' : _displayTitle(organizer),
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
          ? 'Quartzo://widget-toggle?type=task&id=${Uri.encodeComponent(item.id)}&date=$todayKey'
          : item is Habit
          ? 'Quartzo://widget-toggle?type=habit&id=${Uri.encodeComponent(item.id)}&date=$todayKey'
          : null;
      final row = {
        'id': item.id,
        'title': _displayTitle(item),
        'type': item.type,
        'subtitle': item.organizers.isEmpty
            ? _displayType(item)
            : _organizerLabel(item, organizers),
        'completed': completed,
        'linkUri': 'Quartzo:///detail/${item.id}',
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
            session.minutesWorked > 0 &&
            !session.date.isBefore(startOfWeek),
      )
      .toList();
  final totalMinutes = sessions.fold<int>(
    0,
    (sum, session) => sum + session.minutesWorked,
  );
  final bars = List.generate(7, (index) {
    final day = startOfWeek.add(Duration(days: index));
    final minutes = sessions
        .where((session) => _isSameDay(session.date, day))
        .fold<int>(0, (sum, session) => sum + session.minutesWorked);
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

Map<String, dynamic> _buildTasksSnapshot(
  List<ContentObject> allObjects,
  AppSettings settings,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final items = _dayItems(
    today,
    allObjects,
    [],
    settings,
  );

  return {
    'title': 'Tarefas',
    'subtitle': '${items.length} ${items.length == 1 ? 'tarefa' : 'tarefas'}',
    'items': items.take(8).toList(),
  };
}

Future<void> _updateNoteWidget(List<ContentObject> allObjects) async {
  try {
    // Get the most recently updated pinned note
    final pinnedNote = allObjects
        .whereType<Note>()
        .where((note) => note.pinned)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (pinnedNote.isNotEmpty) {
      final note = pinnedNote.first;
      await WidgetService.updateNote(
        widgetId: 0,
        title: note.title,
        content: note.body,
        slug: note.slug,
      );
    }
  } catch (e, st) {
    debugPrint('[WidgetSync] _updateNoteWidget failed: $e\n$st');
  }
}

String _organizerLabel(
  ContentObject object, [
  List<ContentObject> organizerObjects = const [],
]) {
  if (object.organizers.isEmpty) return '';
  final labels = object.organizers
      .map((ref) {
        final resolved = organizerObjects
            .where(
              (organizer) =>
                  ref.matches(organizer.id, organizer.slug, organizer.title),
            )
            .firstOrNull;
        if (resolved != null) {
          return _userFacingText(resolved.displayTitle);
        }
        return _userFacingText(ref.title, fallback: _userFacingText(ref.slug));
      })
      .where((label) => label.isNotEmpty)
      .toList();
  return labels.join(', ');
}

String _displayType(ContentObject item) {
  return switch (item.type) {
    'task' => 'Tarefa',
    'habit' => 'Hábito',
    'goal' => 'Objetivo',
    'note' => 'Nota',
    'entry' => 'Diário',
    'resource' => 'Recurso',
    'person' => 'Pessoa',
    _ => item.displayType,
  };
}

String _displayTitle(ContentObject item) {
  return _userFacingText(item.displayTitle, fallback: item.displayType);
}

String _userFacingText(String value, {String fallback = ''}) {
  var text = value.trim();
  if (text.isEmpty) return fallback;
  if (text.startsWith('[[') && text.endsWith(']]')) {
    text = text.substring(2, text.length - 2).trim();
  }
  final clean = displayTitleFromValue(text);
  if (clean == null || clean.isEmpty) return fallback;
  return clean;
}

Map<String, dynamic> _overdueSnapshot(List<OverdueItem> overdueItems) {
  // Only include count in widget snapshot, not the full list
  // Overdue items will be shown in a separate detail screen
  return {
    'overdueCount': overdueItems.length,
  };
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

Future<void> _updateDayDialWidget(
  List<ContentObject> allObjects,
  List<PomodoroSession> pomodoroHistory,
  List<calendar.Event> googleEvents,
  Map<String, TypeSignature> typeSignatures,
) async {
  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final tasks = allObjects.whereType<Task>().toList();
    final habits = allObjects.whereType<Habit>().toList();
    final reminders = allObjects.whereType<Reminder>().toList();
    final journalEntries = allObjects.whereType<JournalEntry>().toList();
    final moodDefinitions = allObjects.whereType<MoodDefinition>().toList();
    final localEvents = allObjects.whereType<Event>().toList();
    final timeBlocks = allObjects.whereType<Organizer>().where((o) => o.organizerType == OrganizerType.timeBlock).toList();
    
    final snapshot = DayDialAggregator.aggregateForDate(
      date: today,
      tasks: tasks,
      habits: habits,
      pomodoroSessions: pomodoroHistory,
      googleEvents: googleEvents,
      localEvents: localEvents,
      reminders: reminders,
      timeBlocks: timeBlocks,
      journalEntries: journalEntries,
      moodCatalog: moodDefinitions,
      typeSignatures: typeSignatures,
    );
    
    // Count activities for summary
    int taskCount = 0;
    int eventCount = 0;
    int pomodoroCount = 0;
    
    for (final segment in snapshot.segments) {
      if (segment.kind == DialSegmentKind.pomodoroCompleted) {
        pomodoroCount++;
      } else if (segment.kind == DialSegmentKind.taskPlanned) {
        taskCount++;
      } else if (segment.kind == DialSegmentKind.event) {
        eventCount++;
      }
    }
    
    final summary = '$taskCount tasks • $eventCount events • $pomodoroCount pomodoros';

    final widgetHours = List.generate(24, (i) {
      final hStart = DateTime(today.year, today.month, today.day, i);
      final hEnd = DateTime(today.year, today.month, today.day, i + 1);
      final hourSegments = snapshot.segments.where((s) => s.start.isBefore(hEnd) && s.end.isAfter(hStart));
      if (hourSegments.isEmpty) return {'active': false, 'color': '#000000', 'icon': ''};
      return {
        'active': true,
        'color': hourSegments.first.colorHex,
        'icon': hourSegments.first.iconData?.codePoint.toString() ?? '',
      };
    });

    await WidgetService.updateDayDial(
      currentTime: DateFormat('HH:mm').format(now),
      dateLabel: 'Today',
      hours: widgetHours,
      currentHour: now.hour,
      summary: summary,
    );
  } catch (e, st) {
    debugPrint('[WidgetSync] _updateDayDialWidget failed: $e\n$st');
  }
}
