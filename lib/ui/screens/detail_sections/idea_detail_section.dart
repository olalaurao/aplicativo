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
    label: 'Horizon',
    value: '',
    customChild: _buildHorizonBadge(idea),
  ));
  cards.add(PropertyCard(
    icon: Icons.priority_high,
    label: 'Priority',
    value: '',
    customChild: idea.priority != null && idea.priority != TaskPriority.none
        ? _buildPriorityBadge(idea)
        : Text('Not set', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, color: AppColors.textMuted.withValues(alpha: 0.4))),
  ));
  cards.add(PropertyCard(
    icon: Icons.transform,
    label: 'Converted to',
    value: idea.convertedToType ?? 'Not converted',
    state: idea.convertedToType == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.event,
    label: 'Target date',
    value: idea.targetDate != null ? DateFormat('d MMM yyyy').format(idea.targetDate!) : 'Not set',
    state: idea.targetDate == null ? PropertyCardState.empty : (_isOverdue(idea) ? PropertyCardState.overdue : PropertyCardState.normal),
  ));
  cards.add(PropertyCard(
    icon: Icons.calendar_today,
    label: 'Created',
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
      color = AppColors.priorityHigh;
      label = 'NOW';
      break;
    case IdeaHorizon.soon:
      color = AppColors.priorityMedium;
      label = 'SOON';
      break;
    case IdeaHorizon.someday:
      color = AppColors.textMuted;
      label = 'SOMEDAY';
      break;
    case IdeaHorizon.noDeadline:
      color = AppColors.info;
      label = 'NO DEADLINE';
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

Widget _buildPriorityBadge(IdeaDefinition idea) {
  if (idea.priority == null || idea.priority == TaskPriority.none) return const SizedBox.shrink();
  
  Color color;
  String label;
  
  switch (idea.priority!) {
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
