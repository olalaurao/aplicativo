// lib/ui/widgets/organizer_chips.dart
import 'package:flutter/material.dart';
import '../../models/shared_types.dart';
import '../theme.dart';

class OrganizerChips extends StatelessWidget {
  final List<OrganizerReference> organizers;

  const OrganizerChips({super.key, required this.organizers});

  @override
  Widget build(BuildContext context) {
    if (organizers.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: organizers.map((org) {
        final color = _colorForType(org.type);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: AppTheme.chipDecoration(color),
          child: Text(
            org.slug.replaceAll('-', ' '),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'area':
        return AppColors.primary;
      case 'project':
        return AppColors.info;
      case 'activity':
        return AppColors.habitGreen;
      case 'person':
        return AppColors.habitPink;
      case 'label':
        return AppColors.textSecondary;
      default:
        return AppColors.primary;
    }
  }
}
