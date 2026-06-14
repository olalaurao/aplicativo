// lib/ui/screens/habits_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/vault_provider.dart';
import '../../models/habit_model.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/habit_detail_sheet.dart';
import '../forms/create_habit_form.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum HabitsView { today, week, month }

// ─── Main Screen ─────────────────────────────────────────────────────────────

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final activeHabits = habits
        .where((h) => h.status == HabitStatus.active && !h.archived)
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            _buildHeader(context, activeHabits),

            // ─── Tab Bar ───
            _buildTabBar(context, isDark),

            // ─── Content ───
            Expanded(
              child: activeHabits.isEmpty
                  ? EmptyState(
                      icon: Icons.loop_rounded,
                      headline: 'Nenhum hábito ainda',
                      subtext:
                          'Crie hábitos para acompanhar sua consistência e crescimento diário.',
                      ctaLabel: 'Criar Hábito',
                      onCta: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateHabitForm(),
                        ),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _TodayView(habits: activeHabits),
                        _WeekView(habits: activeHabits),
                        _MonthView(habits: activeHabits),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateHabitForm()),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Habit> habits) {
    final now = DateTime.now();
    final weekday = DateFormat('EEEE', 'pt_BR').format(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekday.substring(0, 1).toUpperCase() + weekday.substring(1),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hábitos',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateHabitForm()),
            ),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(9),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textMutedColor(context),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'HOJE'),
            Tab(text: 'SEMANA'),
            Tab(text: 'MÊS'),
          ],
        ),
      ),
    );
  }
}

// ─── Today View ──────────────────────────────────────────────────────────────

class _TodayView extends ConsumerWidget {
  final List<Habit> habits;
  const _TodayView({required this.habits});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final dateStr = now.toIso8601String().split('T').first;
    final dailyData = ref.watch(dailyNoteDataProvider(dateStr));
    final habitsMap = dailyData['habits'] as Map? ?? {};

    // Compute summary stats
    int completedCount = 0;
    int streakDays = 0; // days all habits completed consecutively

    for (final habit in habits) {
      final val = habitsMap[habit.slug];
      if (_isCompleted(val, habit)) completedCount++;
    }

    // Count consecutive days where all habits were completed
    streakDays = _computeAllCompleteStreak(habits);

    final weekday = DateFormat('EEEE', 'pt_BR').format(now);
    final dateLabel =
        '${weekday.substring(0, 1).toUpperCase()}${weekday.substring(1)}, ${DateFormat("d 'de' MMMM", 'pt_BR').format(now)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Date label
        Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Summary chips
        Row(
          children: [
            Flexible(
              child: _SummaryChip(
                icon: Icons.trending_up_rounded,
                label: '$completedCount / ${habits.length} completos',
                color: AppColors.habitGreen,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _SummaryChip(
                icon: Icons.local_fire_department_rounded,
                label: '$streakDays dias completando tudo',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Habit list
        ...habits.map((habit) {
          final val = habitsMap[habit.slug];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TodayHabitCard(habit: habit, currentVal: val, date: now),
          );
        }),
      ],
    );
  }

  bool _isCompleted(dynamic val, Habit habit) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val >= habit.dailyGoal;
    if (val is List) {
      return val.every((v) => v == true) && val.length >= habit.dailyGoal;
    }
    return false;
  }

  int _computeAllCompleteStreak(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    int streak = 0;
    final today = DateTime.now();
    for (int d = 0; d < 365; d++) {
      final date = today.subtract(Duration(days: d));
      final dateStr = date.toIso8601String().split('T').first;
      bool allComplete = habits.every((habit) {
        final record = habit.completionHistory
            .where((r) => r.date.toIso8601String().split('T').first == dateStr)
            .firstOrNull;
        return record?.successful ?? false;
      });
      if (allComplete) {
        streak++;
      } else if (d > 0) {
        break;
      }
    }
    return streak;
  }
}

// ─── Today Habit Card ─────────────────────────────────────────────────────────

class _TodayHabitCard extends ConsumerWidget {
  final Habit habit;
  final dynamic currentVal;
  final DateTime date;

  const _TodayHabitCard({
    required this.habit,
    required this.currentVal,
    required this.date,
  });

