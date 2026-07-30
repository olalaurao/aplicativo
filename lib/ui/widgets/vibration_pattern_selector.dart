// lib/ui/widgets/vibration_pattern_selector.dart
import 'package:flutter/material.dart';
import 'app_dropdown.dart';
import '../../services/vibration_pattern_helper.dart';

/// Reusable dropdown for selecting vibration patterns.
/// Wraps AppDropdown with preset pattern options.
class VibrationPatternSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String?>? onChanged;
  final String label;
  final bool enabled;

  const VibrationPatternSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final patternLabels = VibrationPatternHelper.getAllPatternLabels();
    final patternNames = VibrationPatternHelper.getAllPatternNames();

    final items = patternNames.map((patternName) {
      return DropdownMenuItem<String>(
        value: patternName,
        child: Text(patternLabels[patternName] ?? 'Normal'),
      );
    }).toList();

    return AppDropdown<String>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      label: label,
      isExpanded: true,
    );
  }
}
