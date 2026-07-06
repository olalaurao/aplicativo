// lib/ui/screens/pomodoro_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/vault_provider.dart';
import '../../providers/pomodoro_provider.dart';
import '../../models/pomodoro_session.dart';
import '../theme.dart';
import '../widgets/object_action_wrapper.dart';
import '../widgets/universal_search_picker.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen>
    with SingleTickerProviderStateMixin {
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _scheduledTime = TimeOfDay.now();
  int _sessionCount = 4;
  String? _linkedObjectId;
  String? _linkedObjectTitle;
  bool _handledWidgetStartAction = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledWidgetStartAction) return;

    final action = GoRouterState.of(context).uri.queryParameters['action'];
    if (action == 'start_with_picker') {
      _handledWidgetStartAction = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTaskPicker(context, ref, startAfterSelection: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroProvider);
    final notifier = ref.read(pomodoroProvider.notifier);

    ref.listen(pomodoroProvider, (previous, next) {
      if (previous?.remainingSeconds != 0 &&
          next.remainingSeconds == 0 &&
          next.isRunning == false) {
        _showCompletionSheet(context, next);
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pomodoro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_rounded),
            onPressed: () => _showCompactTimer(context, ref),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ─── Timer Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _showTaskPicker(context, ref),
                          child: Column(
                            children: [
                              Text(
                                state.currentItemTitle ?? 'Selecionar Task',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Toque para mudar',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPhaseBadge(state.currentType),
                        // RA-P2-3: Relay step progress indicator
                        if (state.isRelayMode && state.relaySteps != null) ...[
                          const SizedBox(height: 12),
                          _buildRelayStepIndicator(state),
                          const SizedBox(height: 28),
                        ] else ...[
                          const SizedBox(height: 40),
                        ],

                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CustomPaint(
                            painter: _PomodoroRingPainter(
                              progress: state.totalSeconds <= 0
                                  ? 0
                                  : state.remainingSeconds / state.totalSeconds,
                              phaseColor: _phaseColor(state.currentType),
                            ),
                            child: Center(child: _buildCountdownText(state)),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Session Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(state.sessionsToLongBreak, (
                            i,
                          ) {
                            final completed = i < state.completedSessions;
                            final isCurrent =
                                i == state.completedSessions &&
                                state.currentType == PomodoroType.work;
                            final dot = _sessionDot(
                              completed: completed,
                              isCurrent: isCurrent,
                              color: _phaseColor(state.currentType),
                            );
                            return isCurrent
                                ? ScaleTransition(scale: _pulseAnim, child: dot)
                                : dot;
                          }),
                        ),

                        const SizedBox(height: 24),

                        // Presets Row
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _presetButton(
                              context,
                              ref,
                              '25/5 min',
                              25,
                              PomodoroType.work,
                            ),
                            _presetButton(
                              context,
                              ref,
                              '50/10 min',
                              50,
                              PomodoroType.work,
                            ),
                            _presetButton(
                              context,
                              ref,
                              '90/20 min',
                              90,
                              PomodoroType.work,
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Main Action
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            _actionButton(
                              onPressed: state.isRunning
                                  ? notifier.stop
                                  : notifier.start,
                              icon: state.isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              label: state.isRunning ? 'Pausar' : 'Focar',
                              color: AppColors.error,
                              isPrimary: true,
                            ),
                            if (state.isRunning)
                              _actionButton(
                                onPressed: () => _showStopDialog(context, ref),
                                icon: Icons.stop_rounded,
                                label: 'Parar',
                                color: AppColors.textMuted,
                                isPrimary: false,
                              )
                            else
                              _actionButton(
                                onPressed: () => _handleSkip(context, ref),
                                icon: Icons.skip_next_rounded,
                                label: 'Pular',
                                color: AppColors.textMuted,
                                isPrimary: false,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Current Session Status ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Session',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: List.generate(
                                      state.sessionsToLongBreak,
                                      (i) => Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: i < state.completedSessions
                                              ? AppColors.error
                                              : AppColors.surfaceVariant,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${state.completedSessions}/${state.sessionsToLongBreak} completados',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        FloatingActionButton.small(
                          onPressed: () => _showQuickSetup(context, ref),
                          backgroundColor: AppColors.info,
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Scheduled Pomodoros ───
                  _buildScheduledPomodoros(context),

                  const SizedBox(height: 24),

                  // ─── Scheduling Card ───
                  _buildSchedulingCard(context),

                  const SizedBox(height: 24),

                  // ─── Recent History ───
                  _buildHistoryCard(context, state.history),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSchedulingCard(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Programar Pomodoro',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Schedule Pomodoro blocks on your calendar',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _buildInputBox(
                  Icons.calendar_today_rounded,
                  DateFormat('dd/MM').format(_scheduledDate),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputBox(
                  Icons.access_time_rounded,
                  _scheduledTime.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildCountButton(2)),
              const SizedBox(width: 8),
              Expanded(child: _buildCountButton(4)),
              const SizedBox(width: 8),
              Expanded(child: _buildCountButton(6)),
            ],
          ),

          const SizedBox(height: 12),
          _buildSessionSummary(_sessionCount),

          const SizedBox(height: 16),

          // Linked object picker
          InkWell(
            onTap: () async {
              final result = await showModalBottomSheet<Map<String, String>>(
                context: context,
                isScrollControlled: true,
                builder: (_) => UniversalSearchPickerSheet(
                  title: 'Vincular objeto',
                  onSelected: (obj) {
                    Navigator.pop(context, {
                      'id': obj.id,
                      'title': obj.title,
                    });
                  },
                ),
              );
              if (result != null) {
                setState(() {
                  _linkedObjectId = result['id'];
                  _linkedObjectTitle = result['title'];
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _linkedObjectId != null
                      ? AppColors.info.withValues(alpha: 0.6)
                      : AppColors.textMuted.withValues(alpha: 0.4),
                ),
                color: _linkedObjectId != null
                    ? AppColors.info.withValues(alpha: 0.07)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    _linkedObjectId != null
                        ? Icons.link_rounded
                        : Icons.add_link_rounded,
                    size: 18,
                    color: _linkedObjectId != null
                        ? AppColors.info
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _linkedObjectTitle ?? 'Vincular a um objeto (opcional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _linkedObjectId != null
                            ? AppColors.info
                            : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_linkedObjectId != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        _linkedObjectId = null;
                        _linkedObjectTitle = null;
                      }),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _schedulePomodoro,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Agendar Pomodoro',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBox(IconData? icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountButton(int count) {
    final selected = _sessionCount == count;
    return InkWell(
      onTap: () => setState(() => _sessionCount = count),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.info : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.info
                : AppColors.textMuted.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          '$count x 25m',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  void _schedulePomodoro() {
    final startTime = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );

    // Use linked object if provided, else fall back to current running item
    final linkedId = _linkedObjectId ?? ref.read(pomodoroProvider).currentItemId;
    final linkedTitle = _linkedObjectTitle ?? ref.read(pomodoroProvider).currentItemTitle;

    ref
        .read(pomodoroProvider.notifier)
        .scheduleSessions(
          startTime: startTime,
          count: _sessionCount,
          taskTitle: linkedTitle,
          taskId: linkedId,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Agendado: $_sessionCount pomodoros para ${DateFormat('dd/MM HH:mm').format(startTime)}',
        ),
      ),
    );
  }

  /// Dynamic session summary card
  Widget _buildSessionSummary(int count) {
    final shortBreaks = count - 1;
    final longBreaks = 1;
    // Using default 25min work / 5min short break / 15min long break
    final totalMin = count * 25 + shortBreaks * 5 + longBreaks * 15;
    final hours = totalMin ~/ 60;
    final mins = totalMin % 60;
    final durationStr = hours > 0 ? '${hours}h${mins > 0 ? '${mins}min' : ''}' : '${mins}min';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 12,
        runSpacing: 8,
        children: [
          _summaryChip('🍅', '$count', 'pomodoros'),
          _summaryChip('☕', '$shortBreaks', 'pausas curtas'),
          _summaryChip('🛋', '$longBreaks', 'pausa longa'),
          _summaryChip('⏱', durationStr, 'total'),
        ],
      ),
    );
  }

  Widget _summaryChip(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.info,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildScheduledPomodoros(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final pomodoroTasks =
        tasks
            .where(
              (t) =>
                  t.pomodoroCount != null &&
                  t.pomodoroCount! > 0 &&
                  t.endDate != null,
            )
            .toList()
          ..sort((a, b) {
            if (a.endDate == null || b.endDate == null) return 0;
            final aTime = a.endDate!.add(
              Duration(
                hours: int.parse(a.scheduledTime?.split(':')[0] ?? '0'),
                minutes: int.parse(a.scheduledTime?.split(':')[1] ?? '0'),
              ),
            );
            final bTime = b.endDate!.add(
              Duration(
                hours: int.parse(b.scheduledTime?.split(':')[0] ?? '0'),
                minutes: int.parse(b.scheduledTime?.split(':')[1] ?? '0'),
              ),
            );
            return aTime.compareTo(bTime);
          });

    if (pomodoroTasks.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pomodoros Agendados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...pomodoroTasks.map(
            (s) => ObjectActionWrapper(
              object: s,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => context.push(
                    '/planner',
                    extra: {'initialDate': s.endDate},
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${DateFormat('dd/MM').format(s.endDate!)} ${s.scheduledTime} • ${s.pomodoroCount} ciclos',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.error,
                        ),
                        iconSize: 28,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          ref.read(pomodoroProvider.notifier).setCurrentItem(
                            s.id,
                            s.title,
                          );
                          ref.read(pomodoroProvider.notifier).start();
                          context.go('/pomodoro');
                        },
                        tooltip: 'Iniciar agora',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    List<PomodoroSession> history,
  ) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          if (history.isEmpty)
            const Text(
              'Focus em projeto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            )
          else
            ...history.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () =>
                      context.push('/planner', extra: {'initialDate': s.date}),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_toggle_off_rounded,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${DateFormat('HH:mm').format(s.date)} • ${s.minutesWorked} min',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _badge(
                        s.state == PomodoroSessionState.completed
                            ? 'Completed'
                            : 'Incomplete',
                        s.state == PomodoroSessionState.completed
                            ? AppColors.habitGreen
                            : AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPhaseBadge(PomodoroType type) {
    String label;
    Color color;
    switch (type) {
      case PomodoroType.work:
        label = 'FOCO';
        color = AppColors.error;
        break;
      case PomodoroType.shortBreak:
        label = 'PAUSA CURTA';
        color = AppColors.habitGreen;
        break;
      case PomodoroType.longBreak:
        label = 'PAUSA LONGA';
        color = AppColors.primary;
        break;
      case PomodoroType.custom:
        label = 'PERSONALIZADO';
        color = AppColors.info;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }

  // RA-P2-3: Build relay step progress indicator
  Widget _buildRelayStepIndicator(PomodoroState state) {
    if (state.relaySteps == null || state.relaySteps!.isEmpty) {
      return const SizedBox.shrink();
    }

    final steps = state.relaySteps!;
    final currentIndex = state.currentRelayIndex;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${currentIndex + 1} of ${steps.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              steps[currentIndex].label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(steps.length, (index) {
            final isCompleted = index < currentIndex;
            final isCurrent = index == currentIndex;
            final isBreak = steps[index].isBreak;

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index < steps.length - 1 ? 4 : 0,
                ),
                height: 4,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success
                      : isCurrent
                          ? AppColors.accent
                          : AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _actionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool isPrimary,
  }) {
    if (isPrimary) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160, minHeight: 56),
        child: ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 4,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140, minHeight: 56),
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }

  Widget _presetButton(
    BuildContext context,
    WidgetRef ref,
    String label,
    int minutes,
    PomodoroType type,
  ) {
    final state = ref.watch(pomodoroProvider);
    final isSelected =
        state.totalSeconds == minutes * 60 && state.currentType == type;

    return OutlinedButton(
      onPressed: state.isRunning
          ? null
          : () {
              ref.read(pomodoroProvider.notifier).setDuration(minutes, type);
              HapticFeedback.lightImpact();
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : AppColors.error,
        backgroundColor: isSelected
            ? AppColors.error
            : AppColors.surfaceVariant.withValues(alpha: 0.3),
        side: BorderSide(
          color: isSelected
              ? AppColors.error
              : AppColors.divider.withValues(alpha: 0.1),
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildCountdownText(PomodoroState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(state.remainingSeconds),
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryColor(context),
            letterSpacing: -2,
          ),
        ),
        Text(
          state.isRunning ? 'FOCUSING' : 'PAUSED',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppTheme.textMutedColor(context).withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _sessionDot({
    required bool completed,
    required bool isCurrent,
    required Color color,
  }) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: completed
            ? color
            : (isCurrent
                  ? color.withValues(alpha: 0.3)
                  : AppColors.surfaceVariant),
        shape: BoxShape.circle,
        border: isCurrent ? Border.all(color: color, width: 2) : null,
      ),
    );
  }

  Color _phaseColor(PomodoroType type) {
    switch (type) {
      case PomodoroType.work:
        return const Color(0xFF4CAF50);
      case PomodoroType.shortBreak:
        return const Color(0xFFFB923C);
      case PomodoroType.longBreak:
        return const Color(0xFF60A5FA);
      case PomodoroType.custom:
        return AppColors.info;
    }
  }

  void _showTaskPicker(
    BuildContext context,
    WidgetRef ref, {
    bool startAfterSelection = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => UniversalSearchPickerSheet(
        title: 'Focar em algo',
        onSelected: (obj) {
          final notifier = ref.read(pomodoroProvider.notifier);
          notifier.setCurrentItem(obj.id, obj.title);
          if (startAfterSelection) {
            notifier.start();
          }
          Navigator.pop(ctx);
        },
        onClear: () {
          final notifier = ref.read(pomodoroProvider.notifier);
          notifier.setCurrentItem(null, null);
          if (startAfterSelection) {
            notifier.start();
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showCompactTimer(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(pomodoroProvider);
          final notifier = ref.read(pomodoroProvider.notifier);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Compact Timer',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Text(
                  _formatTime(state.remainingSeconds),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.currentItemTitle ?? 'Focus session',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: state.isRunning
                          ? notifier.stop
                          : notifier.start,
                      icon: Icon(
                        state.isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(state.isRunning ? 'Pause' : 'Start'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _handleSkip(context, ref),
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('Skip'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQuickSetup(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PomodoroSetupSheet(
        onLinkObject: () {
          Navigator.pop(context);
          _showTaskPicker(context, ref);
        },
      ),
    );
  }

  void _handleSkip(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pomodoroProvider.notifier);
    notifier.skip();
    HapticFeedback.lightImpact();
  }

  void _showCompletionSheet(BuildContext context, PomodoroState state) {
    HapticFeedback.mediumImpact();
    final workedMinutes = state.currentType == PomodoroType.work
        ? state.totalSeconds ~/ 60
        : 0;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          color: AppColors.success.withValues(alpha: 0.10),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Session complete!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.completedSessions} blocks · $workedMinutes min worked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        final minutes = (state.totalSeconds ~/ 60).clamp(
                          1,
                          999,
                        );
                        Navigator.pop(ctx);
                        final notifier = ref.read(pomodoroProvider.notifier);
                        notifier.setDuration(minutes, state.currentType);
                        notifier.start();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'One more round',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showStopDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(pomodoroProvider);
    final workedMinutes = state.currentType == PomodoroType.work
        ? ((state.totalSeconds - state.remainingSeconds) ~/ 60)
        : 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop session?'),
        content: Text(
          '${state.completedSessions} blocks · ${workedMinutes}min worked so far.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(pomodoroProvider.notifier)
                  .stopSession(saveIncomplete: false);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(pomodoroProvider.notifier)
                  .stopSession(saveIncomplete: true);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.habitGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save partial'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PomodoroRingPainter extends CustomPainter {
  final double progress;
  final Color phaseColor;

  const _PomodoroRingPainter({
    required this.progress,
    required this.phaseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;
    const startAngle = -pi / 2;

    final bgPaint = Paint()
      ..color = phaseColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * pi,
      false,
      bgPaint,
    );

    final fgPaint = Paint()
      ..color = phaseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progress.clamp(0.0, 1.0) * 2 * pi,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_PomodoroRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phaseColor != phaseColor;
  }
}

class _PomodoroSetupSheet extends ConsumerStatefulWidget {
  final VoidCallback onLinkObject;

  const _PomodoroSetupSheet({required this.onLinkObject});

  @override
  ConsumerState<_PomodoroSetupSheet> createState() =>
      _PomodoroSetupSheetState();
}

class _PomodoroSetupSheetState extends ConsumerState<_PomodoroSetupSheet> {
  PomodoroType _selectedType = PomodoroType.work;
  int _minutes = 25;
  final TextEditingController _minutesController = TextEditingController(
    text: '25',
  );

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroProvider);

    return Container(
      decoration: AppTheme.sheetDecoration(context),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Configure Timer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Type Selector
          const Text(
            'Fase',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: PomodoroType.values.map((type) {
              final isSelected = _selectedType == type;
              return ChoiceChip(
                label: Text(_typeLabel(type)),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: isSelected
                    ? const BorderSide(color: AppColors.primary)
                    : BorderSide(
                        color: AppColors.textMuted.withValues(alpha: 0.3),
                      ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedType = type;
                      if (type == PomodoroType.work) {
                        _minutes = 25;
                      } else if (type == PomodoroType.shortBreak) {
                        _minutes = 5;
                      } else if (type == PomodoroType.longBreak) {
                        _minutes = 15;
                      }
                      _minutesController.text = _minutes.toString();
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Duration Input
          const Text(
            'Duration (minutos)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_minutes > 1) {
                    setState(() {
                      _minutes--;
                      _minutesController.text = _minutes.toString();
                    });
                  }
                },
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: AppColors.primary,
                iconSize: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed > 0) {
                      _minutes = parsed;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  setState(() {
                    _minutes++;
                    _minutesController.text = _minutes.toString();
                  });
                },
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: AppColors.primary,
                iconSize: 32,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Object Linking
          const Text(
            'Objeto Vinculado',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: widget.onLinkObject,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.currentItemTitle ?? 'Nenhum objeto vinculado',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: state.currentItemTitle != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (state.currentItemId != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref
                            .read(pomodoroProvider.notifier)
                            .setCurrentItem(null, null);
                      },
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (_selectedType == PomodoroType.custom) {
                  ref
                      .read(pomodoroProvider.notifier)
                      .setCustomDuration(_minutes);
                } else {
                  ref
                      .read(pomodoroProvider.notifier)
                      .setDuration(_minutes, _selectedType);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Aplicar e Fechar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(PomodoroType type) {
    switch (type) {
      case PomodoroType.work:
        return 'Trabalho';
      case PomodoroType.shortBreak:
        return 'Pausa Curta';
      case PomodoroType.longBreak:
        return 'Pausa Longa';
      case PomodoroType.custom:
        return 'Personalizado';
    }
  }
}
