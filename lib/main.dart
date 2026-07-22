import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:home_widget/home_widget.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:window_manager/window_manager.dart';
import 'package:uuid/uuid.dart';

import 'ui/theme.dart';
import 'models/task_model.dart';
import 'models/habit_model.dart';
import 'models/template_model.dart';
import 'models/content_object.dart';
import 'models/shopping_list_model.dart' as shopping_list_model;
import 'providers/vault_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/widget_sync_provider.dart';
import 'services/sync_manager.dart';
import 'services/crash_report_service.dart';
import 'services/notification_service.dart';
import 'services/resource_metadata_service.dart';
import 'services/widget_service.dart';
import 'services/permission_service.dart';
import 'services/pomodoro_bg_service.dart';

import 'ui/shell/app_shell.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/timeline_screen.dart';
import 'ui/screens/journal_screen.dart';
import 'ui/screens/planner_screen.dart';
import 'ui/forms/create_entry_form.dart';
import 'ui/forms/create_task_form.dart';
import 'ui/forms/create_habit_form.dart';
import 'ui/forms/create_goal_form.dart';
import 'ui/forms/create_event_form.dart';
import 'ui/forms/create_reminder_form.dart';
import 'ui/forms/create_project_form.dart';
import 'ui/screens/shopping_list_screen.dart';
import 'ui/forms/create_note_form.dart';
import 'ui/forms/create_resource_form.dart';
import 'ui/forms/create_template_form.dart';
import 'ui/screens/organize_screen.dart';
import 'ui/screens/more_screen.dart';
import 'ui/screens/pomodoro_screen.dart';
import 'ui/screens/trackers_screen.dart';
import 'ui/screens/habits_screen.dart';
import 'ui/screens/people_screen.dart';
import 'ui/screens/resources_screen.dart';
import 'ui/screens/notes_screen.dart';
import 'ui/screens/goals_screen.dart';
import 'ui/screens/archive_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/reminders_screen.dart';
import 'ui/screens/deleted_files_screen.dart';
import 'ui/screens/statistics_screen.dart';
import 'ui/screens/inbox_screen.dart';
import 'ui/screens/social_screen.dart';
import 'ui/screens/sync_conflicts_screen.dart';
import 'ui/screens/day_theme_screen.dart';
import 'ui/screens/week_timeline_screen.dart';
import 'ui/screens/universal_detail_view.dart';
import 'ui/screens/organizer_detail_screen.dart';
import 'ui/screens/overdue_detail_screen.dart';
import 'ui/screens/tasks_screen.dart';
import 'ui/screens/values_screen.dart';
import 'ui/screens/routines_screen.dart';
import 'ui/screens/systems_screen.dart';
import 'ui/forms/create_social_post_form.dart';
import 'ui/widgets/pomodoro_floating_clock.dart';
import 'ui/widgets/notification_popup_overlay.dart';
import 'features/overdue/replanning/replanning_screen.dart';

@pragma('vm:entry-point')
Future<void> homeWidgetInteractiveCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  debugPrint('[WidgetCallback] received: $uri');
  if (uri == null) return;

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  try {
    await _handleWidgetToggleUri(uri, container);
  } catch (e) {
    debugPrint('homeWidgetInteractiveCallback failed: $e');
  } finally {
    container.dispose();
  }
}

