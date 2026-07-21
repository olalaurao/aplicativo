import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../services/permission_service.dart';
import '../../notification_settings_screen.dart';

class NotificationsSection extends ConsumerStatefulWidget {
  const NotificationsSection({super.key});

  @override
  ConsumerState<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<NotificationsSection> {
  bool? _exactAlarmPermissionGranted;
  bool? _fullScreenIntentGranted;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    if (Platform.isAndroid) {
      final exactAlarm = await PermissionService.canScheduleExactAlarms();
      final fullScreen = await PermissionService.checkFullScreenIntent();
      if (mounted) {
        setState(() {
          _exactAlarmPermissionGranted = exactAlarm;
          _fullScreenIntentGranted = fullScreen;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      children: [
        _switchTile(
          'Habit Reminders',
          settings.habitReminders,
          notifier.updateHabitReminders,
        ),
        _switchTile(
          'Pomodoro Sounds',
          settings.pomodoroSounds,
          notifier.updatePomodoroSounds,
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            title: const Text(
              'Notification Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Customize colors and buttons for popups & alarms',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
        ),
        if (Platform.isAndroid) ...[
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: AppTheme.cardDecoration(context),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _exactAlarmPermissionGranted == true
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: _exactAlarmPermissionGranted == true
                        ? AppColors.success
                        : AppColors.warning,
                    size: 20,
                  ),
                  title: const Text(
                    'Exact Alarm Permission',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _exactAlarmPermissionGranted == true
                        ? 'Granted — alarms fire at exact time'
                        : 'Not granted — alarms may be delayed',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: _exactAlarmPermissionGranted == true
                      ? null
                      : TextButton(
                          onPressed: () async {
                            await PermissionService.showExactAlarmPermissionDialog(
                              context,
                            );
                            _loadPermissions();
                          },
                          child: const Text(
                            'Grant',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: Icon(
                    _fullScreenIntentGranted == true
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: _fullScreenIntentGranted == true
                        ? AppColors.success
                        : AppColors.warning,
                    size: 20,
                  ),
                  title: const Text(
                    'Full-Screen Notification',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _fullScreenIntentGranted == true
                        ? 'Granted — popups appear over lock screen'
                        : 'Not granted — popups may not appear on lock screen',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: _fullScreenIntentGranted == true
                      ? null
                      : TextButton(
                          onPressed: () async {
                            await PermissionService.requestFullScreenIntent();
                            _loadPermissions();
                          },
                          child: const Text(
                            'Grant',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.accentColor(context),
        ),
      ),
    );
  }
}
