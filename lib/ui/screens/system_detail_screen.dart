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
import '../theme.dart';
import '../forms/create_system_form.dart';
import '../forms/create_task_form.dart';

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
  late List<bool> _stepsDone;
  DateTime? _runStart;

  @override
  void initState() {
    super.initState();
    _stepsDone = List.filled(widget.system.steps.length, false);
    if (widget.autoStart) {
      _isRunning = true;
      _runStart = DateTime.now();
    }
  }

  void _startRun() {
    setState(() {
      _isRunning = true;
      _runStart = DateTime.now();
      _stepsDone = List.filled(_system.steps.length, false);
    });
  }

  Future<void> _finishRun() async {
    final elapsed = _runStart != null
        ? DateTime.now().difference(_runStart!).inMinutes
        : 0;
    final system = _system;
    final totalRuns = system.runCount + 1;
    final newAvg = ((system.averageMinutes * system.runCount) + elapsed) ~/ totalRuns;

    final updated = system.copyWith(
      runCount: totalRuns,
      lastRun: DateTime.now(),
      averageMinutes: newAvg,
    );
    await ref.read(systemsProvider.notifier).updateSystem(updated);

    HapticFeedback.mediumImpact();

    setState(() {
      _isRunning = false;
      _runStart = null;
      _stepsDone = List.filled(_system.steps.length, false);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('System concluído em $elapsed min!')),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cancelRun() {
    setState(() {
      _isRunning = false;
      _runStart = null;
      _stepsDone = List.filled(_system.steps.length, false);
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
      builder: (_) => AlertDialog(
        title: const Text('Excluir System?'),
        content: const Text('Esta ação pode ser desfeita por 30 dias.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(systemsProvider.notifier).deleteSystem(_system);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = _system;
    final history = ref.watch(tasksProvider)
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
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_tree_rounded, color: AppColors.primary, size: 24),
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
                    color: AppColors.primary,
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
                          label: const Text('Cancelar'),
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
                        'Nenhum step configurado. Edite o System para adicionar.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    )
                  else
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      child: Column(
                        children: [
                          ...system.steps.asMap().entries.map((e) {
                            final i = e.key;
                            final step = e.value;
                            final done = _isRunning && _stepsDone[i];
                            return Column(
                              children: [
                                ListTile(
                                  dense: true,
                                  leading: _isRunning
                                      ? GestureDetector(
                                          onTap: () => setState(() => _stepsDone[i] = !_stepsDone[i]),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: done ? AppColors.success : Colors.transparent,
                                              border: Border.all(
                                                color: done ? AppColors.success : AppColors.textMuted,
                                                width: 2,
                                              ),
                                            ),
                                            child: done
                                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                                : null,
                                          ),
                                        )
                                      : Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.4), width: 1.5),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${i + 1}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                                          ),
                                        ),
                                  title: Text(
                                    step.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      decoration: done ? TextDecoration.lineThrough : null,
                                      color: done
                                          ? AppTheme.textMutedColor(context)
                                          : AppTheme.textPrimaryColor(context),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: step.substeps.isNotEmpty
                                      ? Text(
                                          '${step.substeps.length} sub-steps',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        )
                                      : null,
                                ),
                                if (i < system.steps.length - 1)
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
            child: _buildHistorySection(context, history),
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
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
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
                              backgroundColor: AppColors.primary,
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

  Widget _buildHistorySection(BuildContext context, List<Task> history) {
    final visibleTasks = history.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'HISTORY',
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
                  '${history.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const Spacer(),
              if (history.length > 5)
                TextButton(
                  onPressed: () => _showAllHistory(context, history),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text('View all (${history.length})'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(history.isEmpty ? 16 : 0),
            decoration: AppTheme.cardDecoration(context),
            child: history.isEmpty
                ? Text(
                    'No runs yet. Use Quick Run or Create Task to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMutedColor(context),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < visibleTasks.length; i++) ...[
                        _buildHistoryTaskRow(context, visibleTasks[i]),
                        if (i < visibleTasks.length - 1)
                          const Divider(
                            height: 1,
                            indent: 52,
                            color: AppColors.divider,
                          ),
                      ],
                    ],
                  ),
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
      TaskStage.todo => AppColors.primary,
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
