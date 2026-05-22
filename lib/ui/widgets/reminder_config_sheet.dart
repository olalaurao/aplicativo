import 'package:flutter/material.dart';
import '../../models/reminder_config.dart';
import '../theme.dart';

/// Mode of the reminder trigger
enum _TriggerMode {
  absolute, // specific date + time
  hoursBefore, // X hours before (requires parent to have a time)
  daysBefore, // X days before at specific time
  sameDay, // same day as parent at specific time (requires parent date only)
}

class ReminderConfigSheet extends StatefulWidget {
  final Function(ReminderConfig) onSave;

  /// If the parent object has a scheduled time, pass it here.
  /// Used to enable "X hours before" and "X days before" options.
  final DateTime? parentDateTime;

  /// If the parent only has a date (no time), pass it here.
  final DateTime? parentDateOnly;

  const ReminderConfigSheet({
    super.key,
    required this.onSave,
    this.parentDateTime,
    this.parentDateOnly,
  });

  @override
  State<ReminderConfigSheet> createState() => _ReminderConfigSheetState();
}

class _ReminderConfigSheetState extends State<ReminderConfigSheet> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  NotificationType _type = NotificationType.push;
  final TextEditingController _bodyController = TextEditingController();
  bool _ringOnSilent = false;
  // New toggles for sound and vibration
  bool _playSound = true;
  bool _vibrate = true;
  int _snoozeMinutes = 10;

  _TriggerMode _triggerMode = _TriggerMode.absolute;
  int _hoursBeforeValue = 1;
  int _daysBeforeValue = 1;
  TimeOfDay _beforeTimeOfDay = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(
      DateTime.now().add(const Duration(hours: 1)),
    );
    // Default mode based on parent info
    if (widget.parentDateTime != null) {
      _triggerMode = _TriggerMode.hoursBefore;
    } else if (widget.parentDateOnly != null) {
      _triggerMode = _TriggerMode.sameDay;
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  bool get _hasParent =>
      widget.parentDateTime != null || widget.parentDateOnly != null;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 24),
            const Text(
              'Novo Lembrete',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // ── Trigger Mode selector (only when parent exists) ──
            if (_hasParent) ...[
              const Text(
                'Quando notificar',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _buildTriggerModeSelector(),
              const SizedBox(height: 20),
            ],

            // ── Trigger configuration ──
            _buildTriggerConfig(context),
            const SizedBox(height: 20),

            // Notification Type
            const Text(
              'Tipo de Notificação',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTypeChip(
                  NotificationType.push,
                  'Push',
                  Icons.notifications_active_rounded,
                ),
                const SizedBox(width: 8),
                _buildTypeChip(
                  NotificationType.popup,
                  'Popup',
                  Icons.picture_in_picture_rounded,
                ),
                const SizedBox(width: 8),
                _buildTypeChip(
                  NotificationType.alarm,
                  'Alarme',
                  Icons.alarm_rounded,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Message
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: 'Mensagem (opcional)',
                labelStyle: const TextStyle(fontSize: 14),
                hintText: 'Ex: Não se esqueça de revisar...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Alarm-specific configs
            if (_type == NotificationType.alarm || _type == NotificationType.popup) ...[
              SwitchListTile(
                title: const Text(
                  'Tocar mesmo no silencioso',
                  style: TextStyle(fontSize: 14),
                ),
                value: _ringOnSilent,
                onChanged: (val) => setState(() => _ringOnSilent = val),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text(
                  'Reproduzir som',
                  style: TextStyle(fontSize: 14),
                ),
                value: _playSound,
                onChanged: (val) => setState(() => _playSound = val),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text(
                  'Vibrar',
                  style: TextStyle(fontSize: 14),
                ),
                value: _vibrate,
                onChanged: (val) => setState(() => _vibrate = val),
                contentPadding: EdgeInsets.zero,
              ),
              Row(
                children: [
                  const Text('Soneca (minutos):', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _snoozeMinutes,
                    items: [5, 10, 15, 30]
                        .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _snoozeMinutes = val ?? 10),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            // Save Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Salvar Lembrete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerModeSelector() {
    final modes = <_TriggerMode, String>{
      if (widget.parentDateTime != null)
        _TriggerMode.hoursBefore: 'X horas antes',
      if (widget.parentDateTime != null || widget.parentDateOnly != null)
        _TriggerMode.daysBefore: 'X dias antes',
      if (widget.parentDateOnly != null)
        _TriggerMode.sameDay: 'No mesmo dia',
      _TriggerMode.absolute: 'Data/hora exata',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: modes.entries.map((entry) {
          final selected = _triggerMode == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _triggerMode = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppTheme.surfaceVariantColor(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTriggerConfig(BuildContext context) {
    switch (_triggerMode) {
      case _TriggerMode.hoursBefore:
        return _buildHoursBeforeConfig();
      case _TriggerMode.daysBefore:
        return _buildDaysBeforeConfig(context);
      case _TriggerMode.sameDay:
        return _buildSameDayConfig(context);
      case _TriggerMode.absolute:
        return _buildAbsoluteConfig(context);
    }
  }

  Widget _buildHoursBeforeConfig() {
    return Row(
      children: [
        const Text('Notificar', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 12),
        _buildNumberStepper(
          value: _hoursBeforeValue,
          min: 1,
          max: 72,
          onChanged: (v) => setState(() => _hoursBeforeValue = v),
        ),
        const SizedBox(width: 12),
        const Text('hora(s) antes', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildDaysBeforeConfig(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Notificar', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 12),
            _buildNumberStepper(
              value: _daysBeforeValue,
              min: 1,
              max: 30,
              onChanged: (v) => setState(() => _daysBeforeValue = v),
            ),
            const SizedBox(width: 12),
            const Text('dia(s) antes', style: TextStyle(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Às que horas:', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        _buildTimePicker(
          context,
          _beforeTimeOfDay,
          (t) => setState(() => _beforeTimeOfDay = t),
        ),
      ],
    );
  }

  Widget _buildSameDayConfig(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No mesmo dia, às:',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildTimePicker(
          context,
          _beforeTimeOfDay,
          (t) => setState(() => _beforeTimeOfDay = t),
        ),
      ],
    );
  }

  Widget _buildAbsoluteConfig(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildPicker(
            label: 'Data',
            value:
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            icon: Icons.calendar_today_rounded,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTimePicker(
            context,
            _selectedTime,
            (t) => setState(() => _selectedTime = t),
            label: 'Hora',
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(
    BuildContext context,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onChanged, {
    String label = 'Hora',
  }) {
    return _buildPicker(
      label: label,
      value: time.format(context),
      icon: Icons.access_time_rounded,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }

  Widget _buildNumberStepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed:
                value > min ? () => onChanged(value - 1) : null,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed:
                value < max ? () => onChanged(value + 1) : null,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _save() {
    ReminderConfig config;

    switch (_triggerMode) {
      case _TriggerMode.hoursBefore:
        config = ReminderConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          minutesBefore: _hoursBeforeValue * 60,
          type: _type,
          notificationBody:
              _bodyController.text.isEmpty ? null : _bodyController.text,
          ringOnSilent: _ringOnSilent,
          snoozeMinutes: _snoozeMinutes,
          playSound: _playSound,
          vibrate: _vibrate,
        );
        break;

      case _TriggerMode.daysBefore:
        config = ReminderConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          daysBefore: _daysBeforeValue,
          timeOfDay:
              '${_beforeTimeOfDay.hour.toString().padLeft(2, '0')}:${_beforeTimeOfDay.minute.toString().padLeft(2, '0')}',
          type: _type,
          notificationBody:
              _bodyController.text.isEmpty ? null : _bodyController.text,
          ringOnSilent: _ringOnSilent,
          snoozeMinutes: _snoozeMinutes,
          playSound: _playSound,
          vibrate: _vibrate,
        );
        break;

      case _TriggerMode.sameDay:
        config = ReminderConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          daysBefore: 0,
          timeOfDay:
              '${_beforeTimeOfDay.hour.toString().padLeft(2, '0')}:${_beforeTimeOfDay.minute.toString().padLeft(2, '0')}',
          type: _type,
          notificationBody:
              _bodyController.text.isEmpty ? null : _bodyController.text,
          ringOnSilent: _ringOnSilent,
          snoozeMinutes: _snoozeMinutes,
          playSound: _playSound,
          vibrate: _vibrate,
        );
        break;

      case _TriggerMode.absolute:
        final trigger = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
        config = ReminderConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          triggerTime: trigger,
          type: _type,
          notificationBody:
              _bodyController.text.isEmpty ? null : _bodyController.text,
          ringOnSilent: _ringOnSilent,
          snoozeMinutes: _snoozeMinutes,
          playSound: _playSound,
          vibrate: _vibrate,
        );
        break;
    }

    widget.onSave(config);
    Navigator.pop(context);
  }

  Widget _buildPicker({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(NotificationType type, String label, IconData icon) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
