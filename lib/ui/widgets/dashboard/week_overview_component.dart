import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/dashboard_block.dart';
import '../../../providers/today_provider.dart';
import '../../theme.dart';
import '../../navigation/object_navigation.dart';

class WeekOverviewComponent extends ConsumerStatefulWidget {
  final DashboardBlock block;

  const WeekOverviewComponent({super.key, required this.block});

  @override
  ConsumerState<WeekOverviewComponent> createState() => _WeekOverviewComponentState();
}

class _WeekOverviewComponentState extends ConsumerState<WeekOverviewComponent> {
  late DateTime _currentWeekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStartsMonday = widget.block.metadata['weekStartsMonday'] as bool? ?? true;
    int daysToSubtract = today.weekday - (weekStartsMonday ? DateTime.monday : DateTime.sunday);
    if (daysToSubtract < 0) daysToSubtract += 7;
    _currentWeekStart = today.subtract(Duration(days: daysToSubtract));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStartsMonday = widget.block.metadata['weekStartsMonday'] as bool? ?? true;
    final maxItemsPerDay = widget.block.metadata['maxItemsPerDay'] as int? ?? 3;

    // Calculate start of week
    int daysToSubtract = today.weekday - (weekStartsMonday ? DateTime.monday : DateTime.sunday);
    if (daysToSubtract < 0) daysToSubtract += 7;
    final startOfWeek = today.subtract(Duration(days: daysToSubtract));

    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => context.push('/week'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.view_week_rounded, color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.block.title.isNotEmpty ? widget.block.title : 'This Week',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 16),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => setState(() {
                          _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => setState(() {
                          _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
                        }),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: days.map((date) {
                final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                final items = ref.watch(todayItemsProvider(date));
                final visibleItems = items.take(maxItemsPerDay).toList();
                final hasMore = items.length > maxItemsPerDay;

                return Expanded(
                  child: InkWell(
                    onTap: () => context.push('/planner?date=${DateFormat('yyyy-MM-dd').format(date)}'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E', 'en_US').format(date).toUpperCase(),
                            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: isToday ? AppColors.accent : AppColors.textMuted,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToday ? AppColors.accent : Colors.transparent,
                            ),
                            child: Text(
                              '${date.day}',
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                color: isToday ? AppColors.surface : AppColors.textPrimary,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (items.isEmpty)
                            const Text('-', style: TextStyle(color: AppColors.textMuted))
                          else
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    ...visibleItems.map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: InkWell(
                                        onTap: () => navigateToObject(context, item.source),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: item.color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(item.emoji, style: const TextStyle(fontSize: 10)),
                                              const SizedBox(width: 2),
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                                    fontSize: 10,
                                                    color: item.color,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )),
                                    if (hasMore)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '+${items.length - maxItemsPerDay}',
                                          style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
