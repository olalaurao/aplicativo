import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/rotation_service.dart';
import '../forms/create_task_form.dart';
import '../theme.dart';
import 'rotation_zone_detail_screen.dart';

class RotationOverviewScreen extends ConsumerStatefulWidget {
  final String projectId;

  const RotationOverviewScreen({super.key, required this.projectId});

  @override
  ConsumerState<RotationOverviewScreen> createState() => _RotationOverviewScreenState();
}

class _RotationOverviewScreenState extends ConsumerState<RotationOverviewScreen> {
  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectsProvider).cast<Project?>().firstWhere(
          (p) => p?.id == widget.projectId,
          orElse: () => null,
        );
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zone Rotation')),
        body: const Center(child: Text('Project not found')),
      );
    }

    final status = RotationService.computeActiveStatus(project);
    final upcoming = RotationService.upcomingGroups(
      project,
      count: project.rotationGroups.length - 1,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Zone Rotation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            project.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${project.methodLabel ?? 'Rotation'} · ${_rotationSubtitle(project)}',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          if (status != null)
            _ActiveZoneHero(
              project: project,
              status: status,
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
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(context),
              child: const Text(
                'Set the rotation start date on the project.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'UPCOMING ZONES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...upcoming.map((entry) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppTheme.accentColor(context).withValues(alpha: 0.15),
                child: Text(entry.group.emoji ?? '📍'),
              ),
              title: Text(
                entry.group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${DateFormat('d MMM').format(entry.startsAt)} – ${DateFormat('d MMM').format(entry.endsAt)}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
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
      floatingActionButton: FloatingActionButton(
        onPressed: status == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateTaskForm(
                      initialOrganizers: project.organizers,
                    ),
                  ),
                ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  String _rotationSubtitle(Project project) {
    final groups = project.rotationGroups;
    if (groups.isEmpty) return 'No zones';
    final same = groups.every((g) => g.periodDays == groups.first.periodDays);
    if (same) {
      return '${project.rotationCycleLengthDays}-day rotation';
    }
    return '${groups.length}-zone rotation';
  }
}

class _ActiveZoneHero extends StatelessWidget {
  final Project project;
  final RotationStatus status;
  final VoidCallback onTap;

  const _ActiveZoneHero({
    required this.project,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(status.group.colorHex) ?? AppTheme.accentColor(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ACTIVE ZONE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(status.group.emoji ?? '📍',
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.group.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${DateFormat('d MMM').format(status.periodStart)} – ${DateFormat('d MMM').format(status.periodEnd)} · Day ${status.dayOfPeriod}/${status.group.periodDays}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
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

class _EmptyRotationState extends StatelessWidget {
  const _EmptyRotationState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          Icon(Icons.rotate_right_rounded,
              size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
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
