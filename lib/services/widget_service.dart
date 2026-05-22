// lib/services/widget_service.dart
//
// Bridge between Flutter snapshots and Android home screen widgets.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _calendarProvider = 'CitrineCalendarWidgetReceiver';
  static const _filterProvider = 'CitrineFilterWidgetProvider';
  static const _pomodoroProvider = 'CitrinePomodoroWidgetProvider';

  static Future<void> init() async {
    await refreshAllWidgets();
  }

  static Future<void> updateDashboardWidgets({
    required Map<String, dynamic> calendar,
    required Map<String, dynamic> filter,
    required Map<String, dynamic> pomodoro,
  }) async {
    try {
      await Future.wait([
        _saveJson('citrine_calendar', calendar),
        _saveJson('citrine_filter', filter),
        _saveJson('citrine_pomodoro', pomodoro),
      ]);
      await refreshAllWidgets();
    } catch (e, st) {
      debugPrint('[WidgetService] updateDashboardWidgets failed: $e\n$st');
    }
  }

  static Future<void> updateHabits(List<dynamic> habits) async {
    await refreshAllWidgets();
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
  }) async {}

  static Future<void> updateQuickAddLabels({
    String journalLabel = 'Journal',
    String taskLabel = 'Task',
    String firstTarget = 'entry',
    String secondTarget = 'task',
  }) async {}

  static Future<void> refreshAllWidgets() async {
    await Future.wait([
      _updateCalendarProviders(),
      _update(_filterProvider),
      _update(_pomodoroProvider),
    ]);
  }

  static Future<void> updateLockNextSession({
    required String title,
    required String time,
    required String date,
  }) async {}

  static Future<void> updateUniversalWidget({
    required String type,
    required String title,
    String size = 'medium',
    Map<String, String>? data,
    int? widgetId,
  }) async {}

  static Future<List<int>> universalWidgetIds() async => [];

  static Future<void> saveUniversalWidgetConfig({
    required int widgetId,
    required String type,
    required String title,
    required String size,
    required String organizer,
    required List<String> objectTypes,
  }) async {}

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
  }) async {}

  static Future<void> updatePomodoroSummary({
    required String total,
    required String details,
    required List<bool> barActive,
    int? widgetId,
  }) async {}

  static Future<void> updateNextTask(dynamic task) async {
    await refreshAllWidgets();
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
  ) async {}

  static Future<void> updateOrganizerSummary({
    required String title,
    required String tasks,
    required String events,
    required String focus,
    required String stats,
    String slug = '',
  }) async {}

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
  }) async {}

  static Future<void> _saveJson(String key, Map<String, dynamic> value) {
    return HomeWidget.saveWidgetData<String>(key, jsonEncode(value));
  }

  static Future<void> _updateCalendarProviders() async {
    await _update(_calendarProvider);
  }

  static Future<void> _update(String provider) async {
    try {
      await HomeWidget.updateWidget(androidName: provider);
    } catch (e) {
      debugPrint('[WidgetService] update $provider failed: $e');
    }
  }
}
