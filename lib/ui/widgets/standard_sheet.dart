// lib/ui/widgets/standard_sheet.dart
import 'package:flutter/material.dart';
import '../theme.dart';

enum SheetRadius {
  small,
  medium,
  large,
}

class StandardSheet extends StatelessWidget {
  final Widget child;
  final SheetRadius radius;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final bool showHandle;
  final double? height;

  const StandardSheet({
    super.key,
    required this.child,
    this.radius = SheetRadius.large,
    this.backgroundColor,
    this.padding,
    this.showHandle = true,
    this.height,
  });

  double _getRadiusValue() {
    switch (radius) {
      case SheetRadius.small:
        return AppBorderRadius.lg;
      case SheetRadius.medium:
        return AppBorderRadius.xl;
      case SheetRadius.large:
        return AppBorderRadius.xxl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? 
        Theme.of(context).scaffoldBackgroundColor;
    
    final effectivePadding = padding ?? 
        const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_getRadiusValue()),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            const SheetHandle(),
            const SizedBox(height: AppSpacing.lg),
          ],
          Padding(
            padding: effectivePadding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppBorderRadius.xs),
        ),
      ),
    );
  }
}
