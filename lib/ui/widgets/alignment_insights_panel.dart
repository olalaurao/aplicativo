// lib/ui/widgets/alignment_insights_panel.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../../models/alignment_log_entry.dart';
import '../../services/alignment_service.dart';

/// Widget displaying alignment insights with sparkline and insight sentences
class AlignmentInsightsPanel extends StatelessWidget {
  final String itemTitle;
  final List<AlignmentLogEntry> logs;
  final int? flexibilityWindowMinutes;

  const AlignmentInsightsPanel({
    super.key,
    required this.itemTitle,
    required this.logs,
    this.flexibilityWindowMinutes,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return _buildEmptyState(context);
    }

    final stats = AlignmentService.calculateAlignmentStats(logs);
    final insightSentence = AlignmentService.generateInsightSentence(itemTitle, stats);

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Routine Alignment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSparkline(context, logs),
          const SizedBox(height: 16),
          _buildStatsRow(stats),
          const SizedBox(height: 12),
          _buildInsightSentence(insightSentence),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Routine Alignment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'No alignment data yet for $itemTitle',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSparkline(BuildContext context, List<AlignmentLogEntry> logs) {
    // Sort logs by date
    final sortedLogs = List<AlignmentLogEntry>.from(logs);
    sortedLogs.sort((a, b) => a.date.compareTo(b.date));

    // Map states to colors
    final stateColors = {
      AlignmentState.aligned: AppColors.success,
      AlignmentState.drifting: AppColors.warning,
      AlignmentState.early: Colors.blue,
      AlignmentState.missed: AppColors.error,
    };

    return SizedBox(
      height: 80,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sortedLogs.length - 1).toDouble().clamp(1, double.infinity),
          minY: -1,
          maxY: 3,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(sortedLogs.length, (index) {
                final log = sortedLogs[index];
                final yValue = _stateToYValue(log.state);
                return FlSpot(index.toDouble(), yValue);
              }),
              isCurved: true,
              color: AppTheme.accentColor(context),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final log = sortedLogs[index];
                  final color = stateColors[log.state] ?? AppColors.textMuted;
                  return FlDotCirclePainter(
                    radius: 4,
                    color: color,
                    strokeWidth: 0,
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  double _stateToYValue(AlignmentState state) {
    switch (state) {
      case AlignmentState.early:
        return 2.0;
      case AlignmentState.aligned:
        return 1.0;
      case AlignmentState.drifting:
        return 0.0;
      case AlignmentState.missed:
        return -1.0;
    }
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    final aligned = stats['aligned'] as int;
    final total = stats['total'] as int;
    final alignmentRate = stats['alignmentRate'] as double;
    final averageDelta = stats['averageDelta'] as double;

    return Row(
      children: [
        _buildStatChip('On Time', '$aligned/$total', AppColors.success),
        const SizedBox(width: 8),
        _buildStatChip('Rate', '${alignmentRate.toStringAsFixed(0)}%', AppColors.primary),
        const SizedBox(width: 8),
        _buildStatChip('Avg Drift', '${averageDelta.toStringAsFixed(0)}m', AppColors.textSecondary),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightSentence(String sentence) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sentence,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