  Color _parseColor() {
    try {
      String c = habit.color.replaceAll('#', '');
      if (c.length == 6) c = 'FF$c';
      return Color(int.parse(c, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  bool get _isFullyCompleted {
    final val = currentVal;
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val >= habit.dailyGoal;
    if (val is List) {
      return val.every((v) => v == true) && val.length >= habit.dailyGoal;
    }
    return false;
  }

  List<bool> get _slotStates {
    final numSlots = habit.slots.isNotEmpty
        ? habit.slots.length
        : habit.dailyGoal;
    if (numSlots <= 0) return [];
    final states = List<bool>.filled(numSlots, false);
    final val = currentVal;
    if (val is List) {
      for (int i = 0; i < val.length && i < numSlots; i++) {
        states[i] = val[i] == true || (val[i] is num && val[i] > 0);
      }
    } else if (val is bool && val) {
      for (int i = 0; i < numSlots; i++) {
        states[i] = true;
      }
    } else if (val is num) {
      for (int i = 0; i < val.toInt() && i < numSlots; i++) {
        states[i] = true;
      }
    }
    return states;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slots = _slotStates;
    final reminderTimes = habit.slots
        .where((s) => s.reminderEnabled && s.reminderTime != null)
        .map((s) => s.reminderTime!.format(context))
        .toList();

    return GestureDetector(
      onTap: () => showHabitDetailSheet(context, habit, date),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardFillColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              // Check box / completion indicator
              if (habit.isFlexibleFrequency)
                _buildFlexibleCheckbox(context, ref, color)
              else
                _buildCheckbox(context, ref, color, slots),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            habit.displayTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _isFullyCompleted
                                  ? AppTheme.textMutedColor(context)
                                  : AppTheme.textPrimaryColor(context),
                              decoration: _isFullyCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (habit.habitMode == HabitMode.pact) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PACT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (habit.habitMode == HabitMode.pact) ...[
                          Icon(
                            Icons.shield_rounded,
                            size: 13,
                            color: color,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            habit.startedAt != null
                                ? 'Dia ${DateTime.now().difference(DateTime(habit.startedAt!.year, habit.startedAt!.month, habit.startedAt!.day)).inDays + 1}'
                                : 'Dia 1',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ] else if (habit.streak > 0) ...[
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 13,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${habit.streak} dias',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (reminderTimes.isNotEmpty) ...[
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            reminderTimes.join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Multi-slot indicators (if > 1 slot)
              if (slots.length > 1)
                _buildMultiSlotDots(context, ref, color, slots),
            ],
          ),
        ),
      ),
    );
  }

  int get _completionsInCurrentPeriod {
    DateTime now = DateTime.now();
    DateTime start;
    if (habit.frequencyDays == 7) {
      start = now.subtract(Duration(days: (now.weekday - 1) % 7));
    } else if (habit.frequencyDays == 30) {
      start = DateTime(now.year, now.month, 1);
    } else {
      start = now.subtract(Duration(days: habit.frequencyDays ?? 7));
    }
    start = DateTime(start.year, start.month, start.day);

    int count = 0;
    for (var record in habit.completionHistory) {
      if (!record.date.isBefore(start) && record.successful) {
        count++;
      }
    }
    // Also consider today's optimistic state
    if (currentVal == true || (currentVal is num && currentVal > 0)) {
      // Check if today is already in history to avoid double counting
      final todayStr = now.toIso8601String().split('T').first;
      final alreadyInHistory = habit.completionHistory.any((r) => r.date.toIso8601String().split('T').first == todayStr && r.successful);
      if (!alreadyInHistory) {
        count++;
      }
    }
    return count;
  }

  Widget _buildFlexibleCheckbox(
    BuildContext context,
    WidgetRef ref,
    Color color,
  ) {
    int target = 1;
    if (habit.scheduler != null && habit.scheduler!.rules.isNotEmpty) {
      target = habit.scheduler!.rules.first.countPerPeriod ?? 1;
    }
    int current = _completionsInCurrentPeriod;
    bool goalReached = current >= target;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(habitsProvider.notifier).toggleHabit(
              habit,
              date,
            );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: goalReached ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: goalReached ? color : color.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$current/$target',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: goalReached ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(
    BuildContext context,
    WidgetRef ref,
    Color color,
    List<bool> slots,
  ) {
    if (slots.length <= 1) {
      final completed = slots.isEmpty ? _isFullyCompleted : slots[0];
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          ref
              .read(habitsProvider.notifier)
              .toggleHabit(
                habit,
                date,
                slotIndex: habit.dailyGoal > 1 ? 0 : null,
              );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: completed ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: completed ? color : color.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: completed
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
        ),
      );
    }
    // Multiple slots: show first slot as checkbox
    final completed = slots[0];
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref
            .read(habitsProvider.notifier)
            .toggleHabit(habit, date, slotIndex: 0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: completed ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: completed ? color : color.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: completed
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildMultiSlotDots(
    BuildContext context,
    WidgetRef ref,
    Color color,
    List<bool> slots,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(slots.length, (i) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ref
                .read(habitsProvider.notifier)
                .toggleHabit(habit, date, slotIndex: i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(left: 5),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: slots[i] ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: slots[i] ? color : color.withValues(alpha: 0.35),
                width: 1.8,
              ),
            ),
            child: slots[i]
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),
        );
      }),
    );
  }
}

