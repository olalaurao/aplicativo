import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    await ref
        .read(tasksProvider.notifier)
        .addTask(
          Task(
            id: '',
            title: system.title,
            stage: TaskStage.finalized,
            createdAt: _runStart ?? DateTime.now(),
            duration: elapsed,
            linkedSystem: system.id,
          ),
        );

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
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text('System executed in ${elapsed}m'),
            ],
          ),
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
    TimeOfDay? initialTime;
    if (system.scheduledTime != null) {
      final parts = system.scheduledTime!.split(':');
      if (parts.length == 2) {
        initialTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskForm(
          initialTitle: system.title,
          initialTime: initialTime,
          existingTask: Task(
            id: '',
            title: system.title,
            stage: TaskStage.todo,
            createdAt: DateTime.now(),
            subtasks: subtasks,
            duration: system.estimatedMinutes > 0
                ? system.estimatedMinutes
                : 15,
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
        title: const Text('Delete System?'),
        content: const Text('This action can be undone for 30 days.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
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
    final doneCount = _systemDoneCount(system);
    final totalSteps = system.steps.length;
    final progress = totalSteps > 0 ? doneCount / totalSteps : 0.0;

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
                tooltip: 'Edit',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateSystemForm(existingSystem: system),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (val) {
                  if (val == 'delete') _delete();
                  if (val == 'create_task') _createTaskFromSystem();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'create_task',
                    child: Row(
                      children: [
                        Icon(Icons.add_task_rounded, size: 18),
                        SizedBox(width: 12),
                        Text('Create Task (Via A)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              system.title,
                              style: const TextStyle(
                                fontSize: AppTextSize.xxl,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _systemDateLabel(system),
                              style: const TextStyle(
                                fontSize: AppTextSize.sm,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          builder: (context, value, _) => Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: value,
                                strokeWidth: 5,
                                color: AppTheme.accentColor(context),
                                backgroundColor: AppTheme.accentColor(
                                  context,
                                ).withValues(alpha: 0.15),
                              ),
                              Text(
                                '${(value * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: AppTextSize.sm,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (system.trigger.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.flash_on_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
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
              child: _SystemProgressBanner(
                doneCount: doneCount,
                totalSteps: totalSteps,
                progress: progress,
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
                  if (system.steps.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(context),
                      child: const Text(
                        'No steps configured. Edit the System to add some.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    _buildSystemStepsCard(system),
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
                        Icon(
                          Icons.notes_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                          'Finish Run',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                            label: const Text(
                              'Create Task',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentColor(context),
                              side: BorderSide(
                                color: AppTheme.accentColor(context),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _createTaskFromSystem,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              'Run Now',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor(context),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: system.steps.isNotEmpty
                                ? _startRun
                                : null,
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

  int _systemDoneCount(SystemDefinition system) {
    return system.steps.where((step) {
      if (step.kind == 'plain') return _plainStepsDone.contains(step.id);
      return computeChecklistStepDone(
        kind: step.kind,
        linkedObjectSlug: step.linkedObjectSlug,
        trackerFieldId: step.trackerFieldId,
        date: _runStart ?? DateTime.now(),
        ref: ref,
        parentObjectId: system.id,
        itemId: step.id,
      );
    }).length;
  }

  String _systemDateLabel(SystemDefinition system) {
    final date = _runStart ?? DateTime.now();
    final formatted = DateFormat('EEE, d MMM yyyy').format(date);
    if (system.scheduledTime == null || system.scheduledTime!.isEmpty) {
      return formatted;
    }
    return '$formatted · ${system.scheduledTime}';
  }

  String _systemPeriodLabel(SystemDefinition system) {
    final raw = system.scheduledTime;
    if (raw == null || raw.isEmpty) return 'System';
    final hour = int.tryParse(raw.split(':').first) ?? 12;
    if (hour >= 5 && hour <= 11) return '🌅 Morning';
    if (hour >= 12 && hour <= 17) return '☀️ Afternoon';
    return '🌙 Night';
  }

  Widget _buildSystemStepsCard(SystemDefinition system) {
    final doneCount = _systemDoneCount(system);
    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _systemPeriodLabel(system),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTextSize.md,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$doneCount/${system.steps.length}',
                  style: const TextStyle(
                    fontSize: AppTextSize.sm,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...system.steps.asMap().entries.map((e) {
            final step = e.value;
            return DecoratedBox(
              decoration: BoxDecoration(
                border: e.key < system.steps.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.35),
                          width: AppBorder.thin,
                        ),
                      )
                    : null,
              ),
              child: ActionableChecklistTile(
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
                  final updatedSteps = List<SystemStep>.from(system.steps);
                  final stepIndex = updatedSteps.indexWhere(
                    (s) => s.id == step.id,
                  );
                  if (stepIndex != -1) {
                    updatedSteps[stepIndex] = step.copyWith(
                      linkedObjectSlug: taskSlug,
                    );
                    final updated = system.copyWith(steps: updatedSteps);
                    await ref
                        .read(systemsProvider.notifier)
                        .updateSystem(updated);
                  }
                },
              ),
            );
          }),
          if (_isRunning)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.close_rounded, size: AppIconSize.sm),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
                onPressed: _cancelRun,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExecutionHistorySection(
    BuildContext context,
    SystemDefinition system,
  ) {
    final cards = buildSystemPropertyCards(system);
    final historyCard = cards.firstWhere(
      (c) => c.label == 'Execution History',
      orElse: () => const PropertyCard(
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
}

class _SystemProgressBanner extends StatelessWidget {
  final int doneCount;
  final int totalSteps;
  final double progress;

  const _SystemProgressBanner({
    required this.doneCount,
    required this.totalSteps,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.accentColor(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$doneCount of $totalSteps tasks',
                style: TextStyle(
                  color: AppTheme.accentColor(context),
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              const Text(
                'today',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: AppTextSize.xs,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.xs),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: AppSpacing.xs,
              color: AppTheme.accentColor(context),
              backgroundColor: AppTheme.accentColor(
                context,
              ).withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}
