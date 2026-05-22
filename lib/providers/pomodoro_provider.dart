// lib/providers/pomodoro_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../models/content_object.dart';
import '../models/pomodoro_session.dart';
import '../models/task_model.dart';
import '../models/shared_types.dart';
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
    return PomodoroState();
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
      final startTime =
          DateTime.tryParse(map['start_time']?.toString() ?? '') ??
          DateTime.now();
      final durationSeconds = (map['duration_seconds'] as num?)?.toInt() ?? 0;
      final pomodoroTypeName = map['pomodoro_type']?.toString() ?? 'work';
      return PomodoroSession(
        id: map['id']?.toString(),
        taskTitle: map['task_title']?.toString() ?? 'Focus Session',
        startTime: startTime,
        duration: Duration(seconds: durationSeconds),
        pomodoroType: PomodoroType.values.firstWhere(
          (type) => type.name == pomodoroTypeName,
          orElse: () => PomodoroType.work,
        ),
        completed: map['completed'] as bool? ?? false,
      );
    }).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
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
              'task_title': session.taskTitle,
              'start_time': session.startTime.toIso8601String(),
              'duration_seconds': session.duration.inSeconds,
              'pomodoro_type': session.pomodoroType.name,
              'completed': session.completed,
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
        if (action == 'pause') stop();
        if (action == 'resume') start();
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

  void start() {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true);

    // Start Background Service
    PomodoroBackgroundService.start(state.remainingSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  void stop() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
    PomodoroBackgroundService.stop();
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
    state = state.copyWith(
      isRunning: false,
      remainingSeconds: state.totalSeconds,
    );
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
  }

  Future<void> _completeSession({bool forceSave = false}) async {
    final now = DateTime.now();
    final elapsedSeconds = state.totalSeconds - state.remainingSeconds;

    final session = PomodoroSession(
      id: now.millisecondsSinceEpoch.toString(),
      taskTitle: state.currentItemTitle ?? 'Focus em projeto',
      startTime: now.subtract(Duration(seconds: elapsedSeconds)),
      duration: Duration(seconds: elapsedSeconds),
      pomodoroType: state.currentType,
      completed: state.remainingSeconds == 0,
    );
    state = state.copyWith(history: [session, ...state.history]);
    await _persistHistory();
    _updateWeeklyWidget();

    // Save to Vault (Daily Note)
    if (session.completed || (forceSave && elapsedSeconds > 60)) {
      await _saveToDailyNote(session);
      await _updateLinkedObjectMetrics(session);
    }
  }

  Future<void> _updateLinkedObjectMetrics(PomodoroSession session) async {
    if (state.currentItemId == null) return;

    final allObjects = await ref.read(allObjectsProvider.future);
    final matches = allObjects.where((obj) => obj.id == state.currentItemId);
    final target = matches.isNotEmpty ? matches.first : null;
    if (target is Task) {
      final updatedTask = target.copyWith(
        timerSessions: target.timerSessions + session.duration.inMinutes,
      );
      await ref.read(tasksProvider.notifier).updateTask(updatedTask);
    }

    // Keep KPI calculations up-to-date for goals/projects linked to planner objects.
    ref.invalidate(allObjectsProvider);
  }

  Future<void> _saveToDailyNote(PomodoroSession session) async {
    final obsidianService = ref.read(obsidianServiceProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final path = 'daily/$dateStr.md';
    final dayThemes = ref.read(dayThemesProvider);

    String content =
        await obsidianService.readFile(path) ??
        getDailyNoteTemplate(dateStr, dayThemes);

    final frontmatter = MarkdownParser.parseFrontmatter(content);
    final body = MarkdownParser.extractBody(content);

    final entries = MarkdownParser.parseJournalEntries(body, dateStr);
    final tasks = MarkdownParser.parseTasksFromDailyNote(body);
    final habits = MarkdownParser.parseHabitCompletions(frontmatter);
    final trackers = MarkdownParser.parseTrackerRecords(frontmatter);
    final pomodoros = MarkdownParser.parsePomodoros(body);

    final timeStr = DateFormat('HH:mm').format(session.startTime);
    pomodoros.add({
      'time': timeStr,
      'title': state.currentItemTitle ?? 'Session de Focus',
      'duration': session.duration.inMinutes,
      'type': session.pomodoroType.name,
      if (state.currentItemId != null) 'linked': state.currentItemId,
      'blocks': state.completedSessions + 1,
    });

    final newBody = MarkdownParser.generateDailyNoteBody(
      entries: entries,
      tasks: tasks,
      habits: habits,
      trackers: trackers,
      pomodoros: pomodoros,
    );

    final finalMarkdown = generateMarkdown(frontmatter, newBody);
    await obsidianService.writeFile(path, finalMarkdown);
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

    await ref.read(tasksProvider.notifier).addTask(pomodoroBlock);

    // Schedule notification for the start of the block
    await NotificationService().scheduleNotification(
      id: startTime.millisecondsSinceEpoch ~/ 1000,
      title: 'Pomodoro Block',
      body: 'Time to start focusing: ${taskTitle ?? "Focus"}',
      scheduledDate: startTime,
      payload: 'pomodoro_start',
    );
  }

  void _updateWeeklyWidget() {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final sessions = state.history
        .where((session) => !session.startTime.isBefore(startOfWeek))
        .toList();
    final dayHours = List<double>.filled(7, 0);
    final byTitle = <String, int>{};
    for (final session in sessions) {
      final index = session.startTime.weekday - 1;
      if (index >= 0 && index < dayHours.length) {
        dayHours[index] += session.duration.inMinutes / 60;
      }
      byTitle[session.taskTitle] =
          (byTitle[session.taskTitle] ?? 0) + session.duration.inMinutes;
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
