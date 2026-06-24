// lib/services/permission_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PermissionService {
  static const _channel = MethodChannel('com.productivity.citrine/settings');

  static Future<void> requestBatteryOptimizationBypass() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (_) {}
  }

  static Future<void> requestExactAlarmSettings() async {
    try {
      await _channel.invokeMethod('requestScheduleExactAlarm');
    } catch (_) {}
  }

  static Future<void> requestFullScreenIntent() async {
    try {
      await _channel.invokeMethod('requestFullScreenIntent');
    } catch (_) {}
  }

  static Future<bool> checkFullScreenIntent() async {
    try {
      return await _channel.invokeMethod<bool>('checkFullScreenIntent') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Check if exact alarm permission is granted using the flutter_local_notifications plugin.
  static Future<bool> canScheduleExactAlarms() async {
    if (Platform.isAndroid) {
      try {
        final nativeAllowed = await _channel.invokeMethod<bool>(
          'checkScheduleExactAlarm',
        );
        if (nativeAllowed != null) return nativeAllowed;
      } catch (_) {}
    }

    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      return await android.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestAllPermissions() async {
    if (Platform.isAndroid) {
      // 1. Notifications
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // 2. Exact alarms (Android 12+)
      // Use the native AlarmManager check first. Declaring USE_EXACT_ALARM
      // bypasses this dialog on some Android versions, so the manifest only
      // declares SCHEDULE_EXACT_ALARM and we explicitly send the user to the
      // special access page when denied.
      final canScheduleExact = await canScheduleExactAlarms();
      if (!canScheduleExact) {
        // Open the system settings page for exact alarms via platform channel
        await requestExactAlarmSettings();
      }

      // 3. Full screen intent (Android 14+)
      if (!(await checkFullScreenIntent())) {
        await requestFullScreenIntent();
      }

      // 4. Storage
      // On Android 11+ we ideally want Manage External Storage for a vault app
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }

      // Fallback/Legacy storage permissions for older Android versions
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }

      // Ignore Battery Optimizations - Direct Redirection to Settings!
      try {
        final batteryIgnored =
            await _channel.invokeMethod<bool>(
              'checkBatteryOptimizationIgnored',
            ) ??
            false;
        if (!batteryIgnored) {
          await requestBatteryOptimizationBypass();
        }
      } catch (_) {
        if (await Permission.ignoreBatteryOptimizations.isDenied) {
          await requestBatteryOptimizationBypass();
        }
      }

      // System Alert Window (aparecer sobre outros apps, pro Pomodoro/alarmes trancados)
      try {
        final alertWindowGranted =
            await _channel.invokeMethod<bool>('checkSystemAlertWindow') ??
            false;
        if (!alertWindowGranted) {
          await _channel.invokeMethod('requestSystemAlertWindow');
        }
      } catch (_) {
        if (await Permission.systemAlertWindow.isDenied) {
          await Permission.systemAlertWindow.request();
        }
      }
    }
  }

  /// Show a dialog explaining why exact alarm permission is needed, then
  /// redirect to the system settings page. Call from a settings screen or
  /// when scheduling the first alarm-type notification.
  static Future<void> showExactAlarmPermissionDialog(
    BuildContext context,
  ) async {
    if (!Platform.isAndroid) return;
    final canSchedule = await canScheduleExactAlarms();
    if (canSchedule) return;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissão de Alarme Exato'),
        content: const Text(
          'Para disparar alarmes e notificações popup no horário exato, '
          'o Citrine precisa da permissão "Agendar alarmes exatos".\n\n'
          'Você será levado às configurações do sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Depois'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir Configurações'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await requestExactAlarmSettings();
    }
  }

  static Future<bool> hasStoragePermission() async {
    if (Platform.isWindows) return true;
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      return false;
    }
    return true; // iOS handles via pickers
  }
}
