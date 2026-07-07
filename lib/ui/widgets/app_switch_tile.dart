// lib/ui/widgets/app_switch_tile.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class AppSwitchTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String? subtitle;
  final bool enabled;
  final Widget? leading;
  final EdgeInsetsGeometry? contentPadding;

  const AppSwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.leading,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: contentPadding ?? EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          fontSize: AppTextSize.md,
          color: enabled ? AppTheme.textPrimaryColor(context) : AppTheme.textMutedColor(context),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: AppTextSize.sm,
                color: AppTheme.textMutedColor(context),
              ),
            )
          : null,
      value: value,
      onChanged: enabled ? onChanged : null,
      activeColor: Theme.of(context).colorScheme.primary,
      secondary: leading,
    );
  }
}
