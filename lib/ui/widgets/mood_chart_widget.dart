// lib/ui/widgets/mood_chart_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/vault_provider.dart';
import '../../models/journal_entry.dart';
import '../../models/mood_model.dart';
import '../theme.dart';

class MoodChartWidget extends ConsumerWidget {
  const MoodChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjectsAsync = ref.watch(allObjectsProvider);

    return allObjectsAsync.when(
      data: (objects) {
        final entries = objects.whereType<JournalEntry>().toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final moods = objects.whereType<MoodDefinition>().toList();

        if (entries.isEmpty) {
          return const Center(
            child: Text(
              'No mood data yet',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          );
        }

        final recentEntries = entries.length > 7
            ? entries.sublist(entries.length - 7)
            : entries;

        return LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: recentEntries.asMap().entries.map((e) {
                  final mood = moods.firstWhere(
                    (m) => m.id == e.value.moodSlug,
                    orElse: () => MoodDefinition(
                      title: '',
                      label: '',
                      emoji: '',
                      color: '',
                      order: 0,
                      quadrant: MoodQuadrant.green,
                      pleasantness: 3,
                      energy: 3,
                    ),
                  );
                  return FlSpot(e.key.toDouble(), mood.numericValue.toDouble());
                }).toList(),
                isCurved: true,
                color: Theme.of(context).primaryColor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                ),
              ),
            ],
            minY: 0,
            maxY: 6,
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }
}
