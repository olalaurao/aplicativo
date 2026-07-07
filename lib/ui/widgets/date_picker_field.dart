// lib/ui/widgets/date_picker_field.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class DatePickerField extends StatelessWidget {
  final DateTime? initialDate;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateChanged;
  final String? label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;
  final String? hintText;

  const DatePickerField({
    super.key,
    this.initialDate,
    this.selectedDate,
    required this.onDateChanged,
    this.label,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.hintText,
  });

  Future<void> _pickDate(BuildContext context) async {
    if (!enabled) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );

    if (picked != null) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _pickDate(context) : null,
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: IgnorePointer(
        child: TextField(
          controller: TextEditingController(
            text: selectedDate != null
                ? _formatDate(selectedDate!)
                : '',
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText ?? 'Select date',
            suffixIcon: const Icon(Icons.calendar_today_rounded),
            enabled: enabled,
          ),
          readOnly: true,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
