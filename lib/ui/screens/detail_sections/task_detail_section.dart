// lib/ui/screens/detail_sections/task_detail_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/task_model.dart';
import '../../../models/content_object.dart';
import '../../../providers/vault_provider.dart';
import '../../widgets/property_grid.dart';
import '../../theme.dart';

/// Task-specific property cards for universal detail view
List<PropertyCard> buildTaskPropertyCards(
  BuildContext context,
  WidgetRef ref,
  Task task,
) {
  final cards = <PropertyCard>[];
  
  cards.add(PropertyCard(
    icon: Icons.calendar_today_outlined,
    label: 'Created',
    value: DateFormat('d MMM yyyy').format(task.createdAt),
  ));
  cards.add(PropertyCard(
    icon: Icons.event,
    label: 'Deadline',
    value: task.endDate != null ? DateFormat('d MMM yyyy').format(task.endDate!) : 'Not set',
    state: task.endDate == null 
        ? PropertyCardState.empty 
        : (_isOverdue(task) ? PropertyCardState.overdue : PropertyCardState.normal),
    onTap: () => _showTaskDueDatePicker(context, ref, task),
  ));
  cards.add(PropertyCard(
    icon: Icons.play_circle_outline,
    label: 'Start',
    value: task.startDate != null ? DateFormat('d MMM yyyy').format(task.startDate!) : 'Not set',
    state: task.startDate == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.priority_high,
    label: 'Priority',
    value: '',
    customChild: _buildPriorityBadge(task),
  ));
  cards.add(PropertyCard(
    icon: Icons.linear_scale,
    label: 'Stage',
    value: _getStatusLabel(task),
    onTap: () => _showEnumPropertyPicker<TaskStage>(
      context: context,
      title: 'Status',
      values: TaskStage.values,
      initialValue: task.stage,
      labelBuilder: (s) => s.name.toUpperCase(),
      onSave: (val) {
        final updated = task.copyWith(stage: val);
        if (task.stage != val) {
          updated.logEvent('stage_change', 'Stage changed from ${task.stage.name} to ${val.name}', oldValue: task.stage.name, newValue: val.name);
        }
        ref.read(vaultProvider.notifier).updateObject(updated);
      },
    ),
  ));
  cards.add(PropertyCard(
    icon: Icons.hourglass_empty,
    label: 'Tempo estimado',
    value: task.estimatedMinutes != null ? '${task.estimatedMinutes} min' : 'Não definido',
    state: task.estimatedMinutes == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.hourglass_full,
    label: 'Tempo real',
    value: task.actualMinutes > 0 ? '${task.actualMinutes} min' : 'Não definido',
    state: task.actualMinutes == 0 ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.timer,
    label: 'Pomodoros',
    value: task.pomodoroCount != null && task.pomodoroCount! > 0 ? '${task.pomodoroCount}' : 'Não definido',
    state: task.pomodoroCount == null || task.pomodoroCount == 0 ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  
  return cards;
}

bool _isOverdue(Task task) {
  if (task.endDate == null) return false;
  return DateTime.now().isAfter(task.endDate!) && task.stage != TaskStage.finalized;
}

String _getStatusLabel(Task task) {
  switch (task.stage) {
    case TaskStage.idea:
      return 'IDEA';
    case TaskStage.backlog:
      return 'BACKLOG';
    case TaskStage.todo:
      return 'TODO';
    case TaskStage.inProgress:
      return 'IN PROGRESS';
    case TaskStage.pending:
      return 'PENDING';
    case TaskStage.finalized:
      return 'DONE';
    default:
      return 'UNKNOWN';
  }
}

Widget _buildPriorityBadge(Task task) {
  Color color;
  String label;
  
  switch (task.priority) {
    case TaskPriority.high:
      color = AppColors.priorityHigh;
      label = 'HIGH';
      break;
    case TaskPriority.medium:
      color = AppColors.priorityMedium;
      label = 'MEDIUM';
      break;
    case TaskPriority.low:
      color = AppColors.priorityLow;
      label = 'LOW';
      break;
    case TaskPriority.none:
      color = AppColors.textMuted;
      label = 'NONE';
      break;
    default:
      color = AppColors.textMuted;
      label = 'UNKNOWN';
  }
  
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

void _showTaskDueDatePicker(BuildContext context, WidgetRef ref, Task task) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: task.endDate ?? DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime(2030),
  );
  if (picked != null) {
    final updated = task.copyWith(endDate: picked);
    updated.logEvent('rescheduled', 'Deadline changed from ${task.endDate} to $picked', oldValue: task.endDate?.toString(), newValue: picked.toString());
    ref.read(vaultProvider.notifier).updateObject(updated);
  }
}

void _showEnumPropertyPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> values,
  required T initialValue,
  required String Function(T) labelBuilder,
  required Function(T) onSave,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: values.map((value) {
          return RadioListTile<T>(
            title: Text(labelBuilder(value)),
            value: value,
            groupValue: initialValue,
            onChanged: (selected) {
              if (selected != null) {
                onSave(selected);
                Navigator.pop(context);
              }
            },
          );
        }).toList(),
      ),
    ),
  );
}
