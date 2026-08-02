// lib/ui/widgets/rotation_reminder_config_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/project_model.dart';
import '../../models/reminder_config.dart';
import '../theme.dart';

// ─── Sheet Widget ─────────────────────────────────────────────────────────────

/// Bottom sheet to add/edit a [RotationReminderConfig] for a rotation project.
///
/// Usage:
/// ```dart
/// showRotationReminderConfigSheet(
///   context,
///   project: project,
///   initialGroupId: group.id,  // null = all groups
///   onSave: (config) { ... },
/// );
/// ```
class RotationReminderConfigSheet extends StatefulWidget {
  final Project project;
  /// Pre-selected group ID; null means "All groups" is pre-selected.
  final String? initialGroupId;
  final Function(RotationReminderConfig) onSave;

  const RotationReminderConfigSheet({
    super.key,
    required this.project,
    required this.onSave,
    this.initialGroupId,
  });

  @override
  State<RotationReminderConfigSheet> createState() =>
      _RotationReminderConfigSheetState();
}

class _RotationReminderConfigSheetState
    extends State<RotationReminderConfigSheet> {
  late String? _selectedGroupId;
  late RotationReminderTriggerMode _triggerMode;
  int _minutesBefore = 10;
  TimeOfDay _timeOfDay = const TimeOfDay(hour: 9, minute: 0);
  NotificationType _notifType = NotificationType.push;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.initialGroupId;
    _triggerMode = RotationReminderTriggerMode.atStartTime;
  }

  void _save() {
    HapticFeedback.lightImpact();
    final config = RotationReminderConfig(
      id: const Uuid().v4(),
      groupId: _selectedGroupId,
      triggerMode: _triggerMode,
      minutesBefore:
          _triggerMode == RotationReminderTriggerMode.minutesBefore
              ? _minutesBefore
              : null,
      timeOfDay:
          _triggerMode == RotationReminderTriggerMode.atTimeOfDay
              ? '${_timeOfDay.hour.toString().padLeft(2, '0')}:${_timeOfDay.minute.toString().padLeft(2, '0')}'
              : null,
      notificationType: _notifType,
    );
    Navigator.pop(context);
    widget.onSave(config);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Handle ───
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Header ───
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.notifications_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rotation Reminder',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Add rotation reminder',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ─── Scope ───
            _SectionLabel(label: 'Scope'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedGroupId,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  hint: const Text('All groups'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'All groups',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ...widget.project.rotationGroups.map(
                      (g) => DropdownMenuItem<String?>(
                        value: g.id,
                        child: Text(
                          '${g.emoji ?? ''} ${g.name}'.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Trigger ───
            _SectionLabel(label: 'When to fire'),
            const SizedBox(height: 10),
            _TriggerOption(
              label: 'At start time',
              subtitle: 'When the rotation block begins in the Planner',
              icon: Icons.play_circle_outline_rounded,
              selected:
                  _triggerMode == RotationReminderTriggerMode.atStartTime,
              onTap: () => setState(
                () => _triggerMode = RotationReminderTriggerMode.atStartTime,
              ),
            ),
            const SizedBox(height: 8),
            _TriggerOption(
              label: 'Before start',
              subtitle: 'N minutes before the block',
              icon: Icons.timer_outlined,
              selected:
                  _triggerMode == RotationReminderTriggerMode.minutesBefore,
              onTap: () => setState(
                () => _triggerMode = RotationReminderTriggerMode.minutesBefore,
              ),
              trailing: _triggerMode == RotationReminderTriggerMode.minutesBefore
                  ? _MinutesBeforePicker(
                      value: _minutesBefore,
                      onChanged: (v) => setState(() => _minutesBefore = v),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            _TriggerOption(
              label: 'At time of day',
              subtitle: 'Fixed time on rotation days',
              icon: Icons.access_time_rounded,
              selected:
                  _triggerMode == RotationReminderTriggerMode.atTimeOfDay,
              onTap: () => setState(
                () => _triggerMode = RotationReminderTriggerMode.atTimeOfDay,
              ),
              trailing:
                  _triggerMode == RotationReminderTriggerMode.atTimeOfDay
                      ? GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _timeOfDay,
                            );
                            if (picked != null) {
                              setState(() => _timeOfDay = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _timeOfDay.format(context),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        )
                      : null,
            ),
            const SizedBox(height: 24),

            // ─── Notification Type ───
            _SectionLabel(label: 'Notification type'),
            const SizedBox(height: 10),
            Row(
              children: [
                _NotifTypeChip(
                  label: 'Push',
                  icon: Icons.notifications_outlined,
                  selected: _notifType == NotificationType.push,
                  onTap: () => setState(() => _notifType = NotificationType.push),
                ),
                const SizedBox(width: 8),
                _NotifTypeChip(
                  label: 'Popup',
                  icon: Icons.open_in_new_rounded,
                  selected: _notifType == NotificationType.popup,
                  onTap: () =>
                      setState(() => _notifType = NotificationType.popup),
                ),
                const SizedBox(width: 8),
                _NotifTypeChip(
                  label: 'Alarm',
                  icon: Icons.alarm_rounded,
                  selected: _notifType == NotificationType.alarm,
                  onTap: () =>
                      setState(() => _notifType = NotificationType.alarm),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── Save ───
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add Reminder',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppTheme.textMutedColor(context),
      letterSpacing: 0.3,
    ),
  );
}

class _TriggerOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _TriggerOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.08)
              : isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? accent : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? accent
                          : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _MinutesBeforePicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _MinutesBeforePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);

    final options = [5, 10, 15, 30, 60];
    return PopupMenuButton<int>(
      initialValue: value,
      onSelected: onChanged,
      borderRadius: BorderRadius.circular(12),
      itemBuilder: (_) => options
          .map(
            (o) => PopupMenuItem(
              value: o,
              child: Text(
                '$o min',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value min',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}

class _NotifTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NotifTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? accent
                : isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper Function ──────────────────────────────────────────────────────────

/// Show the rotation reminder config sheet as a modal.
Future<void> showRotationReminderConfigSheet(
  BuildContext context, {
  required Project project,
  String? initialGroupId,
  required Function(RotationReminderConfig) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RotationReminderConfigSheet(
      project: project,
      initialGroupId: initialGroupId,
      onSave: onSave,
    ),
  );
}
