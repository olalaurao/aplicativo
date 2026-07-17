// lib/providers/pomodoro_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../models/content_object.dart';
import '../models/pomodoro_session.dart';
import '../models/sync_action.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import '../models/project_model.dart';
import '../models/kpi_model.dart';
import '../models/shared_types.dart';
import '../models/relay_step.dart';
import '../services/notification_service.dart';
import 'vault_provider.dart';
import '../services/pomodoro_bg_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/markdown_parser.dart';
import '../services/widget_service.dart';
import 'package:intl/intl.dart';
import '../ui/theme.dart';

class PomodoroState {
  final bool isRunning;
  final int remainingSeconds;
  final int totalSeconds;
  final PomodoroType currentType;
  final List<PomodoroSession> history;
  final String? currentItemId;
  final String? currentItemTitle;
  final int completedSessions;
  final int sessionsToLongBreak;
  final int elapsedSeconds; // For stopwatch mode
  
  // Relay mode fields (RA-P1-4)
  final List<RelayStep>? relaySteps;
  final int currentRelayIndex;
  final bool isRelayMode;

  PomodoroState({
    this.isRunning = false,
    this.remainingSeconds = 1500, // 25 mins
    this.totalSeconds = 1500,
    this.currentType = PomodoroType.work,
    this.history = const [],
    this.currentItemId,
    this.currentItemTitle,
    this.completedSessions = 0,
    this.sessionsToLongBreak = 4,
    this.elapsedSeconds = 0, // For stopwatch mode
    this.relaySteps,
    this.currentRelayIndex = 0,
    this.isRelayMode = false,
  });

  PomodoroState copyWith({
    bool? isRunning,
    int? remainingSeconds,
    int? totalSeconds,
    PomodoroType? currentType,
    List<PomodoroSession>? history,
    String? currentItemId,
    String? currentItemTitle,
    int? completedSessions,
    int? sessionsToLongBreak,
    int? elapsedSeconds,
    List<RelayStep>? relaySteps,
    int? currentRelayIndex,
    bool? isRelayMode,
  }) {
    return PomodoroState(
      isRunning: isRunning ?? this.isRunning,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      currentType: currentType ?? this.currentType,
      history: history ?? this.history,
      currentItemId: currentItemId ?? this.currentItemId,
      currentItemTitle: currentItemTitle ?? this.currentItemTitle,
      completedSessions: completedSessions ?? this.completedSessions,
      sessionsToLongBreak: sessionsToLongBreak ?? this.sessionsToLongBreak,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      relaySteps: relaySteps ?? this.relaySteps,
      currentRelayIndex: currentRelayIndex ?? this.currentRelayIndex,
      isRelayMode: isRelayMode ?? this.isRelayMode,
    );
  }
}

class PomodoroNotifier extends Notifier<PomodoroState> {
  Timer? _timer;

  @override
  PomodoroState build() {
    _initBackgroundListener();
    _loadState().then((_) {
      // Safety: ensure background service is stopped if we loaded a non-running state
      if (!state.isRunning) {
        PomodoroBackgroundService.stop();
      }
    });

    ref.listen<AsyncValue<List<ContentObject>>>(allObjectsProvider, (prev, next) {
      final list = next.value ?? const [];
      final history = list.whereType<PomodoroSession>().toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      Future.microtask(() {
        state = state.copyWith(history: history);
        _updateWeeklyWidget();
      });
    });

    final initialList = ref.read(allObjectsProvider).value ?? const [];
    final history = initialList.whereType<PomodoroSession>().toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return PomodoroState(history: history);
  }

