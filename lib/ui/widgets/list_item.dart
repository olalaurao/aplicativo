// lib/ui/widgets/list_item.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class ListItem extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final bool showDivider;

  const ListItem({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.contentPadding,
    this.backgroundColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? 
        (enabled ? AppTheme.surfaceVariantColor(context) : AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5));

    return Column(
      children: [
        InkWell(
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          child: Container(
            padding: contentPadding ?? const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: effectiveBackgroundColor,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        DefaultTextStyle(
                          style: TextStyle(
                            fontSize: AppTextSize.md,
                            fontWeight: FontWeight.w500,
                            color: enabled ? AppTheme.textPrimaryColor(context) : AppTheme.textMutedColor(context),
                          ),
                          child: title!,
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        DefaultTextStyle(
                          style: TextStyle(
                            fontSize: AppTextSize.sm,
                            color: AppTheme.textMutedColor(context),
                          ),
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
        if (showDivider) const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}
