// lib/ui/screens/detail_views/goal_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/goal_model.dart';
import '../../models/habit_model.dart';
import '../../models/tracker_model.dart';
import '../../models/journal_entry.dart';
import '../../models/mood_model.dart';
import '../../models/note_model.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/kpi_engine.dart';
import '../widgets/property_grid.dart';
import '../theme.dart';

/// Goal-specific detail view methods extracted from universal_detail_view.dart
class GoalDetailView {
  /// Build property cards specific to Goal objects
  static List<PropertyCard> buildPropertyCards(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
    Function(ContentObject) isOverdue,
  ) {
    final cards = <PropertyCard>[];
    
    cards.add(PropertyCard(
      icon: Icons.calendar_today,
      label: 'Início',
      value: goal.startDate != null ? DateFormat('d MMM yyyy').format(goal.startDate!) : 'Não definida',
      state: goal.startDate == null ? PropertyCardState.empty : PropertyCardState.normal,
    ));
    
    cards.add(PropertyCard(
      icon: Icons.event,
      label: 'Prazo',
      value: goal.deadline != null ? DateFormat('d MMM yyyy').format(goal.deadline!) : 'Não definida',
      state: goal.deadline == null ? PropertyCardState.empty : (isOverdue(goal) ? PropertyCardState.overdue : PropertyCardState.normal),
    ));
    
    cards.add(PropertyCard(
      icon: Icons.repeat,
      label: 'Tipo',
      value: goal.goalType == GoalType.repeating ? 'Recorrente' : 'Pontual',
      onTap: () => _showEnumPropertyPicker<GoalType>(
        context: context,
        title: 'Tipo',
        values: GoalType.values,
        initialValue: goal.goalType,
        labelBuilder: (s) => s.name,
        onSave: (val) {
          final updated = goal.copyWith(goalType: val);
          ref.read(vaultProvider.notifier).updateObject(updated);
        },
      ),
    ));
    
    cards.add(PropertyCard(
      icon: Icons.timelapse,
      label: 'Intervalo',
      value: goal.repeatInterval ?? 'Não definido',
      state: goal.repeatInterval == null ? PropertyCardState.empty : PropertyCardState.normal,
    ));
    
    return cards;
  }

  /// Build content slivers specific to Goal objects
  static List<Widget> buildContentSlivers(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
    Widget Function(BuildContext, WidgetRef, Goal, dynamic) buildKPICard,
    Widget Function(BuildContext, WidgetRef, String) buildSnapshotsSection,
  ) {
    // Only watch providers if the goal has KPIs that need live calculation
    final needsLiveData = goal.kpis.isNotEmpty;
    final allObjects = needsLiveData ? ref.watch(allObjectsProvider).value ?? [] : <ContentObject>[];
    final habits = needsLiveData ? allObjects.whereType<Habit>().toList() : <Habit>[];
    final trackerRecords = needsLiveData ? ref.watch(trackingRecordsProvider) : <TrackingRecord>[];
    final entries = needsLiveData ? ref.watch(allEntriesProvider) : <JournalEntry>[];
    final moods = needsLiveData ? ref.watch(moodsProvider) : <MoodDefinition>[];
    final notes = allObjects.whereType<Note>().toList();
    final tasks = allObjects.whereType<Task>().toList();

    double total = 0;
    double completed = 0;
    for (final kpi in goal.kpis) {
      total += 1;
      final val = KPIEngine.calculateKPIValue(
        kpi: kpi,
        habits: habits,
        trackerRecords: trackerRecords,
        entries: entries,
        moods: moods,
        allObjects: allObjects,
      );
      completed += (val / kpi.targetValue).clamp(0.0, 1.0);
    }
    final progress = total > 0 ? (completed / total) : 0.0;
    final kpisDone = goal.kpis.where((k) => k.completed).length;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.accentColor(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.accentColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$kpisDone de ${goal.kpis.length} KPIs atingidos',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Indicadores de Sucesso (KPIs)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ...goal.kpis.map(
                (kpi) => buildKPICard(context, ref, goal, kpi),
              ),
              const SizedBox(height: 24),
              buildSnapshotsSection(context, ref, goal.id),
            ],
          ),
        ),
      ),
    ];
  }

  /// Handle property tap for Goal objects
  static void onPropertyTap(
    BuildContext context,
    WidgetRef ref,
    String key,
    Goal goal,
  ) {
    if (key == 'Status' || key == 'Estado') {
      _showGoalStatePicker(context, ref, goal);
    }
  }

  /// Capture current KPI values for undo
  static Map<String, double> captureCurrentKPIValues(
    WidgetRef ref,
    Goal goal,
  ) {
    final Map<String, double> currentKPIs = {};
    final habits = ref.read(habitsProvider);
    final trackerRecords = ref.read(trackingRecordsProvider);
    final entries = ref.read(allEntriesProvider);
    final moods = ref.read(moodsProvider);
    final allObjects = ref.read(allObjectsProvider).value ?? [];
    final notes = allObjects.whereType<Note>().toList();
    final tasks = allObjects.whereType<Task>().toList();

    for (final kpi in goal.kpis) {
      currentKPIs[kpi.id] = KPIEngine.calculateKPIValue(
        kpi: kpi,
        habits: habits,
        trackerRecords: trackerRecords,
        entries: entries,
        moods: moods,
        allObjects: allObjects,
      );
    }
    return currentKPIs;
  }

  // Private helper methods

  static void _showEnumPropertyPicker<T>({
    required BuildContext context,
    required String title,
    required List<T> values,
    required T initialValue,
    required String Function(T) labelBuilder,
    required Function(T) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          ...values.map((value) => ListTile(
            title: Text(labelBuilder(value)),
            trailing: initialValue == value ? const Icon(Icons.check) : null,
            onTap: () {
              onSave(value);
              Navigator.pop(ctx);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static void _showGoalStatePicker(BuildContext context, WidgetRef ref, Goal goal) {
    _showEnumPropertyPicker<GoalState>(
      context: context,
      title: 'Estado do Objetivo',
      values: GoalState.values,
      initialValue: goal.state,
      labelBuilder: (value) => _translateGoalState(value),
      onSave: (value) {
        final updated = goal.copyWith(state: value);
        ref.read(vaultProvider.notifier).updateObject(updated);
      },
    );
  }

  static String _translateGoalState(GoalState state) {
    switch (state) {
      case GoalState.idea:
        return 'Ideia';
      case GoalState.planning:
        return 'Planejamento';
      case GoalState.active:
        return 'Ativo';
      case GoalState.paused:
        return 'Pausado';
      case GoalState.completed:
        return 'Concluído';
      case GoalState.archived:
        return 'Arquivado';
    }
  }
}
