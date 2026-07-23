import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/system_model.dart';
import '../../models/task_model.dart';
import '../../models/shared_types.dart';
import '../../providers/systems_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/checklist_item_status.dart';
import '../theme.dart';
import '../forms/create_system_form.dart';
import '../forms/create_task_form.dart';
import '../widgets/actionable_checklist_tile.dart';
import '../widgets/property_grid.dart';
import 'detail_sections/system_detail_section.dart';

class SystemDetailScreen extends ConsumerStatefulWidget {
  final SystemDefinition system;
  final bool autoStart;
  const SystemDetailScreen({
    super.key,
    required this.system,
    this.autoStart = false,
  });

  @override
  ConsumerState<SystemDetailScreen> createState() => _SystemDetailScreenState();
}

class _SystemDetailScreenState extends ConsumerState<SystemDetailScreen> {
  SystemDefinition get _system {
    final all = ref.watch(systemsProvider);
    return all.firstWhere(
      (s) => s.id == widget.system.id,
      orElse: () => widget.system,
    );
  }

  // ──────────────────── Via C: Quick-run state ────────────────────
  bool _isRunning = false;
  final Set<String> _plainStepsDone = {}; // For plain items only
  DateTime? _runStart;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _isRunning = true;
      _runStart = DateTime.now();
    }
  }

  void _startRun() {
    setState(() {
      _isRunning = true;
      _runStart = DateTime.now();
      _plainStepsDone.clear();
    });
  }

  Future<void> _finishRun() async {
    final elapsed = _runStart != null
        ? DateTime.now().difference(_runStart!).inMinutes
        : 0;
    final system = _system;

    // Create a lightweight summary Task to feed the existing derivation path
    await ref.read(tasksProvider.notifier).addTask(Task(
      id: '',
      title: system.title,
      stage: TaskStage.finalized,
      createdAt: _runStart ?? DateTime.now(),
      estimatedMinutes: elapsed,
      linkedSystem: system.id,
    ));

    // Create execution record with step completions
    final stepCompletions = <String, bool>{};
    for (final step in system.steps) {
      if (step.kind == 'plain') {
        stepCompletions[step.id] = _plainStepsDone.contains(step.id);
      } else if (step.linkedObjectSlug != null) {
        // For linked steps, check if the linked object is completed
        final isDone = computeChecklistStepDone(
          kind: step.kind,
          linkedObjectSlug: step.linkedObjectSlug,
          trackerFieldId: step.trackerFieldId,
          date: _runStart ?? DateTime.now(),
          ref: ref,
          parentObjectId: system.id,
          itemId: step.id,
        );
        stepCompletions[step.id] = isDone;
      }
    }

    final execution = SystemExecution(
      executedAt: _runStart ?? DateTime.now(),
      stepCompletions: stepCompletions,
    );

    final updatedSystem = system.copyWith(
      executionHistory: [...system.executionHistory, execution],
    );
    await ref.read(systemsProvider.notifier).updateSystem(updatedSystem);

    HapticFeedback.mediumImpact();

    setState(() {
      _isRunning = false;
      _runStart = null;
      _plainStepsDone.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('System executed in ${elapsed}m'),
          ]),
        ),
      );
    }
  }

  void _cancelRun() {
    setState(() {
      _isRunning = false;
      _runStart = null;
      _plainStepsDone.clear();
    });
  }

  // ──────────────────── Via A: Create Task from System ────────────────────
  void _createTaskFromSystem() {
    final system = _system;
    // Pre-build subtasks from system steps
    final subtasks = system.steps.map((s) => Subtask(title: s.title)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskForm(
          initialTitle: system.title,
          existingTask: Task(
            id: '',
            title: system.title,
            stage: TaskStage.todo,
            createdAt: DateTime.now(),
            subtasks: subtasks,
            estimatedMinutes: system.estimatedMinutes > 0 ? system.estimatedMinutes : null,
            linkedSystem: system.id,
          ),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir System?'),
        content: const Text('Esta ação pode ser desfeita por 30 dias.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(systemsProvider.notifier).deleteSystem(_system);
      if (mounted) {
        // Force navigation back regardless of state
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = _system;
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final history = allObjects.whereType<Task>()
        .where((task) => task.linkedSystem == system.id)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'SYSTEM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateSystemForm(existingSystem: system),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  if (val == 'delete') _delete();
                  if (val == 'create_task') _createTaskFromSystem();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'create_task',
                    child: Row(children: [
                      Icon(Icons.add_task_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Criar Task (Via A)'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                      SizedBox(width: 12),
                      Text('Excluir', style: TextStyle(color: AppColors.error)),
                    ]),
                  ),
                ],
              ),
            ],
          ),

          // ─── Header ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.account_tree_rounded, color: AppTheme.accentColor(context), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          system.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  if (system.trigger.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Trigger: ${system.trigger}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ─── Stats ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  _StatCard(
                    label: 'Execuções',
                    value: '${system.runCount}x',
                    icon: Icons.replay_rounded,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 12),
                  if (system.estimatedMinutes > 0) ...[
                    _StatCard(
                      label: 'Estimated',
                      value: '${system.estimatedMinutes}m',
                      icon: Icons.hourglass_bottom_rounded,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                  ],
                  _StatCard(
                    label: 'Tempo médio',
                    value: system.averageMinutes > 0 ? '${system.averageMinutes}m' : '--',
                    icon: Icons.timer_rounded,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Última vez',
                    value: system.lastRun != null
                        ? DateFormat('d/M').format(system.lastRun!)
                        : 'Nunca',
                    icon: Icons.calendar_today_rounded,
                    color: AppTheme.accentColor(context),
                  ),
                ],
              ),
            ),
          ),

          // ─── Steps / Quick-Run ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rounded, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      const Text(
                        'Steps',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${system.steps.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                        ),
                      ),
                      const Spacer(),
                      if (_isRunning)
                        TextButton.icon(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Cancel'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                          onPressed: _cancelRun,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (system.steps.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(context),
                      child: const Text(
                        'No steps configured. Edit the System to add some.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    )
                  else
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      child: Column(
                        children: [
                          ...system.steps.asMap().entries.map((e) {
                            final step = e.value;
                            return Column(
                              children: [
                                ActionableChecklistTile(
                                  itemId: step.id,
                                  title: step.title,
                                  kind: step.kind,
                                  linkedObjectSlug: step.linkedObjectSlug,
                                  trackerFieldId: step.trackerFieldId,
                                  attachedCollectionSlug: step.attachedCollectionSlug,
                                  date: _runStart ?? DateTime.now(),
                                  parentObjectId: system.id,
                                  plainValue: _plainStepsDone.contains(step.id),
                                  onPlainToggle: (done) {
                                    setState(() {
                                      if (done) {
                                        _plainStepsDone.add(step.id);
                                      } else {
                                        _plainStepsDone.remove(step.id);
                                      }
                                    });
                                  },
                                  onTaskCreated: (taskSlug) async {
                                    // Persist the new task slug back to the system step
                                    final updatedSteps = List<SystemStep>.from(system.steps);
                                    final stepIndex = updatedSteps.indexWhere((s) => s.id == step.id);
                                    if (stepIndex != -1) {
                                      updatedSteps[stepIndex] = step.copyWith(linkedObjectSlug: taskSlug);
                                      final updated = system.copyWith(steps: updatedSteps);
                                      await ref.read(systemsProvider.notifier).updateSystem(updated);
                                      // No need to setState - the provider will trigger rebuild
                                    }
                                  },
                                ),
                                if (e.key < system.steps.length - 1)
                                  const Divider(height: 1, indent: 48, color: AppColors.divider),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _buildExecutionHistorySection(context, system),
          ),

          // ─── Description ───
          if (system.description.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notes_rounded, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Descrição', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(context),
                      child: Text(
                        system.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryColor(context),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),

      // ─── Execute Button (Via C) / Finish Button ───
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: _isRunning
              ? Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text(
                          'Concluir Execução',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: _finishRun,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add_task_rounded, size: 18),
                            label: const Text('Criar Task', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentColor(context),
                              side: BorderSide(color: AppTheme.accentColor(context)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _createTaskFromSystem,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text(
                              'Executar Agora',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor(context),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: system.steps.isNotEmpty ? _startRun : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildExecutionHistorySection(BuildContext context, SystemDefinition system) {
    final cards = buildSystemPropertyCards(system);
    final historyCard = cards.firstWhere(
      (c) => c.label == 'Execution History',
      orElse: () => PropertyCard(
        icon: Icons.history,
        label: 'Execution History',
        value: 'No history yet',
        state: PropertyCardState.empty,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'EXECUTION HISTORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${system.executionHistory.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(system.executionHistory.isEmpty ? 16 : 0),
            decoration: AppTheme.cardDecoration(context),
            child: system.executionHistory.isEmpty
                ? Text(
                    'No runs yet. Use Quick Run to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMutedColor(context),
                    ),
                  )
                : historyCard.customChild ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTaskRow(BuildContext context, Task task) {
    final minutes = task.pomodoroCount != null && task.pomodoroCount! > 0
        ? task.pomodoroCount! * 25
        : task.estimatedMinutes;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: const Icon(
        Icons.check_circle_outline_rounded,
        size: 18,
        color: AppColors.info,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _relativeDate(task.updatedAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (minutes != null && minutes > 0)
              Text(
                '${minutes}min',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            _buildStageBadge(task.stage),
          ],
        ),
      ),
      onTap: () => context.push('/detail/${task.id}', extra: {'object': task}),
    );
  }

  void _showAllHistory(BuildContext context, List<Task> history) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${history.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: history.length,
                      separatorBuilder: (_, index) => const Divider(
                        height: 1,
                        indent: 72,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (context, index) =>
                          _buildHistoryTaskRow(context, history[index]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStageBadge(TaskStage stage) {
    final color = switch (stage) {
      TaskStage.finalized => AppColors.success,
      TaskStage.inProgress => AppColors.info,
      TaskStage.pending => AppColors.warning,
      TaskStage.backlog => AppColors.textMuted,
      TaskStage.idea => AppColors.secondary,
      TaskStage.todo => AppTheme.accentColor(context),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _stageLabel(stage),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _stageLabel(TaskStage stage) {
    switch (stage) {
      case TaskStage.idea:
        return 'Idea';
      case TaskStage.backlog:
        return 'Backlog';
      case TaskStage.todo:
        return 'Todo';
      case TaskStage.inProgress:
        return 'In progress';
      case TaskStage.pending:
        return 'Pending';
      case TaskStage.finalized:
        return 'Done';
    }
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return DateFormat('d/M').format(date);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