Future<void> _handleWidgetToggleUri(
  Uri uri,
  ProviderContainer container,
) async {
  if (uri.host != 'widget-toggle') return;
  final prefs = container.read(sharedPreferencesProvider);
  final type = uri.queryParameters['type'];
  final objectId = uri.queryParameters['id'];
  final date =
      DateTime.tryParse(uri.queryParameters['date'] ?? '') ?? DateTime.now();
  final slotIndex = int.tryParse(uri.queryParameters['slot'] ?? '');
  debugPrint(
    '[WidgetCallback] type=$type objectId=$objectId date=$date slot=$slotIndex',
  );

  if (type == 'calendar_mode') {
    final mode = uri.queryParameters['mode'];
    if (mode == 'day' || mode == 'week' || mode == 'month') {
      await container
          .read(settingsProvider.notifier)
          .updateWidgetCalendarSettings(type: mode);
      await prefs.setInt('calendarWidgetOffset', 0);
      await forceWidgetSync(container);
      debugPrint('[WidgetCallback] calendar mode updated: $mode');
    }
    return;
  }

  if (type == 'calendar_offset') {
    final offset = int.tryParse(uri.queryParameters['offset'] ?? '') ?? 0;
    final currentOffset = prefs.getInt('calendarWidgetOffset') ?? 0;
    await prefs.setInt('calendarWidgetOffset', currentOffset + offset);
    await forceWidgetSync(container);
    debugPrint(
      '[WidgetCallback] calendar offset updated: ${currentOffset + offset}',
    );
    return;
  }

  if (type == 'refresh_widgets') {
    await forceWidgetSync(container);
    debugPrint('[WidgetCallback] widgets refreshed');
    return;
  }

  if (type == 'quick_add') {
    final title = uri.queryParameters['title'];
    if (title != null && title.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final newTask = Task(
        id: const Uuid().v4(),
        title: title,
        createdAt: now,
        updatedAt: now,
        stage: TaskStage.todo,
        endDate: today,
        allDay: true,
      );
      await container.read(vaultProvider.notifier).createObject(newTask);
      await forceWidgetSync(container);
      debugPrint('[WidgetCallback] quick add task: $title');
    }
    return;
  }

  if (type == 'shopping_add') {
    final name = uri.queryParameters['name'];
    if (name != null && name.isNotEmpty) {
      // Find first active shopping list or create default
      final objects = await container.read(allObjectsProvider.future);
      final shoppingLists = objects
          .whereType<shopping_list_model.ShoppingList>()
          .where((list) => !list.archived)
          .toList();

      shopping_list_model.ShoppingList targetList;
      if (shoppingLists.isEmpty) {
        // Create default shopping list
        targetList = shopping_list_model.ShoppingList(
          id: const Uuid().v4(),
          title: 'Lista de Mercado',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          archived: false,
          items: [],
        );
        await container.read(vaultProvider.notifier).createObject(targetList);
      } else {
        targetList = shoppingLists.first;
      }

      // Add item to list
      final newItem = shopping_list_model.ShoppingItem(
        id: const Uuid().v4(),
        name: name,
        status: shopping_list_model.ShoppingItemStatus.active,
      );
      final updatedList = targetList.copyWith(
        items: [...targetList.items, newItem],
        updatedAt: DateTime.now(),
      );
      await container.read(vaultProvider.notifier).updateObject(updatedList);
      await forceWidgetSync(container);
      debugPrint('[WidgetCallback] shopping add item: $name');
    }
    return;
  }

  if (objectId == null || objectId.isEmpty) return;

  final objects = await container.read(allObjectsProvider.future);
  final object = objects
      .where((candidate) => candidate.id == objectId)
      .firstOrNull;
  if (type == 'task' && object is Task) {
    await container
        .read(vaultProvider.notifier)
        .updateObject(
          object.copyWith(
            stage: object.isCompleted ? TaskStage.todo : TaskStage.finalized,
          ),
        );
    await forceWidgetSync(container);
    debugPrint('[WidgetCallback] task toggled: $objectId');
  } else if (type == 'habit' && object is Habit) {
    await container
        .read(habitsProvider.notifier)
        .toggleHabit(object, date, slotIndex: slotIndex);
    await forceWidgetSync(container);
    debugPrint('[WidgetCallback] habit toggled: $objectId');
  }
  await WidgetService.refreshAllWidgets();
}

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('pt_BR');
      if (Platform.isAndroid || Platform.isIOS) {
        await HomeWidget.registerInteractivityCallback(
          homeWidgetInteractiveCallback,
        );
      }
      // #region agent log
      await _emitAgentDebugLog(
        location: 'main.dart:main',
        hypothesisId: 'H1',
        message: 'main_enter',
        data: {'platform': Platform.operatingSystem},
      );
      // #endregion

      if (Platform.isWindows || Platform.isLinux) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // Load SharedPreferences BEFORE runApp so SettingsNotifier has real values
      // from the very first build â€” eliminates the double-build of allObjectsProvider.
      final prefs = await SharedPreferences.getInstance();

      // Initialize CrashReportService
      await CrashReportService.instance.init(
        vaultPath: prefs.getString('vaultPath'),
      );

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await windowManager.ensureInitialized();
        const windowOptions = WindowOptions(
          minimumSize: Size(900, 600),
          size: Size(1280, 820),
          center: true,
          title: 'Quartzo',
          titleBarStyle: TitleBarStyle.normal,
        );
        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: BootstrapApp(container: container),
        ),
      );
    },
    (error, stack) {
      debugPrint('[ZonedGuarded] Unhandled error: $error');
      CrashReportService.instance.logEvent(
        'zone_error ${error.runtimeType}: $error',
      );
      // Note: PlatformDispatcher.onError handles most async errors;
      // this catches synchronous top-level errors that slip through.
    },
  );
}

