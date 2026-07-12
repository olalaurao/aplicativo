import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/dashboard_block.dart';
import '../../../providers/today_provider.dart';
import '../../theme.dart';

class MonthOverviewComponent extends ConsumerStatefulWidget {
  final DashboardBlock block;

  const MonthOverviewComponent({super.key, required this.block});

  @override
  ConsumerState<MonthOverviewComponent> createState() => _MonthOverviewComponentState();
}

class _MonthOverviewComponentState extends ConsumerState<MonthOverviewComponent> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final maxChipsPerCell = widget.block.metadata['maxChipsPerCell'] as int? ?? 4;

    // Build grid data
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    // Calendar starts on Sunday
    int daysBefore = firstDayOfMonth.weekday % 7;
    int daysAfter = 6 - (lastDayOfMonth.weekday % 7);
    
    final startDate = firstDayOfMonth.subtract(Duration(days: daysBefore));
    final endDate = lastDayOfMonth.add(Duration(days: daysAfter));
    
    final int numDays = endDate.difference(startDate).inDays + 1;
    final days = List.generate(numDays, (i) => startDate.add(Duration(days: i)));

    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.calendar_view_month_rounded, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.block.title.isNotEmpty ? widget.block.title : 'This Month',
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
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                      }),
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'en_US').format(_currentMonth),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Header (S M T W T F S)
                Row(
                  children: List.generate(7, (index) {
                    final headerDate = startDate.add(Duration(days: index));
                    return Expanded(
                      child: Center(
                        child: Text(
                          DateFormat('E', 'en_US').format(headerDate).substring(0, 1),
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                // Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final date = days[index];
                    final isCurrentMonth = date.month == _currentMonth.month;
                    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                    
                    final items = ref.watch(todayItemsProvider(date));
                    final visibleItems = items.take(maxChipsPerCell).toList();
                    final hasMore = items.length > maxChipsPerCell;

                    return InkWell(
                      onTap: () => context.push('/planner?date=${DateFormat('yyyy-MM-dd').format(date)}'),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              '${date.day}',
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                color: isToday 
                                  ? AppColors.accent 
                                  : (isCurrentMonth ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.5)),
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (isCurrentMonth)
                              Expanded(
                                child: ListView(
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  children: [
                                    ...visibleItems.map((item) => Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: item.color.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: Text(
                                          item.title.length > 8 ? '${item.title.substring(0, 8)}...' : item.title,
                                          style: TextStyle(
                                            fontSize: 7,
                                            color: item.color,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                    )),
                                    if (hasMore)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 1),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: const BoxDecoration(
                                                color: AppColors.textMuted,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