// ─── Week View ────────────────────────────────────────────────────────────────

class _WeekView extends ConsumerWidget {
  final List<Habit> habits;
  const _WeekView({required this.habits});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    // Start of week (Monday)
    final weekStart = now.subtract(Duration(days: (now.weekday - 1) % 7));
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    // Compute overall week completions
    final overallCompletions = <int>[];
    for (final day in weekDays) {
      final ds = day.toIso8601String().split('T').first;
      int completed = 0;
      for (final habit in habits) {
        final record = habit.completionHistory
            .where((r) => r.date.toIso8601String().split('T').first == ds)
            .firstOrNull;
        if (record?.successful ?? false) completed++;
      }
      overallCompletions.add(completed);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ─── Overview card ───
        _OverviewCard(
          title: 'Visão Geral - Semana',
          child: _WeekCalendarRow(
            weekDays: weekDays,
            completions: overallCompletions,
            totalHabits: habits.length,
            accentColor: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 24),

        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'Hábitos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
        ),

        // Each habit week row
        ...habits.map(
          (habit) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HabitWeekCard(habit: habit, weekDays: weekDays),
          ),
        ),
      ],
    );
  }
}

// ─── Month View ───────────────────────────────────────────────────────────────

class _MonthView extends ConsumerWidget {
  final List<Habit> habits;
  const _MonthView({required this.habits});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    // Build per-day overall completions for month
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthCompletions = <String, int>{};
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(now.year, now.month, d);
      final ds = date.toIso8601String().split('T').first;
      int count = 0;
      for (final habit in habits) {
        final record = habit.completionHistory
            .where((r) => r.date.toIso8601String().split('T').first == ds)
            .firstOrNull;
        if (record?.successful ?? false) count++;
      }
      monthCompletions[ds] = count;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ─── Overview month calendar ───
        _OverviewCard(
          title: 'Visão Geral - Mês',
          child: _MonthCalendarGrid(
            year: now.year,
            month: now.month,
            completionsPerDay: monthCompletions,
            totalHabits: habits.length,
            accentColor: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 24),

        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'Hábitos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
        ),

        // Each habit month
        ...habits.map(
          (habit) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HabitMonthCard(habit: habit),
          ),
        ),
      ],
    );
  }
}

// ─── Overview Card ────────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _OverviewCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Week Calendar Row ────────────────────────────────────────────────────────

class _WeekCalendarRow extends StatelessWidget {
  final List<DateTime> weekDays;
  final List<int> completions;
  final int totalHabits;
  final Color accentColor;

  const _WeekCalendarRow({
    required this.weekDays,
    required this.completions,
    required this.totalHabits,
    required this.accentColor,
  });

  static const _dayLabels = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = weekDays[i];
        final count = i < completions.length ? completions[i] : 0;
        final isToday =
            day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;
        final isFuture = day.isAfter(now);
        final isCompleted =
            !isFuture && totalHabits > 0 && count == totalHabits;

