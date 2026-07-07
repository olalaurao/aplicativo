// lib/ui/widgets/time_picker_field.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class TimePickerField extends StatelessWidget {
  final TimeOfDay? initialTime;
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay?> onTimeChanged;
  final String? label;
  final bool enabled;
  final String? hintText;

  const TimePickerField({
    super.key,
    this.initialTime,
    this.selectedTime,
    required this.onTimeChanged,
    this.label,
    this.enabled = true,
    this.hintText,
  });

  Future<void> _pickTime(BuildContext context) async {
    if (!enabled) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? initialTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      onTimeChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _pickTime(context) : null,
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: IgnorePointer(
        child: TextField(
          controller: TextEditingController(
            text: selectedTime != null
                ? _formatTime(selectedTime!)
                : '',
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText ?? 'Select time',
            suffixIcon: const Icon(Icons.access_time),
            enabled: enabled,
          ),
          readOnly: true,
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
