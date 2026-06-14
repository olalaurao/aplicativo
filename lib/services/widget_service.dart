// lib/services/widget_service.dart
//
// Bridge between Flutter snapshots and Android home screen widgets.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _androidPackage = 'com.productivity.citrine';
  static const _calendarProvider = 'CitrineCalendarWidgetReceiver';
  static const _tasksProvider = 'CitrineTasksWidgetReceiver';
  static const _shoppingProvider = 'CitrineShoppingWidgetProvider';
  static const _pomodoroProvider = 'CitrinePomodoroWidgetProvider';
  static const _quickAddProvider = 'CitrineQuickAddWidgetProvider';
  static const _noteProvider = 'CitrineNoteWidgetProvider';
  static const _checklistProvider = 'CitrineChecklistWidgetProvider';

  static bool get _isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  static Future<void> init() async {
    if (!_isSupportedPlatform) return;
    await refreshAllWidgets();
  }

  static Future<void> updateDashboardWidgets({
    required Map<String, dynamic> calendar,
    required Map<String, dynamic> shopping,
    required Map<String, dynamic> pomodoro,
  }) async {
    try {
      await Future.wait([
        _saveJson('citrine_calendar', calendar),
        _saveJson('citrine_shopping', shopping),
        _saveJson('citrine_pomodoro', pomodoro),
      ]);
      await refreshAllWidgets();
    } catch (e, st) {
      debugPrint('[WidgetService] updateDashboardWidgets failed: $e\n$st');
    }
  }

  static Future<void> updateHabits(List<dynamic> habits) async {
    await _updateTaskProviders();
  }

  static Future<void> updateCalendar({
    required String monthTitle,
    required List<Map<String, dynamic>> days,
    String type = 'week',
  }) async {
    await _saveJson('citrine_calendar', {
      'title': monthTitle,
      'mode': type,
      'days': days,
    });
    await _updateCalendarProviders();
  }

  static Future<void> updateNote({
    required int widgetId,
    required String title,
    required String content,
    required String slug,
  }) async {
    await _saveJson('citrine_note_$widgetId', {
      'title': title,
      'content': content,
      'slug': slug,
      'linkUri': 'citrine:///detail/$slug',
    });
    await _saveJson('citrine_note', {
      'title': title,
      'content': content,
      'slug': slug,
      'linkUri': 'citrine:///detail/$slug',
    });
    await _update(_noteProvider);
  }

  static Future<void> updateChecklist({
    required int widgetId,
    required String title,
    required List<Map<String, dynamic>> items,
    required String slug,
  }) async {
    await _saveJson('citrine_checklist_$widgetId', {
      'title': title,
      'items': items,
      'slug': slug,
      'linkUri': 'citrine:///detail/$slug',
    });
    // fallback for config
    await _saveJson('citrine_checklist', {
      'title': title,
      'items': items,
      'slug': slug,
      'linkUri': 'citrine:///detail/$slug',
    });
    await _update(_checklistProvider);
  }

  static Future<void> updateQuickAddLabels({
    String journalLabel = 'Diário',
    String taskLabel = 'Tarefa',
    String firstTarget = 'entry',
    String secondTarget = 'task',
  }) async {
    await _saveJson('citrine_quick_add', {
      'buttons': [
        {
          'label': journalLabel,
          'target': firstTarget,
          'uri': 'citrine:///create/$firstTarget',
        },
        {
          'label': taskLabel,
          'target': secondTarget,
          'uri': 'citrine:///create/$secondTarget',
        },
      ],
    });
    await _update(_quickAddProvider);
  }

  static Future<void> refreshAllWidgets() async {
    await Future.wait([
      _updateCalendarProviders(),
      _updateTaskProviders(),
      _update(_pomodoroProvider),
      _update(_quickAddProvider),
      _update(_noteProvider),
    ]);
  }

  static Future<void> updateLockNextSession({
    required String title,
    required String time,
    required String date,
  }) async {
    await _saveJson('citrine_lock_next_session', {
      'title': title,
      'time': time,
      'date': date,
    });
    await _updateCalendarProviders();
  }

  static Future<void> updateUniversalWidget({
    required String type,
    required String title,
    String size = 'medium',
    Map<String, String>? data,
    int? widgetId,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'size': size,
      'data': data ?? <String, String>{},
    };
    if (widgetId != null) {
      payload['widgetId'] = widgetId;
    }
    await _saveJson('citrine_widget_$type', payload);
    await refreshUniversalWidgets();
  }

  static Future<List<int>> universalWidgetIds() async {
    if (!_isSupportedPlatform) return [];
    try {
      final installed = await HomeWidget.getInstalledWidgets();
      final ids =
          installed
              .where((widget) {
                final className = widget.androidClassName ?? '';
                return className.contains('Citrine');
              })
              .map((widget) => widget.androidWidgetId)
              .whereType<int>()
              .toSet()
              .toList()
            ..sort();
      return ids;
    } catch (e, st) {
      debugPrint('[WidgetService] universalWidgetIds failed: $e\n$st');
      final stored = await HomeWidget.getWidgetData<String>(
        'citrine_universal_widget_ids',
        defaultValue: '[]',
      );
      final decoded = jsonDecode(stored ?? '[]');
      if (decoded is List) {
        return decoded
            .map((item) => item is int ? item : int.tryParse(item.toString()))
            .whereType<int>()
            .toList();
      }
      return [];
    }
  }

  static Future<void> saveUniversalWidgetConfig({
    required int widgetId,
    required String type,
    required String title,
    required String size,
    required String organizer,
    required List<String> objectTypes,
  }) async {
    final existingIds = await universalWidgetIds();
    final ids = {...existingIds, widgetId}.toList()..sort();
    await HomeWidget.saveWidgetData<String>(
      'citrine_universal_widget_ids',
      jsonEncode(ids),
    );
    await _saveJson('citrine_widget_config_$widgetId', {
      'widgetId': widgetId,
      'type': type,
      'title': title,
      'size': size,
      'organizer': organizer,
      'objectTypes': objectTypes,
    });
    await refreshUniversalWidgets();
  }

  static Future<void> refreshUniversalWidgets() async => refreshAllWidgets();

  static Future<void> updateCalendarWidget({
    required String dateLabel,
    required List<Map<String, String>> sessions,
    required int totalCount,
    int? widgetId,
  }) async {
    await updateCalendar(
      monthTitle: dateLabel,
      days: [
        {
          'date': DateTime.now().toIso8601String().split('T').first,
          'items': sessions,
          'count': totalCount,
        },
      ],
    );
  }

  static Future<void> updateOrganizerDetailed({
    required String slug,
    required String title,
    required List<Map<String, String>> tasks,
    required int completedCount,
    required int totalCount,
    int? widgetId,
  }) async {
    final payload = {
      'type': 'organizer_detailed',
      'slug': slug,
      'title': title,
      'tasks': tasks,
      'completedCount': completedCount,
      'totalCount': totalCount,
    };
    await _saveUniversalPayload(payload, widgetId: widgetId);
  }

  static Future<void> updatePomodoroSummary({
    required String total,
    required String details,
    required List<bool> barActive,
    int? widgetId,
  }) async {
    final payload = {
      'type': 'pomodoro_summary',
      'total': total,
      'details': details,
      'barActive': barActive,
    };
    await _saveJson('citrine_pomodoro_summary', payload);
    await _saveUniversalPayload(payload, widgetId: widgetId);
    await _update(_pomodoroProvider);
  }

  static Future<void> updateNextTask(dynamic task) async {
    await _updateTaskProviders();
  }

  static Future<void> updatePomodoro(
    String title,
    String timeRemaining, {
    String? taskTitle,
  }) async {
    await _saveJson('citrine_pomodoro_live', {
      'title': title,
      'timeRemaining': timeRemaining,
      'taskTitle': taskTitle,
    });
    await _update(_pomodoroProvider);
  }

  static Future<void> updatePlanner(
    String title,
    String content,
    String footer,
  ) async {
    await _saveJson('citrine_planner', {
      'title': title,
      'content': content,
      'footer': footer,
    });
    await _updateCalendarProviders();
  }

  static Future<void> updateOrganizerSummary({
    required String title,
    required String tasks,
    required String events,
    required String focus,
    required String stats,
    String slug = '',
  }) async {
    final payload = {
      'type': 'organizer_summary',
      'title': title,
      'tasks': tasks,
      'events': events,
      'focus': focus,
      'stats': stats,
      'slug': slug,
    };
    await _saveJson('citrine_organizer_summary', payload);
    await _saveUniversalPayload(payload);
  }

  static Future<void> updatePomodoroWeekly(
    String total,
    List<double> heights,
    String details,
    int? widgetId,
  ) async {
    await _saveJson('citrine_pomodoro', {
      'total': total,
      'details': details,
      'bars': heights,
    });
    await _update(_pomodoroProvider);
  }

  static Future<void> updatePlannerDetailed({
    required List<String> dailyItems,
    required Map<int, String> weeklyDays,
    required String monthTitle,
    required List<String> monthFocus,
  }) async {
    final payload = {
      'type': 'planner_detailed',
      'dailyItems': dailyItems,
      'weeklyDays': weeklyDays.map((key, value) => MapEntry('$key', value)),
      'monthTitle': monthTitle,
      'monthFocus': monthFocus,
    };
    await _saveJson('citrine_planner_detailed', payload);
    await _saveUniversalPayload(payload);
  }

  static Future<void> _saveUniversalPayload(
    Map<String, dynamic> payload, {
    int? widgetId,
  }) async {
    await _saveJson('citrine_universal_widget', payload);
    if (widgetId != null) {
      await _saveJson('citrine_universal_widget_$widgetId', payload);
    }
    await refreshUniversalWidgets();
  }

  static Future<void> _saveJson(String key, Map<String, dynamic> value) {
    if (!_isSupportedPlatform) return Future.value();
    return HomeWidget.saveWidgetData<String>(key, jsonEncode(value));
  }

  static Future<void> _updateCalendarProviders() async {
    await _update(_calendarProvider);
  }

  static Future<void> _updateTaskProviders() async {
    await Future.wait([_update(_tasksProvider), _update(_shoppingProvider)]);
  }

  static Future<void> _update(String provider) async {
    if (!_isSupportedPlatform) return;
    try {
      await HomeWidget.updateWidget(
        androidName: provider,
        qualifiedAndroidName: '$_androidPackage.$provider',
      );
    } catch (e) {
      debugPrint('[WidgetService] update $provider failed: $e');
    }
  }
}
