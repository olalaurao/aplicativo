// lib/ui/screens/detail_sections/idea_detail_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/idea_model.dart';
import '../../../models/task_model.dart';
import '../../widgets/property_grid.dart';
import '../../theme.dart';

/// Idea-specific property cards for universal detail view
List<PropertyCard> buildIdeaPropertyCards(IdeaDefinition idea) {
  final cards = <PropertyCard>[];
  
  cards.add(PropertyCard(
    icon: Icons.visibility,
    label: 'Horizonte',
    value: '',
    customChild: _buildHorizonBadge(idea),
  ));
  cards.add(PropertyCard(
    icon: Icons.priority_high,
    label: 'Prioridade',
    value: '',
    customChild: idea.priority != null && idea.priority != TaskPriority.none
        ? _buildPriorityBadge(idea)
        : Text('Não definida', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, color: Colors.grey.withValues(alpha: 0.4))),
  ));
  cards.add(PropertyCard(
    icon: Icons.transform,
    label: 'Convertida em',
    value: idea.convertedToType ?? 'Não convertida',
    state: idea.convertedToType == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.event,
    label: 'Data alvo',
    value: idea.targetDate != null ? DateFormat('d MMM yyyy').format(idea.targetDate!) : 'Não definida',
    state: idea.targetDate == null ? PropertyCardState.empty : (_isOverdue(idea) ? PropertyCardState.overdue : PropertyCardState.normal),
  ));
  cards.add(PropertyCard(
    icon: Icons.calendar_today,
    label: 'Criado',
    value: DateFormat('d MMM yyyy').format(idea.createdAt),
  ));
  
  return cards;
}

bool _isOverdue(IdeaDefinition idea) {
  if (idea.targetDate == null) return false;
  return DateTime.now().isAfter(idea.targetDate!);
}

Widget _buildHorizonBadge(IdeaDefinition idea) {
  Color color;
  String label;
  
  switch (idea.horizon) {
    case IdeaHorizon.now:
      color = Colors.red;
      label = 'AGORA';
      break;
    case IdeaHorizon.soon:
      color = Colors.orange;
      label = 'EM BREVE';
      break;
    case IdeaHorizon.someday:
      color = Colors.grey;
      label = 'ALGUM DIA';
      break;
    case IdeaHorizon.noDeadline:
      color = Colors.blue;
      label = 'SEM PRAZO';
      break;
  }
  
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

Widget _buildPriorityBadge(IdeaDefinition idea) {
  if (idea.priority == null || idea.priority == TaskPriority.none) return const SizedBox.shrink();
  
  Color color;
  String label;
  
  switch (idea.priority!) {
    case TaskPriority.high:
      color = Colors.red;
      label = 'ALTA';
      break;
    case TaskPriority.medium:
      color = Colors.orange;
      label = 'MÉDIA';
      break;
    case TaskPriority.low:
      color = Colors.green;
      label = 'BAIXA';
      break;
    case TaskPriority.none:
      color = Colors.grey;
      label = 'NENHUMA';
      break;
  }
  
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