class BootstrapApp extends StatefulWidget {
  final ProviderContainer container;
  const BootstrapApp({super.key, required this.container});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final Future<void> _initFuture = _initApp(widget.container);
  late final AppLifecycleListener _lifecycleListener;
  StreamSubscription<List<SharedMediaFile>>? _shareIntentSub;
  Timer? _midnightTimer;
  DateTime _lastCheckedDate = DateTime.now();
  String? _pendingSharedUrl;
  String? _lastProcessedSharedText;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        debugPrint('[AppLifecycle] Resumed - refreshing widgets');
        // Debounce widget sync to avoid cascade with sync
        Future.delayed(const Duration(seconds: 2), () {
          unawaited(forceWidgetSync(widget.container));
        });
        unawaited(_checkPendingSharedTextFromNative());
        unawaited(_checkPendingWidgetUriFromNative());
        // 1.4 — check person contacts on resume (moved out of PeopleNotifier.build)
        Future.delayed(const Duration(seconds: 1), () {
          widget.container
              .read(peopleProvider.notifier)
              .checkPersonContactsNow();
        });
      },
    );
    _initShareIntentHandling();
    unawaited(_checkPendingWidgetUriFromNative());

    _midnightTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      final currentDate = DateTime(now.year, now.month, now.day);
      final lastDate = DateTime(
        _lastCheckedDate.year,
        _lastCheckedDate.month,
        _lastCheckedDate.day,
      );
      if (currentDate != lastDate) {
        debugPrint(
          '[MidnightTimer] Day changed from $lastDate to $currentDate. '
          'Invalidating date-dependent providers.',
        );
        _lastCheckedDate = now;
        // Invalidate only date-dependent providers instead of entire vault
        final todayStr = currentDate.toIso8601String().split('T').first;
        widget.container.invalidate(dailyNoteDataProvider(todayStr));
        widget.container.invalidate(vaultProvider); // Still needed for habit streaks, overdue tasks, etc.
        unawaited(forceWidgetSync(widget.container));
      }
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _shareIntentSub?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _initShareIntentHandling() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _shareIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (error) => debugPrint('Share intent stream failed: $error'),
    );
    unawaited(
      ReceiveSharingIntent.instance
          .getInitialMedia()
          .then(_handleSharedMedia)
          .catchError(
            (error) => debugPrint('Initial share intent failed: $error'),
          ),
    );
    unawaited(_checkPendingSharedTextFromNative());
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> files) async {
    final url = _extractSharedUrl(files);
    if (url == null) {
      debugPrint('Share intent ignored: no http(s) URL found.');
      return;
    }
    await ReceiveSharingIntent.instance.reset();
    _openSharedUrl(url);
  }

  String? _extractSharedUrl(List<SharedMediaFile> files) {
    for (final file in files) {
      final candidates = [file.path, file.message].whereType<String>();
      for (final candidate in candidates) {
        final url = _extractUrlFromText(candidate);
        if (url != null) return url;
      }
    }
    return null;
  }

  Future<void> _checkPendingSharedTextFromNative() async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel('com.productivity.Quartzo/settings');
      final text = await channel.invokeMethod<String>('getAndClearSharedText');
      if (text == null || text.trim().isEmpty) return;
      if (text == _lastProcessedSharedText) {
        debugPrint('Skipping duplicate shared text: $text');
        return;
      }
      _lastProcessedSharedText = text;
      final url = _extractUrlFromText(text);
      if (url != null) {
        _openSharedUrl(url);
      }
    } catch (error) {
      debugPrint('Native share intent check failed: $error');
    }
  }

  Future<void> _checkPendingWidgetUriFromNative() async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel('com.productivity.Quartzo/settings');
      final rawUri = await channel.invokeMethod<String>(
        'getAndClearPendingWidgetUri',
      );
      if (rawUri == null || rawUri.isEmpty) return;
      final uri = Uri.tryParse(rawUri);
      if (uri == null) return;
      await _handleWidgetToggleUri(uri, widget.container);
    } catch (error) {
      debugPrint('Native widget uri check failed: $error');
    }
  }

  String? _extractUrlFromText(String? text) {
    if (text == null) return null;
    final match = RegExp(r'https?://[^\s<>"\]]+').firstMatch(text);
    return match?.group(0)?.trim().replaceFirst(RegExp(r'[),.;]+$'), '');
  }

  void _openSharedUrl(String url) {
    _pendingSharedUrl = url;
    _tryOpenPendingSharedUrl();
  }

  void _tryOpenPendingSharedUrl([int attempt = 0]) {
    final url = _pendingSharedUrl;
    if (url == null) return;

    final navigator = _rootNavigatorKey.currentState;
    if (navigator == null) {
      if (attempt < 20) {
        Future.delayed(
          const Duration(milliseconds: 250),
          () => _tryOpenPendingSharedUrl(attempt + 1),
        );
      }
      return;
    }

    _pendingSharedUrl = null;
    if (ResourceMetadataService.isResourceUrl(url)) {
      navigator.push(
        MaterialPageRoute(builder: (_) => CreateResourceForm(initialUrl: url)),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute(builder: (_) => CreateSocialPostForm(initialUrl: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // #region agent log
    _emitAgentDebugLog(
      location: 'main.dart:BootstrapApp.build',
      hypothesisId: 'H4',
      message: 'bootstrap_build',
      data: const {},
    );
    // #endregion

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const MyApp();
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getLightTheme(AppColors.primary),
          darkTheme: AppTheme.getDarkTheme(AppColors.primary),
          home: Scaffold(
            backgroundColor: AppColors.darkBackground,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/app_icon.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _initApp(ProviderContainer container) async {
  Future<void> step(
    String name,
    Future<void> Function() fn, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      await fn().timeout(timeout);
    } catch (e) {
      debugPrint('Startup init failed: $name: $e');
    }
  }

  // Critical path: only what's needed before the UI can appear.
  // Permissions are NOT blocking — they'll be requested after the app renders.
  // vault_load removed — vault now loads in background after UI appears.
  await Future.wait([
    step(
      'sync_queue_init',
      () => container.read(syncQueueServiceProvider).init(),
    ),
    step('notifications_init', () async {
      final service = NotificationService();
      service.setProviderContainer(container);
      service.setNavigatorKey(_rootNavigatorKey);
      await service.init();
    }, timeout: const Duration(seconds: 10)),
    // Initialize home_widget bridge for native home screen widgets
    step(
      'widget_service_init',
      () => WidgetService.init(),
      timeout: const Duration(seconds: 5),
    ),
  ]);

  // Kick off vault load independently from HomeScreen. Home used to watch a
  // large dashboard tree; after the dashboard was simplified this explicit read
  // keeps the vault scan alive even if no first-screen widget needs objects yet.
  unawaited(
    container
        .read(allObjectsProvider.future)
        .then((objects) async {
          debugPrint('[Startup] Vault loaded: ${objects.length} objects.');
          
          // Start sync AFTER vault loads to avoid conflicts and reduce startup load
          try {
            container.read(syncManagerProvider).start();
            debugPrint('[Startup] Sync manager started after vault load');
          } catch (e) {
            debugPrint('Startup init failed: sync_manager_start: $e');
          }
          
          Future.delayed(const Duration(seconds: 3), () {
            container.read(peopleProvider.notifier).checkPersonContactsNow();
          });
        })
        .catchError((Object e, StackTrace st) {
          debugPrint('[Startup] Vault load failed: $e\n$st');
        }),
  );

  // Update CrashReportService with the real vault path now that vault has loaded
  try {
    final prefs = container.read(sharedPreferencesProvider);
    final vp = prefs.getString('vaultPath') ?? '';
    if (vp.isNotEmpty) {
      CrashReportService.instance.setVaultPath(vp);
      CrashReportService.instance.logEvent('vault_loaded');
    }
  } catch (e) {
    debugPrint('CrashReport: could not update vault path: $e');
  }

  // Register foreground task callback (sync only)
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      FlutterForegroundTask.addTaskDataCallback((data) {
        // DISABLED: Sync causing crashes
        debugPrint('[Main] Foreground task sync disabled to prevent crashes');
        // if (data is Map && data['action'] == 'sync_tick') {
        //   container.read(syncManagerProvider).performSync(debounce: true);
        // }
      });
    } catch (e) {
      debugPrint('Startup init failed: foreground_task_callback: $e');
    }
  }

  // Non-critical: run in background after UI is shown
  Future.microtask(() async {
    final notificationService = NotificationService();
    notificationService.setProviderContainer(container);
    notificationService.setNavigatorKey(_rootNavigatorKey);

    // Request permissions after app is visible (avoids blocking splash)
    await PermissionService.requestAllPermissions();
    await notificationService.scheduleWeeklyReviewNotifications();

    // Defer notification cache purge and reminder rescheduling until after vault loads
    // to reduce startup overhead
    try {
      final prefs = await SharedPreferences.getInstance();
      const purgeKey = 'notification_cache_purged_late_duplicates_20260525';
      if (prefs.getBool(purgeKey) != true) {
        await notificationService.clearNotificationCache();
        await prefs.setBool(purgeKey, true);
        // Wait for vault to load before rescheduling reminders
        await container.read(allObjectsProvider.future);
        await container
            .read(vaultProvider.notifier)
            .rescheduleAllObjectReminders();
        debugPrint('Notification cache purge completed.');
      }
    } catch (e) {
      debugPrint('Startup init failed: notification_cache_purge: $e');
    }

    // Check for expired pacts
    try {
      final habits = container.read(habitsProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiredPacts = habits
          .where(
            (h) =>
                h.habitMode == HabitMode.pact &&
                h.status == HabitStatus.active &&
                h.endsAt != null &&
                h.endsAt!.isBefore(today) &&
                h.pactOutcome == null,
          )
          .toList();

      for (final pact in expiredPacts) {
        debugPrint('[PactChecker] Found expired pact: ${pact.title}');
        await notificationService.showImmediateNotification(
          id: pact.id.hashCode,
          title: 'Pacto Expirado: ${pact.displayTitle}',
          body: 'Seu pacto expirou e precisa de revisão (Steering Sheet).',
          payload: 'steering_sheet?id=${pact.id}',
        );
      }
    } catch (e) {
      debugPrint('Startup init failed: expired_pact_checker: $e');
    }

    // Reset Sleep In Tomorrow setting if the target date has arrived or passed
    try {
      final settings = container.read(settingsProvider);
      if (settings.sleepInTomorrow && settings.sleepInDate.isNotEmpty) {
        final todayStr = DateTime.now().toIso8601String().split('T').first;
        if (todayStr.compareTo(settings.sleepInDate) >= 0) {
          await container
              .read(settingsProvider.notifier)
              .updateSleepInTomorrow(false);
          await container.read(vaultProvider.notifier).rescheduleAllHabits();
        }
      }
    } catch (e) {
      debugPrint('Startup init failed: reset_sleep_in_tomorrow: $e');
    }

    // Process any tapped notification actions
    try {
      await container
          .read(vaultProvider.notifier)
          .processPendingNotificationActions();
    } catch (e) {
      debugPrint(
        'Startup init failed: process_pending_notification_actions: $e',
      );
    }

    // Persistent quick-capture notification
    try {
      await NotificationService().showQuickCaptureNotification();
    } catch (e) {
      debugPrint('Startup init failed: quick_capture_notification: $e');
    }

    // Quick Actions shortcuts
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        const QuickActions quickActions = QuickActions();
        quickActions.initialize((shortcutType) {
          if (shortcutType == 'new_entry') {
            _rootNavigatorKey.currentState?.pushNamed('/?action=new_entry');
          } else if (shortcutType == 'new_task') {
            _rootNavigatorKey.currentState?.pushNamed('/?action=new_task');
          } else if (shortcutType == 'new_habit') {
            _rootNavigatorKey.currentState?.pushNamed('/?action=new_habit');
          }
        });
        quickActions.setShortcutItems(<ShortcutItem>[
          const ShortcutItem(
            type: 'new_entry',
            localizedTitle: 'New Journal',
            icon: 'action_entry',
          ),
          const ShortcutItem(
            type: 'new_task',
            localizedTitle: 'New Task',
            icon: 'action_task',
          ),
          const ShortcutItem(
            type: 'new_habit',
            localizedTitle: 'New Habit',
            icon: 'action_habit',
          ),
        ]);
      } catch (e) {
        debugPrint('Startup init failed: quick_actions_init: $e');
      }
    }

    // Pomodoro background service
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        PomodoroBackgroundService.init();
      } catch (e) {
        debugPrint('Startup init failed: pomodoro_bg_init: $e');
      }
    }
  });
}

