// lib/ui/widgets/organizer_chips.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/shared_types.dart';
import '../theme.dart';
import '../utils/object_icons.dart';
import '../../providers/settings_provider.dart';

class OrganizerChips extends ConsumerWidget {
  final List<OrganizerReference> organizers;

  const OrganizerChips({super.key, required this.organizers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (organizers.isEmpty) return const SizedBox.shrink();

    final settings = ref.read(settingsProvider);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: organizers.map((org) {
        final color = _colorForType(org.type, settings);
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

  Color _colorForType(String type, AppSettings settings) {
    // Try typeSignatures first
    final signatureColor = ObjectIcons.colorForTypeWithSignatures(type, settings.typeSignatures);
    final defaultColor = ObjectIcons.defaultColorForType(type);
    if (signatureColor != defaultColor) {
      return signatureColor;
    }
    
    // Fall back to hardcoded colors
    return switch (type) {
      'area' => AppColors.primary,
      'project' => AppColors.info,
      'activity' => AppColors.habitGreen,
      'person' => AppColors.habitPink,
      'label' => AppColors.textSecondary,
      _ => AppColors.primary,
    };
  }
}
