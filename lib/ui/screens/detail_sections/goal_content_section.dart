// lib/ui/screens/detail_sections/goal_content_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/goal_model.dart';
import '../../../models/habit_model.dart';
import '../../../models/tracker_model.dart';
import '../../../models/journal_entry.dart';
import '../../../models/mood_model.dart';
import '../../../models/note_model.dart';
import '../../../models/task_model.dart';
import '../../../models/kpi_model.dart';
import '../../../services/kpi_engine.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';

/// Goal-specific content section for universal detail view
List<Widget> buildGoalContentSection(
  BuildContext context,
  WidgetRef ref,
  Goal goal,
  Widget Function(BuildContext, WidgetRef, Goal, KPI) buildKPICard,
  Widget Function(BuildContext, WidgetRef, String) buildSnapshotsSection,
) {
  // Only watch providers if the goal has KPIs that need live calculation
  final needsLiveData = goal.kpis.isNotEmpty;
  
  // Use .select() to narrow watches to only objects referenced by this goal's KPIs
  final habits = needsLiveData 
      ? ref.watch(habitsProvider.select((habits) => habits.where((h) => 
          goal.kpis.any((k) => k.sourceType == KPISourceType.habit && k.sourceId == h.id)
        ).toList()))
      : <Habit>[];
  final trackerRecords = needsLiveData 
      ? ref.watch(trackingRecordsProvider.select((records) => records.where((r) => 
          goal.kpis.any((k) => k.sourceType == KPISourceType.trackerField && k.sourceId == r.trackerId)
        ).toList()))
      : <TrackingRecord>[];
  final entries = needsLiveData 
      ? ref.watch(allEntriesProvider.select((entries) => entries.where((e) => 
          goal.kpis.any((k) => k.sourceType == KPISourceType.entry)
        ).toList()))
      : <JournalEntry>[];
  final moods = needsLiveData 
      ? ref.watch(moodsProvider.select((moods) => moods.where((m) => 
          goal.kpis.any((k) => k.sourceType == KPISourceType.others && 
              (k.calculationMode == 'mood_average' || k.calculationMode == 'mood_trend'))
        ).toList()))
      : <MoodDefinition>[];
  final notes = needsLiveData 
      ? ref.watch(notesProvider.select((notes) => notes.where((n) => 
          goal.kpis.any((k) => k.sourceType == KPISourceType.collection && k.sourceId == n.id)
        ).toList()))
      : <Note>[];
  final tasks = needsLiveData 
      ? ref.watch(tasksProvider.select((tasks) => tasks.where((t) => 
          goal.kpis.any((k) => k.sourceType == KPISourceType.subtasks && 
              (t.organizers.any((org) => org.slug == k.sourceId) || 
               t.dependsOn.contains('[[${k.sourceId}]]')))
        ).toList()))
      : <Task>[];

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
      notes: notes,
      tasks: tasks,
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
