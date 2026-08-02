// lib/ui/widgets/snooze_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

// ─── Unit Enum ────────────────────────────────────────────────────────────────

enum SnoozeUnit { minutes, hours, days }

extension SnoozeUnitExt on SnoozeUnit {
  String get label {
    switch (this) {
      case SnoozeUnit.minutes:
        return 'minutes';
      case SnoozeUnit.hours:
        return 'hours';
      case SnoozeUnit.days:
        return 'days';
    }
  }

  Duration toDuration(int amount) {
    switch (this) {
      case SnoozeUnit.minutes:
        return Duration(minutes: amount);
      case SnoozeUnit.hours:
        return Duration(hours: amount);
      case SnoozeUnit.days:
        return Duration(days: amount);
    }
  }

  int get defaultAmount {
    switch (this) {
      case SnoozeUnit.minutes:
        return 10;
      case SnoozeUnit.hours:
        return 1;
      case SnoozeUnit.days:
        return 1;
    }
  }

  int get max {
    switch (this) {
      case SnoozeUnit.minutes:
        return 120;
      case SnoozeUnit.hours:
        return 24;
      case SnoozeUnit.days:
        return 30;
    }
  }
}

// ─── Presets ─────────────────────────────────────────────────────────────────

class _SnoozePreset {
  final String label;
  final int amount;
  final SnoozeUnit unit;
  const _SnoozePreset(this.label, this.amount, this.unit);
}

const _presets = [
  _SnoozePreset('10 min', 10, SnoozeUnit.minutes),
  _SnoozePreset('30 min', 30, SnoozeUnit.minutes),
  _SnoozePreset('1 hour', 1, SnoozeUnit.hours),
  _SnoozePreset('3 hours', 3, SnoozeUnit.hours),
  _SnoozePreset('1 day', 1, SnoozeUnit.days),
  _SnoozePreset('3 days', 3, SnoozeUnit.days),
];

// ─── Sheet Widget ─────────────────────────────────────────────────────────────

/// A reusable bottom sheet for snoozing/deferring any item.
///
/// Usage:
/// ```dart
/// showSnoozePickerSheet(context, title: 'Snooze habit', onSnooze: (duration) {
///   // schedule notification or defer item
/// });
/// ```
class SnoozePickerSheet extends StatefulWidget {
  /// Title shown at the top (e.g. "Snooze: Exercise")
  final String title;

  /// Called when the user confirms. Receives the computed [Duration].
  final ValueChanged<Duration> onSnooze;

  const SnoozePickerSheet({
    super.key,
    required this.title,
    required this.onSnooze,
  });

  @override
  State<SnoozePickerSheet> createState() => _SnoozePickerSheetState();
}

class _SnoozePickerSheetState extends State<SnoozePickerSheet> {
  int _amount = 10;
  SnoozeUnit _unit = SnoozeUnit.minutes;
  int? _activePresetIndex = 0; // index into _presets, null = custom

  void _applyPreset(int index) {
    final preset = _presets[index];
    setState(() {
      _amount = preset.amount;
      _unit = preset.unit;
      _activePresetIndex = index;
    });
  }

  void _onAmountChanged(int value) {
    setState(() {
      _amount = value.clamp(1, _unit.max);
      _activePresetIndex = _matchPreset();
    });
  }

  void _onUnitChanged(SnoozeUnit unit) {
    setState(() {
      _unit = unit;
      _amount = _amount.clamp(1, unit.max);
      _activePresetIndex = _matchPreset();
    });
  }

  int? _matchPreset() {
    for (int i = 0; i < _presets.length; i++) {
      if (_presets[i].amount == _amount && _presets[i].unit == _unit) return i;
    }
    return null;
  }

  void _confirm() {
    HapticFeedback.lightImpact();
    final duration = _unit.toDuration(_amount);
    Navigator.pop(context);
    widget.onSnooze(duration);
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
                child: Icon(Icons.snooze_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Snooze',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Preset Chips ───
          Text(
            'Quick pick',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMutedColor(context),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_presets.length, (i) {
              final active = _activePresetIndex == i;
              return GestureDetector(
                onTap: () => _applyPreset(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? accent
                        : isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? accent
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _presets[i].label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // ─── Custom Picker ───
          Text(
            'Custom',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMutedColor(context),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // − button
              _StepButton(
                icon: Icons.remove_rounded,
                onPressed: _amount > 1
                    ? () => _onAmountChanged(_amount - 1)
                    : null,
              ),
              const SizedBox(width: 10),
              // Amount display
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_amount',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // + button
              _StepButton(
                icon: Icons.add_rounded,
                onPressed: _amount < _unit.max
                    ? () => _onAmountChanged(_amount + 1)
                    : null,
              ),
              const SizedBox(width: 12),
              // Unit dropdown
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SnoozeUnit>(
                      value: _unit,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      items: SnoozeUnit.values
                          .map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Text(
                                u.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (u) {
                        if (u != null) _onUnitChanged(u);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ─── Confirm Button ───
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'Snooze $_amount ${_unit.label}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step Button ──────────────────────────────────────────────────────────────

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed != null
          ? () {
              HapticFeedback.selectionClick();
              onPressed!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? accent.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? accent : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ─── Helper Function ──────────────────────────────────────────────────────────

/// Convenience function to show the snooze picker as a bottom sheet.
Future<void> showSnoozePickerSheet(
  BuildContext context, {
  required String title,
  required ValueChanged<Duration> onSnooze,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SnoozePickerSheet(title: title, onSnooze: onSnooze),
  );
}
