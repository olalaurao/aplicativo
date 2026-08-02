// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/reminder_config.dart';
import '../models/project_model.dart';
import '../ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vault_provider.dart';
import '../providers/notification_overlay_provider.dart';
import '../providers/settings_provider.dart';
import '../ui/screens/alarm_screen.dart';
import '../ui/screens/popup_notification_screen.dart';
import 'package:flutter/services.dart';
import 'permission_service.dart';
import 'rotation_service.dart';
import 'vibration_pattern_helper.dart';

class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  ProviderContainer? _container;
  GlobalKey<NavigatorState>? _navigatorKey;
  NotificationResponse? _pendingFullScreenResponse;

  // ── Foreground timer management ──────────────────────────────────────
  // When the app is in the foreground, system fullScreenIntent is ignored
  // and the notification just shows as a heads-up push. We use in-app timers
  // to detect the fire time and open alarm/popup screens directly.
  final Map<int, Timer> _foregroundTimers = {};
  final Map<int, _ForegroundEntry> _foregroundEntries = {};

  void setProviderContainer(ProviderContainer container) {
    _container = container;
  }

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    final pending = _pendingFullScreenResponse;
    if (pending != null) {
      _pendingFullScreenResponse = null;
      Future.delayed(const Duration(milliseconds: 250), () {
        _handleFullScreenLaunch(pending);
      });
    }
  }

  /// Show an in-app popup notification (overlay banner at top of screen).
  void showInAppPopup({
    required String title,
    required String body,
    PopupType type = PopupType.reminder,
    Color? color,
    String? objectId,
  }) {
    if (_container == null) return;
    final defaultColors = <PopupType, Color>{
      PopupType.task: const Color(0xFF3B82F6),
      PopupType.event: const Color(0xFF8B5CF6),
      PopupType.habit: const Color(0xFF22C55E),
      PopupType.reminder: const Color(0xFF9CA3AF),
    };
    _container!
        .read(notificationOverlayProvider.notifier)
        .show(
          PopupNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            body: body,
            type: type,
            color: color ?? defaultColors[type] ?? AppColors.primary,
            objectId: objectId,
          ),
        );
  }

  /// Open the full-screen alarm screen.
  void showAlarmScreen({
    required String title,
    required String body,
    AlarmType type = AlarmType.alarm,
    String? objectId,
    int? notificationId,
    Color? customColor,
  }) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      debugPrint('NotificationService: navigator not ready for alarm screen');
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(
          data: AlarmData(
            title: title,
            body: body,
            type: type,
            objectId: objectId,
            notificationId: notificationId,
            customColor: customColor,
          ),
        ),
      ),
    );
  }

  /// Open the full-screen popup notification screen.
  void showPopupScreen({
    required String title,
    required String body,
    PopupScreenType type = PopupScreenType.reminder,
    String? objectId,
    int? notificationId,
    Color? customColor,
  }) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      debugPrint('NotificationService: navigator not ready for popup screen');
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (_) => PopupNotificationScreen(
          data: PopupScreenData(
            title: title,
            body: body,
            type: type,
            objectId: objectId,
            notificationId: notificationId,
            customColor: customColor,
          ),
        ),
      ),
    );
  }

  Future<void> init() async {
    // flutter_local_notifications is not supported on Windows/Linux/macOS.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('NotificationService: skipping init on desktop platform');
      return;
    }
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create notification channels for Android
    await createNotificationChannels();

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Request notification permissions explicitly
    final granted = await android?.requestNotificationsPermission();
    debugPrint(
      'NotificationService: notification permission granted: $granted',
    );

    // Also request POST_NOTIFICATIONS permission for Android 13+
    if (Platform.isAndroid) {
      try {
        await PermissionService.requestAllPermissions();
        debugPrint('NotificationService: permissions requested');
      } catch (e) {
        debugPrint('NotificationService: permission request failed: $e');
      }
    }

    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Handle cold-start: if the app was launched by a fullScreenIntent notification
    try {
      final launchDetails = await _notifications
          .getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse != null) {
        final response = launchDetails.notificationResponse!;
        _handleFullScreenLaunch(response);
      }
    } catch (e) {
      debugPrint('NotificationService: cold-start launch check failed: $e');
    }

    // Check for native payload immediately on initialization
    _checkPendingPayloadFromNative();
  }

  /// Handle a notification that launched the app via fullScreenIntent.
  void _handleFullScreenLaunch(NotificationResponse response) {
    if (_navigatorKey?.currentState == null) {
      _pendingFullScreenResponse = response;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (identical(_pendingFullScreenResponse, response)) {
          _pendingFullScreenResponse = null;
          _handleFullScreenLaunch(response);
        }
      });
      return;
    }

    final payload = response.payload ?? '';
    final notifType = _extractNotifType(payload);

    // Cancel any foreground timer for this ID to avoid double-show
    if (response.id != null) {
      _cancelForegroundTimer(response.id!);
    }

    if (notifType == 'alarm' || notifType == 'popup') {
      unawaited(
        _openNativeNotificationPopup(
          payload: payload,
          notificationId: response.id,
        ),
      );
      return;
    }
  }

  static String? _extractField(String payload, String key) {
    final regex = RegExp('$key=([^&]*)');
    final match = regex.firstMatch(payload);
    return match?.group(1);
  }

  static String _extractNotifType(String payload) {
    return _extractField(payload, 'ntype') ?? 'push';
  }

  Future<void> createNotificationChannels() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    // Get user settings if available, otherwise use defaults
    final settings = _container?.read(settingsProvider);
    final version = settings?.notificationChannelVersion ?? 1;

    final alarmPattern = settings?.alarmVibrationPattern ?? 'strong';
    final popupPattern = settings?.popupVibrationPattern ?? 'normal';
    final reminderPattern = settings?.reminderVibrationPattern ?? 'gentle';
    final alarmSound = settings?.alarmSoundEnabled ?? true;
    final popupSound = settings?.popupSoundEnabled ?? true;
    final reminderSound = settings?.reminderSoundEnabled ?? true;

    final alarmSoundName = settings?.alarmSoundName ?? 'default';
    final popupSoundName = settings?.popupSoundName ?? 'default';
    final pushSoundName = settings?.pushSoundName ?? 'default';

    final popupRingOnSilent = settings?.popupRingOnSilent ?? true;
    final pushRingOnSilent = settings?.pushRingOnSilent ?? false;

    // Helper for custom sounds
    AndroidNotificationSound? getSound(String soundName) {
      if (soundName == 'default' || soundName.isEmpty) return null;
      return RawResourceAndroidNotificationSound(soundName);
    }

    // Alarms Channel (Always bypass silent)
    Int64List? alarmVibrationPattern;
    try {
      alarmVibrationPattern = VibrationPatternHelper.getPattern(alarmPattern);
    } catch (e) {
      debugPrint('NotificationService: failed to get alarm vibration pattern: $e');
      alarmVibrationPattern = VibrationPatternHelper.getPattern('strong');
    }

    final alarmChannel = AndroidNotificationChannel(
      'alarm_channel_v$version',
      'Alarms',
      description: 'High priority intrusive alarms',
      importance: Importance.max,
      playSound: alarmSound,
      sound: alarmSound ? getSound(alarmSoundName) : null,
      enableVibration: true,
      enableLights: true,
      vibrationPattern: alarmVibrationPattern,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    // Popups Channel
    Int64List? popupVibrationPattern;
    try {
      popupVibrationPattern = VibrationPatternHelper.getPattern(popupPattern);
    } catch (e) {
      debugPrint('NotificationService: failed to get popup vibration pattern: $e');
      popupVibrationPattern = VibrationPatternHelper.getPattern('normal');
    }

    final popupChannel = AndroidNotificationChannel(
      'popup_channel_v$version',
      'Popups',
      description: 'Important visual popups',
      importance: Importance.max,
      playSound: popupSound,
      sound: popupSound ? getSound(popupSoundName) : null,
      enableVibration: true,
      vibrationPattern: popupVibrationPattern,
      audioAttributesUsage: popupRingOnSilent ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
    );

    // Reminders Channel
    Int64List? reminderVibrationPattern;
    try {
      reminderVibrationPattern = VibrationPatternHelper.getPattern(reminderPattern);
    } catch (e) {
      debugPrint('NotificationService: failed to get reminder vibration pattern: $e');
      reminderVibrationPattern = VibrationPatternHelper.getPattern('gentle');
    }

    final reminderChannel = AndroidNotificationChannel(
      'reminder_channel_v$version',
      'Reminders',
      description: 'General task reminders',
      importance: Importance.max,
      playSound: reminderSound,
      sound: reminderSound ? getSound(pushSoundName) : null,
      enableVibration: true,
      vibrationPattern: reminderVibrationPattern,
      audioAttributesUsage: pushRingOnSilent ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
    );

    final immediateChannel = AndroidNotificationChannel(
      'immediate_channel_v$version',
      'Immediate Notifications',
      description: 'Ongoing or immediate notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 200, 100, 200]),
    );

    final quickCaptureChannel = AndroidNotificationChannel(
      'quick_capture_channel_v$version',
      'Quick Capture',
      description: 'Add a journal entry or task from the lock screen',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    );

    await android.createNotificationChannel(alarmChannel);
    await android.createNotificationChannel(popupChannel);
    await android.createNotificationChannel(reminderChannel);
    await android.createNotificationChannel(immediateChannel);
    await android.createNotificationChannel(quickCaptureChannel);
  }

  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    await _handleNotificationResponse(response);
  }

  static Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId?.isEmpty ?? true
        ? 'open'
        : response.actionId!;

    // Cancel any foreground timer for this notification to avoid double-show
    if (response.id != null) {
      _instance._cancelForegroundTimer(response.id!);
    }

    // If user tapped the notification body (not an action button), check if we
    // should open alarm or popup screen
    if (actionId == 'open') {
      final payload = response.payload ?? '';
      final notifType = _extractNotifType(payload);
      if (notifType == 'alarm' || notifType == 'popup') {
        _instance._handleFullScreenLaunch(response);
        return;
      }
    }

    if (actionId == 'snooze') {
      final payload = response.payload ?? '';
      final titleStr = Uri.decodeComponent(_extractField(payload, 'title') ?? 'Snoozed Reminder');
      final notifType = _extractNotifType(payload);
      var type = NotificationType.push;
      if (notifType == 'alarm') { type = NotificationType.alarm; }
      else if (notifType == 'popup') { type = NotificationType.popup; }

      final snoozeMinutes = _snoozeMinutesFromPayload(payload);
      
      final notificationService = NotificationService();
      await notificationService.scheduleReminder(
        id: response.id ?? 999998,
        title: titleStr,
        config: ReminderConfig(
          id: '${response.id}_snooze',
          triggerTime: DateTime.now().add(Duration(minutes: snoozeMinutes)),
          type: type,
          notificationBody: 'Adiado por ${snoozeMinutes}min',
          snoozeMinutes: snoozeMinutes,
        ),
        payload: payload,
      );
      return;
    }
    if (actionId == 'dismiss') {
      if (response.id != null) {
        await _instance.cancelNotification(response.id!);
      }
      // Reschedule habit reminders for the next day
      await _rescheduleHabitReminderIfApplicable(response);
      return;
    }
    await _enqueueAction(actionId, response.payload, response.id);
    if (response.input != null && response.input!.trim().isNotEmpty) {
      await _enqueueAction('${actionId}_text', response.input, response.id);
    }

    // If app is currently running, process immediately
    if (_instance._container != null) {
      try {
        await _instance._container!
            .read(vaultProvider.notifier)
            .processPendingNotificationActions();
      } catch (e) {
        debugPrint('NotificationService: processPending failed: $e');
      }
    }

    if (actionId == 'quick_entry' ||
        actionId == 'quick_task' ||
        actionId == 'quick_habit') {
      try {
        await _instance.cancelNotification(999);
        await _instance.showQuickCaptureNotification();
        await _instance._bringAppToForeground();
        final input = response.input?.trim();
        if (input != null && input.isNotEmpty) {
          final title = switch (actionId) {
            'quick_entry' => 'Entrada salva',
            'quick_task' => 'Tarefa salva',
            'quick_habit' => 'Hábito salvo',
            _ => 'Captura salva',
          };
          _instance.showInAppPopup(
            title: title,
            body: input.length > 80 ? '${input.substring(0, 80)}...' : input,
            type: actionId == 'quick_task'
                ? PopupType.task
                : actionId == 'quick_habit'
                ? PopupType.habit
                : PopupType.reminder,
          );
        }
      } catch (e) {
        debugPrint('NotificationService: quick capture reset failed: $e');
      }
    }
  }

  static int _snoozeMinutesFromPayload(String? payload) {
    if (payload == null) return 10;
    final match = RegExp(r'snooze=(\d+)').firstMatch(payload);
    return int.tryParse(match?.group(1) ?? '') ?? 10;
  }

  static Future<void> _rescheduleHabitReminderIfApplicable(
    NotificationResponse response,
  ) async {
    if (_instance._container == null) return;
    
    final payload = response.payload ?? '';
    // Check if this is a habit notification
    final typeMatch = RegExp(r'type=habit').firstMatch(payload);
    if (typeMatch == null) return;
    
    try {
      // Simply reschedule all habits - this is the cleanest approach
      // and ensures all habit reminders are properly scheduled for the future
      await _instance._container!.read(vaultProvider.notifier).rescheduleAllHabits();
      debugPrint('Rescheduled all habit reminders after notification dismiss');
    } catch (e) {
      debugPrint('Failed to reschedule habit reminders: $e');
    }
  }

  static Future<void> _enqueueAction(
    String actionId,
    String? payload,
    int? notificationId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('notification_actions') ?? [];
    pending.add(
      jsonEncode({
        'action': actionId,
        'payload': payload,
        'notification_id': notificationId,
        'created_at': DateTime.now().toIso8601String(),
      }),
    );
    await prefs.setStringList('notification_actions', pending);
  }

  Future<List<Map<String, dynamic>>> takePendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    final pending = prefs.getStringList('notification_actions') ?? [];
    await prefs.remove('notification_actions');
    return pending
        .map((item) => jsonDecode(item))
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// F2.16: Clean up old notification actions (14-day rolling window)
  Future<void> cleanOldNotificationActions() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    final pending = prefs.getStringList('notification_actions') ?? [];
    if (pending.isEmpty) return;

    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final filtered = pending.where((item) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        final createdAt = decoded['created_at'] as String?;
        if (createdAt == null) return false;
        final date = DateTime.tryParse(createdAt);
        return date != null && date.isAfter(cutoff);
      } catch (_) {
        return false;
      }
    }).toList();

    await prefs.setStringList('notification_actions', filtered);
  }

  /// Pre-schedules all rotation reminders for [project] for the next [daysAhead] days.
  ///
  /// Called after saving a Project that has rotation groups and rotationReminders.
  /// Uses [RotationService.computeActiveStatus] per day to check if a rotation is
  /// active, then computes each reminder's trigger time via [RotationReminderConfig.computeTriggerTime].
  Future<void> scheduleRotationRemindersForProject(
    Project project, {
    int daysAhead = 7,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    if (!project.hasRotation || project.rotationReminders.isEmpty) return;

    final today = DateTime.now();
    for (int d = 0; d < daysAhead; d++) {
      final day = DateTime(today.year, today.month, today.day + d);
      final status = RotationService.computeActiveStatus(project, now: day);
      if (status == null) continue;

      final schedule = RotationService.scheduleForStatus(project, status, day);
      final startMinutes = _parseTimeString(schedule.time) ?? (9 * 60);
      final blockStart = DateTime(
        day.year,
        day.month,
        day.day,
        startMinutes ~/ 60,
        startMinutes % 60,
      );

      for (final reminder in project.rotationReminders) {
        // Skip if reminder is for a different group
        if (reminder.groupId != null && reminder.groupId != status.group.id) {
          continue;
        }

        final triggerTime = reminder.computeTriggerTime(blockStart);
        if (triggerTime == null) continue;
        if (triggerTime.isBefore(DateTime.now())) continue;

        // Stable ID: hash of project+reminderConfig+day
        final idSeed =
            'rotation_${project.id}_${reminder.id}_${day.toIso8601String().split('T').first}';
        final notifId = idSeed.hashCode.abs() % 999990000 + 1;

        final groupLabel = reminder.groupId == null
            ? ''
            : ' · ${status.group.name}';
        await scheduleReminder(
          id: notifId,
          title: '${project.title}$groupLabel',
          config: ReminderConfig(
            id: idSeed,
            triggerTime: triggerTime,
            type: reminder.notificationType,
            notificationBody: 'Your rotation block is starting.',
            snoozeMinutes: 10,
          ),
          triggerTime: triggerTime,
          payload:
              'Quartzo://notification?oid=${Uri.encodeComponent(project.id)}&type=project',
        );
      }
    }
  }

  static int? _parseTimeString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour.clamp(0, 23) * 60) + minute.clamp(0, 59);
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required ReminderConfig config,
    DateTime? triggerTime,
    String? payload,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return;
    }
    var time = triggerTime ?? config.triggerTime;
    if (time == null) return;
    
    // If time is in the past, schedule for tomorrow (for recurring reminders like habits)
    if (time.isBefore(DateTime.now())) {
      time = time.add(const Duration(days: 1));
    }

    final isAlarm = config.type == NotificationType.alarm;
    final isPopup = config.type == NotificationType.popup;

    if (Platform.isAndroid && (isAlarm || isPopup)) {
      try {
        if (!await PermissionService.canScheduleExactAlarms()) {
          await PermissionService.requestExactAlarmSettings();
        }
        if (!await PermissionService.checkFullScreenIntent()) {
          await PermissionService.requestFullScreenIntent();
        }
      } catch (e) {
        debugPrint('NotificationService: permission check failed: $e');
      }
    }

    // Get user settings for vibration patterns and sound
    final settings = _container?.read(settingsProvider);
    final alarmPattern = settings?.alarmVibrationPattern ?? 'normal';
    final popupPattern = settings?.popupVibrationPattern ?? 'normal';
    final reminderPattern = settings?.reminderVibrationPattern ?? 'normal';
    final alarmSound = settings?.alarmSoundEnabled ?? true;
    final popupSound = settings?.popupSoundEnabled ?? true;
    final reminderSound = settings?.reminderSoundEnabled ?? true;
    final popupRingOnSilent = settings?.popupRingOnSilent ?? true;
    final pushRingOnSilent = settings?.pushRingOnSilent ?? false;

    // Get vibration pattern with error handling
    Int64List vibrationPattern;
    try {
      vibrationPattern = isAlarm
          ? VibrationPatternHelper.getPattern(alarmPattern)
          : (isPopup
                ? VibrationPatternHelper.getPattern(popupPattern)
                : VibrationPatternHelper.getPattern(reminderPattern));
    } catch (e) {
      debugPrint('NotificationService: failed to get vibration pattern: $e');
      vibrationPattern = VibrationPatternHelper.getPattern('normal');
    }

    // Build notification actions based on user button visibility settings
    final buttonConfig = settings?.notificationAppearanceConfig ?? {};
    final showDone = buttonConfig['btn_done'] != 'false';
    final showSnooze = buttonConfig['btn_snooze'] != 'false';
    final showDismiss = buttonConfig['btn_dismiss'] != 'false';

    final List<AndroidNotificationAction> actions = [];
    if (showDone) {
      actions.add(const AndroidNotificationAction('done', 'Concluído'));
    }
    if (showSnooze) {
      actions.add(const AndroidNotificationAction('snooze', 'Adiar'));
    }
    if (showDismiss) {
      actions.add(const AndroidNotificationAction('dismiss', 'Dispensar'));
    }

    // Enforce Android's 3-action limit by prioritizing Done, Snooze, Dismiss
    final filteredActions = actions.take(3).toList();

    final version = settings?.notificationChannelVersion ?? 1;

    final androidDetails = AndroidNotificationDetails(
      isAlarm
          ? 'alarm_channel_v$version'
          : (isPopup ? 'popup_channel_v$version' : 'reminder_channel_v$version'),
      isAlarm ? 'Alarms' : (isPopup ? 'Popups' : 'Reminders'),
      channelDescription: isAlarm
          ? 'High priority intrusive alarms'
          : (isPopup ? 'Important visual popups' : 'General task reminders'),
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: isAlarm || isPopup,
      category: (isAlarm || isPopup)
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      // Use user settings for sound and vibration
      playSound: isAlarm ? alarmSound : (isPopup ? popupSound : reminderSound),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      audioAttributesUsage: isAlarm
          ? AudioAttributesUsage.alarm
          : (isPopup && popupRingOnSilent
              ? AudioAttributesUsage.alarm
              : (!isAlarm && !isPopup && pushRingOnSilent
                  ? AudioAttributesUsage.alarm
                  : AudioAttributesUsage.notification)),
      color: config.popupColor ?? AppColors.primary,
      visibility: NotificationVisibility.public,
      // Note: ongoing:true blocks fullScreenIntent on Android 12+ — keep false
      ongoing: false,
      autoCancel: true,
      timeoutAfter: isAlarm ? null : const Duration(minutes: 1).inMilliseconds,
      additionalFlags: isAlarm ? Int32List.fromList(<int>[4]) : null,
      ticker: isAlarm ? title : null,
      channelShowBadge: true,
      actions: filteredActions,
    );

    // iOS notification respects playSound flag - force true for all types
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true, // Force sound for all notification types
      categoryIdentifier: 'reminder_category',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Build enriched payload with notification type info for routing
    final enrichedPayload = _buildEnrichedPayload(
      originalPayload: payload,
      title: title,
      body: config.notificationBody ?? '',
      notifType: isAlarm ? 'alarm' : (isPopup ? 'popup' : 'push'),
      id: id,
      snoozeMinutes: config.snoozeMinutes,
    );

    final notifTypeLabel = isAlarm ? 'alarm' : (isPopup ? 'popup' : 'push');
    final channelId = isAlarm
        ? 'alarm_channel_v$version'
        : (isPopup ? 'popup_channel_v$version' : 'reminder_channel_v$version');
    debugPrint(
      'NotificationService: scheduling $notifTypeLabel id=$id '
      'channel=$channelId fireTime=${time.toIso8601String()} '
      'fullScreenIntent=${isAlarm || isPopup}',
    );

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        config.notificationBody ?? 'Quartzo Reminder',
        tz.TZDateTime.from(time, tz.local),
        details,
        androidScheduleMode: isAlarm
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: enrichedPayload,
      );
      debugPrint('NotificationService: zonedSchedule OK id=$id');
    } catch (e) {
      debugPrint('NotificationService: failed exact zonedSchedule id=$id: $e');
      try {
        await _notifications.zonedSchedule(
          id,
          title,
          config.notificationBody ?? 'Quartzo Reminder',
          tz.TZDateTime.from(time, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: enrichedPayload,
        );
        debugPrint('NotificationService: zonedSchedule inexact OK id=$id');
      } catch (e2) {
        debugPrint('NotificationService: failed ALL schedules id=$id: $e2');
      }
    }

    // ── Foreground timer: auto-show alarm/popup UI when app is active ──
    // Android's fullScreenIntent only works when the screen is off or locked.
    // When the app is in the foreground, the notification just appears in the
    // notification shade. This timer fires at the same time and opens the
    // alarm/popup screen directly if the app is in the foreground.
    if (isAlarm || isPopup) {
      _scheduleForegroundTimer(
        id: id,
        fireTime: time,
        title: title,
        body: config.notificationBody ?? '',
        type: config.type,
        objectId: payload,
        snoozeMinutes: config.snoozeMinutes,
      );
    }
  }

  // ── Foreground timer logic ───────────────────────────────────────────

  void _scheduleForegroundTimer({
    required int id,
    required DateTime fireTime,
    required String title,
    required String body,
    required NotificationType type,
    String? objectId,
    int snoozeMinutes = 10,
  }) {
    _cancelForegroundTimer(id);

    final delay = fireTime.difference(DateTime.now());
    if (delay.isNegative) return;

    _foregroundEntries[id] = _ForegroundEntry(
      id: id,
      title: title,
      body: body,
      type: type,
      objectId: objectId,
      snoozeMinutes: snoozeMinutes,
    );

    _foregroundTimers[id] = Timer(delay, () => _fireForegroundTimer(id));
  }

  void _cancelForegroundTimer(int id) {
    _foregroundTimers[id]?.cancel();
    _foregroundTimers.remove(id);
    _foregroundEntries.remove(id);
  }

  void _fireForegroundTimer(int id) {
    final entry = _foregroundEntries.remove(id);
    _foregroundTimers.remove(id);
    
    if (entry == null) return;

    // Only show the screen if the app is in the foreground (navigator available)
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    // Cancel the system notification — we're showing the UI directly
    cancelNotification(id);

    final payload = _buildEnrichedPayload(
      originalPayload: entry.objectId,
      title: entry.title,
      body: entry.body,
      notifType: entry.type == NotificationType.alarm ? 'alarm' : 'popup',
      id: id,
      snoozeMinutes: entry.snoozeMinutes,
    );
    unawaited(
      _openNativeNotificationPopup(payload: payload, notificationId: id),
    );
  }

  String _buildEnrichedPayload({
    String? originalPayload,
    required String title,
    required String body,
    required String notifType,
    required int id,
    int snoozeMinutes = 10,
  }) {
    final base = originalPayload ?? '';
    final sep = base.contains('?') ? '&' : '?';
    final encodedTitle = Uri.encodeComponent(title);
    final encodedBody = Uri.encodeComponent(body);
    final encodedObjectId = Uri.encodeComponent(
      _objectIdFromPayload(base) ?? base,
    );
    return '$base${sep}ntype=$notifType&title=$encodedTitle&body=$encodedBody&snooze=$snoozeMinutes&id=$id${base.isNotEmpty ? '&oid=$encodedObjectId' : ''}';
  }

  static String? _objectIdFromPayload(String payload) {
    if (payload.isEmpty) return null;
    final uri = Uri.tryParse(payload);
    final explicit = uri?.queryParameters['id'] ?? uri?.queryParameters['oid'];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return payload.split('|').first.split('?').first;
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint(
        'NotificationService: skipping immediate notification on desktop platform',
      );
      return;
    }
    final settings = _container?.read(settingsProvider);
    final version = settings?.notificationChannelVersion ?? 1;

    final androidDetails = AndroidNotificationDetails(
      'immediate_channel_v$version',
      'Immediate Notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 200, 100, 200]),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _notifications.show(id, title, body, details, payload: payload);
  }

  // Legacy method alias
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await scheduleReminder(
      id: id,
      title: title,
      config: ReminderConfig(
        id: id.toString(),
        triggerTime: scheduledDate,
        type: NotificationType.push,
        notificationBody: body,
      ),
      payload: payload,
    );
  }

  Future<void> showQuickCaptureNotification() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint(
        'NotificationService: skipping quick capture notification on desktop platform',
      );
      return;
    }
    final settings = _container?.read(settingsProvider);
    final version = settings?.notificationChannelVersion ?? 1;

    final androidDetails = AndroidNotificationDetails(
      'quick_capture_channel_v$version',
      'Quick Capture',
      channelDescription: 'Add a journal entry or task from the lock screen',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: false,
      showWhen: false,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      actions: [
        AndroidNotificationAction(
          'quick_entry',
          'Entrada',
          showsUserInterface: true,
          inputs: [AndroidNotificationActionInput(label: 'Write entry')],
        ),
        AndroidNotificationAction(
          'quick_task',
          'Tarefa',
          showsUserInterface: true,
          inputs: [
            AndroidNotificationActionInput(label: 'Ex: Buy milk tomorrow 10am'),
          ],
        ),
        AndroidNotificationAction(
          'quick_habit',
          'Hábito',
          showsUserInterface: true,
          inputs: [AndroidNotificationActionInput(label: 'Nome do hábito')],
        ),
      ],
    );
    final details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      999,
      'Touch to add',
      'Journal entry or quick task',
      details,
    );
  }

  Future<void> scheduleWeeklyReviewNotifications() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint(
        'NotificationService: skipping weekly review notifications on desktop platform',
      );
      return;
    }
    await _scheduleWeeklyReviewNotification(
      id: 999991,
      weekday: DateTime.friday,
    );
    await _scheduleWeeklyReviewNotification(
      id: 999992,
      weekday: DateTime.sunday,
    );
  }

  Future<void> _scheduleWeeklyReviewNotification({
    required int id,
    required int weekday,
  }) async {
    const title = 'Weekly Review';
    const body =
        'Sua review da semana está pronta! Que tal dar uma olhada e planejar os próximos passos?';
    final fireTime = _nextWeekdayAt(weekday, hour: 20);
    final payload = _buildEnrichedPayload(
      originalPayload: 'action=weekly_review',
      title: title,
      body: body,
      notifType: 'push',
      id: id,
    );

    final settings = _container?.read(settingsProvider);
    final version = settings?.notificationChannelVersion ?? 1;

    final androidDetails = AndroidNotificationDetails(
      'reminder_channel_v$version',
      'Reminders',
      channelDescription: 'General task reminders',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 250, 150, 250]),
      actions: [
        const AndroidNotificationAction('done', 'Concluído'),
        const AndroidNotificationAction('snooze', 'Adiar'),
        const AndroidNotificationAction('dismiss', 'Dispensar'),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'reminder_category',
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(fireTime, tz.local),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  DateTime _nextWeekdayAt(int weekday, {required int hour}) {
    final now = DateTime.now();
    var date = now.add(Duration(days: (weekday - now.weekday + 7) % 7));
    date = DateTime(date.year, date.month, date.day, hour);
    if (!date.isAfter(now)) {
      date = date.add(const Duration(days: 7));
    }
    return date;
  }

  Future<void> cancelNotification(int id) async {
    _cancelForegroundTimer(id);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    await _notifications.cancel(id);
  }

  Future<void> clearNotificationCache() async {
    for (final timer in _foregroundTimers.values) {
      timer.cancel();
    }
    _foregroundTimers.clear();
    _foregroundEntries.clear();

    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      await _notifications.cancelAll();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_actions');
  }

  Future<void> cancelAllScheduled() async {
    for (final timer in _foregroundTimers.values) {
      timer.cancel();
    }
    _foregroundTimers.clear();
    _foregroundEntries.clear();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    await _notifications.cancelAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingPayloadFromNative();
    }
  }

  Future<void> _checkPendingPayloadFromNative() async {
    try {
      const channel = MethodChannel('com.productivity.Quartzo/settings');
      final payload = await channel.invokeMethod<String>(
        'getAndClearPendingPayload',
      );
      if (payload != null && payload.isNotEmpty) {
        debugPrint(
          'NotificationService: found pending payload from native: $payload',
        );
        final response = NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: payload,
          id: _extractNotificationId(payload),
        );
        _handleNotificationResponse(response);
      }
    } catch (e) {
      debugPrint(
        'NotificationService: failed to check pending native payload: $e',
      );
    }
  }

  Future<void> _bringAppToForeground() async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel('com.productivity.Quartzo/settings');
      await channel.invokeMethod('bringAppToForeground');
    } catch (e) {
      debugPrint('NotificationService: bringAppToForeground failed: $e');
    }
  }

  Future<void> _openNativeNotificationPopup({
    required String payload,
    int? notificationId,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel('com.productivity.Quartzo/settings');
      await channel.invokeMethod('startNativeNotificationPopup', {
        'payload': payload,
        'notification_id':
            notificationId ?? _extractNotificationId(payload) ?? 0,
      });
    } catch (e) {
      debugPrint(
        'NotificationService: startNativeNotificationPopup failed: $e',
      );
    }
  }

  static int? _extractNotificationId(String payload) {
    final idStr = _extractField(payload, 'id');
    return idStr != null ? int.tryParse(idStr) : null;
  }
}

/// Internal data for a foreground-scheduled alarm/popup.
class _ForegroundEntry {
  final int id;
  final String title;
  final String body;
  final NotificationType type;
  final String? objectId;
  final int snoozeMinutes;

  const _ForegroundEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.objectId,
    this.snoozeMinutes = 10,
  });
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final timezoneInfo = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
  await NotificationService._handleNotificationResponse(response);
}
