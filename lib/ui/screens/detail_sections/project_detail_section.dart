// lib/ui/screens/detail_sections/project_detail_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../providers/vault_provider.dart';
import '../../../services/kpi_engine.dart';
import '../../../services/project_progress_cache.dart';
import '../../widgets/property_grid.dart';
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
      label: 'Concluído',
      value: '${(progress * 100).toInt()}%',
    ));
    cards.add(PropertyCard(
      icon: Icons.task_alt,
      label: 'Tarefas',
      value: '$doneCount de $linkedTasksCount',
    ));
  }
  cards.add(PropertyCard(
    icon: Icons.calendar_today,
    label: 'Início',
    value: project.startDate != null ? DateFormat('d MMM yyyy').format(project.startDate!) : 'Não definida',
    state: project.startDate == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.event,
    label: 'Término',
    value: project.endDate != null ? DateFormat('d MMM yyyy').format(project.endDate!) : 'Não definida',
    state: project.endDate == null ? PropertyCardState.empty : (_isOverdue(project) ? PropertyCardState.overdue : PropertyCardState.normal),
  ));
  if (_hasPriority(project)) {
    cards.add(PropertyCard(
      icon: Icons.priority_high,
      label: 'Prioridade',
      value: '',
      customChild: _buildPriorityBadge(project),
    ));
  }
  cards.add(PropertyCard(
    icon: Icons.linear_scale,
    label: 'Estado',
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
    return 'Em rotação';
  }
  return 'Ativo';
}

String _getStatus(Project project) {
  if (project.hasRotation) {
    return 'Em rotação';
  }
  return 'Ativo';
}

Widget _buildPriorityBadge(Project project) {
  if (project.projectPriority == null) return const SizedBox.shrink();
  
  final color = switch (project.projectPriority) {
    TaskPriority.high => Colors.red,
    TaskPriority.medium => Colors.orange,
    TaskPriority.low => Colors.green,
    TaskPriority.none => Colors.grey,
  };
  
  final label = switch (project.projectPriority) {
    TaskPriority.high => 'ALTA',
    TaskPriority.medium => 'MÉDIA',
    TaskPriority.low => 'BAIXA',
    TaskPriority.none => 'NENHUMA',
  };
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
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
