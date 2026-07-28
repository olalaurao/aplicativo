import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/daily_schedule_provider.dart';
import '../../models/daily_schedule_snapshot.dart';
import '../theme.dart';
import '../utils/object_icons.dart';
import '../../providers/settings_provider.dart';

class PlannerWeekView extends ConsumerWidget {
  final DateTime selectedDate;

  const PlannerWeekView({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine the start of the week (Monday)
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final date = startOfWeek.add(Duration(days: index));
            return _buildDaySection(context, ref, date);
          },
          childCount: 7, // 7 days in a week
        ),
      ),
    );
  }

  Widget _buildDaySection(BuildContext context, WidgetRef ref, DateTime date) {
    final schedule = ref.watch(dailyScheduleProvider(date));
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    final allItems = [
      ...schedule.allDayItems,
      ...schedule.timedItems,
      ...schedule.completableItems
    ];
    
    // De-duplicate items based on object id, prioritizing timed items
    final uniqueItems = <String, DailyScheduleItem>{};
    for (final item in allItems) {
      if (!uniqueItems.containsKey(item.source.id) || item.startTime != null) {
        uniqueItems[item.source.id] = item;
      }
    }

    final sortedItems = uniqueItems.values.toList()
      ..sort((a, b) {
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return -1;
        if (b.startTime == null) return 1;
        return a.startTime!.compareTo(b.startTime!);
      });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: isToday ? Border.all(color: AppTheme.accentColor(context), width: 1.5) : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isToday ? AppTheme.accentColor(context) : AppTheme.surfaceVariantColor(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('EEEE, MMM d').format(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isToday ? Colors.white : AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              const Spacer(),
              if (sortedItems.isNotEmpty)
                Text(
                  '${sortedItems.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (sortedItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No items scheduled',
                style: TextStyle(color: AppTheme.textMutedColor(context), fontSize: 13),
              ),
            )
          else
            ...sortedItems.map((item) => _buildItemRow(context, ref, item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, WidgetRef ref, DailyScheduleItem item) {
    final settings = ref.watch(settingsProvider);
    final typeSignatures = settings.typeSignatures;
    
    final iconData = ObjectIcons.iconDataForTypeWithSignatures(item.source.type, typeSignatures) ??
        ObjectIcons.defaultIconDataForType(item.source.type);
    final color = ObjectIcons.colorForTypeWithSignatures(item.source.type, typeSignatures);

    return InkWell(
      onTap: () => context.push('/detail/${item.source.id}', extra: item.source),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (item.startTime != null) ...[
              SizedBox(
                width: 45,
                child: Text(
                  DateFormat('HH:mm').format(item.startTime!),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else ...[
              const SizedBox(width: 53),
            ],
            Icon(iconData, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                  color: item.isCompleted ? AppTheme.textMutedColor(context) : AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
