import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Reusable widget for a single settings row with consistent styling
class SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon != null
          ? Icon(
              icon,
              color: iconColor ?? AppTheme.accentColor(context),
              size: 20,
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Reusable widget for a settings switch row
class SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.accentColor(context),
      ),
    );
  }
}

/// Reusable widget for a settings group with card decoration and dividers
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? margin;

  const SettingsGroup({
    super.key,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      child: Column(
        children: _buildChildrenWithDividers(),
      ),
    );
  }

  List<Widget> _buildChildrenWithDividers() {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(const Divider(height: 1, indent: 16));
      }
    }
    return result;
  }
}

/// Reusable widget for a section header
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}
