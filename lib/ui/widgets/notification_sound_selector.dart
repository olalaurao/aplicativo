// lib/ui/widgets/notification_sound_selector.dart
import 'package:flutter/material.dart';
import 'app_dropdown.dart';

/// Reusable dropdown for selecting notification sounds.
/// Wraps AppDropdown with preset sound options.
class NotificationSoundSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String?>? onChanged;
  final String label;
  final bool enabled;

  const NotificationSoundSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Note: To add more sounds, place the files in android/app/src/main/res/raw/
    // and iOS resources, then add them to this map.
    final Map<String, String> sounds = {
      'default': 'System Default',
    };

    final items = sounds.entries.map((entry) {
      return DropdownMenuItem<String>(
        value: entry.key,
        child: Text(entry.value),
      );
    }).toList();

    return AppDropdown<String>(
      value: sounds.containsKey(value) ? value : 'default',
      items: items,
      onChanged: enabled ? onChanged : null,
      label: label,
      isExpanded: true,
    );
  }
}
