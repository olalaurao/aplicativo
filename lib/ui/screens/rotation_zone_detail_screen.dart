import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/rotation_service.dart';
import '../theme.dart';

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
    final project = ref.watch(projectsProvider).cast<Project?>().firstWhere(
          (p) => p?.id == projectId,
          orElse: () => null,
        );
    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Projeto não encontrado')),
      );
    }

    final group = project.rotationGroups.cast<RotationGroup?>().firstWhere(
          (g) => g?.id == groupId,
          orElse: () => null,
        );
    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Zona não encontrada')),
      );
    }

    final activeStatus = RotationService.computeActiveStatus(project);
    final isActiveZone = activeStatus?.group.id == groupId;
    final status = isActiveZone
        ? activeStatus
        : _previewStatus(project, group);

    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final tasks = allObjects.whereType<Task>().where((t) {
      return t.rotationGroupId == groupId && t.isRotationTask;
    }).toList();

    final daily = tasks
        .where((t) => t.rotationFrequencyType == RotationFrequencyType.daily)
        .toList();
    final once = tasks
        .where((t) =>
            t.rotationFrequencyType == RotationFrequencyType.oncePerPeriod)
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
        title: Text(isPreview ? 'ZONA: ${group.name}' : 'ZONA ATIVA'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isPreview && status != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(context),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esta zona ainda não está ativa — disponível a partir de ${DateFormat('d MMM yyyy').format(status.periodStart)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (status != null) _ZoneHero(status: status, group: group),
          const SizedBox(height: 24),
          _section(context, ref, project, 'DIÁRIAS — resetam todo dia', daily, status,
              RotationFrequencyType.daily),
          _section(context, ref, project, 'UMA VEZ NO PERÍODO', once, status,
              RotationFrequencyType.oncePerPeriod),
          _section(context, ref, project, 'POR FREQUÊNCIA', everyN, status,
              RotationFrequencyType.everyNRotations),
        ],
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
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ...tasks.map((task) {
          final color = rotationFrequencyColor(type, context);
          final done = _isDone(task, status, type);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Semantics(
                  label: "Marcar '${task.title}' como feito",
                  button: true,
                  child: GestureDetector(
                    onTap: isPreview || status == null
                        ? null
                        : () => _toggle(context, ref, project, task, status, type),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: done ? color : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 2),
                        ),
                        child: done
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      decoration:
                          done ? TextDecoration.lineThrough : TextDecoration.none,
                      color: done ? AppColors.textMuted : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  bool _isDone(Task task, RotationStatus? status, RotationFrequencyType type) {
    if (status == null) return false;
    return switch (type) {
      RotationFrequencyType.daily =>
        task.rotationDailyCompletions[RotationService.dateKey(DateTime.now())] ==
            true,
      RotationFrequencyType.oncePerPeriod =>
        RotationService.isDoneThisOccurrence(task, status),
      RotationFrequencyType.everyNRotations =>
        task.rotationLastCompletedAtOccurrence == status.occurrenceNumber,
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
      RotationFrequencyType.daily =>
        RotationService.toggleDailyCompletion(task, DateTime.now()),
      RotationFrequencyType.oncePerPeriod =>
        RotationService.toggleOncePerPeriod(task, status),
      RotationFrequencyType.everyNRotations =>
        RotationService.toggleEveryNRotations(task, status),
      RotationFrequencyType.none => task,
    };
    await ref.read(vaultProvider.notifier).updateObject(updated);

    // Check for zone advancement
    final allObjects = ref.read(allObjectsProvider).value ?? [];
    final allTasks = allObjects.whereType<Task>().toList();
    final result = RotationService.checkAndAdvanceZone(project, allTasks);
    
    if (result.advanced && result.nextGroup != null) {
      await ref.read(vaultProvider.notifier).updateObject(result.updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zone completed! Next: ${result.nextGroup!.name} 🎉'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${group.emoji ?? ''} ${group.name}'.trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dia ${status.dayOfPeriod} de ${group.periodDays}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
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
