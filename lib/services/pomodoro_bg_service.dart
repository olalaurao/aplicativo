// lib/services/pomodoro_bg_service.dart
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'notification_service.dart';
import '../models/reminder_config.dart';

class PomodoroTaskHandler extends TaskHandler {
  int _remainingSeconds = 0;
  bool _isRunning = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await NotificationService().init();
    _updateNotification();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_isRunning && _remainingSeconds > 0) {
      _remainingSeconds--;
      _updateNotification();
      FlutterForegroundTask.sendDataToMain(_remainingSeconds);
    } else if (_remainingSeconds <= 0) {
      _isRunning = false;
      _updateNotification(done: true);
      FlutterForegroundTask.sendDataToMain(0);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Cleanup
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'pauseButton') {
      _isRunning = !_isRunning;
      FlutterForegroundTask.sendDataToMain({
        'action': _isRunning ? 'resume' : 'pause',
      });
      _updateNotification();
    } else if (id == 'skipButton') {
      FlutterForegroundTask.sendDataToMain({'action': 'skip'});
    } else if (id == 'stopButton') {
      FlutterForegroundTask.sendDataToMain({'action': 'stop'});
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('seconds')) _remainingSeconds = data['seconds'];
      if (data.containsKey('isRunning')) _isRunning = data['isRunning'];
      _updateNotification();
    }
  }

  void _updateNotification({bool done = false}) {
    if (done) {
      NotificationService().scheduleReminder(
        id: 888,
        title: 'Pomodoro Completed!',
        config: ReminderConfig(
          id: 'pomodoro_done',
          triggerTime: DateTime.now(),
          type: NotificationType.alarm,
          notificationBody: 'Time to switch phases.',
        ),
      );
    }

    if (_isRunning) {
      final minutes = _remainingSeconds ~/ 60;
      final seconds = _remainingSeconds % 60;
      final timeStr =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      FlutterForegroundTask.updateService(
        notificationTitle: 'Pomodoro em andamento',
        notificationText: 'Tempo restante: $timeStr',
        notificationButtons: PomodoroBackgroundService._notificationButtons,
      );
      return;
    }

    FlutterForegroundTask.updateService(
      notificationTitle: done ? 'Pomodoro concluído!' : 'Pomodoro pausado',
      notificationText: done
          ? 'Hora de trocar de fase.'
          : 'Retome quando estiver pronto.',
      notificationButtons: done
          ? const []
          : PomodoroBackgroundService._notificationButtons,
    );
  }
}

class PomodoroBackgroundService {
  static const _notificationButtons = [
    NotificationButton(id: 'pauseButton', text: 'Pausar/Retomar'),
    NotificationButton(id: 'skipButton', text: 'Pular fase'),
    NotificationButton(id: 'stopButton', text: 'Parar'),
  ];

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pomodoro_service',
        channelName: 'Pomodoro',
        channelDescription: 'Keeps Pomodoro running in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startAutoSync({bool enabled = true}) async {
    if (!enabled && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static Future<void> setAutoSyncEnabled(bool enabled) async {
    await startAutoSync(enabled: enabled);
  }

  static Future<void> start(int seconds) async {
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Pomodoro Active',
        notificationText: 'Preparando timer...',
        callback: startCallback,
      );
    }
    FlutterForegroundTask.sendDataToTask({
      'seconds': seconds,
      'isRunning': true,
    });
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static Future<void> pause(int remainingSeconds) async {
    FlutterForegroundTask.sendDataToTask({
      'seconds': remainingSeconds,
      'isRunning': false,
    });
    FlutterForegroundTask.updateService(
      notificationTitle: 'Pomodoro Paused',
      notificationText: 'Retome quando estiver pronto',
      notificationButtons: _notificationButtons,
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PomodoroTaskHandler());
}
