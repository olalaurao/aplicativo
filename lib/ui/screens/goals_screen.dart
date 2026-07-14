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
import '../../models/kpi_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/kpi_engine.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/overdue_section.dart';
import '../widgets/incomplete_badge.dart';
import '../forms/create_goal_form.dart';
import 'universal_detail_view.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final goals = allObjects.whereType<Goal>().toList();
    final activeGoals = goals
        .where((g) => g.state == GoalStatus.active && !g.archived)
        .toList();
    final completedGoals = goals
        .where((g) => g.state == GoalStatus.completed && !g.archived)
        .toList();
    final onHoldGoals = goals
        .where((g) => g.state == GoalStatus.onHold && !g.archived)
        .toList();
    final cancelledGoals = goals
        .where((g) => g.state == GoalStatus.cancelled && !g.archived)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Goals',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Metas',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${completedGoals.length}/${goals.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: goals.isEmpty
                          ? 0
                          : completedGoals.length / goals.length,
                      minHeight: 6,
                      backgroundColor: AppTheme.surfaceVariantColor(context),
                      valueColor: AlwaysStoppedAnimation(
                        AppTheme.accentColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${activeGoals.length} em andamento · ${onHoldGoals.length} pausadas',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: goals.isEmpty
                  ? _buildEmptyState(context)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      children: [
                        const OverdueSection(filterTypes: ['goal']),
                        if (activeGoals.isNotEmpty) ...[
                          _buildSectionHeader('IN PROGRESS'),
                          const SizedBox(height: 12),
                          ...activeGoals.map((g) => _GoalCard(key: ValueKey(g.id), goal: g)),
                        ],
                        if (onHoldGoals.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildSectionHeader('ON HOLD'),
                          const SizedBox(height: 12),
                          ...onHoldGoals.map((g) => _GoalCard(key: ValueKey(g.id), goal: g)),
                        ],
                        if (completedGoals.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildSectionHeader('COMPLETED'),
                          const SizedBox(height: 12),
                          ...completedGoals.map(
                            (g) => _GoalCard(key: ValueKey(g.id), goal: g, isCompleted: true),
                          ),
                        ],
                        if (cancelledGoals.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildSectionHeader('CANCELLED'),
                          const SizedBox(height: 12),
                          ...cancelledGoals.map(
                            (g) => _GoalCard(key: ValueKey(g.id), goal: g, isCompleted: true),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGoalForm()),
        ),
        backgroundColor: AppTheme.accentColor(context),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.flag_circle_rounded,
      headline: 'Define your goals',
      subtext:
          'Turn your dreams into actionable steps. Start by creating your first goal.',
      ctaLabel: 'Create Goal',
      onCta: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateGoalForm()),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Extracted as a ConsumerWidget so it can watch providers for live KPI data.
class _GoalCard extends ConsumerWidget {
  final Goal goal;
  final bool isCompleted;

  const _GoalCard({super.key, required this.goal, this.isCompleted = false});

  Color _goalColor(String? rawColor) {
    if (rawColor == null || rawColor.trim().isEmpty) return AppColors.primary;
    try {
      final normalized = rawColor.trim().replaceFirst('#', '0xFF');
      final parsed = int.tryParse(normalized);
      if (parsed == null) return AppColors.primary;
      return Color(parsed);
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _goalColor(goal.color);
    final accentColor = color;

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
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final notes = needsLiveData 
        ? allObjects.whereType<Note>().where((n) => 
            goal.kpis.any((k) => k.sourceType == KPISourceType.collection && k.sourceId == n.id)
          ).toList()
        : <Note>[];
    final tasks = needsLiveData 
        ? allObjects.whereType<Task>().where((t) => 
            goal.kpis.any((k) => k.sourceType == KPISourceType.subtasks && 
                (t.organizers.any((org) => org.slug == k.sourceId) || 
                 t.dependsOn.contains('[[${k.sourceId}]]')))
          ).toList()
        : <Task>[];

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UniversalDetailView(object: goal)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: AppTheme.cardDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.textMuted : accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (goal.icon != null) ...[
                                Text(
                                  goal.icon!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isCompleted
                                        ? AppColors.textMuted
                                        : AppColors.textPrimary,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IncompleteBadge(visible: goal.isIncomplete),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                          if (goal.description != null &&
                              goal.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              goal.description!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildProgressInfo(
                            context,
                            ref: ref,
                            habits: habits,
                            trackerRecords: trackerRecords,
                            entries: entries,
                            moods: moods,
                            allObjects: allObjects,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressInfo(
    BuildContext context, {
    required WidgetRef ref,
    required List<Habit> habits,
    required List<TrackingRecord> trackerRecords,
    required List<JournalEntry> entries,
    required List<MoodDefinition> moods,
    required List<dynamic> allObjects,
  }) {
    if (isCompleted) {
      return Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.habitGreen,
          ),
          const SizedBox(width: 4),
          Text(
            goal.state == GoalStatus.cancelled ? 'Cancelled' : 'Completed',
            style: TextStyle(
              fontSize: 12,
              color: goal.state == GoalStatus.cancelled
                  ? AppColors.textMuted
                  : AppColors.habitGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final deadline = goal.deadline;
    final progress = _calculateLiveProgress(
      habits: habits,
      trackerRecords: trackerRecords,
      entries: entries,
      moods: moods,
      allObjects: allObjects,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(_goalColor(goal.color)),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (deadline != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Deadline: ${DateFormat('d MMM yyyy').format(deadline)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (deadline.isBefore(DateTime.now())) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'OVERDUE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (goal.kpis.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${goal.kpis.length} KPI${goal.kpis.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Calculate live progress using KPIEngine for real-time values.
  double _calculateLiveProgress({
    required List<Habit> habits,
    required List<TrackingRecord> trackerRecords,
    required List<JournalEntry> entries,
    required List<MoodDefinition> moods,
    required List<dynamic> allObjects,
  }) {
    if (goal.kpis.isEmpty) return goal.progress;

    double total = 0;
    double completed = 0;

    for (final kpi in goal.kpis) {
      total += 1;
      final currentValue = KPIEngine.calculateKPIValue(
        kpi: kpi,
        habits: habits,
        trackerRecords: trackerRecords,
        entries: entries,
        moods: moods,
        allObjects: allObjects,
      );
      completed += (currentValue / kpi.targetValue).clamp(0.0, 1.0);
    }

    return total > 0 ? (completed / total) : 0;
  }
}
