// lib/ui/screens/detail_views/habit_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/habit_model.dart';
import '../../providers/vault_provider.dart';
import '../widgets/property_grid.dart';
import '../theme.dart';

/// Habit-specific detail view methods extracted from universal_detail_view.dart
class HabitDetailView {
  /// Build property cards specific to Habit objects
  static List<PropertyCard> buildPropertyCards(
    BuildContext context,
    Habit habit,
  ) {
    final cards = <PropertyCard>[];
    
    if (!habit.isChecklistHabit) {
      cards.add(PropertyCard(
        icon: Icons.repeat,
        label: 'Frequência',
        value: habit.scheduler?.rules.isNotEmpty == true ? habit.scheduler!.rules.first.repeatType.name : 'Não definida',
        state: habit.scheduler == null || habit.scheduler!.rules.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
      ));
      cards.add(PropertyCard(
        icon: Icons.local_fire_department,
        label: 'Streak',
        value: '${habit.streak} 🔥',
        state: habit.streak > 0 ? PropertyCardState.streakActive : PropertyCardState.normal,
      ));
      cards.add(PropertyCard(
        icon: Icons.history,
        label: 'Último registro',
        value: habit.daysSinceLastCompletion == 0 ? 'Hoje' : '${habit.daysSinceLastCompletion} dias atrás',
        state: habit.completionHistory.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
      ));
      cards.add(PropertyCard(
        icon: Icons.category,
        label: 'Categoria',
        value: habit.categories.isNotEmpty ? habit.categories.first : 'Não definida',
        state: habit.categories.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
      ));
    }
    
    return cards;
  }

  /// Build content slivers specific to Habit objects
  static List<Widget> buildContentSlivers(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    Widget Function(BuildContext, WidgetRef, Habit) buildHabitChecklistSliver,
    Widget Function(BuildContext, WidgetRef, Habit) buildHabitNormalSliver,
    Widget Function(BuildContext, WidgetRef, Habit) buildHabitLinkedItemsSliver,
  ) {
    final linkedSliver = buildHabitLinkedItemsSliver(context, ref, habit);
    
    if (habit.isChecklistHabit) {
      return [
        buildHabitChecklistSliver(context, ref, habit),
        linkedSliver,
      ];
    }
    
    return [
      buildHabitNormalSliver(context, ref, habit),
      linkedSliver,
    ];
  }

