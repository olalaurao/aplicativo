import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/tracker_model.dart';
import '../../../models/mood_model.dart';
import '../../../models/content_object.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';

class TrackerAnalysisComponent extends ConsumerWidget {
  final DashboardBlock block;
  const TrackerAnalysisComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackerId = block.metadata['trackerId'] as String?;
    final trackerTitle = block.metadata['trackerTitle'] as String? ?? 'Tracker';
    final chartType = block.metadata['chartType'] as String? ?? 'bar';
    final daysBack = block.metadata['daysBack'] as int? ?? 30;

    if (trackerId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(context),
        child: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: AppColors.textMuted),
            const SizedBox(width: 12),
            const Text(
              'No tracker selected — configure this block',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final records = ref.watch(trackingRecordsProvider);
    final cutoff = DateTime.now().subtract(Duration(days: daysBack));

    // Find the tracker/mood object
    final ContentObject? trackerObj = allObjects.cast<ContentObject?>().firstWhere(
      (o) => o?.id == trackerId,
      orElse: () => null,
    );

    // Aggregate daily numeric values
    final Map<String, double> dailyValues = {};
    for (final record in records) {
      if (record.trackerId != trackerId) continue;
      if (record.date.isBefore(cutoff)) continue;
      final dateKey = record.date.toIso8601String().split('T').first;
      // Try to extract a numeric value from the first numeric field
      for (final field in record.fieldValues.values) {
        final parsed = double.tryParse(field.toString());
        if (parsed != null) {
          dailyValues[dateKey] = (dailyValues[dateKey] ?? 0) + parsed;
          break;
        }
      }
    }

    if (dailyValues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trackerTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'No data in the last $daysBack days',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final sortedKeys = dailyValues.keys.toList()..sort();
    final spots = sortedKeys.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), dailyValues[e.value] ?? 0);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                trackerObj is MoodDefinition
                    ? Icons.emoji_emotions_outlined
                    : Icons.bar_chart_rounded,
                color: AppTheme.accentColor(context),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                trackerTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'Last $daysBack days',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: chartType == 'line'
                ? LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppTheme.accentColor(context),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  )
                : BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: spots
                          .map((s) => BarChartGroupData(
                                x: s.x.toInt(),
                                barRods: [
                                  BarChartRodData(
                                    toY: s.y,
                                    color: AppTheme.accentColor(context),
                                    width: 6,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            '${dailyValues.length} entries · avg ${(dailyValues.values.fold(0.0, (a, b) => a + b) / dailyValues.length).toStringAsFixed(1)}',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
