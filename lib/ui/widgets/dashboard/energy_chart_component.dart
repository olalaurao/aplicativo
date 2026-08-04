import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/task_model.dart';
import '../../../models/pomodoro_session.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';

class EnergyChartComponent extends ConsumerWidget {
  final DashboardBlock block;
  const EnergyChartComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeksBack = block.metadata['weeksBack'] as int? ?? 1;
    final daysBack = weeksBack * 7;
    
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    final pomodoros = allObjects.whereType<PomodoroSession>().toList();

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysBack));

    // Find the latest sleep task to determine wake time
    final sleepTasks = tasks.where((t) => t.slug.startsWith('sys-sleep') || (t.title.toLowerCase().contains('sleep') && t.scheduledTime != null)).toList();
    sleepTasks.sort((a, b) {
      final dateA = a.startDate ?? DateTime.now();
      final dateB = b.startDate ?? DateTime.now();
      return dateB.compareTo(dateA);
    });
    
    int wakeHour = 7; // default
    if (sleepTasks.isNotEmpty) {
      final st = sleepTasks.first;
      if (st.scheduledTime != null) {
        final parts = st.scheduledTime!.split(':');
        if (parts.isNotEmpty) {
          final h = int.tryParse(parts[0]) ?? 23;
          final dur = st.duration ?? 480;
          wakeHour = (h + (dur ~/ 60)) % 24;
        }
      }
    }

    // Calculate focused time per hour over the period
    List<double> focusPerHour = List.filled(24, 0.0);
    int daysCount = daysBack == 0 ? 1 : daysBack;

    for (final session in pomodoros) {
      if (session.state != PomodoroSessionState.completed) continue;
      final effectiveDate = session.occurredAt ?? session.date;
      if (effectiveDate.isBefore(cutoff)) continue;
      focusPerHour[effectiveDate.hour] += session.minutesWorked.toDouble();
    }
    
    for (int i = 0; i < 24; i++) {
      focusPerHour[i] = focusPerHour[i] / daysCount; // average per day
    }
    
    double maxFocus = focusPerHour.reduce(max);
    if (maxFocus == 0) maxFocus = 1;

    // Generate circadian energy curve (0 to 100)
    List<double> energyCurve = List.filled(24, 0.0);
    for (int i = 0; i < 24; i++) {
      int hSinceWake = (i - wakeHour) % 24;
      if (hSinceWake < 0) hSinceWake += 24;
      
      double val = 20.0; // sleep baseline
      if (hSinceWake <= 16) {
        if (hSinceWake <= 4)       val = 40 + (hSinceWake * 15.0);        // Rise to ~100
        else if (hSinceWake <= 8)  val = 100 - ((hSinceWake - 4) * 10.0); // Slump to ~60
        else if (hSinceWake <= 12) val = 60 + ((hSinceWake - 8) * 7.5);   // Afternoon peak ~90
        else                       val = 90 - ((hSinceWake - 12) * 17.5); // Drop to 20
      }
      energyCurve[i] = val.clamp(0.0, 100.0);
    }

    final int peakHour = (wakeHour + 4) % 24;
    final Color orangeColor = Colors.orange;

    List<FlSpot> energySpots = [];
    List<FlSpot> focusSpots = [];
    
    for (int i = 0; i < 24; i++) {
      energySpots.add(FlSpot(i.toDouble(), energyCurve[i]));
      focusSpots.add(FlSpot(i.toDouble(), (focusPerHour[i] / maxFocus) * 100));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: AppTheme.accentColor(context), size: 18),
              const SizedBox(width: 8),
              Text(
                block.title ?? 'Energy & Focus',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'Peak: ${peakHour.toString().padLeft(2, '0')}:00',
                style: TextStyle(fontSize: 11, color: AppTheme.accentColor(context), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 25,
                  verticalInterval: 6,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                  getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 6,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('${value.toInt()}h', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: energySpots,
                    isCurved: true,
                    color: orangeColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: focusSpots,
                    isCurved: true,
                    color: AppTheme.accentColor(context),
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.accentColor(context).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            children: [
              _LegendItem(color: orangeColor, label: 'Est. Energy'),
              _LegendItem(color: AppTheme.accentColor(context), label: 'Avg Focus (dashed)'),
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