  /// Build habit checklist sliver for checklist habits
  static Widget buildHabitChecklistSliver(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    Function(String) parseColor,
  ) {
    final today = DateTime.now();
    final dateStr = today.toIso8601String().split('T').first;
    final dailyData = ref.watch(dailyNoteDataProvider(dateStr));
    final habitsMap = (dailyData['habits'] as Map<String, dynamic>?) ?? const {};
    final rawVal = habitsMap[habit.slug];
    final checklistState = habit.resolveChecklistState(rawVal);
    final doneCount = checklistState.values.where((v) => v).length;
    final total = habit.totalChecklistItems;
    final progress = total > 0 ? doneCount / total : 0.0;
    final habitColor = parseColor(habit.color);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, d MMM').format(today),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    builder: (context, value, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 5,
                          color: habitColor,
                          backgroundColor: habitColor.withValues(alpha: 0.15),
                        ),
                        Text(
                          '${(value * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: habitColor,
                backgroundColor: habitColor.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$doneCount de $total tarefas',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (habit.streak > 0)
                  Text(
                    '${habit.streak} 🔥',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...checklistState.entries.map((entry) {
              final index = habit.checklistItems.indexWhere((item) => item == entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: AppTheme.surfaceColor(context),
                  leading: Checkbox(
                    value: entry.value,
                    onChanged: (val) {
                      // Toggle checklist item
                      final newState = Map<String, bool>.from(checklistState);
                      newState[entry.key] = val ?? false;
                      // Update daily note
                      // This would need to be implemented with the actual update logic
                    },
                  ),
                  title: Text(entry.key),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Build habit normal sliver for non-checklist habits
  static Widget buildHabitNormalSliver(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    Function(String) parseColor,
    Widget Function(Habit) buildHabitFrequencyChart,
    Widget Function(Habit) buildHabitNumericTrendChart,
    Widget Function(BuildContext, WidgetRef, Habit, dynamic) buildHabitPeriodSlots,
  ) {
    final today = DateTime.now();
    final dateStr = today.toIso8601String().split('T').first;
    final dailyData = ref.watch(dailyNoteDataProvider(dateStr));
    final habitsMap = (dailyData['habits'] as Map<String, dynamic>?) ?? const {};
    final todayVal = habitsMap[habit.slug];
    final habitColor = parseColor(habit.color);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertiesCard(
              context: context,
              title: 'Hoje',
              icon: Icons.today_outlined,
              rows: [
                _PropRow(
                  label: 'Progresso',
                  value: '${(habit.dailyGoal > 0 ? (habit.isCompletedToday ? 1.0 : 0.0) * 100 : 0).round()}%',
                  trailing: SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: habit.isCompletedToday ? 1.0 : 0.3,
                      color: habitColor,
                      backgroundColor: habitColor.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ],
            ),
            if (habit.slots.isNotEmpty) ...[
              const SizedBox(height: 8),
              buildHabitPeriodSlots(context, ref, habit, todayVal),
            ],
            const SizedBox(height: 16),
            const Text(
              'Atividade (30d)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: habit.inputType == HabitInputType.boolean
                  ? buildHabitFrequencyChart(habit)
                  : buildHabitNumericTrendChart(habit),
            ),
          ],
        ),
      ),
    );
  }

  /// Build habit period slots
  static Widget buildHabitPeriodSlots(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    dynamic todayVal,
  ) {
    final groups = <String, List<(int index, HabitSlot slot)>>{
      'manha': [],
      'tarde': [],
      'noite': [],
      'indefinido': [],
    };
    for (var i = 0; i < habit.slots.length; i++) {
      final slot = habit.slots[i];
      final hour = slot.time?.hour;
      final period = hour == null
          ? 'indefinido'
          : hour >= 5 && hour <= 11
          ? 'manha'
          : hour >= 12 && hour <= 17
          ? 'tarde'
          : 'noite';
      groups[period]!.add((i, slot));
    }

    final labels = {
      'manha': '🌅 Manhã',
      'tarde': '☀️ Tarde',
      'noite': '🌙 Noite',
      'indefinido': 'Indefinido',
    };

    List<bool> slotStates = [];
    if (todayVal is List) {
      slotStates = todayVal.map((e) => e == true || e == 'true').toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.where((e) => e.value.isNotEmpty).map((entry) {
        final period = entry.key;
        final slots = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labels[period]!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((item) {
                  final index = item.$1;
                  final slot = item.$2;
                  final isDone = index < slotStates.length ? slotStates[index] : false;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDone 
                          ? AppTheme.accentColor(context).withValues(alpha: 0.2)
                          : AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDone 
                            ? AppTheme.accentColor(context)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      slot.label ?? 'Slot ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDone 
                            ? AppTheme.accentColor(context)
                            : AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Build habit frequency chart
  static Widget buildHabitFrequencyChart(Habit habit) {
    final today = DateTime.now();
    final data = List.generate(30, (i) {
      final date = today.subtract(Duration(days: 29 - i));
      final hasEntry = habit.completionHistory.any(
        (e) => _isSameDay(e.date, date),
      );
      return ChartDataPoint(
        label: '',
        value: hasEntry ? 1.0 : 0.0,
      );
    });

    return BarChart(
      BarChartData(
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: entry.value.value > 0 
                    ? AppTheme.accentColor(BuildContext as BuildContext)
                    : AppColors.surfaceVariant,
                width: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  /// Build habit numeric trend chart
  static Widget buildHabitNumericTrendChart(Habit habit) {
    final history = habit.completionHistory
        .where((r) => r.value != null)
        .toList();

    if (history.isEmpty) {
      return const Center(child: Text('Sem dados'));
    }

    final data = history.map((r) => ChartDataPoint(
      label: DateFormat('d MMM').format(r.date),
      value: r.value!.toDouble(),
    )).toList();

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value);
            }).toList(),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  // Private helper methods

  static bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  static Widget _buildPropertiesCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<_PropRow> rows,
  }) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => _buildPropRow(context, row)),
        ],
      ),
    );
  }

  static Widget _buildPropRow(BuildContext context, _PropRow row) {
    final valueColor = row.isOverdue
        ? AppColors.error
        : row.isEmpty
        ? AppColors.textMuted.withValues(alpha: 0.4)
        : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            row.label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          if (row.trailing != null)
            row.trailing!
          else
            GestureDetector(
              onTap: row.onTap,
              child: Text(
                row.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                  fontStyle: row.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Helper classes
class _PropRow {
  final String label;
  final String value;
  final bool isEmpty;
  final bool isOverdue;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _PropRow({
    required this.label,
    required this.value,
    this.isEmpty = false,
    this.isOverdue = false,
    this.onTap,
    this.trailing,
  });
}

class ChartDataPoint {
  final String label;
  final double value;

  ChartDataPoint({required this.label, required this.value});
}
