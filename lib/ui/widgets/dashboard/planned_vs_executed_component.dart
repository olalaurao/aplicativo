import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/task_model.dart';
import '../../../models/pomodoro_session.dart';
import '../../../models/organizer_model.dart';
import '../../../models/shared_types.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';

class PlannedVsExecutedComponent extends ConsumerWidget {
  final DashboardBlock block;
  const PlannedVsExecutedComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = block.metadata['typeFilter'] as String? ?? 'area';
    final daysBack = block.metadata['daysBack'] as int? ?? 7;
    
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    final pomodoros = allObjects.whereType<PomodoroSession>().toList();
    final organizers = allObjects.whereType<Organizer>().toList();

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysBack));

    Map<String, double> plannedByGroup = {};
    Map<String, double> executedByGroup = {};

    // 1. Aggregate Planned (Tasks duration in minutes)
    for (final task in tasks) {
      if (task.duration == null || task.duration! <= 0) continue;
      final taskDate = task.startDate;
      if (taskDate == null || taskDate.isBefore(cutoff)) continue;

      OrganizerReference? linkedGroup;
      for (final o in task.organizers) {
        if (o.type == typeFilter) { linkedGroup = o; break; }
      }
      final groupSlug = linkedGroup?.slug ?? 'unassigned';
      plannedByGroup[groupSlug] = (plannedByGroup[groupSlug] ?? 0) + task.duration!;
    }

    // 2. Aggregate Executed (Pomodoros minutes)
    for (final session in pomodoros) {
      if (session.state != PomodoroSessionState.completed) continue;
      final effectiveDate = session.occurredAt ?? session.date;
      if (effectiveDate.isBefore(cutoff)) continue;
      
      String groupSlug = 'unassigned';
      if (session.linkedItemSlug != null) {
        for (final obj in allObjects) {
          if (obj.id == session.linkedItemSlug || obj.slug == session.linkedItemSlug) {
            for (final o in obj.organizers) {
              if (o.type == typeFilter) { groupSlug = o.slug; break; }
            }
            break;
          }
        }
      }

      executedByGroup[groupSlug] = (executedByGroup[groupSlug] ?? 0) + session.minutesWorked;
    }

    // Combine all groups
    final Set<String> allGroups = {};
    allGroups.addAll(plannedByGroup.keys);
    allGroups.addAll(executedByGroup.keys);

    final sortedGroups = allGroups.toList()
      ..sort((a, b) {
        double maxA = max(plannedByGroup[a] ?? 0, executedByGroup[a] ?? 0);
        double maxB = max(plannedByGroup[b] ?? 0, executedByGroup[b] ?? 0);
        return maxB.compareTo(maxA);
      });

    // Take top 5 for the chart
    final topGroups = sortedGroups.take(5).toList();
    if (topGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows_rounded, color: AppTheme.accentColor(context), size: 18),
                const SizedBox(width: 8),
                Text(
                  block.title ?? 'Planned vs Executed',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('No data for the period', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    double maxY = 0;
    for (final g in topGroups) {
      maxY = max(maxY, (plannedByGroup[g] ?? 0) / 60);
      maxY = max(maxY, (executedByGroup[g] ?? 0) / 60);
    }
    if (maxY == 0) maxY = 1;
    maxY = maxY * 1.2;

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < topGroups.length; i++) {
      final groupSlug = topGroups[i];
      final plannedH = (plannedByGroup[groupSlug] ?? 0) / 60;
      final executedH = (executedByGroup[groupSlug] ?? 0) / 60;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: plannedH,
              color: Colors.grey.withOpacity(0.4),
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: executedH,
              color: AppTheme.accentColor(context),
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
          barsSpace: 4,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows_rounded, color: AppTheme.accentColor(context), size: 18),
              const SizedBox(width: 8),
              Text(
                block.title ?? 'Planned vs Executed',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text('${value.toStringAsFixed(0)}h', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= topGroups.length) return const SizedBox.shrink();
                        final groupSlug = topGroups[idx];
                        String title = groupSlug;
                        if (groupSlug != 'unassigned') {
                          final org = organizers.where((o) => o.slug == groupSlug).firstOrNull;
                          title = org?.title ?? groupSlug;
                        }
                        if (title.length > 8) title = '${title.substring(0, 6)}..';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(title, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            children: [
              _LegendItem(color: Colors.grey.withOpacity(0.4), label: 'Planned (h)'),
              _LegendItem(color: AppTheme.accentColor(context), label: 'Executed (h)'),
            ],
          )
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
