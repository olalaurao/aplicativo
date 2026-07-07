import 'package:flutter/material.dart';
import '../theme.dart';

/// F3.11: Incomplete badge for objects missing required properties
/// Outline style, muted gray border, "!" icon, label "Incomplete"
/// Never color-coded (no red) - neutral state, not an error
class IncompleteBadge extends StatelessWidget {
  final bool visible;

  const IncompleteBadge({
    super.key,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: AppColors.textMuted.withValues(alpha: 0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 12,
            color: AppColors.textMuted,
          ),
          SizedBox(width: 4),
          Text(
            'Incomplete',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
