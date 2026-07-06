import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/tracker_model.dart';
import '../theme.dart';

class TrackerMetricCard extends StatelessWidget {
  final TrackerDefinition definition;
  final dynamic value;
  final List<double>? history;
  final String fieldId;

  const TrackerMetricCard({
    super.key,
    required this.definition,
    required this.value,
    this.history,
    required this.fieldId,
  });

  @override
  Widget build(BuildContext context) {
    final field = _getField();
    if (field == null) return const SizedBox.shrink();

    final trackerColor = _parseColor(definition.color);

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      width: 140,
      decoration: BoxDecoration(
        color: trackerColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: trackerColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (definition.icon != null) ...[
                Text(definition.icon!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  field.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: trackerColor.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildValueDisplay(field, trackerColor),
          const SizedBox(height: 8),
          if (history != null && history!.length > 1)
            SizedBox(height: 24, child: _buildSparkline(trackerColor)),
        ],
      ),
    );
  }

  InputField? _getField() {
    for (var section in definition.sections) {
      for (var f in section.inputFields) {
        if (f.id == fieldId) return f;
      }
    }
    return null;
  }

  Widget _buildValueDisplay(InputField field, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSpecificGraphic(field, color),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                _formatValue(field),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (field.unit != null && field.unit!.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                field.unit!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSpecificGraphic(InputField field, Color color) {
    switch (field.type) {
      case InputFieldType.mood:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value?.toString() ?? '😶',
            style: const TextStyle(fontSize: 20),
          ),
        );

      case InputFieldType.duration:
        final mins = (value as num?)?.toDouble() ?? 0.0;
        final progress = (mins / 480).clamp(
          0.0,
          1.0,
        ); // 8h default max for visualization
        return SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Icon(Icons.access_time_rounded, size: 14, color: color),
            ],
          ),
        );

      case InputFieldType.range:
        final val = (value as num?)?.toDouble() ?? 0.0;
        final min = field.min ?? 0.0;
        final max = field.max ?? 10.0;
        final progress = ((val - min) / (max - min)).clamp(0.0, 1.0);
        return Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );

      case InputFieldType.quantity:
        if (field.max != null) {
          final progress = ((value as num?)?.toDouble() ?? 0.0) / field.max!;
          return ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          );
        }
        return const SizedBox(height: 4);

      default:
        return const SizedBox(height: 4);
    }
  }

  String _formatValue(InputField field) {
    if (value == null) return '--';

    switch (field.type) {
      case InputFieldType.checkbox:
        return (value as bool) ? 'Yes' : 'No';
      case InputFieldType.mood:
        return ''; // Handled by graphic
      case InputFieldType.duration:
        final mins = (value as num?)?.toInt() ?? 0;
        if (mins >= 60) {
          final h = mins ~/ 60;
          final m = mins % 60;
          return '${h}h${m > 0 ? '${m}m' : ''}';
        }
        return '${mins}m';
      case InputFieldType.quantity:
      case InputFieldType.range:
        if (value is num) {
          if (value % 1 == 0) return value.toInt().toString();
          return value.toStringAsFixed(1);
        }
        return value.toString();
      default:
        return value.toString();
    }
  }

  Widget _buildSparkline(Color color) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: history!
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String color) {
    try {
      return Color(int.parse(color.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
