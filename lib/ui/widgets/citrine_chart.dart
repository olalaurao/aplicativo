import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';

enum ChartType { line, bar, pie, heatmap }

class CitrineChart extends StatelessWidget {
  final ChartType type;
  final List<ChartDataPoint> data;
  final List<List<ChartDataPoint>>? multiData;
  final String? title;
  final Color? color;
  final List<Color>? colors;

  const CitrineChart({
    super.key,
    required this.type,
    required this.data,
    this.multiData,
    this.title,
    this.color,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(child: _buildChart(context)),
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    switch (type) {
      case ChartType.line:
        return _buildLineChart(context);
      case ChartType.bar:
        return _buildBarChart(context);
      case ChartType.pie:
        return _buildPieChart(context);
      case ChartType.heatmap:
        return _buildHeatmap(context);
    }
  }

  Widget _buildLineChart(BuildContext context) {
    final series = multiData ?? [data];
    final seriesColors = colors ?? [color ?? AppColors.primary];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: data.length > 7 ? 3 : 1,
              getTitlesWidget: (val, meta) {
                if (val.toInt() < 0 || val.toInt() >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data[val.toInt()].label,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.textMutedColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: series.asMap().entries.map((entry) {
          final idx = entry.key;
          final d = entry.value;
          return LineChartBarData(
            spots: d
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                .toList(),
            isCurved: true,
            color: seriesColors[idx % seriesColors.length],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: d.length < 15),
            belowBarData: BarAreaData(
              show: true,
              color: seriesColors[idx % seriesColors.length].withValues(
                alpha: 0.1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.isEmpty
            ? 1.0
            : data
                      .map((e) => e.value)
                      .fold(0.0, (prev, curr) => curr > prev ? curr : prev) *
                  1.2,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: data
            .asMap()
            .entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.value,
                    color: color ?? AppColors.primary,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: data
            .map(
              (e) => PieChartSectionData(
                value: e.value,
                title: '${e.value.toInt()}',
                color: e.color ?? AppColors.primary,
                radius: 50,
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 7;
        const spacing = 4.0;
        final availableWidth = constraints.maxWidth;
        // Limit max cell size to 32 to avoid huge squares on wide screens
        final cellSize =
            ((availableWidth - (spacing * (crossAxisCount - 1))) /
                    crossAxisCount)
                .clamp(10.0, 32.0);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: data.map((e) {
            final intensity = (e.value).clamp(0.0, 1.0);
            return Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: intensity > 0
                    ? color?.withValues(alpha: 0.2 + (intensity * 0.8))
                    : AppTheme.surfaceVariantColor(
                        context,
                      ).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class ChartDataPoint {
  final String label;
  final double value;
  final Color? color;

  ChartDataPoint({required this.label, required this.value, this.color});
}