  Future<void> _loadState() async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final content = await obsidianService.readFile('sessions/current.md');
    if (content != null) {
      final fm = MarkdownParser.parseFrontmatter(content);
      if (fm['type'] == 'pomodoro_state') {
        state = PomodoroState(
          isRunning: false, // Always start paused on load
          remainingSeconds: fm['remainingSeconds'] ?? 1500,
          totalSeconds: fm['totalSeconds'] ?? 1500,
          currentType: PomodoroType.values.firstWhere(
            (t) => t.name == fm['currentType'],
            orElse: () => PomodoroType.work,
          ),
          currentItemId: fm['currentItemId'],
          currentItemTitle: fm['currentItemTitle'],
          elapsedSeconds: fm['elapsedSeconds'] ?? 0,
        );
      }
    }
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final content = await obsidianService.readFile(
      'sessions/pomodoro_history.md',
    );
    if (content == null) return;
    final fm = MarkdownParser.parseFrontmatter(content);
    final rawSessions = fm['sessions'] as List? ?? const [];
    final history = rawSessions.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final date = DateTime.tryParse(map['date']?.toString() ?? map['start_time']?.toString() ?? '') ?? DateTime.now();
      final blocksCompleted = (map['blocks_completed'] as num?)?.toInt() ?? (map['completed'] == true ? 1 : 0);
      final minutesWorked = (map['minutes_worked'] as num?)?.toInt() ?? ((map['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60;
      final minutesBreak = (map['minutes_break'] as num?)?.toInt() ?? 0;
      final stateStr = map['state']?.toString() ?? 'completed';
      final stateVal = PomodoroSessionState.values.firstWhere((s) => s.name == stateStr, orElse: () => PomodoroSessionState.completed);
      return PomodoroSession(
        id: map['id']?.toString(),
        taskTitle: map['task_title']?.toString() ?? map['title']?.toString() ?? 'Focus Session',
        date: date,
        linkedItemSlug: map['linked_item_slug'],
        blocksCompleted: blocksCompleted,
        minutesWorked: minutesWorked,
        minutesBreak: minutesBreak,
        state: stateVal,
      );
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    state = state.copyWith(history: history);
    _updateWeeklyWidget();
  }

  Future<void> _persistState() async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final fm = {
      'type': 'pomodoro_state',
      'isRunning': state.isRunning,
      'remainingSeconds': state.remainingSeconds,
      'totalSeconds': state.totalSeconds,
      'currentType': state.currentType.name,
      'currentItemId': state.currentItemId,
      'currentItemTitle': state.currentItemTitle,
      'elapsedSeconds': state.elapsedSeconds,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
    final content = generateMarkdown(fm, '# Pomodoro Current State');
    await obsidianService.writeFile('sessions/current.md', content);
  }

  Future<void> _persistHistory() async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final frontmatter = {
      'type': 'pomodoro_history',
      'updated_at': DateTime.now().toIso8601String(),
      'sessions': state.history
          .take(200)
          .map(
            (session) => {
              'id': session.id,
              'task_title': session.title,
              'date': session.date.toIso8601String(),
              'linked_item_slug': session.linkedItemSlug,
              'blocks_completed': session.blocksCompleted,
              'minutes_worked': session.minutesWorked,
              'minutes_break': session.minutesBreak,
              'state': session.state.name,
            },
          )
          .toList(),
    };
    final markdown = generateMarkdown(
      frontmatter,
      '# Pomodoro History\n\nPersisted pomodoro sessions for analytics and timeline.',
    );
    await obsidianService.writeFile('sessions/pomodoro_history.md', markdown);
  }

  void _initBackgroundListener() {
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data is int) {
        if (data == 0 && state.isRunning) {
          stop();
          _completeSession();
          _notifyPhaseEnd();
        } else {
          state = state.copyWith(remainingSeconds: data);
        }
      } else if (data is Map<String, dynamic>) {
        final action = data['action'];
        if (action == 'pause') pause();
        if (action == 'resume') start();
        if (action == 'skip') skip();
        if (action == 'stop') {
          stop();
          reset();
        }
      }
    });
  }

  void setDuration(int minutes, PomodoroType type) {
    _timer?.cancel();
    final seconds = minutes * 60;
    state = state.copyWith(
      isRunning: false,
      remainingSeconds: seconds,
      totalSeconds: seconds,
      currentType: type,
    );
    _persistState();
  }

  void setCustomDuration(int minutes, {String? id, String? title}) {
    _timer?.cancel();
    final seconds = minutes * 60;
    state = state.copyWith(
      isRunning: false,
      remainingSeconds: seconds,
      totalSeconds: seconds,
      currentType: PomodoroType.custom,
      currentItemId: id,
      currentItemTitle: title,
    );
    _persistState();
  }

  void startStopwatch({String? id, String? title}) {
    _timer?.cancel();
    state = state.copyWith(
      isRunning: false,
      remainingSeconds: 0,
      totalSeconds: 0,
      currentType: PomodoroType.stopwatch,
      currentItemId: id,
      currentItemTitle: title,
      elapsedSeconds: 0,
    );
    _persistState();
  }

  void setCurrentItem(String? id, String? title) {
    if (state.currentItemId != id) {
      reset();
      state = state.copyWith(
        currentItemId: id,
        currentItemTitle: title,
        completedSessions: 0,
      );
    } else {
      state = state.copyWith(currentItemTitle: title);
    }
    _persistState();
  }

  // RA-P1-4: Relay mode methods
  void startRelayMode(List<RelayStep> steps, String itemId, String itemTitle) {
    if (steps.isEmpty) return;
    
    reset();
    state = state.copyWith(
      isRelayMode: true,
      relaySteps: steps,
      currentRelayIndex: 0,
      currentItemId: itemId,
      currentItemTitle: itemTitle,
    );
    
    _loadRelayStep(0);
  }

  void _loadRelayStep(int index) {
    if (state.relaySteps == null || index >= state.relaySteps!.length) {
      // Relay complete
      stop();
      state = state.copyWith(
        isRelayMode: false,
        currentRelayIndex: 0,
      );
      _persistState();
      return;
    }

    final step = state.relaySteps![index];
    final seconds = step.durationMinutes * 60;
    
    state = state.copyWith(
      remainingSeconds: seconds,
      totalSeconds: seconds,
      currentType: step.isBreak 
          ? PomodoroType.shortBreak 
          : PomodoroType.work,
      currentRelayIndex: index,
    );
    
    _persistState();
  }

  void _advanceRelayStep() {
    if (!state.isRelayMode || state.relaySteps == null) return;
    
    final nextIndex = state.currentRelayIndex + 1;
    if (nextIndex >= state.relaySteps!.length) {
      // Relay complete
      stop();
      state = state.copyWith(
        isRelayMode: false,
        currentRelayIndex: 0,
      );
      _persistState();
      return;
    }
    
    _loadRelayStep(nextIndex);
  }

  void stopRelayMode() {
    stop();
    state = state.copyWith(
      isRelayMode: false,
      relaySteps: null,
      currentRelayIndex: 0,
    );
    _persistState();
  }

  void start() {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true);

    // Start Background Service
    if (state.currentType == PomodoroType.stopwatch) {
      PomodoroBackgroundService.start(0); // No countdown for stopwatch
    } else {
      PomodoroBackgroundService.start(state.remainingSeconds);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.currentType == PomodoroType.stopwatch) {
        // Stopwatch mode: count up
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
        
        // 5-minute reminder vibration
        if (state.elapsedSeconds % 300 == 0 && state.elapsedSeconds > 0) {
          _vibrateReminder();
          _sendReminderNotification();
        }
        
        // Update widget every 10 seconds
        if (state.elapsedSeconds % 10 == 0) {
          final minutes = state.elapsedSeconds ~/ 60;
          final seconds = state.elapsedSeconds % 60;
          final timeStr =
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          WidgetService.updatePomodoro(
            state.currentItemTitle ?? 'Stopwatch',
            timeStr,
          );
          _persistState();
        }
      } else {
        // Countdown mode
        if (state.remainingSeconds > 0) {
          state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);

          // Update widget every 10 seconds or when starting
          if (state.remainingSeconds % 10 == 0 ||
              state.remainingSeconds == state.totalSeconds - 1) {
            final minutes = state.remainingSeconds ~/ 60;
            final seconds = state.remainingSeconds % 60;
            final timeStr =
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
            WidgetService.updatePomodoro(
              state.currentItemTitle ?? 'Session de Focus',
              timeStr,
            );
            _updateWeeklyWidget();
            _persistState();
          }
        } else {
          stop();
          _completeSession();
          _notifyPhaseEnd();
          
          // RA-P1-4: Auto-advance relay step if in relay mode
          if (state.isRelayMode) {
            _advanceRelayStep();
          }
        }
      }
    });
    _persistState();
  }

  void _notifyPhaseEnd() {
    _vibrateSessionEnd();
    String title;
    String body;

    switch (state.currentType) {
      case PomodoroType.work:
        title = 'Trabalho Completed';
        body = 'Time to rest a little.';
        break;
      case PomodoroType.shortBreak:
      case PomodoroType.longBreak:
        title = 'Pausa Completed';
        body = 'Ready to focus again?';
        break;
      case PomodoroType.custom:
        title = 'Session Completed';
        body = 'Your custom timer is done.';
        break;
      case PomodoroType.stopwatch:
        title = 'Cronômetro Stopped';
        body = 'Stopwatch session completed.';
        break;
    }

    NotificationService().showImmediateNotification(
      id: 100,
      title: title,
      body: body,
    );
  }

  Future<void> _vibrateSessionEnd() async {
    for (var i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      if (i < 2) {
        await Future.delayed(const Duration(milliseconds: 220));
      }
    }
  }

  Future<void> _vibrateReminder() async {
    HapticFeedback.mediumImpact();
  }

  void _sendReminderNotification() {
    final minutes = state.elapsedSeconds ~/ 60;
    NotificationService().showImmediateNotification(
      id: 101,
      title: 'Foco contínuo',
      body: 'Você está focado em "${state.currentItemTitle ?? "esta tarefa"}" há $minutes minutos',
    );
  }

  void stop() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
    PomodoroBackgroundService.stop();
    _persistState();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
    PomodoroBackgroundService.pause(state.remainingSeconds);
    _persistState();
  }

  void stopSession({bool saveIncomplete = false}) {
    _timer?.cancel();
    if (saveIncomplete) {
      _completeSession(forceSave: true);
    }
    state = state.copyWith(
      isRunning: false,
      remainingSeconds: state.totalSeconds,
    );
    PomodoroBackgroundService.stop();
    _persistState();
  }

  void reset() {
    _timer?.cancel();
    if (state.currentType == PomodoroType.stopwatch) {
      state = state.copyWith(
        isRunning: false,
        elapsedSeconds: 0,
      );
    } else {
      state = state.copyWith(
        isRunning: false,
        remainingSeconds: state.totalSeconds,
      );
    }
    PomodoroBackgroundService.stop();
    _persistState();
  }

  void skip() {
    _timer?.cancel();
    if (state.currentType == PomodoroType.work) {
      _completeSession();
      final newCompleted = state.completedSessions + 1;
      if (newCompleted >= state.sessionsToLongBreak) {
        state = state.copyWith(completedSessions: 0);
        setDuration(20, PomodoroType.longBreak);
      } else {
        state = state.copyWith(completedSessions: newCompleted);
        setDuration(5, PomodoroType.shortBreak);
      }
    } else {
      // From break or custom, always go back to work (default 25)
      setDuration(25, PomodoroType.work);
    }
    PomodoroBackgroundService.start(state.remainingSeconds);
  }

  Future<void> _completeSession({bool forceSave = false}) async {
    final now = DateTime.now();
    final elapsedSeconds = state.currentType == PomodoroType.stopwatch
        ? state.elapsedSeconds
        : state.totalSeconds - state.remainingSeconds;
    final elapsedMinutes = elapsedSeconds ~/ 60;

    final session = PomodoroSession(
      id: now.millisecondsSinceEpoch.toString(),
      taskTitle: state.currentItemTitle ?? 'Focus em projeto',
      date: now.subtract(Duration(seconds: elapsedSeconds)),
      linkedItemSlug: state.currentItemId,
      blocksCompleted: state.currentType == PomodoroType.work && state.remainingSeconds == 0 ? 1 : 0,
      minutesWorked: (state.currentType == PomodoroType.work || state.currentType == PomodoroType.stopwatch) ? elapsedMinutes : 0,
      minutesBreak: state.currentType != PomodoroType.work && state.currentType != PomodoroType.stopwatch ? elapsedMinutes : 0,
      state: state.remainingSeconds == 0 || state.currentType == PomodoroType.stopwatch ? PomodoroSessionState.completed : PomodoroSessionState.cancelled,
    );
    state = state.copyWith(history: [session, ...state.history]);
    await _persistHistory();
    _updateWeeklyWidget();

    // Save to Vault (Standalone + Daily Note projection)
    if (state.remainingSeconds == 0 || state.currentType == PomodoroType.stopwatch || (forceSave && elapsedSeconds > 60)) {
      await ref.read(vaultProvider.notifier).createObject(session);
      await _saveToDailyNote(session);
      await _updateLinkedObjectMetrics(session);
    }
  }

  Future<void> _updateLinkedObjectMetrics(PomodoroSession session) async {
    if (state.currentItemId == null) return;

    final allObjects = await ref.read(allObjectsProvider.future);
    final matches = allObjects.where((obj) => obj.id == state.currentItemId || obj.slug == state.currentItemId);
    final target = matches.isNotEmpty ? matches.first : null;
    if (target is Task) {
      final updatedTask = target.copyWith(
        timerSessions: target.timerSessions + session.minutesWorked,
      );
      await ref.read(vaultProvider.notifier).updateObject(updatedTask);
    } else if (target is Goal) {
      for (final kpi in target.kpis) {
        if (kpi.sourceType == KPISourceType.timeSpent ||
            kpi.sourceType == KPISourceType.others) {
          kpi.currentValue += session.minutesWorked;
        }
      }
      await ref.read(vaultProvider.notifier).updateObject(target);
    } else if (target is Project) {
      target.totalPomodoroTime += session.minutesWorked;
      await ref.read(vaultProvider.notifier).updateObject(target);
    }

    // Keep KPI calculations up-to-date for goals/projects linked to planner objects.
    // Note: updateObject already uses replaceObjectInMemory, so no need to invalidate here
  }

  Future<void> _saveToDailyNote(PomodoroSession session) async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final block = session.toDailyNoteBlock();

    await obsidianService.appendToDailyNote(
      session.date,
      '## Pomodoros',
      block,
    );
    await ref.read(syncQueueServiceProvider).enqueueAction(
      SyncAction(
        objectType: 'daily_note',
        objectId: dateStr,
        operation: SyncOperation.update,
        payload: {'date': dateStr, 'section': 'Pomodoros'},
      ),
    );
    ref.invalidate(dailyNoteDataProvider(dateStr));
    ref.invalidate(allEntriesProvider);
  }

  Future<void> scheduleSessions({
    required DateTime startTime,
    required int count,
    String? taskTitle,
    String? taskId,
  }) async {
    // Add pomodoros to vault

    // Create a unified Pomodoro Block session for the planner
    // 25m work + 5m break (except last break)
    final totalDuration = (count * 25) + ((count - 1) * 5);

    final pomodoroBlock = Task(
      id: 'pomo_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Bloco Pomodoro: ${taskTitle ?? "Focus"}',
      endDate: startTime,
      duration: totalDuration,
      stage: TaskStage.todo,
      scheduledTime: DateFormat('HH:mm').format(startTime),
      color: AppColors.error.toARGB32().toRadixString(16),
      pomodoroCount: count,
      organizers: taskId != null
          ? [
              OrganizerReference(
                type: 'task',
                slug: taskId,
                title: taskTitle ?? 'Task',
              ),
            ]
          : [],
    );
    
    await ref.read(vaultProvider.notifier).createObject(pomodoroBlock);
  }

  /// F2.18: Log retroactive pomodoro session
  /// Allows user to log past work sessions ("I did 4 pomodoros starting at 11am")
  /// Auto-creates Calendar Session/Event for the logged session
  Future<void> logRetroactiveSession({
    required DateTime occurredAt,
    required int blocksCompleted,
    required int minutesWorked,
    String? taskTitle,
    String? linkedItemId,
  }) async {
    final session = PomodoroSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      taskTitle: taskTitle ?? 'Retroactive Focus',
      date: DateTime.now(), // When logged
      occurredAt: occurredAt, // When actually occurred
      linkedItemSlug: linkedItemId,
      blocksCompleted: blocksCompleted,
      minutesWorked: minutesWorked,
      minutesBreak: 0,
      state: PomodoroSessionState.completed,
    );
    
    state = state.copyWith(history: [session, ...state.history]);
    await _persistHistory();
    await ref.read(vaultProvider.notifier).createObject(session);
    await _saveToDailyNote(session);
    await _updateLinkedObjectMetrics(session);
    
    // F2.18: Auto-create Calendar Session/Event
    await _createEventForRetroactiveSession(session);
  }

  Future<void> _createEventForRetroactiveSession(PomodoroSession session) async {
    final event = Task(
      id: 'event_${DateTime.now().millisecondsSinceEpoch}',
      title: session.title,
      startDate: session.occurredAt ?? session.date,
      duration: session.minutesWorked,
      stage: TaskStage.finalized,
      pomodoroCount: session.blocksCompleted,
    );
    
    await ref.read(vaultProvider.notifier).createObject(event);
  }


  void _updateWeeklyWidget() {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final sessions = state.history
        .where((session) => !session.date.isBefore(startOfWeek))
        .toList();
    final dayHours = List<double>.filled(7, 0);
    final byTitle = <String, int>{};
    for (final session in sessions) {
      final index = session.date.weekday - 1;
      if (index >= 0 && index < dayHours.length) {
        dayHours[index] += session.minutesWorked / 60;
      }
      byTitle[session.title] =
          (byTitle[session.title] ?? 0) + session.minutesWorked;
    }
    final totalHours = dayHours.fold<double>(0, (sum, value) => sum + value);
    final details =
        (byTitle.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(4)
            .map(
              (entry) =>
                  '${entry.key} ${(entry.value / 60).toStringAsFixed(0)}h',
            )
            .join('\n');
    WidgetService.updatePomodoroWeekly(
      '${totalHours.toStringAsFixed(0)}h esta semana',
      dayHours,
      details.isEmpty ? 'Sem sessões registradas' : details,
      null,
    );
  }
}

final pomodoroProvider = NotifierProvider<PomodoroNotifier, PomodoroState>(() {
  return PomodoroNotifier();
});
