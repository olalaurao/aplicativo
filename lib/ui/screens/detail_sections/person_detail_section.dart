// lib/ui/screens/detail_sections/person_detail_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/people_model.dart';
import '../../../models/task_model.dart';
import '../../../providers/vault_provider.dart';
import '../../widgets/property_grid.dart';
import '../../theme.dart';

/// Person-specific property cards for universal detail view
List<PropertyCard> buildPersonPropertyCards(
  BuildContext context,
  WidgetRef ref,
  Person person,
) {
  final cards = <PropertyCard>[];
  
  cards.add(PropertyCard(
    icon: Icons.priority_high,
    label: 'Priority',
    value: '',
    customChild: _buildContactPriorityBadge(person),
  ));
  cards.add(PropertyCard(
    icon: Icons.repeat,
    label: 'Frequency',
    value: person.contactFrequency != null ? 'Every ${person.contactFrequency!.inDays} days' : 'Not set',
    state: person.contactFrequency == null ? PropertyCardState.empty : PropertyCardState.normal,
    onTap: person.contactFrequency != null ? () => _showFrequencyPicker(context, ref, person) : null,
  ));
  cards.add(PropertyCard(
    icon: Icons.phone,
    label: 'Next contact',
    value: () {
      if (person.lastContactDate == null || person.contactFrequency == null) return 'Not set';
      final next = person.lastContactDate!.add(person.contactFrequency!);
      return DateFormat('d MMM yyyy').format(next);
    }(),
    state: person.lastContactDate == null || person.contactFrequency == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.calendar_today,
    label: 'Last contact',
    value: person.lastContactDate != null 
        ? DateFormat('d MMM yyyy').format(person.lastContactDate!) 
        : 'Never',
    state: person.lastContactDate == null || person.contactFrequency == null 
        ? PropertyCardState.empty 
        : PropertyCardState.normal,
  ));
  
  return cards;
}

Widget _buildContactPriorityBadge(Person person) {
  Color color;
  String label;
  
  switch (person.contactPriority) {
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
      break;
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

void _showFrequencyPicker(BuildContext context, WidgetRef ref, Person person) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Contact frequency'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('7 days'),
            onTap: () {
              final updated = person.copyWith(contactFrequency: const Duration(days: 7));
              ref.read(vaultProvider.notifier).updateObject(updated);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('14 days'),
            onTap: () {
              final updated = person.copyWith(contactFrequency: const Duration(days: 14));
              ref.read(vaultProvider.notifier).updateObject(updated);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('30 days'),
            onTap: () {
              final updated = person.copyWith(contactFrequency: const Duration(days: 30));
              ref.read(vaultProvider.notifier).updateObject(updated);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('60 days'),
            onTap: () {
              final updated = person.copyWith(contactFrequency: const Duration(days: 60));
              ref.read(vaultProvider.notifier).updateObject(updated);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}
