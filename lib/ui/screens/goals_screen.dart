import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/goal_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/kpi_engine.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/object_action_wrapper.dart';
import '../forms/create_goal_form.dart';
import 'universal_detail_view.dart';

import 'package:flutter/services.dart';
import '../../models/saved_filter.dart';
import '../../providers/settings_provider.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  SavedFilter? _activeFilter;
  List<SavedFilter> _savedFilters = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _savedFilters = ref.read(settingsProvider).filtersFor('goal'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final activeGoals = goals
        .where((g) => g.state == GoalStatus.active)
        .toList();
    final completedGoals = goals
        .where((g) => g.state == GoalStatus.completed)
        .toList();
    final onHoldGoals = goals
        .where((g) => g.state == GoalStatus.onHold)
        .toList();
    final cancelledGoals = goals
        .where((g) => g.state == GoalStatus.cancelled)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            title: Text('Goals'),
            centerTitle: true,
            floating: true,
            pinned: true,
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Metas',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
                Text('${completedGoals.length}/${goals.length}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goals.isEmpty ? 0 : completedGoals.length / goals.length,
                  minHeight: 6,
                  backgroundColor: AppTheme.surfaceVariantColor(context),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
              const SizedBox(height: 4),
              Text('${activeGoals.length} em andamento · ${onHoldGoals.length} pausadas',
                style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context))),
            ]))),
          if (goals.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(context),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (activeGoals.isNotEmpty) ...[
                    _buildSectionHeader('IN PROGRESS'),
                    const SizedBox(height: 12),
                    ...activeGoals.map((g) => _GoalCard(goal: g)),
                  ],
                  if (onHoldGoals.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader('ON HOLD'),
                    const SizedBox(height: 12),
                    ...onHoldGoals.map((g) => _GoalCard(goal: g)),
                  ],
                  if (completedGoals.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader('COMPLETED'),
                    const SizedBox(height: 12),
                    ...completedGoals.map(
                      (g) => _GoalCard(goal: g, isCompleted: true),
                    ),
                  ],
                  if (cancelledGoals.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader('CANCELLED'),
                    const SizedBox(height: 12),
                    ...cancelledGoals.map(
                      (g) => _GoalCard(goal: g, isCompleted: true),
                    ),
                  ],
                ]),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGoalForm()),
        ),
        backgroundColor: AppColors.primary,
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

  const _GoalCard({required this.goal, this.isCompleted = false});

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

    return ObjectActionWrapper(
      object: goal,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UniversalDetailView(object: goal)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: AppTheme.cardDecoration(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.textMuted : color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20), bottomLeft: Radius.circular(20))),
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
                          _buildProgressInfo(context, ref),
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

  Widget _buildProgressInfo(BuildContext context, WidgetRef ref) {
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
    final progress = _calculateLiveProgress(ref);

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
              if (goal.subtasks.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.checklist_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${goal.subtasks.where((s) => s.completed).length}/${goal.subtasks.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// Calculate live progress using KPIEngine for real-time values.
  double _calculateLiveProgress(WidgetRef ref) {
    if (goal.kpis.isEmpty && goal.subtasks.isEmpty) return goal.progress;

    final habits = ref.watch(habitsProvider);
    final trackerRecords = ref.watch(trackingRecordsProvider);
    final entries = ref.watch(allEntriesProvider);
    final moods = ref.watch(moodsProvider);
    final notes = ref.watch(notesProvider);

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
        notes: notes,
      );
      completed += (currentValue / kpi.targetValue).clamp(0.0, 1.0);
    }

    for (final st in goal.subtasks) {
      total += 1;
      if (st.completed) completed += 1;
    }

    return total > 0 ? (completed / total) : 0;
  }
}
