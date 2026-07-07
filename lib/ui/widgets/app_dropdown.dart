// lib/ui/widgets/app_dropdown.dart
import 'package:flutter/material.dart';

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hintText;
  final bool enabled;
  final Widget? icon;
  final bool isExpanded;

  const AppDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.label,
    this.hintText,
    this.enabled = true,
    this.icon,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixIcon: icon,
      ),
      isExpanded: isExpanded,
      icon: const Icon(Icons.expand_more),
    );
  }
}
