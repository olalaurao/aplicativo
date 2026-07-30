// lib/ui/widgets/notification_sound_toggle.dart
import 'package:flutter/material.dart';
import 'app_switch_tile.dart';

/// Reusable switch tile for notification sound on/off.
/// Wraps AppSwitchTile with consistent styling for sound toggles.
class NotificationSoundToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final bool enabled;

  const NotificationSoundToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppSwitchTile(
      value: value,
      onChanged: enabled ? onChanged : null,
      title: label,
      enabled: enabled,
    );
  }
}
