import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final blockColor = _parseColor(colorStr);
    final activeColor = blockColor ?? AppTheme.accentColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : Colors.transparent,
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

  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.trim().isEmpty) return null;
    try {
      final value = colorStr.trim().replaceAll('#', '');
      if (value.length == 6) {
        return Color(int.parse('0xFF$value'));
      }
      if (value.length == 8) {
        return Color(int.parse('0x$value'));
      }
    } catch (_) {
      debugPrint('Invalid time block color: $colorStr');
    }
    return null;
  }
}
