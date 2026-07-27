import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/project_model.dart';
import '../../models/shared_types.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/rotation_service.dart';
import '../forms/create_project_form.dart';
import '../forms/create_task_form.dart';
import '../theme.dart';
import 'rotation_zone_detail_screen.dart';

class RotationOverviewScreen extends ConsumerStatefulWidget {
  final String projectId;

  const RotationOverviewScreen({super.key, required this.projectId});

  @override
  ConsumerState<RotationOverviewScreen> createState() =>
      _RotationOverviewScreenState();
}

class _RotationOverviewScreenState
    extends ConsumerState<RotationOverviewScreen> {
  @override
  Widget build(BuildContext context) {
    final project = ref
        .watch(projectsProvider)
        .cast<Project?>()
        .firstWhere((p) => p?.id == widget.projectId, orElse: () => null);
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zone Rotation')),
        body: const Center(child: Text('Project not found')),
      );
    }

    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final allTasks = allObjects.whereType<Task>().toList();
    final status = RotationService.computeActiveStatus(project);
    final upcoming = RotationService.upcomingGroups(
      project,
      count: project.rotationGroups.length - 1,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'ZONE ROTATION',
          style: TextStyle(
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
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
          Text(
            project.title,
            style: const TextStyle(
              fontSize: AppTextSize.xxl,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${project.methodLabel ?? 'Rotation'} · ${_rotationSubtitle(project)}',
            style: const TextStyle(
              fontSize: AppTextSize.sm,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (status != null)
            _ActiveZoneHero(
              project: project,
              status: status,
              tasks: RotationService.rotationTasksForGroup(
                project,
                status.group,
                allTasks,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RotationZoneDetailScreen(
                    projectId: project.id,
                    groupId: status.group.id,
                  ),
                ),
              ),
            )
          else if (project.rotationGroups.isEmpty)
            const _EmptyRotationState()
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: AppTheme.cardDecoration(context),
              child: const Text(
                'Set the rotation start date on the project.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'UPCOMING ZONES',
            style: TextStyle(
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
                ...upcoming.map((entry) {
                  return _UpcomingZoneRow(
                    group: entry.group,
                    startsAt: entry.startsAt,
                    endsAt: entry.endsAt,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RotationZoneDetailScreen(
                          projectId: project.id,
                          groupId: entry.group.id,
                          isPreview: true,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _AddZoneRow(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateProjectForm(existingProject: project),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: status == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateTaskForm(
                    initialOrganizers: [_projectReference(project)],
                    initialRotationGroupId: status.group.id,
                    initialRotationFrequencyType:
                        RotationFrequencyType.oncePerPeriod,
                  ),
                ),
              ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  String _rotationSubtitle(Project project) {
    final groups = project.rotationGroups;
    if (groups.isEmpty) return 'no zones';
    final same = groups.every((g) => g.periodDays == groups.first.periodDays);
    if (same) {
      return 'weekly rotation';
    }
    return '${groups.length} zones';
  }
}

OrganizerReference _projectReference(Project project) => OrganizerReference(
  type: 'project',
  slug: project.slug,
  title: project.title,
);

class _ActiveZoneHero extends StatelessWidget {
  final Project project;
  final RotationStatus status;
  final List<Task> tasks;
  final VoidCallback onTap;

  const _ActiveZoneHero({
    required this.project,
    required this.status,
    required this.tasks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        _parseColor(status.group.colorHex) ?? AppTheme.accentColor(context);
    final completed = tasks.where((task) {
      if (task.rotationFrequencyType == RotationFrequencyType.daily) {
        final (done, _) = RotationService.dailyProgressForPeriod(task, status);
        return done > 0;
      }
      return RotationService.isDoneThisOccurrence(task, status);
    }).length;
    final pending = (tasks.length - completed).clamp(0, tasks.length);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  ),
                  child: const Text(
                    'ACTIVE ZONE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppTextSize.xs,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${DateFormat('d').format(status.periodStart)} – ${DateFormat('d MMM').format(status.periodEnd)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: AppTextSize.sm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  status.group.emoji ?? '📍',
                  style: const TextStyle(fontSize: AppIconSize.xl),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.group.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.xxl,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Day ${status.dayOfPeriod} of ${status.group.periodDays} · $pending tasks pending',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: AppTextSize.sm,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _ProgressBars(
              total: status.group.periodDays,
              completed: status.dayOfPeriod
                  .clamp(0, status.group.periodDays)
                  .toInt(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$completed of ${tasks.length} done',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: AppTextSize.xs,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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

class _UpcomingZoneRow extends StatelessWidget {
  final RotationGroup group;
  final DateTime startsAt;
  final DateTime endsAt;
  final VoidCallback onTap;

  const _UpcomingZoneRow({
    required this.group,
    required this.startsAt,
    required this.endsAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        backgroundColor: AppTheme.accentColor(context).withValues(alpha: 0.12),
        child: Text(group.emoji ?? '📍'),
      ),
      title: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${DateFormat('d MMM').format(startsAt)} – ${DateFormat('d MMM').format(endsAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _AddZoneRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddZoneRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: AppTheme.cardDecoration(context),
          child: const Row(
            children: [
              Icon(Icons.add_rounded, size: AppIconSize.sm),
              SizedBox(width: AppSpacing.sm),
              Text('Add zone'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBars extends StatelessWidget {
  final int total;
  final int completed;

  const _ProgressBars({required this.total, required this.completed});

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
              color: Colors.white.withValues(alpha: active ? 0.95 : 0.26),
              borderRadius: BorderRadius.circular(AppBorderRadius.xs),
            ),
          ),
        );
      }),
    );
  }
}

class _EmptyRotationState extends StatelessWidget {
  const _EmptyRotationState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.rotate_right_rounded,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No zones configured',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add the first zone in the project form.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMutedColor(context)),
          ),
        ],
      ),
    );
  }
}
