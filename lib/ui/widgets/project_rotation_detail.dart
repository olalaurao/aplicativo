import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/project_model.dart';
import '../../models/shared_types.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/rotation_service.dart';
import '../forms/create_task_form.dart';
import '../navigation/object_navigation.dart';
import '../theme.dart';
import 'object_action_wrapper.dart';

class ProjectRotationDetailScreen extends ConsumerStatefulWidget {
  final String projectId;
  final Project? initialProject;

  const ProjectRotationDetailScreen({
    super.key,
    required this.projectId,
    this.initialProject,
  });

  @override
  ConsumerState<ProjectRotationDetailScreen> createState() =>
      _ProjectRotationDetailScreenState();
}

class _ProjectRotationDetailScreenState
    extends ConsumerState<ProjectRotationDetailScreen> {
  String? _frequencyFilter;
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};

  void _enterSelectionMode(String taskId) {
    setState(() {
      _isSelectionMode = true;
      _selectedTaskIds.add(taskId);
    });
  }

  void _toggleSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _deleteSelected(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tasks?'),
        content: Text('Are you sure you want to delete ${_selectedTaskIds.length} tasks?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final allObjects = ref.read(allObjectsProvider).value ?? [];
      for (final id in _selectedTaskIds) {
        final obj = allObjects.whereType<Task>().where((o) => o.id == id).firstOrNull;
        if (obj != null) {
          ref.read(vaultProvider.notifier).deleteObject(obj);
        }
      }
      setState(() {
        _isSelectionMode = false;
        _selectedTaskIds.clear();
      });
    }
  }

  void _changeZoneForSelected(BuildContext context, Project project, List<Task> allTasks) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text('Move to Zone', style: TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: AppSpacing.md),
              ...project.rotationGroups.map((group) => ListTile(
                leading: _ZoneIcon(group: group),
                title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  for (final id in _selectedTaskIds) {
                    final task = allTasks.firstWhere((t) => t.id == id);
                    final updated = task.copyWith(rotationGroupId: group.id);
                    ref.read(vaultProvider.notifier).updateObject(updated);
                  }
                  if (mounted) {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedTaskIds.clear();
                    });
                  }
                  Navigator.pop(ctx);
                },
              )),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('None (Unassigned)'),
                onTap: () {
                  for (final id in _selectedTaskIds) {
                    final task = allTasks.firstWhere((t) => t.id == id);
                    final updated = task.copyWith(rotationGroupId: null);
                    ref.read(vaultProvider.notifier).updateObject(updated);
                  }
                  if (mounted) {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedTaskIds.clear();
                    });
                  }
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project =
        ref
            .watch(projectsProvider)
            .cast<Project?>()
            .firstWhere(
              (p) => p?.id == widget.projectId || p?.slug == widget.projectId,
              orElse: () => null,
            ) ??
        widget.initialProject;

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: const Center(child: Text('Project not found')),
      );
    }

    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final allTasks = allObjects.whereType<Task>().toList();
    final rotationTasks = RotationService.rotationTasksForProject(
      project,
      allTasks,
    );
    final unassignedTasks = RotationService.tasksForProject(project, allTasks)
        .where((t) => !t.isRotationTask)
        .toList();
    final visibleTasks = _applyFrequencyFilter(rotationTasks);
    final groups = [...project.rotationGroups]
      ..sort((a, b) => a.order.compareTo(b.order));
    final activeStatus = RotationService.computeActiveStatus(project);

    final Map<String, ({DateTime startsAt, DateTime endsAt})> zonePeriods = {};
    if (activeStatus != null) {
      final currentIdx = groups.indexWhere((g) => g.id == activeStatus.group.id);
      if (currentIdx >= 0) {
        zonePeriods[activeStatus.group.id] = (startsAt: activeStatus.periodStart, endsAt: activeStatus.periodEnd);
        var cursor = activeStatus.periodEnd.add(const Duration(days: 1));
        for (var i = 1; i < groups.length; i++) {
          final g = groups[(currentIdx + i) % groups.length];
          final endsAt = cursor.add(Duration(days: g.periodDays - 1));
          zonePeriods[g.id] = (startsAt: cursor, endsAt: endsAt);
          cursor = endsAt.add(const Duration(days: 1));
        }
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedTaskIds.clear();
                }),
              ),
              title: Text('${_selectedTaskIds.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz_rounded),
                  tooltip: 'Change zone',
                  onPressed: _selectedTaskIds.isEmpty ? null : () => _changeZoneForSelected(context, project, allTasks),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete selected',
                  onPressed: _selectedTaskIds.isEmpty ? null : () => _deleteSelected(context),
                ),
              ],
            )
          : AppBar(
              centerTitle: true,
              title: const Text(
                'PROJECT',
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () => showObjectActionSheet(context, ref, project),
                ),
              ],
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          Text(
            project.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTextSize.xxl,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${project.methodLabel ?? 'Rotation'} · ${rotationTasks.length} scheduled tasks',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTextSize.sm,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FrequencyChip(
                  label: 'Daily',
                  color: rotationFrequencyColor(
                    RotationFrequencyType.daily,
                    context,
                  ),
                  selected: _frequencyFilter == 'daily',
                  onTap: () => _toggleFilter('daily'),
                ),
                _FrequencyChip(
                  label: 'Once per period',
                  color: rotationFrequencyColor(
                    RotationFrequencyType.oncePerPeriod,
                    context,
                  ),
                  selected: _frequencyFilter == 'oncePerPeriod',
                  onTap: () => _toggleFilter('oncePerPeriod'),
                ),
                _FrequencyChip(
                  label: 'By frequency',
                  color: rotationFrequencyColor(
                    RotationFrequencyType.everyNRotations,
                    context,
                  ),
                  selected: _frequencyFilter == 'everyNRotations',
                  onTap: () => _toggleFilter('everyNRotations'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...groups.map((group) {
            final groupTasks = visibleTasks
                .where(
                  (task) =>
                      RotationService.taskBelongsToRotationGroup(task, group),
                )
                .toList();
            if (groupTasks.isEmpty) return const SizedBox.shrink();
            return _ProjectZoneSection(
              project: project,
              group: group,
              tasks: groupTasks,
              activeStatus: activeStatus,
              period: zonePeriods[group.id],
              isSelectionMode: _isSelectionMode,
              selectedTaskIds: _selectedTaskIds,
              onToggleSelection: _toggleSelection,
              onEnterSelectionMode: _enterSelectionMode,
            );
          }),
          if (activeStatus != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _NextRotationCard(project: project, allTasks: allTasks),
          ],
          if (unassignedTasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Unassigned Tasks',
              style: TextStyle(
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: AppTheme.cardDecoration(context),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ...unassignedTasks.asMap().entries.map((entry) {
                    return _ProjectRotationTaskRow(
                      project: project,
                      task: entry.value,
                      activeStatus: activeStatus,
                      showDivider: entry.key < unassignedTasks.length - 1,
                      isSelectionMode: _isSelectionMode,
                      isSelected: _selectedTaskIds.contains(entry.value.id),
                      onToggleSelection: () => _toggleSelection(entry.value.id),
                      onEnterSelectionMode: () => _enterSelectionMode(entry.value.id),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: activeStatus == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateTaskForm(
                    initialOrganizers: [_projectReference(project)],
                    initialRotationGroupId: activeStatus.group.id,
                    initialRotationFrequencyType:
                        RotationFrequencyType.oncePerPeriod,
                  ),
                ),
              ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  List<Task> _applyFrequencyFilter(List<Task> tasks) {
    return switch (_frequencyFilter) {
      'daily' =>
        tasks
            .where(
              (t) => t.rotationFrequencyType == RotationFrequencyType.daily,
            )
            .toList(),
      'oncePerPeriod' =>
        tasks
            .where(
              (t) =>
                  t.rotationFrequencyType ==
                  RotationFrequencyType.oncePerPeriod,
            )
            .toList(),
      'everyNRotations' =>
        tasks
            .where(
              (t) =>
                  t.rotationFrequencyType ==
                  RotationFrequencyType.everyNRotations,
            )
            .toList(),
      _ => tasks,
    };
  }

  void _toggleFilter(String value) {
    setState(() {
      _frequencyFilter = _frequencyFilter == value ? null : value;
    });
  }
}

class _ProjectZoneSection extends StatefulWidget {
  final Project project;
  final RotationGroup group;
  final List<Task> tasks;
  final RotationStatus? activeStatus;
  final ({DateTime startsAt, DateTime endsAt})? period;
  final bool isSelectionMode;
  final Set<String> selectedTaskIds;
  final Function(String) onToggleSelection;
  final Function(String) onEnterSelectionMode;

  const _ProjectZoneSection({
    required this.project,
    required this.group,
    required this.tasks,
    required this.activeStatus,
    required this.period,
    required this.isSelectionMode,
    required this.selectedTaskIds,
    required this.onToggleSelection,
    required this.onEnterSelectionMode,
  });

  @override
  State<_ProjectZoneSection> createState() => _ProjectZoneSectionState();
}

class _ProjectZoneSectionState extends State<_ProjectZoneSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.activeStatus?.group.id == widget.group.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  _ZoneIcon(group: widget.group),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTextSize.md,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (widget.period != null)
                          Text(
                            '${DateFormat('d MMM').format(widget.period!.startsAt)} - ${DateFormat('d MMM').format(widget.period!.endsAt)}',
                            style: const TextStyle(
                              fontSize: AppTextSize.xs,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isActive)
                    _StatusPill(
                      label: 'active now',
                      color: AppTheme.accentColor(context),
                    ),
                  Text(
                    '${widget.tasks.length} tasks',
                    style: const TextStyle(
                      fontSize: AppTextSize.xs,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    color: AppColors.textMuted,
                    onPressed: () => navigateToRotationZone(
                      context,
                      projectId: widget.project.id,
                      groupId: widget.group.id,
                      isPreview: !isActive,
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: AppTheme.cardDecoration(context),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ...widget.tasks.asMap().entries.map((entry) {
                    return _ProjectRotationTaskRow(
                      project: widget.project,
                      task: entry.value,
                      activeStatus: widget.activeStatus,
                      showDivider: entry.key < widget.tasks.length - 1,
                      isSelectionMode: widget.isSelectionMode,
                      isSelected: widget.selectedTaskIds.contains(entry.value.id),
                      onToggleSelection: () => widget.onToggleSelection(entry.value.id),
                      onEnterSelectionMode: () => widget.onEnterSelectionMode(entry.value.id),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectRotationTaskRow extends StatelessWidget {
  final Project project;
  final Task task;
  final RotationStatus? activeStatus;
  final bool showDivider;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onEnterSelectionMode;

  const _ProjectRotationTaskRow({
    required this.project,
    required this.task,
    required this.activeStatus,
    required this.showDivider,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onEnterSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = rotationFrequencyColor(
      task.rotationFrequencyType,
      context,
    );
    final trailing = _trailingText();
    final done = trailing == 'done';

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
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: isSelectionMode
            ? Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppTheme.accentColor(context) : AppColors.textMuted,
                size: 20,
              )
            : Container(
                width: AppSpacing.sm,
                height: AppSpacing.sm,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: AppTextSize.sm,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          _subtitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: AppTextSize.xs,
            color: AppColors.textMuted,
          ),
        ),
        trailing: trailing.isEmpty
            ? null
            : Text(
                trailing,
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  color: done ? AppTheme.accentColor(context) : dotColor,
                  fontWeight: done ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
        onTap: isSelectionMode
            ? onToggleSelection
            : () => context.push('/detail/${task.id}', extra: {'object': task}),
        onLongPress: isSelectionMode ? null : onEnterSelectionMode,
      ),
    );
  }

  String _subtitle() {
    return switch (task.rotationFrequencyType) {
      RotationFrequencyType.daily => 'Daily',
      RotationFrequencyType.oncePerPeriod => '1x per rotation',
      RotationFrequencyType.everyNRotations =>
        'Every ${task.rotationEveryN ?? 1} rotations',
      RotationFrequencyType.none => '',
    };
  }

  String _trailingText() {
    if (activeStatus == null) return '';
    return switch (task.rotationFrequencyType) {
      RotationFrequencyType.daily =>
        task.rotationDailyCompletions[RotationService.dateKey(
                  DateTime.now(),
                )] ==
                true
            ? 'done'
            : DateFormat('d MMM').format(DateTime.now()),
      RotationFrequencyType.oncePerPeriod =>
        RotationService.isDoneThisOccurrence(task, activeStatus!)
            ? 'done'
            : _oncePerPeriodDueText(),
      RotationFrequencyType.everyNRotations => _everyNDueText(),
      RotationFrequencyType.none => '',
    };
  }

  String _everyNDueText() {
    final next = RotationService.nextDueDateForEveryN(task, project);
    return next == null ? '-> -' : '-> ${DateFormat('MMM').format(next)}';
  }

  String _oncePerPeriodDueText() {
    final next = RotationService.nextDueDateForOncePerPeriod(task, project);
    return next == null ? '-' : DateFormat('d MMM').format(next);
  }
}

class _NextRotationCard extends StatelessWidget {
  final Project project;
  final List<Task> allTasks;

  const _NextRotationCard({required this.project, required this.allTasks});

  @override
  Widget build(BuildContext context) {
    final upcoming = RotationService.upcomingGroups(project, count: 1);
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final next = upcoming.first;
    final taskCount = RotationService.rotationTasksForGroup(
      project,
      next.group,
      allTasks,
    ).length;

    return InkWell(
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      onTap: () => navigateToRotationZone(
        context,
        projectId: project.id,
        groupId: next.group.id,
        isPreview: true,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.accentColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next rotation',
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: AppTheme.accentColor(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _ZoneIcon(group: next.group),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              next.group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTextSize.sm,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${DateFormat('d MMM').format(next.startsAt)} - ${DateFormat('d MMM').format(next.endsAt)} · $taskCount tasks',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTextSize.xs,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : AppTheme.cardFillColor(context),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSpacing.xs,
                height: AppSpacing.xs,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneIcon extends StatelessWidget {
  final RotationGroup group;

  const _ZoneIcon({required this.group});

  @override
  Widget build(BuildContext context) {
    return Text(
      group.emoji ?? '•',
      style: const TextStyle(fontSize: AppTextSize.lg),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

OrganizerReference _projectReference(Project project) => OrganizerReference(
  type: 'project',
  slug: project.slug,
  title: project.title,
);
