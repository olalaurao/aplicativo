// lib/ui/screens/detail_sections/goal_detail_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/goal_model.dart';
import '../../../providers/vault_provider.dart';
import '../../widgets/property_grid.dart';
import '../../theme.dart';

/// Goal-specific property cards for universal detail view
List<PropertyCard> buildGoalPropertyCards(
  BuildContext context,
  WidgetRef ref,
  Goal goal,
) {
  final cards = <PropertyCard>[];
  
  cards.add(PropertyCard(
    icon: Icons.calendar_today,
    label: 'Início',
    value: goal.startDate != null ? DateFormat('d MMM yyyy').format(goal.startDate!) : 'Não definida',
    state: goal.startDate == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.event,
    label: 'Prazo',
    value: goal.deadline != null ? DateFormat('d MMM yyyy').format(goal.deadline!) : 'Não definida',
    state: goal.deadline == null ? PropertyCardState.empty : (_isOverdue(goal) ? PropertyCardState.overdue : PropertyCardState.normal),
  ));
  cards.add(PropertyCard(
    icon: Icons.repeat,
    label: 'Tipo',
    value: goal.goalType == GoalType.repeating ? 'Recorrente' : 'Pontual',
    onTap: () => _showEnumPropertyPicker<GoalType>(
      context: context,
      title: 'Tipo',
      values: GoalType.values,
      initialValue: goal.goalType,
      labelBuilder: (s) => s.name,
      onSave: (val) {
        final updated = goal.copyWith(goalType: val);
        ref.read(vaultProvider.notifier).updateObject(updated);
      },
    ),
  ));
  cards.add(PropertyCard(
    icon: Icons.timelapse,
    label: 'Intervalo',
    value: goal.repeatInterval ?? 'Não definido',
    state: goal.repeatInterval == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  
  return cards;
}

bool _isOverdue(Goal goal) {
  if (goal.deadline == null) return false;
  return DateTime.now().isAfter(goal.deadline!) && goal.state != GoalStatus.completed;
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
