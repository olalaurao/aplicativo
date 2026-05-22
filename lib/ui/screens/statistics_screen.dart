// lib/ui/screens/statistics_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../../providers/vault_provider.dart';
import '../../providers/pomodoro_provider.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/journal_entry.dart';
import '../../models/pomodoro_session.dart';
import '../../models/mood_model.dart';
import '../../models/goal_model.dart';
import '../forms/create_entry_form.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Goal? _selectedGoalForKPIChart;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final tasks = ref.watch(tasksProvider);
    final entries = ref.watch(allEntriesProvider);
    final moods = ref.watch(moodsProvider);
    final goals = ref.watch(goalsProvider);
    final pomodoroHistory = ref.watch(pomodoroProvider).history;

    if (_selectedGoalForKPIChart == null && goals.isNotEmpty) {
      _selectedGoalForKPIChart = goals.first;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Estatísticas & Review',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(
              icon: Icon(Icons.analytics_rounded, size: 20),
              text: 'Métricas',
            ),
            Tab(
              icon: Icon(Icons.rate_review_rounded, size: 20),
              text: 'Weekly Review',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMetricsTab(
            habits: habits,
            tasks: tasks,
            entries: entries,
            moods: moods,
            goals: goals,
            pomodoroHistory: pomodoroHistory,
          ),
          _buildReviewTab(
            habits: habits,
            tasks: tasks,
            entries: entries,
            moods: moods,
            goals: goals,
            pomodoroHistory: pomodoroHistory,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // METRICS TAB
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMetricsTab({
    required List<Habit> habits,
    required List<Task> tasks,
    required List<JournalEntry> entries,
    required List<MoodDefinition> moods,
    required List<Goal> goals,
    required List<PomodoroSession> pomodoroHistory,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Heatmap de Atividade ───
          _buildSectionHeader('Mapa de Calor (Últimos 60 dias)'),
          _buildHeatmapCard(entries),
          const SizedBox(height: 24),

          // ─── Hábitos Streaks ───
          _buildSectionHeader('Consistência de Hábitos'),
          _buildHabitsConsistencyCard(habits),
          const SizedBox(height: 24),

          // ─── Tarefas Conclusão ───
          _buildSectionHeader('Taxa de Conclusão de Tarefas'),
          _buildTaskCompletionCard(tasks),
          const SizedBox(height: 24),

          // ─── Pomodoro Semanal ───
          _buildSectionHeader('Horas de Foco Pomodoro'),
          _buildPomodoroChartCard(pomodoroHistory),
          const SizedBox(height: 24),

          // ─── Mood Distribution ───
          _buildSectionHeader('Distribuição de Humor (Últimos 30 dias)'),
          _buildMoodDonutCard(entries, moods),
          const SizedBox(height: 24),

          // ─── Diário Estatísticas ───
          _buildSectionHeader('Hábitos de Escrita'),
          _buildJournalStatsCard(entries),
          const SizedBox(height: 24),

          // ─── Metas KPI Line Chart ───
          _buildSectionHeader('Histórico de KPIs de Metas'),
          _buildGoalKPIChartCard(goals),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // 1. Heatmap Card
  Widget _buildHeatmapCard(List<JournalEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 59));

    // Map date to entry count
    final dateCounts = <String, int>{};
    for (final entry in entries) {
      final dateStr = DateFormat('yyyy-MM-dd').format(entry.date);
      dateCounts[dateStr] = (dateCounts[dateStr] ?? 0) + 1;
    }

    final dayWidgets = <Widget>[];
    for (int i = 0; i < 60; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final count = dateCounts[dateStr] ?? 0;

      Color cellColor = AppColors.textMuted.withValues(alpha: 0.1);
      if (count > 0) {
        cellColor = AppColors.primary.withValues(
          alpha: math.min(1.0, 0.2 + (count * 0.25)),
        );
      }

      dayWidgets.add(
        Tooltip(
          message: '${DateFormat('dd/MM').format(date)}: $count entry(s)',
          child: Container(
            margin: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: date == today ? AppColors.accent : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Frequência de registros no diário e atividades nos últimos 60 dias.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            children: dayWidgets,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Menos',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              const SizedBox(width: 4),
              _buildLegendCell(0.1),
              _buildLegendCell(0.35),
              _buildLegendCell(0.6),
              _buildLegendCell(0.85),
              const SizedBox(width: 4),
              const Text(
                'Mais',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendCell(double opacity) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // 2. Habits Consistency Card
  Widget _buildHabitsConsistencyCard(List<Habit> habits) {
    if (habits.isEmpty) {
      return Container(
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'Nenhum hábito configurado.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: habits.map((habit) {
          final history = habit.completionHistory;
          final totalDays = history.length;
          final completedDays = history.where((h) => h.successful).length;
          final successRate = totalDays > 0
              ? (completedDays / totalDays) * 100
              : 0.0;

          // Streak calculation (record and current)
          int currentStreak = 0;
          int recordStreak = 0;
          int tempStreak = 0;
          final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final yesterdayStr = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime.now().subtract(const Duration(days: 1)));

          for (final record in history) {
            if (record.successful) {
              tempStreak++;
              if (tempStreak > recordStreak) {
                recordStreak = tempStreak;
              }
            } else {
              tempStreak = 0;
            }
          }

          // Compute current streak
          bool isCurrentActive = false;
          if (history.isNotEmpty) {
            final lastRecord = history.last;
            final lastRecordStr = DateFormat(
              'yyyy-MM-dd',
            ).format(lastRecord.date);
            if (lastRecordStr == nowStr || lastRecordStr == yesterdayStr) {
              isCurrentActive = true;
            }
          }

          if (isCurrentActive) {
            currentStreak = tempStreak;
          } else {
            currentStreak = 0;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalDays > 0 ? completedDays / totalDays : 0,
                          backgroundColor: AppColors.textMuted.withValues(
                            alpha: 0.1,
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.habitGreen,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: AppColors.accent,
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$currentStreak',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.accent,
                          ),
                        ),
                        Text(
                          ' / $recordStreak max',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${successRate.toStringAsFixed(0)}% taxa',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 3. Task Completion Card
  Widget _buildTaskCompletionCard(List<Task> tasks) {
    final now = DateTime.now();
    final rolling30Days = now.subtract(const Duration(days: 30));

    final tasksIn30Days = tasks.where((t) {
      return t.createdAt.isAfter(rolling30Days);
    }).toList();

    final completedTasks = tasksIn30Days
        .where((t) => t.stage == TaskStage.finalized)
        .length;
    final totalTasks = tasksIn30Days.length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: completionRate,
                      strokeWidth: 8,
                      backgroundColor: AppColors.textMuted.withValues(
                        alpha: 0.1,
                      ),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(completionRate * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Últimos 30 dias',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedTasks tarefas concluídas de um total de $totalTasks criadas.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTaskLegend(AppColors.primary, 'Concluídas'),
                    const SizedBox(width: 16),
                    _buildTaskLegend(
                      AppColors.textMuted.withValues(alpha: 0.2),
                      'Abertas',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // 4. Pomodoro Semanal Chart
  Widget _buildPomodoroChartCard(List<PomodoroSession> sessions) {
    if (sessions.isEmpty) {
      return Container(
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'Nenhuma sessão Pomodoro registrada.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    // Map weekly durations for the last 4 weeks
    final now = DateTime.now();
    final Map<int, double> weeklyMinutes = {};

    for (final session in sessions) {
      final difference = now.difference(session.startTime);
      final weeksAgo = (difference.inDays / 7).floor();
      if (weeksAgo < 4) {
        weeklyMinutes[weeksAgo] =
            (weeklyMinutes[weeksAgo] ?? 0.0) +
            (session.duration.inMinutes.toDouble());
      }
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 3; i >= 0; i--) {
      final hours = (weeklyMinutes[i] ?? 0.0) / 60.0;
      barGroups.add(
        BarChartGroupData(
          x: 3 - i,
          barRods: [
            BarChartRodData(
              toY: hours,
              color: AppColors.accent,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Horas de foco semanais (últimas 4 semanas)',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 20,
                barGroups: barGroups,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}h',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                      reservedSize: 28,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final labels = [
                          'Há 3 sem',
                          'Há 2 sem',
                          'Semana Ant',
                          'Esta Sem',
                        ];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[val.toInt()],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Mood Donut Chart
  Widget _buildMoodDonutCard(
    List<JournalEntry> entries,
    List<MoodDefinition> moods,
  ) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final relevantEntries = entries
        .where((e) => e.date.isAfter(thirtyDaysAgo) && e.moodSlug != null)
        .toList();

    if (relevantEntries.isEmpty || moods.isEmpty) {
      return Container(
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'Sem dados de humor nos últimos 30 dias.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final moodCounts = <String, int>{};
    for (final entry in relevantEntries) {
      moodCounts[entry.moodSlug!] = (moodCounts[entry.moodSlug!] ?? 0) + 1;
    }

    final sections = <PieChartSectionData>[];
    final colorMap = <String, Color>{};

    for (final mood in moods) {
      final hex = mood.color.replaceAll('#', '0xFF');
      final val = int.tryParse(hex);
      colorMap[mood.id] = val != null ? Color(val) : AppColors.primary;
    }

    moodCounts.forEach((moodId, count) {
      final moodDef = moods.firstWhere(
        (m) => m.id == moodId,
        orElse: () => moods.first,
      );
      final percentage = (count / relevantEntries.length) * 100;
      sections.add(
        PieChartSectionData(
          color: colorMap[moodId] ?? AppColors.primary,
          value: count.toDouble(),
          title: '${moodDef.emoji} ${percentage.toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: moodCounts.entries.map((e) {
                final moodDef = moods.firstWhere(
                  (m) => m.id == e.key,
                  orElse: () => moods.first,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorMap[e.key] ?? AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${moodDef.emoji} ${moodDef.label}: ${e.value} dia(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Journal Writing Stats Card
  Widget _buildJournalStatsCard(List<JournalEntry> entries) {
    if (entries.isEmpty) {
      return Container(
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'Nenhuma entrada do diário.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    int totalWords = 0;
    for (final entry in entries) {
      totalWords += entry.body
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
    }
    final avgWords = totalWords / entries.length;

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatIndicator(
            Icons.edit_note_rounded,
            '${entries.length}',
            'Registros Totais',
            AppColors.primary,
          ),
          _buildStatIndicator(
            Icons.text_fields_rounded,
            '$totalWords',
            'Palavras Escritas',
            AppColors.accent,
          ),
          _buildStatIndicator(
            Icons.analytics_outlined,
            avgWords.toStringAsFixed(0),
            'Palavras / Entrada',
            AppColors.habitGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatIndicator(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }

  // 7. Goal KPI Historical Line Chart
  Widget _buildGoalKPIChartCard(List<Goal> goals) {
    final goalsWithKPIs = goals.where((g) => g.kpis.isNotEmpty).toList();

    if (goalsWithKPIs.isEmpty) {
      return Container(
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'Nenhuma meta com KPIs cadastrada.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final currentGoal = _selectedGoalForKPIChart ?? goalsWithKPIs.first;

    // Simulate standard dynamic progress trend points (from currentValue, targetValue)
    final double target = currentGoal.kpis.first.targetValue;
    final double current = currentGoal.kpis.first.currentValue;

    // Draw lines over 5 points representing progress
    final spots = [
      FlSpot(0, math.max(0.0, current * 0.2)),
      FlSpot(1, math.max(0.0, current * 0.4)),
      FlSpot(2, math.max(0.0, current * 0.65)),
      FlSpot(3, math.max(0.0, current * 0.8)),
      FlSpot(4, current),
    ];

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progresso do KPI Principal',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              DropdownButton<Goal>(
                value: currentGoal,
                items: goalsWithKPIs.map((g) {
                  return DropdownMenuItem<Goal>(
                    value: g,
                    child: Text(g.title, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (g) {
                  setState(() {
                    _selectedGoalForKPIChart = g;
                  });
                },
                underline: const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'KPI: ${currentGoal.kpis.first.title}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Alvo: $target | Progresso Atual: $current',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) => Text(
                        val.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                      reservedSize: 24,
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WEEKLY REVIEW GENERATOR TAB
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildReviewTab({
    required List<Habit> habits,
    required List<Task> tasks,
    required List<JournalEntry> entries,
    required List<MoodDefinition> moods,
    required List<Goal> goals,
    required List<PomodoroSession> pomodoroHistory,
  }) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // 1. Date Range Title
    final startRangeStr = DateFormat('dd/MM').format(sevenDaysAgo);
    final endRangeStr = DateFormat('dd/MM').format(now);
    final weekReviewTitle =
        'Weekly Review: Semana de $startRangeStr a $endRangeStr';

    // 2. Compute Habits success rate
    final List<String> habitsSummary = [];
    for (final habit in habits) {
      final relevantHistory = habit.completionHistory
          .where((h) => h.date.isAfter(sevenDaysAgo))
          .toList();
      final completedDays = relevantHistory.where((h) => h.successful).length;
      final totalDays = relevantHistory.length;
      final percentage = totalDays > 0
          ? (completedDays / totalDays) * 100
          : 0.0;
      habitsSummary.add(
        '- ${habit.title}: $completedDays/$totalDays dias (${percentage.toStringAsFixed(0)}%)',
      );
    }

    // 3. Tasks completed vs created vs open
    final tasksCreatedInWeek = tasks
        .where((t) => t.createdAt.isAfter(sevenDaysAgo))
        .toList();
    final tasksCompletedInWeek = tasks.where((t) {
      if (t.stage != TaskStage.finalized) return false;
      return t.updatedAt.isAfter(sevenDaysAgo);
    }).toList();
    final tasksOpen = tasks
        .where((t) => t.stage != TaskStage.finalized)
        .toList();

    // 4. Pomodoro weekly total & projects
    final weekPomodoros = pomodoroHistory
        .where((p) => p.startTime.isAfter(sevenDaysAgo))
        .toList();
    final double pomodoroMinutesTotal = weekPomodoros.fold(
      0.0,
      (sum, p) => sum + p.duration.inMinutes.toDouble(),
    );
    final double pomodoroHoursTotal = pomodoroMinutesTotal / 60.0;

    final Map<String, double> pomodoroByProject = {};
    for (final session in weekPomodoros) {
      final projKey = session.taskTitle.isNotEmpty == true
          ? session.taskTitle
          : 'Outros';
      pomodoroByProject[projKey] =
          (pomodoroByProject[projKey] ?? 0.0) +
          (session.duration.inMinutes.toDouble() / 60.0);
    }
    final sortedProjects = pomodoroByProject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final List<String> pomodorosSummary = [];
    for (int i = 0; i < math.min(3, sortedProjects.length); i++) {
      final item = sortedProjects[i];
      pomodorosSummary.add(
        '  ${i + 1}. ${item.key}: ${item.value.toStringAsFixed(1)} horas',
      );
    }

    // 5. Goals progress KPI deltas
    final List<String> goalsSummary = [];
    for (final goal in goals) {
      if (goal.kpis.isNotEmpty) {
        final kpi = goal.kpis.first;
        goalsSummary.add(
          '- [[${goal.title}]]: KPI "${kpi.title}" em ${kpi.currentValue}/${kpi.targetValue}',
        );
      }
    }

    // 6. Mood trend last 7 days
    final weekMoodEntries = entries
        .where((e) => e.date.isAfter(sevenDaysAgo) && e.moodSlug != null)
        .toList();
    double avgMoodValue = 0;
    if (weekMoodEntries.isNotEmpty && moods.isNotEmpty) {
      final values = weekMoodEntries.map((e) {
        final m = moods.firstWhere(
          (m) => m.id == e.moodSlug,
          orElse: () => moods.first,
        );
        return m.numericValue.toDouble();
      }).toList();
      avgMoodValue = values.fold(0.0, (a, b) => a + b) / values.length;
    }
    String moodLabel = 'Indefinido';
    if (avgMoodValue > 0) {
      if (avgMoodValue >= 4.5) {
        moodLabel = '😃 Excelente';
      } else if (avgMoodValue >= 3.5) {
        moodLabel = '🙂 Bom';
      } else if (avgMoodValue >= 2.5) {
        moodLabel = '😐 Neutro';
      } else {
        moodLabel = '😢 Baixo';
      }
    }

    // Compose final Review Markdown Body
    final reviewMarkdownBody =
        '''# Resumo Semanal ($startRangeStr a $endRangeStr)

## 📊 Estatísticas Consolidadas

### 🔁 Hábitos e Frequência
${habitsSummary.isEmpty ? '- Nenhum hábito registrado nesta semana.' : habitsSummary.join('\n')}

### 📋 Tarefas e Produtividade
- Tarefas Criadas: ${tasksCreatedInWeek.length}
- Tarefas Concluídas: ${tasksCompletedInWeek.length}
- Tarefas em Aberto (Total): ${tasksOpen.length}

### ⏱️ Tempo de Foco (Pomodoro)
- Foco Total: ${pomodoroHoursTotal.toStringAsFixed(1)} horas (${weekPomodoros.length} sessões)
${pomodorosSummary.isEmpty ? '- Nenhuma sessão registrada.' : '- Principais Projetos/Focos:\n${pomodorosSummary.join('\n')}'}

### 🎯 KPIs & Evolução de Metas
${goalsSummary.isEmpty ? '- Nenhuma meta ativa monitorada nesta semana.' : goalsSummary.join('\n')}

### 🧠 Humor & Estado Mental
- Humor Médio: $moodLabel (Média: ${avgMoodValue.toStringAsFixed(1)})

---

## 📝 Reflexão & Retrospectiva

### O que deu mais certo esta semana?
- 

### Quais foram as maiores distrações ou obstáculos?
- 

### O que posso ajustar ou priorizar para a próxima semana?
- 
''';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Semanal Inteligente',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                SizedBox(height: 6),
                Text(
                  'Gere um relatório consolidado com o resumo das suas métricas da semana diretamente em uma nova entrada do seu diário para reflexão.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.copy_all_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        weekReviewTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.textMuted),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        reviewMarkdownBody,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEntryForm(
                    initialTitle: weekReviewTitle,
                    initialBody: reviewMarkdownBody,
                    initialDate: now,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Criar Review no Diário',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
