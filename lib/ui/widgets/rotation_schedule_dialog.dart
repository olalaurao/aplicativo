import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/project_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/rotation_service.dart';
import '../theme.dart';
import 'number_stepper.dart';

class RotationScheduleDialog extends ConsumerStatefulWidget {
  final Project project;
  final RotationStatus status;
  final DateTime date;
  final String initialTime;
  final int initialDuration;

  const RotationScheduleDialog({
    super.key,
    required this.project,
    required this.status,
    required this.date,
    required this.initialTime,
    required this.initialDuration,
  });

  @override
  ConsumerState<RotationScheduleDialog> createState() => _RotationScheduleDialogState();
}

class _RotationScheduleDialogState extends ConsumerState<RotationScheduleDialog> {
  late TimeOfDay _time;
  late int _durationMinutes;
  String _scope = 'occurrence';

  @override
  void initState() {
    super.initState();
    final parts = widget.initialTime.split(':');
    _time = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    _durationMinutes = widget.initialDuration;
  }

  void _save() async {
    final formattedTime = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final updated = RotationService.applyScheduleOverride(
      widget.project,
      status: widget.status,
      date: widget.date,
      time: formattedTime,
      durationMinutes: _durationMinutes,
      scope: _scope,
    );
    await ref.read(vaultProvider.notifier).updateObject(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adjust Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTextSize.lg)),
      backgroundColor: AppTheme.surfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Time', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () async {
                final selected = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (selected != null && mounted) {
                  setState(() => _time = selected);
                }
              },
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 20, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _time.format(context),
                      style: const TextStyle(fontSize: AppTextSize.md, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Duration (minutes)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            NumberStepper(
              value: _durationMinutes,
              min: 5,
              max: 480,
              step: 5,
              onChanged: (val) => setState(() => _durationMinutes = val),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Apply to', style: TextStyle(fontWeight: FontWeight.w600)),
            RadioListTile<String>(
              title: const Text('Just today', style: TextStyle(fontSize: AppTextSize.sm)),
              value: 'date',
              groupValue: _scope,
              onChanged: (val) => setState(() => _scope = val!),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              title: const Text('This occurrence', style: TextStyle(fontSize: AppTextSize.sm)),
              subtitle: Text(
                'Current repetition of ${widget.status.group.name}',
                style: const TextStyle(fontSize: AppTextSize.xs, color: AppColors.textMuted),
              ),
              value: 'occurrence',
              groupValue: _scope,
              onChanged: (val) => setState(() => _scope = val!),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              title: const Text('Future default', style: TextStyle(fontSize: AppTextSize.sm)),
              value: 'future',
              groupValue: _scope,
              onChanged: (val) => setState(() => _scope = val!),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
