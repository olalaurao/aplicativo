// lib/ui/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../theme.dart';

enum BadgeVariant {
  success,
  warning,
  error,
  info,
  neutral,
}

enum BadgeSize {
  small,
  medium,
  large,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final BadgeSize size;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.size = BadgeSize.medium,
    this.icon,
    this.onTap,
  });

  Color _getBadgeColor() {
    switch (variant) {
      case BadgeVariant.success:
        return AppColors.success;
      case BadgeVariant.warning:
        return AppColors.warning;
      case BadgeVariant.error:
        return AppColors.error;
      case BadgeVariant.info:
        return AppColors.info;
      case BadgeVariant.neutral:
        return AppColors.textSecondary;
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    final badgeColor = _getBadgeColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    switch (variant) {
      case BadgeVariant.success:
      case BadgeVariant.warning:
      case BadgeVariant.error:
      case BadgeVariant.info:
        return badgeColor.withValues(alpha: isDark ? 0.18 : 0.10);
      case BadgeVariant.neutral:
        return AppColors.surfaceVariant;
    }
  }

  double _getPadding() {
    switch (size) {
      case BadgeSize.small:
        return AppSpacing.xs;
      case BadgeSize.medium:
        return AppSpacing.sm;
      case BadgeSize.large:
        return AppSpacing.md;
    }
  }

  double _getHorizontalPadding() {
    switch (size) {
      case BadgeSize.small:
        return AppSpacing.sm;
      case BadgeSize.medium:
        return AppSpacing.md;
      case BadgeSize.large:
        return AppSpacing.lg;
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case BadgeSize.small:
        return AppBorderRadius.xs;
      case BadgeSize.medium:
        return AppBorderRadius.sm;
      case BadgeSize.large:
        return AppBorderRadius.md;
    }
  }

  double _getFontSize() {
    switch (size) {
      case BadgeSize.small:
        return AppTextSize.xs;
      case BadgeSize.medium:
        return AppTextSize.sm;
      case BadgeSize.large:
        return AppTextSize.md;
    }
  }

  double _getIconSize() {
    switch (size) {
      case BadgeSize.small:
        return AppIconSize.xs;
      case BadgeSize.medium:
        return AppIconSize.sm;
      case BadgeSize.large:
        return AppIconSize.md;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor();
    final backgroundColor = _getBackgroundColor(context);

    Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getHorizontalPadding(),
        vertical: _getPadding(),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(_getBorderRadius()),
        border: variant == BadgeVariant.neutral
            ? Border.all(color: AppColors.divider)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: _getIconSize(),
              color: badgeColor,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: _getFontSize(),
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      badge = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          child: badge,
        ),
      );
    }

    return badge;
  }
}
