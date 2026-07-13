// lib/ui/screens/detail_views/mood_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/mood_model.dart';
import '../../../models/journal_entry.dart';
import '../../../models/content_object.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../../widgets/object_action_wrapper.dart';
import '../../widgets/quartzo_chart.dart';
import '../universal_detail_view.dart';

/// MoodDefinition-specific content section for universal detail view
List<Widget> buildMoodContentSection(
  BuildContext context,
  WidgetRef ref,
  MoodDefinition mood,
  Widget Function(List<JournalEntry>) buildMoodFrequencyChart,
  Widget Function(BuildContext, ContentObject) buildMentionRow,
) {
  final moodEntries = ref.watch(allEntriesProvider.select((entries) => entries.where((e) => e.moodSlug == mood.id).toList()..sort((a, b) => b.date.compareTo(a.date))));

  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mood Frequency',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: buildMoodFrequencyChart(moodEntries),
            ),
            const SizedBox(height: 24),
            const Text(
              'Monthly Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              width: double.infinity,
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(16),
              child: QuartzoChart(
                type: ChartType.heatmap,
                color: AppColors.habitPurple,
                data: List.generate(30, (i) {
                  final date = DateTime.now().subtract(
                    Duration(days: 29 - i),
                  );
                  final hasEntry = moodEntries.any(
                    (e) =>
                        e.moodSlug == mood.id && _isSameDay(e.date, date),
                  );
                  return ChartDataPoint(
                    label: '',
                    value: hasEntry ? 1.0 : 0.0,
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Entries',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (moodEntries.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No entries with this mood yet.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          final entry = moodEntries[index];
          return buildMentionRow(context, entry);
        }, childCount: moodEntries.isEmpty ? 1 : moodEntries.length),
      ),
    ),
  ];
}

bool _isSameDay(DateTime d1, DateTime d2) {
  return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
}
