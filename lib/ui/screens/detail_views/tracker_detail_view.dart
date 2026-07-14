// lib/ui/screens/detail_views/tracker_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/tracker_model.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../../widgets/tracker_metric_card.dart';
import '../../widgets/quartzo_chart.dart';
import '../../../models/content_object.dart';

/// TrackerDefinition-specific content section for universal detail view
List<Widget> buildTrackerContentSection(
  BuildContext context,
  WidgetRef ref,
  TrackerDefinition tracker,
  Function(String) parseColor,
  Function(DateTime, DateTime) isSameDay,
  void Function(BuildContext, WidgetRef, TrackerDefinition, TrackingRecord) showRecordDetails,
) {
  final trackerRecords = ref.watch(
    trackingRecordsProvider.select((records) => records
        .where(
          (r) =>
              r.trackerId == tracker.id ||
              r.trackerId == tracker.slug ||
              r.trackerId == tracker.title,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)))
  );

  return [
    // ─── Summaries ───
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'General Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tracker.sections.expand((s) => s.inputFields).map(
                  (field) {
                    final values = trackerRecords
                        .map((r) => r.fieldValues[field.id])
                        .whereType<num>()
                        .map((n) => n.toDouble())
                        .toList();

                    final latestValue = trackerRecords.isNotEmpty
                        ? trackerRecords.first.fieldValues[field.id]
                        : null;

                    return TrackerMetricCard(
                      definition: tracker,
                      fieldId: field.id,
                      value: latestValue,
                      history: values.reversed.toList(),
                    );
                  },
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    ),

    // ─── Distribution ───
    ...tracker.sections
        .expand((s) => s.inputFields)
        .where(
          (f) =>
              f.type == InputFieldType.selection ||
              f.type == InputFieldType.checklist,
        )
        .map((field) {
          final Map<String, int> counts = {};
          for (var r in trackerRecords) {
            final val = r.fieldValues[field.id];
            if (val is String) {
              counts[val] = (counts[val] ?? 0) + 1;
            } else if (val is List) {
              for (var item in val) {
                if (item is String) {
                  counts[item] = (counts[item] ?? 0) + 1;
                }
              }
            }
          }

          if (counts.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distribution: ${field.title}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: QuartzoChart(
                      type: ChartType.pie,
                      data: counts.entries
                          .map(
                            (e) => ChartDataPoint(
                              label: e.key,
                              value: e.value.toDouble(),
                              color:
                                  Colors.primaries[counts.keys
                                          .toList()
                                          .indexOf(e.key) %
                                      Colors.primaries.length],
                            ),
                          )
                          .toList(),
                    ),
                  )
                ],
              ),
            ),
          );
        }),

    // ─── Activity Heatmap ───
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              height: 130,
              width: double.infinity,
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(16),
              child: QuartzoChart(
                type: ChartType.heatmap,
                color: parseColor(tracker.color),
                data: List.generate(30, (i) {
                  final date = DateTime.now().subtract(
                    Duration(days: 29 - i),
                  );
                  final count = trackerRecords
                      .where((r) => isSameDay(r.date, date))
                      .length;
                  return ChartDataPoint(label: '', value: count.toDouble());
                }),
              ),
            ),
          ],
        ),
      ),
    ),

    // ─── Records List ───
    const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
        child: Text(
          'Records History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final record = trackerRecords[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: InkWell(
            onTap: () => showRecordDetails(context, ref, tracker, record),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(context),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: parseColor(
                        tracker.color,
                      ).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: parseColor(tracker.color),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'dd MMM yyyy HH:mm',
                          ).format(record.date),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${record.fieldValues.length} fields filled',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      }, childCount: trackerRecords.length),
    ),
  ];
}
