// lib/ui/screens/trackers_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../forms/create_record_form.dart';
import '../forms/create_tracker_form.dart';
import 'universal_detail_view.dart';
import 'combined_analysis_screen.dart';
import '../widgets/object_action_wrapper.dart';
import 'package:intl/intl.dart';

class TrackersScreen extends ConsumerWidget {
  const TrackersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackers = ref.watch(trackersProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Trackers'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateTrackerForm(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monitor custom data points daily',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CombinedAnalysisScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(context),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.habitPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_graph_rounded,
                          color: AppColors.habitPurple,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Analysis',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Compare trackers, habits and mood',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildTrackerCard(context, ref, trackers[index]),
                childCount: trackers.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                "Today's Logs",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          _buildTodayRecords(ref, trackers),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildTrackerCard(
    BuildContext context,
    WidgetRef ref,
    dynamic tracker,
  ) {
    final color = _parseColor(tracker.color);
    final records = ref.watch(trackingRecordsProvider);
    final trackerRecords =
        records
            .where(
              (record) =>
                  record.trackerId == tracker.id ||
                  record.trackerId == tracker.slug ||
                  record.title == tracker.title,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final last = trackerRecords.isNotEmpty ? trackerRecords.first : null;
    final firstField = last?.fieldValues.entries.firstOrNull;

    return ObjectActionWrapper(
      object: tracker,
      child: Stack(
        children: [
          Container(
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UniversalDetailView(object: tracker),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.analytics_outlined,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textMutedColor(context),
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tracker.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tracker.description?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMutedColor(context),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (firstField != null) ...[
                            const Spacer(),
                            const Divider(height: 16),
                            Row(children: [
                              Expanded(child: Text(firstField.key, style: TextStyle(
                                fontSize: 10, color: AppTheme.textMutedColor(context)), maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                              Text(firstField.value.toString(),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                              const SizedBox(width: 6),
                              Text(DateFormat('d/M').format(last!.date),
                                style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(context))),
                            ]),
                          ] else ...[
                            const Spacer(),
                            const Divider(height: 16),
                            Text('Sem registros', style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(context))),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(bottom: 10, right: 10,
            child: GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CreateRecordForm(tracker: tracker)),
              child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35),
                    blurRadius: 8, offset: const Offset(0, 3))]),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 18)))),
        ],
      ),
    );
  }

  Widget _buildTodayRecords(WidgetRef ref, List<dynamic> trackers) {
    final records = ref.watch(trackingRecordsProvider);
    final today = DateTime.now();
    final todayRecords =
        records
            .where(
              (r) =>
                  r.date.year == today.year &&
                  r.date.month == today.month &&
                  r.date.day == today.day,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (todayRecords.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No logs today',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final record = todayRecords[index];
        final tracker = trackers
            .where(
              (t) =>
                  t.id == record.trackerId ||
                  t.slug == record.trackerId ||
                  t.title == record.trackerId,
            )
            .firstOrNull;
        if (tracker == null) return const SizedBox.shrink();

        final color = _parseColor(tracker.color);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(context),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_toggle_off_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracker.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${DateFormat('HH:mm').format(record.date)} • ${record.fieldValues.length} fields',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UniversalDetailView(object: tracker),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }, childCount: todayRecords.length),
    );
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return AppColors.primary;
    try {
      return Color(int.parse(colorStr.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
