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
import '../ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vault_provider.dart';
import '../providers/notification_overlay_provider.dart';
import '../ui/screens/alarm_screen.dart';
import '../ui/screens/popup_notification_screen.dart';
import 'package:flutter/services.dart';
import 'permission_service.dart';

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
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final timeZoneName = timeZoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

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
    await _createNotificationChannels();

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

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
    final title = _extractField(payload, 'title') ?? 'Reminder';
    final body = _extractField(payload, 'body') ?? '';
    final objectId = _extractField(payload, 'oid');

    // Cancel any foreground timer for this ID to avoid double-show
    if (response.id != null) {
      _cancelForegroundTimer(response.id!);
    }

    // Delay slightly to let navigator initialize
    Future.delayed(const Duration(milliseconds: 600), () {
      if (notifType == 'alarm') {
        showAlarmScreen(
          title: Uri.decodeComponent(title),
          body: Uri.decodeComponent(body),
          type: _parseAlarmType(_extractField(payload, 'subtype')),
          objectId: objectId,
          notificationId: response.id,
        );
      } else if (notifType == 'popup') {
        showPopupScreen(
          title: Uri.decodeComponent(title),
          body: Uri.decodeComponent(body),
          type: _parsePopupScreenType(_extractField(payload, 'subtype')),
          objectId: objectId,
          notificationId: response.id,
        );
      }
    });
  }

  static String? _extractField(String payload, String key) {
    final regex = RegExp('$key=([^&]*)');
    final match = regex.firstMatch(payload);
    return match?.group(1);
  }

  static String _extractNotifType(String payload) {
    return _extractField(payload, 'ntype') ?? 'push';
  }

  static AlarmType _parseAlarmType(String? subtype) {
    switch (subtype) {
      case 'task':
        return AlarmType.task;
      case 'event':
        return AlarmType.event;
      case 'reminder':
        return AlarmType.reminder;
      default:
        return AlarmType.alarm;
    }
  }

  static PopupScreenType _parsePopupScreenType(String? subtype) {
    switch (subtype) {
      case 'task':
        return PopupScreenType.task;
      case 'event':
        return PopupScreenType.event;
      case 'habit':
        return PopupScreenType.habit;
      default:
        return PopupScreenType.reminder;
    }
  }

  Future<void> _createNotificationChannels() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    // Alarms Channel
    const alarmChannel = AndroidNotificationChannel(
      'alarm_channel_v4',
      'Alarms',
      description: 'High priority intrusive alarms',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    // Popups Channel
    const popupChannel = AndroidNotificationChannel(
      'popup_channel_v4',
      'Popups',
      description: 'Important visual popups',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    // Reminders Channel
    const reminderChannel = AndroidNotificationChannel(
      'reminder_channel_v2',
      'Reminders',
      description: 'General task reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Immediate Channel
    const immediateChannel = AndroidNotificationChannel(
      'immediate_channel_v2',
      'Immediate Notifications',
      description: 'Ongoing or immediate notifications',
      importance: Importance.low,
      playSound: false,
    );

    const quickCaptureChannel = AndroidNotificationChannel(
      'quick_capture_channel_v2',
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
      final notificationService = NotificationService();
      await notificationService.scheduleReminder(
        id: response.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
        title: response.payload ?? 'Snoozed Reminder',
        config: ReminderConfig(
          id: '${response.id}_snooze',
          triggerTime: DateTime.now().add(
            Duration(minutes: _snoozeMinutesFromPayload(response.payload)),
          ),
          type: NotificationType.push,
          notificationBody: 'Snoozed: ${response.payload ?? "Reminder"}',
        ),
        payload: response.payload,
      );
    }
    if (actionId == 'dismiss') {
      if (response.id != null) {
        await _instance.cancelNotification(response.id!);
      }
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
        await _instance.showQuickCaptureNotification();
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

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required ReminderConfig config,
    DateTime? triggerTime,
    String? payload,
  }) async {
    final time = triggerTime ?? config.triggerTime;
    if (time == null || time.isBefore(DateTime.now())) return;

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

    final androidDetails = AndroidNotificationDetails(
      isAlarm
          ? 'alarm_channel_v4'
          : (isPopup ? 'popup_channel_v4' : 'reminder_channel_v2'),
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
      // Use user-configurable sound and vibration settings
      playSound: isAlarm ? true : config.playSound,
      enableVibration: isAlarm || config.vibrate,
      vibrationPattern: (isAlarm || config.vibrate)
          ? Int64List.fromList(const <int>[0, 700, 350, 700])
          : null,
      audioAttributesUsage: isAlarm || isPopup
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      color: config.popupColor ?? AppColors.primary,
      visibility: NotificationVisibility.public,
      ongoing: isAlarm || isPopup,
      autoCancel: !(isAlarm || isPopup),
      timeoutAfter: null,
      additionalFlags: isAlarm ? Int32List.fromList(<int>[4]) : null,
      channelShowBadge: true,
      actions: [
        const AndroidNotificationAction('done', 'Concluído'),
        const AndroidNotificationAction('snooze', 'Adiar'),
        const AndroidNotificationAction('dismiss', 'Dispensar'),
      ],
    );

    // iOS notification respects playSound flag
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: config.playSound,
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

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        config.notificationBody ?? 'Citrine Reminder',
        tz.TZDateTime.from(time, tz.local),
        details,
        androidScheduleMode: isAlarm
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: enrichedPayload,
      );
    } catch (e) {
      debugPrint('Failed exact zonedSchedule: $e');
      try {
        await _notifications.zonedSchedule(
          id,
          title,
          config.notificationBody ?? 'Citrine Reminder',
          tz.TZDateTime.from(time, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: enrichedPayload,
        );
      } catch (e2) {
        debugPrint('Failed inexact zonedSchedule: $e2');
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

    // Bring the app to the foreground if in background
    _bringAppToForeground();

    if (entry.type == NotificationType.alarm) {
      showAlarmScreen(
        title: entry.title,
        body: entry.body,
        type: AlarmType.alarm,
        objectId: entry.objectId,
        notificationId: id,
      );
    } else if (entry.type == NotificationType.popup) {
      showPopupScreen(
        title: entry.title,
        body: entry.body,
        type: PopupScreenType.reminder,
        objectId: entry.objectId,
        notificationId: id,
      );
    }
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
    const androidDetails = AndroidNotificationDetails(
      'immediate_channel_v2',
      'Immediate Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
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
    const androidDetails = AndroidNotificationDetails(
      'quick_capture_channel_v2',
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
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      999,
      'Touch to add',
      'Journal entry or quick task',
      details,
    );
  }

  Future<void> scheduleWeeklyReviewNotifications() async {
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

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel_v2',
      'Reminders',
      channelDescription: 'General task reminders',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      actions: [
        AndroidNotificationAction('done', 'Concluído'),
        AndroidNotificationAction('snooze', 'Adiar'),
        AndroidNotificationAction('dismiss', 'Dispensar'),
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
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
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
    await _notifications.cancel(id);
  }

  Future<void> clearNotificationCache() async {
    for (final timer in _foregroundTimers.values) {
      timer.cancel();
    }
    _foregroundTimers.clear();
    _foregroundEntries.clear();

    await _notifications.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_actions');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingPayloadFromNative();
    }
  }

  Future<void> _checkPendingPayloadFromNative() async {
    try {
      const channel = MethodChannel('com.productivity.citrine/settings');
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
      const channel = MethodChannel('com.productivity.citrine/settings');
      await channel.invokeMethod('bringAppToForeground');
    } catch (e) {
      debugPrint('NotificationService: bringAppToForeground failed: $e');
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
  final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
  await NotificationService._handleNotificationResponse(response);
}
