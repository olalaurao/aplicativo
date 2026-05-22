import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/day_theme_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';

class TimeBlockPicker extends ConsumerWidget {
  final String? selectedBlockId;
  final ValueChanged<String?> onBlockSelected;

  const TimeBlockPicker({
    super.key,
    this.selectedBlockId,
    required this.onBlockSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(timeBlocksProvider);

    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'TIME BLOCK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChip(
                context: context,
                label: 'None',
                isSelected: selectedBlockId == null,
                onTap: () => onBlockSelected(null),
              ),
              const SizedBox(width: 8),
              ...blocks.map((block) {
                final isSelected = block.id == selectedBlockId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildChip(
                    context: context,
                    label: block.title,
                    isSelected: isSelected,
                    colorStr: block.color,
                    onTap: () => onBlockSelected(isSelected ? null : block.id),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    String? colorStr,
    required VoidCallback onTap,
  }) {
    Color? blockColor;
    if (colorStr != null && colorStr.isNotEmpty) {
      if (colorStr.startsWith('#')) {
        blockColor = Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
    }
    
    final activeColor = blockColor ?? AppColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? activeColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
