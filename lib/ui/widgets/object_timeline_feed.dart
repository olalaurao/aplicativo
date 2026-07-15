// lib/ui/widgets/object_timeline_feed.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/timeline_aggregator_service.dart';
import '../../models/shared_types.dart';
import '../theme.dart';
import '../utils/object_icons.dart';
import 'object_action_wrapper.dart';

class ObjectTimelineFeed extends ConsumerWidget {
  final List<TodayItem> items;
  final Function(TodayItem)? onTap;
  final bool showDateSeparators;
  final int? maxItems;
  final Widget Function(BuildContext, WidgetRef, TodayItem)? itemBuilder;
  final Widget Function()? emptyStateBuilder;
  final Map<String, TypeSignature> typeSignatures;

  const ObjectTimelineFeed({
    super.key,
    required this.items,
    this.onTap,
    this.showDateSeparators = true,
    this.maxItems,
    this.itemBuilder,
    this.emptyStateBuilder,
    this.typeSignatures = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayItems = maxItems != null ? items.take(maxItems!).toList() : items;

    if (displayItems.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final item = displayItems[index];
        final showDate = !showDateSeparators
            ? false
            : index == 0 ||
                !_isSameDay(
                  item.date,
                  displayItems[index - 1].date,
                );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDate) _buildDateSeparator(context, item.date),
            itemBuilder != null
                ? itemBuilder!(context, ref, item)
                : _buildTimelineItem(context, ref, item),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    if (emptyStateBuilder != null) {
      return emptyStateBuilder!();
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          const Text(
            'No items found',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(BuildContext context, DateTime date) {
    final isToday = _isSameDay(date, DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        isToday ? 'Today' : DateFormat('EEEE, d MMMM').format(date),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, WidgetRef ref, TodayItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onTap?.call(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOriginIcon(context, item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(item.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOriginIcon(BuildContext context, TodayItem item) {
    final iconData = ObjectIcons.iconDataForTypeWithSignatures(item.kind.name, typeSignatures);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.accentColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            iconData ?? ObjectIcons.defaultIconDataForType(item.kind.name),
            size: 18,
            color: AppTheme.accentColor(context),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Text(
              item.originGlyph,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
