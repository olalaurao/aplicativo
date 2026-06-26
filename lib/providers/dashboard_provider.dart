// lib/providers/dashboard_provider.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_block.dart';

class DashboardNotifier extends AsyncNotifier<List<DashboardBlock>> {
  static const _prefKey = 'dashboard_blocks_v3';

  @override
  Future<List<DashboardBlock>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKey);

    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((item) => DashboardBlock.fromMap(item)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static final List<DashboardBlock> _defaultBlocks = [
    DashboardBlock(
      id: 'home-calendar',
      type: BlockType.calendar,
      title: 'Calendário',
      order: 0,
    ),
    DashboardBlock(
      id: 'home-area',
      type: BlockType.organizerSummary,
      title: 'Filtro',
      order: 1,
      metadata: {
        'size': 'medium',
        'filterObjectTypes': ['task', 'habit'],
      },
    ),
    DashboardBlock(
      id: 'home-pomodoro-week',
      type: BlockType.pomodoroSummary,
      title: 'Pomodoros da Semana',
      order: 2,
    ),
    DashboardBlock(
      id: 'home-universal',
      type: BlockType.universal,
      title: 'Hoje',
      order: 3,
      metadata: {
        'sourceBlockType': 'plannerDay',
        'size': 'large',
        'objectTypes': ['task', 'goal'],
      },
    ),
    DashboardBlock(
      id: 'home-shopping',
      type: BlockType.shoppingList,
      title: 'Lista de Mercado',
      order: 4,
    ),
    DashboardBlock(
      id: 'home-pacts',
      type: BlockType.pactToday,
      title: 'Pacts Hoje',
      order: 5,
    ),
  ];

  static final List<DashboardBlock> availableWidgetBlocks = [
    DashboardBlock(
      id: 'shortcuts',
      type: BlockType.shortcuts,
      title: 'Atalhos',
      order: 0,
    ),
    DashboardBlock(
      id: 'habits',
      type: BlockType.habits,
      title: 'Habits',
      order: 1,
    ),
    DashboardBlock(
      id: 'tasks',
      type: BlockType.tasks,
      title: 'Tasks',
      order: 2,
    ),
    DashboardBlock(
      id: 'goals',
      type: BlockType.goals,
      title: 'Goals',
      order: 3,
    ),
    DashboardBlock(
      id: 'timeline',
      type: BlockType.timeline,
      title: 'Timeline',
      order: 4,
    ),
    DashboardBlock(
      id: 'notes',
      type: BlockType.notes,
      title: 'Notes',
      order: 5,
    ),
    DashboardBlock(
      id: 'planner-day',
      type: BlockType.plannerDay,
      title: 'Planner do Dia',
      order: 7,
    ),
    DashboardBlock(
      id: 'planner-week',
      type: BlockType.plannerWeek,
      title: 'Week',
      order: 8,
    ),
    DashboardBlock(
      id: 'planner-month',
      type: BlockType.plannerMonth,
      title: 'Month',
      order: 9,
    ),
    DashboardBlock(
      id: 'calendar',
      type: BlockType.calendar,
      title: 'Calendário',
      order: 10,
    ),
    DashboardBlock(
      id: 'google-calendar',
      type: BlockType.googleCalendar,
      title: 'Google Calendar',
      order: 11,
    ),
    DashboardBlock(
      id: 'pomodoro-summary',
      type: BlockType.pomodoroSummary,
      title: 'Resumo Focus',
      order: 12,
    ),
    DashboardBlock(
      id: 'timer',
      type: BlockType.timer,
      title: 'Focus Agora',
      order: 12,
    ),
    DashboardBlock(
      id: 'tracker-field',
      type: BlockType.trackerField,
      title: 'Latest Metric',
      order: 13,
    ),
    DashboardBlock(
      id: 'people',
      type: BlockType.people,
      title: 'People',
      order: 14,
    ),
    DashboardBlock(
      id: 'resources',
      type: BlockType.resources,
      title: 'Resources',
      order: 15,
    ),
    DashboardBlock(id: 'mood', type: BlockType.mood, title: 'Mood', order: 16),
    DashboardBlock(id: 'kpi', type: BlockType.kpi, title: 'KPIs', order: 17),
    DashboardBlock(
      id: 'daily-goal',
      type: BlockType.dailyGoal,
      title: 'Daily Goal',
      order: 18,
    ),
    DashboardBlock(
      id: 'pact-today',
      type: BlockType.pactToday,
      title: 'Pacts Hoje',
      order: 19,
    ),
    DashboardBlock(
      id: 'analysis-trend',
      type: BlockType.analysisTrend,
      title: 'Insights',
      order: 20,
    ),
    DashboardBlock(
      id: 'habit-trend',
      type: BlockType.habitTrend,
      title: 'Atividade de Habits',
      order: 21,
    ),
    DashboardBlock(
      id: 'journal-quick-add',
      type: BlockType.journalQuickAdd,
      title: 'Quick Entry',
      order: 22,
    ),
    DashboardBlock(
      id: 'time-blocking',
      type: BlockType.timeBlocking,
      title: 'Time Blocks',
      order: 23,
    ),
    DashboardBlock(
      id: 'photos',
      type: BlockType.photos,
      title: 'Fotos',
      order: 24,
    ),
    DashboardBlock(
      id: 'custom-markdown',
      type: BlockType.customMarkdown,
      title: 'Markdown',
      order: 25,
    ),
    DashboardBlock(
      id: 'organizer-summary',
      type: BlockType.organizerSummary,
      title: 'Filtro',
      order: 26,
    ),
    DashboardBlock(
      id: 'quotes',
      type: BlockType.quotes,
      title: 'Quote',
      order: 27,
    ),
    DashboardBlock(
      id: 'system-quick-run',
      type: BlockType.systemQuickRun,
      title: 'Systems',
      order: 28,
    ),
    DashboardBlock(
      id: 'energy-map',
      type: BlockType.energyMap,
      title: 'Energy Map',
      order: 29,
    ),
  ];

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.valueOrNull ?? [];
    await prefs.setString(
      _prefKey,
      jsonEncode(data.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> toggleVisibility(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final block in current)
        if (block.id == id)
          DashboardBlock(
            id: block.id,
            type: block.type,
            title: block.title,
            visible: !block.visible,
            order: block.order,
            metadata: block.metadata,
          )
        else
          block,
    ]);
    await _save();
  }

  Future<void> reorderBlocks(int oldIndex, int newIndex) async {
    final current = state.valueOrNull ?? [];
    final list = List<DashboardBlock>.from(current);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Update order values
    state = AsyncData(
      list.asMap().entries.map((entry) {
        final block = entry.value;
        return DashboardBlock(
          id: block.id,
          type: block.type,
          title: block.title,
          visible: block.visible,
          order: entry.key,
          metadata: block.metadata,
        );
      }).toList(),
    );
    await _save();
  }

  Future<void> updateBlock(DashboardBlock updated) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final block in current)
        if (block.id == updated.id) updated else block,
    ]);
    await _save();
  }

  Future<void> addBlock(
    BlockType type,
    String title, {
    Map<String, dynamic> metadata = const {},
  }) async {
    final current = state.valueOrNull ?? [];
    final newBlock = DashboardBlock(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: title,
      order: current.length,
      metadata: metadata,
    );
    state = AsyncData([...current, newBlock]);
    await _save();
  }

  Future<void> removeBlock(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((block) => block.id != id).toList());
    await _save();
  }

  Future<void> clearAll() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, List<DashboardBlock>>(() {
      return DashboardNotifier();
    });