Future<void> _emitAgentDebugLog({
  required String location,
  required String hypothesisId,
  required String message,
  required Map<String, Object?> data,
  String runId = 'run1',
}) async {
  debugPrint('[$runId][$hypothesisId] $location: $message $data');
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// NavigatorObserver that keeps CrashReportService updated with the current route.
class _CrashRouteObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    final name =
        route?.settings.name ?? route?.runtimeType.toString() ?? 'unknown';
    CrashReportService.instance.setCurrentRoute(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _track(newRoute);
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    observers: [_CrashRouteObserver()],
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return NotificationPopupOverlay(child: AppShell(child: child));
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/shopping',
            builder: (context, state) => const ShoppingListScreen(),
          ),
          GoRoute(
            path: '/timeline',
            builder: (context, state) => const TimelineScreen(),
          ),
          GoRoute(
            path: '/journal',
            builder: (context, state) => const JournalScreen(),
          ),
          GoRoute(
            path: '/planner',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return PlannerScreen(
                initialDate: extra?['initialDate'] as DateTime?,
                showPopup: extra?['showPopup'] as bool? ?? false,
              );
            },
          ),
          GoRoute(
            path: '/planner/day/:date',
            builder: (context, state) {
              final rawDate = state.pathParameters['date'];
              return PlannerScreen(
                initialDate: rawDate == null
                    ? null
                    : DateTime.tryParse(rawDate),
              );
            },
          ),
          GoRoute(
            path: '/week',
            builder: (context, state) => const WeekTimelineScreen(),
          ),
          GoRoute(
            path: '/create/entry',
            builder: (context, state) => const CreateEntryForm(),
          ),
          GoRoute(
            path: '/create/task',
            builder: (context, state) => const CreateTaskForm(),
          ),
          GoRoute(
            path: '/create/habit',
            builder: (context, state) => const CreateHabitForm(),
          ),
          GoRoute(
            path: '/create/goal',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CreateGoalForm(
                initialTitle: extra?['initialTitle'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/create/event',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CreateEventForm(
                initialTitle: extra?['initialTitle'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/create/reminder',
            builder: (context, state) => const CreateReminderForm(),
          ),
          GoRoute(
            path: '/create-project',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CreateProjectForm(
                initialTitle: extra?['initialTitle'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/create/note',
            builder: (context, state) => const CreateNoteForm(),
          ),
          GoRoute(
            path: '/create/template',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CreateTemplateForm(
                existingTemplate:
                    extra?['existingTemplate'] as TemplateDefinition?,
                initialType: extra?['initialType'] as String?,
                initialBody: extra?['initialBody'] as String?,
              );
            },
          ),

          GoRoute(
            path: '/organize',
            builder: (context, state) => const OrganizeScreen(),
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const MoreScreen(),
          ),
          GoRoute(
            path: '/pomodoro',
            builder: (context, state) => const PomodoroScreen(),
          ),
          GoRoute(
            path: '/trackers',
            builder: (context, state) => const TrackersScreen(),
          ),
          GoRoute(
            path: '/habits',
            builder: (context, state) => const HabitsScreen(),
          ),
          GoRoute(
            path: '/people',
            builder: (context, state) => const PeopleScreen(),
          ),
          GoRoute(
            path: '/resources',
            builder: (context, state) => const ResourcesScreen(),
          ),
          GoRoute(
            path: '/notes',
            builder: (context, state) => const NotesScreen(),
          ),
          GoRoute(
            path: '/goals',
            builder: (context, state) => const GoalsScreen(),
          ),
          GoRoute(
            path: '/archive',
            builder: (context, state) => const ArchiveScreen(),
          ),

          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/reminders',
            builder: (context, state) => const RemindersScreen(),
          ),
          GoRoute(
            path: '/deleted_files',
            builder: (context, state) => const DeletedFilesScreen(),
          ),
          GoRoute(
            path: '/statistics',
            builder: (context, state) => const StatisticsScreen(),
          ),
          GoRoute(
            path: '/inbox',
            builder: (context, state) => const InboxScreen(),
          ),
          GoRoute(
            path: '/social',
            builder: (context, state) => const SocialScreen(),
          ),
          GoRoute(
            path: '/sync-conflicts',
            builder: (context, state) => const SyncConflictsScreen(),
          ),
          GoRoute(
            path: '/day-themes',
            builder: (context, state) => const DayThemeScreen(),
          ),
          GoRoute(
            path: '/time-blocks',
            builder: (context, state) => const DayThemeScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/values',
            builder: (context, state) => const ValuesScreen(),
          ),
          GoRoute(
            path: '/routines',
            builder: (context, state) => const RoutinesScreen(),
          ),
          GoRoute(
            path: '/systems',
            builder: (context, state) => const SystemsScreen(),
          ),
          GoRoute(
            path: '/replanning',
            builder: (context, state) => const ReplanningScreen(),
          ),
          GoRoute(
            path: '/overdue',
            builder: (context, state) => const OverdueDetailScreen(),
          ),
          GoRoute(
            path: '/detail/:id',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              // If object is passed directly, skip the resolver lookup
              final directObject = extra?['object'] as ContentObject?;
              if (directObject != null) {
                return UniversalDetailView(
                  object: directObject,
                  searchQuery: extra?['searchQuery'] as String?,
                  searchSnippet: extra?['searchSnippet'] as String?,
                );
              }
              return _ObjectDetailResolver(
                id: state.pathParameters['id']!,
                searchQuery: extra?['searchQuery'] as String?,
                searchSnippet: extra?['searchSnippet'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/organizer/:id',
            builder: (context, state) =>
                _OrganizerDetailResolver(id: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeBundle = ref.watch(themeProvider);
    // Initialize widget sync listener
    ref.watch(widgetSyncProvider);

    return WithForegroundTask(
      child: MaterialApp.router(
        title: 'Quartzo',
        debugShowCheckedModeBanner: false,
        theme: themeBundle.lightTheme,
        darkTheme: themeBundle.darkTheme,
        themeMode: themeBundle.themeMode,
        routerConfig: router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', '')],
        builder: (context, child) =>
            PomodoroFloatingClock(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

class _ObjectDetailResolver extends ConsumerWidget {
  final String id;
  final String? searchQuery;
  final String? searchSnippet;
  const _ObjectDetailResolver({
    required this.id,
    this.searchQuery,
    this.searchSnippet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectsAsync = ref.watch(allObjectsProvider);
    return objectsAsync.when(
      data: (objects) {
        final object = objects
            .where((o) => o.id == id || o.slug == id)
            .firstOrNull;
        if (object == null) {
          return const Scaffold(body: Center(child: Text('Object not found')));
        }
        return UniversalDetailView(
          object: object,
          searchQuery: searchQuery,
          searchSnippet: searchSnippet,
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _OrganizerDetailResolver extends ConsumerWidget {
  final String id;
  const _OrganizerDetailResolver({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizers = ref.watch(organizersProvider);
    final organizer = organizers
        .where((o) => o.id == id || o.slug == id)
        .firstOrNull;
    if (organizer == null) {
      return const Scaffold(body: Center(child: Text('Organizer not found')));
    }
    return OrganizerDetailScreen(organizer: organizer);
  }
}
