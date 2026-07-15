import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/dashboard_block.dart';
import '../../../providers/today_provider.dart';
import '../../../services/today_aggregator_service.dart';
import '../../theme.dart';
import '../../navigation/object_navigation.dart';

class TodayTimelineComponent extends ConsumerWidget {
  final DashboardBlock block;

  const TodayTimelineComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final items = ref.watch(todayItemsProvider(DateTime(now.year, now.month, now.day)));

    final maxItems = block.metadata['maxItems'] as int? ?? 12;
    final showUntimedGroup = block.metadata['showUntimedGroup'] as bool? ?? true;

    var displayItems = items;
    if (!showUntimedGroup) {
      displayItems = items.where((i) => !(i.timestamp.hour == 0 && i.timestamp.minute == 0 && i.timestamp.second == 0)).toList();
    }

    final hasMore = displayItems.length > maxItems;
    final visibleItems = displayItems.take(maxItems).toList();

    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 8),
                Text(
                  block.title.isNotEmpty ? block.title : 'Timeline do dia',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (visibleItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Nothing on your plate today yet', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.push('/planner'), // FAB's Plan tab is planner view
                    child: const Text('Plan today'),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleItems.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final isUntimed = item.timestamp.hour == 0 && item.timestamp.minute == 0 && item.timestamp.second == 0;
                
                // Agora header logic
                bool showAgora = false;
                if (!isUntimed) {
                  final isPast = item.timestamp.isBefore(now);
                  final isNextOrCurrent = !isPast;
                  if (index == 0 && isNextOrCurrent) {
                    showAgora = true;
                  } else if (index > 0) {
                    final prev = visibleItems[index - 1];
                    final prevUntimed = prev.timestamp.hour == 0 && prev.timestamp.minute == 0 && prev.timestamp.second == 0;
                    if ((prev.timestamp.isBefore(now) || prevUntimed) && isNextOrCurrent) {
                      showAgora = true;
                    }
                  }
                }

                return Column(
                  children: [
                    if (showAgora)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Text(
                              'agora ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Divider(color: AppColors.accent.withValues(alpha: 0.3), thickness: 1)),
                          ],
                        ),
                      ),
                    InkWell(
                      onTap: () => navigateToObject(context, item.source),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Time rail
                            SizedBox(
                              width: 50,
                              child: isUntimed
                                  ? const SizedBox.shrink()
                                  : Text(
                                      '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.textMuted),
                                    ),
                            ),
                            // Line and dot
                            Column(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(top: 6, right: 10),
                                  decoration: BoxDecoration(
                                    color: item.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            // Content
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(item.iconData, size: 16, color: item.color),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                        fontWeight: (item.origin == TodayItemOrigin.scheduled && item.timestamp.isAfter(now))
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    item.origin == TodayItemOrigin.created ? Icons.schedule_rounded : Icons.bolt_rounded,
                                    size: 12,
                                    color: AppColors.textMuted.withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          if (hasMore)
            InkWell(
              onTap: () => context.push('/planner?date=today'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '+${displayItems.length - maxItems} more · View full day in Planner',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.accent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
