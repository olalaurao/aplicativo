// lib/ui/widgets/metadata_strip.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class MetadataStrip extends StatelessWidget {
  final List<MetadataChip> chips;

  const MetadataStrip({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) => _buildMetaChip(context, chip)).toList(),
      ),
    );
  }

  Widget _buildMetaChip(BuildContext context, MetadataChip chip) {
    return GestureDetector(
      onTap: chip.onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chip.isActive
              ? AppTheme.accentColor(context).withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: chip.isActive ? AppTheme.accentColor(context) : AppColors.divider,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              chip.icon,
              size: 16,
              color: chip.isActive
                  ? AppTheme.accentColor(context)
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              chip.label,
              style: TextStyle(
                fontSize: 13,
                color: chip.isActive
                    ? AppTheme.accentColor(context)
                    : AppColors.textSecondary,
                fontWeight: chip.isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MetadataChip {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  const MetadataChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
  });
}