        return Expanded(
          child: Column(
            children: [
              Text(
                _dayLabels[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMutedColor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              _DayCell(
                day: day.day,
                isToday: isToday,
                isFuture: isFuture,
                isCompleted: isCompleted,
                isPartial: !isFuture && !isCompleted && count > 0,
                color: accentColor,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Month Calendar Grid ──────────────────────────────────────────────────────

class _MonthCalendarGrid extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, int> completionsPerDay;
  final int totalHabits;
  final Color accentColor;

  const _MonthCalendarGrid({
    required this.year,
    required this.month,
    required this.completionsPerDay,
    required this.totalHabits,
    required this.accentColor,
  });

  static const _dayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(year, month, 1);
    // weekday: 1=Mon..7=Sun. Offset to make Mon=0
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _dayLabels
              .map(
                (d) => Expanded(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMutedColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate(rows, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - startOffset + 1;

                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }

                final date = DateTime(year, month, dayNum);
                final ds = date.toIso8601String().split('T').first;
                final count = completionsPerDay[ds] ?? 0;
                final isToday =
                    date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;
                final isFuture = date.isAfter(now);
                final isCompleted =
                    !isFuture && totalHabits > 0 && count == totalHabits;

                return Expanded(
                  child: _DayCell(
                    day: dayNum,
                    isToday: isToday,
                    isFuture: isFuture,
                    isCompleted: isCompleted,
                    isPartial: !isFuture && !isCompleted && count > 0,
                    color: accentColor,
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Day Cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isFuture;
  final bool isCompleted;
  final bool isPartial;
  final Color color;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.isCompleted,
    required this.isPartial,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color textColor;
    Border? border;

    if (isCompleted) {
      bgColor = color;
      textColor = Colors.white;
    } else if (isPartial) {
      bgColor = color.withValues(alpha: 0.25);
      textColor = color;
    } else if (isToday) {
      bgColor = Colors.transparent;
      textColor = color;
      border = Border.all(color: color, width: 1.5);
    } else if (isFuture) {
      bgColor = Colors.transparent;
      textColor = AppTheme.textMutedColor(context).withValues(alpha: 0.5);
    } else {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.03);
      textColor = AppTheme.textMutedColor(context);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      height: 34,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: textColor,
                ),
              ),
      ),
    );
  }
}

// ─── Habit Week Card ──────────────────────────────────────────────────────────

class _HabitWeekCard extends ConsumerWidget {
  final Habit habit;
  final List<DateTime> weekDays;

  const _HabitWeekCard({required this.habit, required this.weekDays});

  Color _parseColor() {
    try {
      String c = habit.color.replaceAll('#', '');
      if (c.length == 6) c = 'FF$c';
      return Color(int.parse(c, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseColor();
    final now = DateTime.now();

    return GestureDetector(
      onTap: () => showHabitDetailSheet(context, habit, now),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: AppTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    habit.displayTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Week day row
            _HabitWeekRow(habit: habit, weekDays: weekDays, color: color),
            if (habit.streak <= 0 && habit.daysSinceLastCompletion >= 0) ...[
              const SizedBox(height: 10),
              Text(
                habit.daysSinceLastCompletion == 0
                    ? 'Concluído hoje'
                    : '${habit.daysSinceLastCompletion} dias desde a última conclusão',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMutedColor(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HabitWeekRow extends ConsumerWidget {
  final Habit habit;
  final List<DateTime> weekDays;
  final Color color;

  const _HabitWeekRow({
    required this.habit,
    required this.weekDays,
    required this.color,
  });

  static const _dayLabels = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];

  bool _isCompletedOn(DateTime day) {
    final ds = day.toIso8601String().split('T').first;
    final record = habit.completionHistory
        .where((r) => r.date.toIso8601String().split('T').first == ds)
        .firstOrNull;
    return record?.successful ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = weekDays[i];
        final isCompleted = _isCompletedOn(day);
        final isToday =
            day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;
        final isFuture = day.isAfter(now);

        return Expanded(
          child: Column(
            children: [
              Text(
                _dayLabels[i],
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMutedColor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: isFuture
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(habitsProvider.notifier)
                            .toggleHabit(habit, day);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 34,
                  decoration: BoxDecoration(
                    color: isCompleted ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFuture
                          ? AppTheme.textMutedColor(
                              context,
                            ).withValues(alpha: 0.2)
                          : isCompleted
                          ? color
                          : isToday
                          ? color
                          : AppTheme.textMutedColor(
                              context,
                            ).withValues(alpha: 0.35),
                      width: isToday && !isCompleted ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isFuture
                                  ? AppTheme.textMutedColor(
                                      context,
                                    ).withValues(alpha: 0.4)
                                  : isToday
                                  ? color
                                  : AppTheme.textMutedColor(context),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Habit Month Card ─────────────────────────────────────────────────────────

class _HabitMonthCard extends StatelessWidget {
  final Habit habit;
  const _HabitMonthCard({required this.habit});

  Color _parseColor() {
    try {
      String c = habit.color.replaceAll('#', '');
      if (c.length == 6) c = 'FF$c';
      return Color(int.parse(c, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor();
    final now = DateTime.now();

    // Build completion map for this month
    final completedDays = <String>{};
    for (final record in habit.completionHistory) {
      if (record.date.year == now.year &&
          record.date.month == now.month &&
          record.successful) {
        completedDays.add(record.date.toIso8601String().split('T').first);
      }
    }

    return GestureDetector(
      onTap: () => showHabitDetailSheet(context, habit, now),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    habit.displayTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Compact month grid
            _CompactMonthGrid(
              year: now.year,
              month: now.month,
              completedDays: completedDays,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final Set<String> completedDays;
  final Color color;

  const _CompactMonthGrid({
    required this.year,
    required this.month,
    required this.completedDays,
    required this.color,
  });

  static const _dayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(year, month, 1);
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _dayLabels
              .map(
                (d) => Expanded(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMutedColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        ...List.generate(
          rows,
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - startOffset + 1;

                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }

                final date = DateTime(year, month, dayNum);
                final ds = date.toIso8601String().split('T').first;
                final isCompleted = completedDays.contains(ds);
                final isToday =
                    date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;
                final isFuture = date.isAfter(now);

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isToday && !isCompleted
                          ? Border.all(color: color, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: Colors.white,
                            )
                          : Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w400,
                                color: isFuture
                                    ? AppTheme.textMutedColor(
                                        context,
                                      ).withValues(alpha: 0.3)
                                    : isToday
                                    ? color
                                    : AppTheme.textMutedColor(context),
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Summary Chip ─────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
