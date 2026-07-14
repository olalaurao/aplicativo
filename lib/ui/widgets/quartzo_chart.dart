import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';

enum ChartType { line, bar, pie, heatmap }

class QuartzoChart extends StatelessWidget {
  final ChartType type;
  final List<ChartDataPoint> data;
  final List<List<ChartDataPoint>>? multiData;
  final String? title;
  final Color? color;
  final List<Color>? colors;

  const QuartzoChart({
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
    final seriesColors = colors ?? [color ?? AppTheme.accentColor(context)];
    final segments = <_LineSeriesSegment>[];
    for (final entry in series.asMap().entries) {
      final idx = entry.key;
      final d = entry.value;
      var current = <FlSpot>[];

      for (final pointEntry in d.asMap().entries) {
        final value = pointEntry.value.value;
        if (value == null) {
          if (current.isNotEmpty) {
            segments.add(_LineSeriesSegment(idx, current));
            current = <FlSpot>[];
          }
          continue;
        }
        current.add(FlSpot(pointEntry.key.toDouble(), value));
      }

      if (current.isNotEmpty) {
        segments.add(_LineSeriesSegment(idx, current));
      }
    }

    final lineBars = segments
        .map((segment) {
          final idx = segment.seriesIndex;
          final d = series[idx];
          return LineChartBarData(
            spots: segment.spots,
            isCurved: true,
            color: seriesColors[idx % seriesColors.length],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, spotIdx) {
                final pointIdx = spot.x.toInt();
                final hasEmoji =
                    pointIdx >= 0 &&
                    pointIdx < d.length &&
                    (d[pointIdx].emoji?.isNotEmpty ?? false);
                if (hasEmoji) {
                  // Use larger, colored dot when there is an emoji
                  return FlDotCirclePainter(
                    radius: 6,
                    color: seriesColors[idx % seriesColors.length],
                    strokeColor: Colors.white,
                    strokeWidth: 2,
                  );
                }
                return FlDotCirclePainter(
                  radius: 3,
                  color: seriesColors[idx % seriesColors.length],
                  strokeColor: seriesColors[idx % seriesColors.length]
                      .withValues(alpha: 0.3),
                  strokeWidth: 1,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: segment.spots.length > 1,
              color: seriesColors[idx % seriesColors.length].withValues(
                alpha: 0.1,
              ),
            ),
          );
        })
        .where((bar) => bar.spots.isNotEmpty)
        .toList();

    // Collect emoji annotations at points
    final List<ShowingTooltipIndicators> emojiAnnotations = [];
    for (var barIndex = 0; barIndex < segments.length; barIndex++) {
      final segment = segments[barIndex];
      final d = series[segment.seriesIndex];
      for (final spot in segment.spots) {
        final xi = spot.x.toInt();
        final point = d[xi];
        if (point.value != null && (point.emoji?.isNotEmpty ?? false)) {
          emojiAnnotations.add(
            ShowingTooltipIndicators([
              LineBarSpot(lineBars[barIndex], barIndex, spot),
            ]),
          );
        }
      }
    }

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
        showingTooltipIndicators: emojiAnnotations,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((barSpot) {
                final si = barSpot.barIndex;
                final xi = barSpot.x.toInt();
                if (si < 0 || si >= segments.length) return null;
                final d = series[segments[si].seriesIndex];
                final hasEmoji =
                    xi >= 0 &&
                    xi < d.length &&
                    (d[xi].emoji?.isNotEmpty ?? false);
                return LineTooltipItem(
                  hasEmoji
                      ? '${d[xi].emoji} ${barSpot.y.toStringAsFixed(1)}'
                      : barSpot.y.toStringAsFixed(1),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                );
              }).toList();
            },
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
        lineBarsData: lineBars,
      ),
    );
  }

  Widget _buildBarChart(BuildContext context) {
    final nonNullData = data
        .asMap()
        .entries
        .where((e) => e.value.value != null)
        .toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: nonNullData.isEmpty
            ? 1.0
            : nonNullData
                      .map((e) => e.value.value!)
                      .fold(0.0, (prev, curr) => curr > prev ? curr : prev) *
                  1.2,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: nonNullData
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.value!,
                    color: color ?? AppTheme.accentColor(context),
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
                value: e.value ?? 0,
                title: '${(e.value ?? 0).toInt()}',
                color: e.color ?? AppTheme.accentColor(context),
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
            final intensity = e.value?.clamp(0.0, 1.0);
            return Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: intensity != null && intensity > 0
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
  final double? value;
  final Color? color;

  /// Optional emoji — displayed as visual marker at line chart point
  final String? emoji;

  ChartDataPoint({
    required this.label,
    required this.value,
    this.color,
    this.emoji,
  });
}

class _LineSeriesSegment {
  final int seriesIndex;
  final List<FlSpot> spots;

  const _LineSeriesSegment(this.seriesIndex, this.spots);
}
