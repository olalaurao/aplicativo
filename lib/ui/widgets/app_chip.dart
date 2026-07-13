// lib/ui/widgets/app_chip.dart
import 'package:flutter/material.dart';
import '../theme.dart';

enum ChipVariant {
  choice,
  filter,
  action,
}

enum ChipSize {
  small,
  medium,
  large,
}

class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final ChipVariant variant;
  final ChipSize size;
  final Color? color;
  final IconData? icon;
  final bool showCheckmark;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.variant = ChipVariant.choice,
    this.size = ChipSize.medium,
    this.color,
    this.icon,
    this.showCheckmark = true,
  });

  double _getPadding() {
    switch (size) {
      case ChipSize.small:
        return AppSpacing.sm;
      case ChipSize.medium:
        return AppSpacing.md;
      case ChipSize.large:
        return AppSpacing.lg;
    }
  }

  double _getHorizontalPadding() {
    switch (size) {
      case ChipSize.small:
        return AppSpacing.md;
      case ChipSize.medium:
        return AppSpacing.lg;
      case ChipSize.large:
        return AppSpacing.xl;
    }
  }

  double _getFontSize() {
    switch (size) {
      case ChipSize.small:
        return AppTextSize.xs;
      case ChipSize.medium:
        return AppTextSize.sm;
      case ChipSize.large:
        return AppTextSize.md;
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case ChipSize.small:
        return AppBorderRadius.md;
      case ChipSize.medium:
        return AppBorderRadius.lg;
      case ChipSize.large:
        return AppBorderRadius.xl;
    }
  }

  Color _getEffectiveColor(BuildContext context) {
    if (color != null) return color!;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = _getEffectiveColor(context);

    switch (variant) {
      case ChipVariant.choice:
        return ChoiceChip(
          label: _buildLabel(effectiveColor),
          selected: selected,
          onSelected: onTap != null ? (_) => onTap!() : null,
          selectedColor: effectiveColor.withValues(alpha: 0.16),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected
                ? effectiveColor
                : AppTheme.textSecondaryColor(context),
            fontSize: _getFontSize(),
          ),
          side: BorderSide(
            color: selected
                ? effectiveColor.withValues(alpha: 0.28)
                : Theme.of(context).dividerColor,
          ),
          backgroundColor: AppTheme.surfaceVariantColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
          showCheckmark: showCheckmark,
          avatar: icon != null
              ? Icon(
                  icon,
                  size: size == ChipSize.small ? 16 : 20,
                  color: selected ? effectiveColor : AppTheme.textSecondaryColor(context),
                )
              : null,
        );

      case ChipVariant.filter:
        return FilterChip(
          label: _buildLabel(effectiveColor),
          selected: selected,
          onSelected: onTap != null ? (_) => onTap!() : null,
          selectedColor: effectiveColor.withValues(alpha: 0.16),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected
                ? effectiveColor
                : AppTheme.textSecondaryColor(context),
            fontSize: _getFontSize(),
          ),
          side: BorderSide(
            color: selected
                ? effectiveColor.withValues(alpha: 0.28)
                : Theme.of(context).dividerColor,
          ),
          backgroundColor: AppTheme.surfaceVariantColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
          checkmarkColor: effectiveColor,
          avatar: icon != null
              ? Icon(
                  icon,
                  size: size == ChipSize.small ? 16 : 20,
                  color: selected ? effectiveColor : AppTheme.textSecondaryColor(context),
                )
              : null,
        );

      case ChipVariant.action:
        return ActionChip(
          label: _buildLabel(effectiveColor),
          onPressed: onTap,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: _getFontSize(),
          ),
          side: BorderSide(
            color: effectiveColor.withValues(alpha: 0.35),
          ),
          backgroundColor: effectiveColor.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getBorderRadius()),
          ),
          avatar: icon != null
              ? Icon(
                  icon,
                  size: size == ChipSize.small ? 16 : 20,
                  color: effectiveColor,
                )
              : null,
        );
    }
  }

  Widget _buildLabel(Color effectiveColor) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _getHorizontalPadding(),
        vertical: _getPadding(),
      ),
      child: Text(label),
    );
  }
}
