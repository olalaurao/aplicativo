import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/project_model.dart';
import '../../models/shared_types.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/rotation_service.dart';
import '../forms/create_task_form.dart';
import '../theme.dart';

// Top-level function for compute() - must be static or top-level
({Project updated, bool advanced, RotationGroup? nextGroup, bool viaTimeout})
_checkAndAdvanceZoneIsolate(({Project project, List<Task> allTasks}) params) {
  return RotationService.checkAndAdvanceZone(params.project, params.allTasks);
}

class RotationZoneDetailScreen extends ConsumerWidget {
  final String projectId;
  final String groupId;
  final bool isPreview;

  const RotationZoneDetailScreen({
    super.key,
    required this.projectId,
    required this.groupId,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref
        .watch(projectsProvider)
        .cast<Project?>()
        .firstWhere((p) => p?.id == projectId, orElse: () => null);
    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Project not found')),
      );
    }

    final group = project.rotationGroups.cast<RotationGroup?>().firstWhere(
      (g) => g?.id == groupId,
      orElse: () => null,
    );
    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Zone not found')),
      );
    }

    final activeStatus = RotationService.computeActiveStatus(project);
    final isActiveZone = activeStatus?.group.id == groupId;
    final status = isActiveZone ? activeStatus : _previewStatus(project, group);

    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final allTasks = allObjects.whereType<Task>().toList();
    final tasks = RotationService.rotationTasksForGroup(
      project,
      group,
      allTasks,
    );

    final daily = tasks
        .where((t) => t.rotationFrequencyType == RotationFrequencyType.daily)
        .toList();
    final once = tasks
        .where(
          (t) => t.rotationFrequencyType == RotationFrequencyType.oncePerPeriod,
        )
        .toList();
    final everyN = tasks.where((t) {
      if (t.rotationFrequencyType != RotationFrequencyType.everyNRotations) {
        return false;
      }
      if (status == null) return false;
      return RotationService.isDueNow(t, status);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isPreview ? 'ZONE: ${group.name.toUpperCase()}' : 'ACTIVE ZONE',
          style: const TextStyle(
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          if (isPreview && status != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: AppTheme.cardDecoration(context),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This zone is not active yet — available on ${DateFormat('d MMM yyyy').format(status.periodStart)}',
                      style: const TextStyle(fontSize: AppTextSize.sm),
                    ),
                  ),
                ],
              ),
            ),
          if (status != null) _ZoneHero(status: status, group: group),
          const SizedBox(height: AppSpacing.lg),
          _section(
            context,
            ref,
            project,
            'DAILY — reset every day',
            daily,
            status,
            RotationFrequencyType.daily,
          ),
          _section(
            context,
            ref,
            project,
            'ONCE PER PERIOD',
            once,
            status,
            RotationFrequencyType.oncePerPeriod,
          ),
          _section(
            context,
            ref,
            project,
            'BY FREQUENCY',
            everyN,
            status,
            RotationFrequencyType.everyNRotations,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateTaskForm(
              initialOrganizers: [_projectReference(project)],
              initialRotationGroupId: group.id,
              initialRotationFrequencyType: RotationFrequencyType.oncePerPeriod,
            ),
          ),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  RotationStatus? _previewStatus(Project project, RotationGroup group) {
    final upcoming = RotationService.upcomingGroups(project);
    for (final entry in upcoming) {
      if (entry.group.id == group.id) {
        return RotationStatus(
          group: group,
          dayOfPeriod: 1,
          periodStart: entry.startsAt,
          periodEnd: entry.endsAt,
          occurrenceNumber: 1,
        );
      }
    }
    return null;
  }

  Widget _section(
    BuildContext context,
    WidgetRef ref,
    Project project,
    String title,
    List<Task> tasks,
    RotationStatus? status,
    RotationFrequencyType type,
  ) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: AppTheme.cardDecoration(context),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ...tasks.asMap().entries.map((entry) {
                final index = entry.key;
                final task = entry.value;
                final done = _isDone(task, status, type);
                return _RotationZoneTaskRow(
                  task: task,
                  type: type,
                  status: status,
                  done: done,
                  showDivider: index < tasks.length - 1,
                  disabled: isPreview || status == null,
                  onToggle: isPreview || status == null
                      ? null
                      : () =>
                            _toggle(context, ref, project, task, status, type),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  bool _isDone(Task task, RotationStatus? status, RotationFrequencyType type) {
    if (status == null) return false;
    return switch (type) {
      RotationFrequencyType.daily =>
        task.rotationDailyCompletions[RotationService.dateKey(
              DateTime.now(),
            )] ==
            true,
      RotationFrequencyType.oncePerPeriod =>
        RotationService.isDoneThisOccurrence(task, status),
      RotationFrequencyType.everyNRotations =>
        RotationService.isDoneThisOccurrence(task, status),
      RotationFrequencyType.none => false,
    };
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Project project,
    Task task,
    RotationStatus status,
    RotationFrequencyType type,
  ) async {
    HapticFeedback.lightImpact();
    final updated = switch (type) {
      RotationFrequencyType.daily => RotationService.toggleDailyCompletion(
        task,
        DateTime.now(),
      ),
      RotationFrequencyType.oncePerPeriod =>
        RotationService.toggleOncePerPeriod(task, status),
      RotationFrequencyType.everyNRotations =>
        RotationService.toggleEveryNRotations(task, status),
      RotationFrequencyType.none => task,
    };
    await ref.read(vaultProvider.notifier).updateObject(updated);

    // Check for zone advancement - run in isolate to avoid blocking main thread
    try {
      if (!context.mounted) return;

      final allObjects = ref.read(allObjectsProvider).value ?? [];
      final allTasks = allObjects.whereType<Task>().toList();

      // Use compute to run in background isolate
      final result = await compute(_checkAndAdvanceZoneIsolate, (
        project: project,
        allTasks: allTasks,
      ));

      if (result.advanced && result.nextGroup != null && context.mounted) {
        await ref.read(vaultProvider.notifier).updateObject(result.updated);
        if (context.mounted) {
          final message = result.viaTimeout
              ? "Time's up for this zone. Moving on to: ${result.nextGroup!.name}"
              : 'Zone completed! Next: ${result.nextGroup!.name}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking zone advancement: $e');
    }
  }
}

OrganizerReference _projectReference(Project project) => OrganizerReference(
  type: 'project',
  slug: project.slug,
  title: project.title,
);

class _RotationZoneTaskRow extends StatelessWidget {
  final Task task;
  final RotationFrequencyType type;
  final RotationStatus? status;
  final bool done;
  final bool showDivider;
  final bool disabled;
  final VoidCallback? onToggle;

  const _RotationZoneTaskRow({
    required this.task,
    required this.type,
    required this.status,
    required this.done,
    required this.showDivider,
    required this.disabled,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = rotationFrequencyColor(type, context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
                  width: AppBorder.thin,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Semantics(
              label: "Mark '${task.title}' as done",
              button: true,
              child: GestureDetector(
                onTap: disabled ? null : onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: AppIconSize.md,
                    height: AppIconSize.md,
                    decoration: BoxDecoration(
                      color: done ? color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done
                            ? color
                            : AppColors.textMuted.withValues(alpha: 0.28),
                        width: AppBorder.normal,
                      ),
                    ),
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            size: AppIconSize.xs,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: done ? AppColors.textMuted : null,
                      ),
                    ),
                    if (type == RotationFrequencyType.daily ||
                        _subtitle(context).isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _subtitleWidget(context),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _TrailingStatus(type: type, task: task, status: status, done: done),
          ],
        ),
      ),
    );
  }

  String _subtitle(BuildContext context) {
    if (status == null) return '';
    return switch (type) {
      RotationFrequencyType.daily => '',
      RotationFrequencyType.oncePerPeriod => '',
      RotationFrequencyType.everyNRotations =>
        'Every ${task.rotationEveryN ?? 1} rotations · next in ${DateFormat('MMM').format(status!.periodStart)}',
      RotationFrequencyType.none => '',
    };
  }

  Widget _subtitleWidget(BuildContext context) {
    if (type == RotationFrequencyType.daily && status != null) {
      final (dailyDone, total) = RotationService.dailyProgressForPeriod(
        task,
        status!,
      );
      return Row(
        children: [
          ...List.generate(total, (index) {
            final active = index < dailyDone;
            return Container(
              width: AppSpacing.sm,
              height: AppSpacing.xs,
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              decoration: BoxDecoration(
                color: active
                    ? rotationFrequencyColor(type, context)
                    : AppColors.textMuted.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppBorderRadius.xs),
              ),
            );
          }),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$dailyDone/$total days',
            style: const TextStyle(
              fontSize: AppTextSize.xs,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );
    }

    final text = _subtitle(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: AppTextSize.xs,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _TrailingStatus extends StatelessWidget {
  final RotationFrequencyType type;
  final Task task;
  final RotationStatus? status;
  final bool done;

  const _TrailingStatus({
    required this.type,
    required this.task,
    required this.status,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.accentColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        child: Text(
          'done',
          style: TextStyle(
            color: AppTheme.accentColor(context),
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (type == RotationFrequencyType.everyNRotations) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        child: Text(
          '${task.rotationEveryN ?? 1}×',
          style: const TextStyle(
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    if (status == null) return const SizedBox.shrink();

    final label = type == RotationFrequencyType.daily
        ? DateFormat('d MMM').format(DateTime.now())
        : DateFormat('d MMM').format(status!.periodEnd);
    return Text(
      label,
      style: TextStyle(
        fontSize: AppTextSize.xs,
        color: rotationFrequencyColor(type, context),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ZoneHero extends StatelessWidget {
  final RotationStatus status;
  final RotationGroup group;

  const _ZoneHero({required this.status, required this.group});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(group.colorHex) ?? AppTheme.accentColor(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${group.emoji ?? ''} ${group.name}'.trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppTextSize.xxl,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${DateFormat('d').format(status.periodStart)} – ${DateFormat('d MMM').format(status.periodEnd)} · Day ${status.dayOfPeriod}/${group.periodDays}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: AppSpacing.md),
          _ZoneProgressBars(
            total: group.periodDays,
            completed: status.dayOfPeriod.clamp(0, group.periodDays).toInt(),
          ),
        ],
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }
}

class _ZoneProgressBars extends StatelessWidget {
  final int total;
  final int completed;

  const _ZoneProgressBars({required this.total, required this.completed});

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    return Row(
      children: List.generate(safeTotal, (index) {
        final active = index < completed;
        return Expanded(
          child: Container(
            height: AppSpacing.xs,
            margin: EdgeInsets.only(
              right: index == safeTotal - 1 ? 0 : AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: active ? 0.95 : 0.25),
              borderRadius: BorderRadius.circular(AppBorderRadius.xs),
            ),
          ),
        );
      }),
    );
  }
}
