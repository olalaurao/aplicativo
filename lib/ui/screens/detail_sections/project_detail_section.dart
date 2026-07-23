// lib/ui/screens/detail_sections/project_detail_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../models/checklist_step.dart';
import '../../../providers/vault_provider.dart';
import '../../../services/kpi_engine.dart';
import '../../../services/project_progress_cache.dart';
import '../../widgets/property_grid.dart';
import '../../widgets/actionable_checklist_tile.dart';
import '../../theme.dart';

/// Project-specific property cards for universal detail view
List<PropertyCard> buildProjectPropertyCards(
  BuildContext context,
  WidgetRef ref,
  Project project,
) {
  final cards = <PropertyCard>[];
  final allObjects = ref.watch(allObjectsProvider).value ?? [];
  final tasks = allObjects.whereType<Task>().toList();
  final progress = ProjectProgressCache.getProgress(project.id, project, tasks);
  final linkedTasksCount = ProjectProgressCache.getLinkedTaskCount(project.id, project, tasks);
  final doneCount = ProjectProgressCache.getCompletedTaskCount(project.id, project, tasks);

  if (project.hasRotation) {
    cards.add(PropertyCard(
      icon: Icons.trending_up_rounded,
      label: 'Completed',
      value: '${(progress * 100).toInt()}%',
    ));
    cards.add(PropertyCard(
      icon: Icons.task_alt,
      label: 'Tasks',
      value: '$doneCount of $linkedTasksCount',
    ));
  }
  cards.add(PropertyCard(
    icon: Icons.calendar_today,
    label: 'Start',
    value: project.startDate != null ? DateFormat('d MMM yyyy').format(project.startDate!) : 'Not set',
    state: project.startDate == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.event,
    label: 'End',
    value: project.endDate != null ? DateFormat('d MMM yyyy').format(project.endDate!) : 'Not set',
    state: project.endDate == null ? PropertyCardState.empty : (_isOverdue(project) ? PropertyCardState.overdue : PropertyCardState.normal),
  ));
  if (_hasPriority(project)) {
    cards.add(PropertyCard(
      icon: Icons.priority_high,
      label: 'Priority',
      value: '',
      customChild: _buildPriorityBadge(project),
    ));
  }
  cards.add(PropertyCard(
    icon: Icons.linear_scale,
    label: 'State',
    value: _getStatusLabel(project),
    onTap: () => _onPropertyTap(context, ref, 'Status', _getStatus(project)),
  ));
  
  return cards;
}

bool _isOverdue(Project project) {
  if (project.endDate == null) return false;
  return DateTime.now().isAfter(project.endDate!);
}

bool _hasPriority(Project project) {
  return project.priority != null;
}

String _getStatusLabel(Project project) {
  if (project.hasRotation) {
    return 'In rotation';
  }
  return 'Active';
}

String _getStatus(Project project) {
  if (project.hasRotation) {
    return 'In rotation';
  }
  return 'Active';
}

Widget _buildPriorityBadge(Project project) {
  if (project.projectPriority == null) return const SizedBox.shrink();
  
  final color = switch (project.projectPriority) {
    TaskPriority.high => AppColors.priorityHigh,
    TaskPriority.medium => AppColors.priorityMedium,
    TaskPriority.low => AppColors.priorityLow,
    TaskPriority.none => AppColors.textMuted,
  };
  
  final label = switch (project.projectPriority) {
    TaskPriority.high => 'HIGH',
    TaskPriority.medium => 'MEDIUM',
    TaskPriority.low => 'LOW',
    TaskPriority.none => 'NONE',
  };
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

void _onPropertyTap(BuildContext context, WidgetRef ref, String property, String value) {
  // Property tap handler - can be extended for editing
}

/// Build the checklist section for Project detail view
Widget buildProjectChecklistSection(
  BuildContext context,
  WidgetRef ref,
  Project project,
) {
  if (project.steps.isEmpty) {
    return const SizedBox.shrink();
  }

  final today = DateTime.now();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
        child: Text(
          'Checklist',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: AppTheme.cardDecoration(context),
        child: Column(
          children: [
            ...project.steps.asMap().entries.map((e) {
              final step = e.value;
              return ActionableChecklistTile(
                itemId: step.id,
                title: step.title,
                kind: step.kind,
                linkedObjectSlug: step.linkedObjectSlug,
                trackerFieldId: step.trackerFieldId,
                attachedCollectionSlug: step.attachedCollectionSlug,
                date: today,
                parentObjectId: project.id,
                onTaskCreated: (taskSlug) async {
                  // Persist the new task slug back to the project step
                  final updatedSteps = List<ChecklistStep>.from(project.steps);
                  final stepIndex = updatedSteps.indexWhere((s) => s.id == step.id);
                  if (stepIndex != -1) {
                    updatedSteps[stepIndex] = step.copyWith(linkedObjectSlug: taskSlug);
                    final updated = project.copyProjectWith(steps: updatedSteps);
                    await ref.read(projectsProvider.notifier).updateProject(updated);
                  }
                },
              );
            }),
          ],
        ),
      ),
    ],
  );
}
