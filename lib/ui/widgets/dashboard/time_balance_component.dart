import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/task_model.dart';
import '../../../models/organizer_model.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../../../services/time_balance_aggregator.dart';

class TimeBalanceComponent extends ConsumerWidget {
  final DashboardBlock block;
  const TimeBalanceComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMode = block.metadata['displayMode'] as String? ?? 'percent';
    final typeFilter = block.metadata['typeFilter'] as String? ?? 'area'; // area, project, etc
    final chartType = block.metadata['chartType'] as String? ?? 'pie';

    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    final organizers = allObjects.whereType<Organizer>().toList();
    
    // Period: last 7 days including today
    final now = DateTime.now();
    final startOfPeriod = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final endOfPeriod = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    final agg = TimeBalanceAggregator.aggregate(
      tasks: tasks,
      organizers: organizers,
      startDate: startOfPeriod,
      endDate: endOfPeriod,
      typeFilter: typeFilter,
    );

    final totalWildcard = agg.totalWildcard;
    final byGroup = agg.byGroup;
    final openTime = agg.openTime;
    final totalMinutesInPeriod = agg.totalMinutesInPeriod;

    // Prepare chart data
    List<PieChartSectionData> pieSections = [];
    int colorIndex = 0;
    
    final List<Color> palette = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.cyan,
      Colors.pink,
    ];

    void addSection(String title, double value, Color color) {
      if (value <= 0) return;
      if (chartType == 'pie') {
        pieSections.add(
          PieChartSectionData(
            color: color,
            value: value,
            title: displayMode == 'percent' 
                ? '${((value / totalMinutesInPeriod) * 100).toStringAsFixed(1)}%' 
                : '${(value / 60).toStringAsFixed(1)}h',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          )
        );
      }
    }

    addSection('Wildcard', totalWildcard, AppColors.textMuted);
    
    byGroup.forEach((groupId, value) {
      final org = organizers.firstWhere((o) => o.slug == groupId, orElse: () => Organizer(id: '', title: groupId, organizerType: OrganizerType.area));
      addSection(org.title, value, palette[colorIndex % palette.length]);
      colorIndex++;
    });

    addSection('Open', openTime, Colors.grey.withOpacity(0.2));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: AppTheme.accentColor(context), size: 18),
              const SizedBox(width: 8),
              Text(
                block.title ?? 'Time Balance',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: chartType == 'pie'
                ? PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: pieSections,
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.center,
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: totalMinutesInPeriod.toDouble(),
                              rodStackItems: _buildStackItems(totalWildcard, byGroup, openTime, palette),
                              width: 30,
                            )
                          ]
                        )
                      ],
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                    )
                  ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendItem(color: AppColors.textMuted, label: 'Wildcard'),
              _LegendItem(color: Colors.grey.withOpacity(0.2), label: 'Open'),
              ...byGroup.entries.toList().asMap().entries.map((e) {
                final org = organizers.firstWhere((o) => o.slug == e.value.key, orElse: () => Organizer(id: '', title: e.value.key, organizerType: OrganizerType.area));
                return _LegendItem(color: palette[e.key % palette.length], label: org.title);
              }),
            ],
          )
        ],
      ),
    );
  }

  List<BarChartRodStackItem> _buildStackItems(double wildcard, Map<String, double> grouped, double open, List<Color> palette) {
    List<BarChartRodStackItem> items = [];
    double current = 0;
    
    if (wildcard > 0) {
      items.add(BarChartRodStackItem(current, current + wildcard, AppColors.textMuted));
      current += wildcard;
    }
    
    int cIdx = 0;
    for (final v in grouped.values) {
      if (v > 0) {
        items.add(BarChartRodStackItem(current, current + v, palette[cIdx % palette.length]));
        current += v;
        cIdx++;
      }
    }
    
    if (open > 0) {
      items.add(BarChartRodStackItem(current, current + open, Colors.grey.withOpacity(0.2)));
    }
    
    return items;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

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
