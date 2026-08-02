// lib/ui/screens/detail_sections/project_detail_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../models/checklist_step.dart';
import '../../../models/reminder_config.dart';
import '../../../providers/vault_provider.dart';
import '../../../services/kpi_engine.dart';
import '../../../services/project_progress_cache.dart';
import '../../../services/project_hierarchy_service.dart';
import '../../widgets/property_grid.dart';
import '../../widgets/actionable_checklist_tile.dart';
import '../../widgets/rotation_reminder_config_sheet.dart';
import '../../theme.dart';
import '../../../services/rotation_service.dart';

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

Widget buildProjectZonesSection(
  BuildContext context,
  WidgetRef ref,
  Project project,
) {
  if (!project.hasRotation || project.rotationGroups.isEmpty) {
    return const SizedBox.shrink();
  }

  final activeStatus = RotationService.computeActiveStatus(project);
  final upcoming = RotationService.upcomingGroups(project, count: 1);
  final nextGroup = upcoming.isNotEmpty ? upcoming.first : null;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Text(
          'Zonas (Rotação)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activeStatus != null)
              _buildZoneCard(context, activeStatus.group, 'Zona Ativa', isActive: true, status: activeStatus),
            if (activeStatus != null && nextGroup != null)
              const SizedBox(height: 12),
            if (nextGroup != null)
              _buildZoneCard(context, nextGroup.group, 'Próxima Zona'),
            const SizedBox(height: 20),
            const Text(
              'Todas as Zonas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: project.rotationGroups.map((g) {
                final isCurrent = activeStatus?.group.id == g.id;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppTheme.accentColor(context).withValues(alpha: 0.1)
                        : AppTheme.surfaceVariantColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent
                          ? AppTheme.accentColor(context)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '${g.emoji ?? ''} ${g.name}'.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      color: isCurrent
                          ? AppTheme.accentColor(context)
                          : AppTheme.textSecondaryColor(context),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildZoneCard(BuildContext context, RotationGroup group, String title, {bool isActive = false, RotationStatus? status}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: AppTheme.cardDecoration(context).copyWith(
      border: isActive
          ? Border.all(
              color: AppTheme.accentColor(context).withValues(alpha: 0.5),
              width: 1,
            )
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? AppTheme.accentColor(context)
                    : AppColors.textSecondary,
              ),
            ),
            if (isActive && status != null) ...[
              const Spacer(),
              Text(
                'Dia ${status.dayOfPeriod} de ${group.periodDays}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (group.emoji != null) ...[
              Text(group.emoji!, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                group.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Build the subprojects section for Project detail view
/// Exported for use in project_content_section.dart
Widget buildSubprojectsSection(
  BuildContext context,
  WidgetRef ref,
  Project project,
) {
  final allProjects = ref.watch(projectsProvider);
  final allObjects = ref.watch(allObjectsProvider).value ?? [];
  final tasks = allObjects.whereType<Task>().toList();
  
  final children = ProjectHierarchyService.getChildProjects(
    project.id,
    allProjects,
  );

  if (children.isEmpty) {
    return const SizedBox.shrink();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
        child: Text(
          'Subprojects',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            ...children.map((child) {
              final childProgress = ProjectProgressCache.getProgress(
                child.id,
                child,
                tasks,
              );
              final childColor = child.color != null
                  ? _parseColor(child.color!)
                  : AppTheme.accentColor(context);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => context.push('/projects/${child.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: AppTheme.cardDecorationFlat(context),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: childColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.folder_outlined,
                            size: 16,
                            color: childColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                child.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: childProgress,
                                        minHeight: 4,
                                        backgroundColor: AppColors.surfaceVariant,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          childColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(childProgress * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.push('/projects/new', extra: {'parentId': project.id}),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add Subproject',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Color _parseColor(String hexColor) {
  try {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  } catch (_) {
    return AppColors.textMuted;
  }
}

// ─── Rotation Reminders Section ───────────────────────────────────────────────

/// Build the rotation reminders section for a Project with rotation groups.
/// Shows all current rotation reminders with their scope and trigger, plus
/// an "Add reminder" button.
Widget buildProjectRotationRemindersSection(
  BuildContext context,
  WidgetRef ref,
  Project project,
) {
  if (!project.hasRotation) return const SizedBox.shrink();

  final reminders = project.rotationReminders;
  final accent = AppTheme.accentColor(context);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
        child: Text(
          'Rotation Reminders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            if (reminders.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecorationFlat(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No reminders set for rotation blocks.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ...reminders.map((reminder) {
              final groupName = reminder.groupId == null
                  ? 'All groups'
                  : project.rotationGroups
                          .cast<RotationGroup?>()
                          .firstWhere(
                            (g) => g?.id == reminder.groupId,
                            orElse: () => null,
                          )
                          ?.name ??
                      'Unknown group';

              final triggerText = switch (reminder.triggerMode) {
                RotationReminderTriggerMode.atStartTime => 'At start time',
                RotationReminderTriggerMode.minutesBefore =>
                  '${reminder.minutesBefore ?? 10} min before',
                RotationReminderTriggerMode.atTimeOfDay =>
                  'At ${reminder.timeOfDay ?? '09:00'}',
              };

              final notifIcon = switch (reminder.notificationType) {
                NotificationType.push => Icons.notifications_outlined,
                NotificationType.popup => Icons.open_in_new_rounded,
                NotificationType.alarm => Icons.alarm_rounded,
              };

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: AppTheme.cardDecorationFlat(context),
                  child: Row(
                    children: [
                      Icon(notifIcon, size: 18, color: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              triggerText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              groupName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        color: AppColors.textMuted,
                        onPressed: () async {
                          final updated = project.copyProjectWith(
                            rotationReminders: project.rotationReminders
                                .where((r) => r.id != reminder.id)
                                .toList(),
                          );
                          await ref
                              .read(projectsProvider.notifier)
                              .updateProject(updated);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            // Add Reminder button
            InkWell(
              onTap: () => showRotationReminderConfigSheet(
                context,
                project: project,
                onSave: (config) async {
                  final updated = project.copyProjectWith(
                    rotationReminders: [
                      ...project.rotationReminders,
                      config,
                    ],
                  );
                  await ref
                      .read(projectsProvider.notifier)
                      .updateProject(updated);
                },
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add Rotation Reminder',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
