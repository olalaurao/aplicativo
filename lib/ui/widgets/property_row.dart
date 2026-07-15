import 'package:flutter/material.dart';
import '../theme.dart';

class PropertyRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;       // defaults to AppColors.primary when onTap != null, else textPrimary
  final VoidCallback? onTap;      // null = not tappable, hides chevron automatically
  final IconData? leadingIcon;    // optional, e.g. Icons.flag_rounded for Priority
  final bool dense;               // true = 14px value text, tighter vertical padding (form usage); false = detail-view usage
  final Widget? trailing;         // escape hatch for custom trailing content (e.g. a Switch) instead of value+chevron

  const PropertyRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.leadingIcon,
    this.dense = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: dense
            ? const EdgeInsets.symmetric(vertical: 10)
            : const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (trailing != null)
              trailing!
            else
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? (onTap != null ? AppTheme.accentColor(context) : AppColors.textPrimary),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (onTap != null && trailing == null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
