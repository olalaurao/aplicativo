import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/task_model.dart';
import '../../../models/organizer_model.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../../../services/time_balance_aggregator.dart';

class WhereTimeGoesComponent extends ConsumerWidget {
  final DashboardBlock block;
  const WhereTimeGoesComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showOther = block.metadata['showOther'] as bool? ?? true;

    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    final organizers = allObjects.whereType<Organizer>().toList();
    
    final now = DateTime.now();
    final startOfPeriod = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final endOfPeriod = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    // Always group by area for 'Where Time Goes' to get root organizers
    final agg = TimeBalanceAggregator.aggregate(
      tasks: tasks,
      organizers: organizers,
      startDate: startOfPeriod,
      endDate: endOfPeriod,
      typeFilters: ['area'],
    );

    // Top 4 + Other
    final entries = agg.byGroup.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    
    final top4 = entries.take(4).toList();
    final otherEntries = entries.skip(4).toList();
    double otherValue = otherEntries.fold(0.0, (sum, e) => sum + e.value);

    final List<Color> palette = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
    ];

    List<PieChartSectionData> pieSections = [];
    int cIdx = 0;
    
    void addSection(String title, double value, Color color) {
      if (value <= 0) return;
      pieSections.add(
        PieChartSectionData(
          color: color,
          value: value,
          title: '${(value / 60).toStringAsFixed(1)}h',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        )
      );
    }

    addSection('Wildcard', agg.totalWildcard, AppColors.textMuted);
    
    for (final e in top4) {
      final org = organizers.firstWhere((o) => o.slug == e.key, orElse: () => Organizer(id: '', title: e.key, organizerType: OrganizerType.area));
      addSection(org.title, e.value, palette[cIdx % palette.length]);
      cIdx++;
    }

    if (showOther && otherValue > 0) {
      addSection('Other', otherValue, Colors.brown);
    }

    addSection('Open', agg.openTime, Colors.grey.withOpacity(0.2));

    // Fill the bottom half with empty if we want a semicircle, but fl_chart doesn't support start degree offset easily
    // We will just draw a full donut chart

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_rounded, color: AppTheme.accentColor(context), size: 18),
              const SizedBox(width: 8),
              Text(
                block.title ?? 'Where Your Time Goes',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: pieSections,
              ),
            )
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendItem(color: AppColors.textMuted, label: 'Wildcard'),
              _LegendItem(color: Colors.grey.withOpacity(0.2), label: 'Open'),
              ...top4.asMap().entries.map((e) {
                final org = organizers.firstWhere((o) => o.slug == e.value.key, orElse: () => Organizer(id: '', title: e.value.key, organizerType: OrganizerType.area));
                return _LegendItem(color: palette[e.key % palette.length], label: org.title);
              }),
              if (showOther && otherValue > 0)
                const _LegendItem(color: Colors.brown, label: 'Other'),
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
