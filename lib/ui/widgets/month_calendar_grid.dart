import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/daily_schedule_provider.dart';
import '../theme.dart';

class MonthCalendarGrid extends ConsumerWidget {
  final DateTime selectedMonth;
  final Function(DateTime) onDayTap;
  final DateTime? selectedDate;
  final int maxChipsPerCell;
  final bool showDayOfWeek;
  final bool isTodayHighlight;

  const MonthCalendarGrid({
    super.key,
    required this.selectedMonth,
    required this.onDayTap,
    this.selectedDate,
    this.maxChipsPerCell = 2,
    this.showDayOfWeek = true,
    this.isTodayHighlight = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build grid data
    final firstDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    // Calendar starts on Sunday
    int daysBefore = firstDayOfMonth.weekday % 7;
    int daysAfter = 6 - (lastDayOfMonth.weekday % 7);

    final startDate = firstDayOfMonth.subtract(Duration(days: daysBefore));
    final endDate = lastDayOfMonth.add(Duration(days: daysAfter));

    final int numDays = endDate.difference(startDate).inDays + 1;
    final days = List.generate(numDays, (i) => startDate.add(Duration(days: i)));

    return Column(
      children: [
        // Week day headers
        if (showDayOfWeek)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: List.generate(7, (index) {
                final headerDate = startDate.add(Duration(days: index));
                return Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('E', 'en_US').format(headerDate).substring(0, 1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        if (showDayOfWeek) const SizedBox(height: 8),
        // Grid — built as static Column/Rows to avoid nested scroll semantics issues
        ...List.generate((days.length / 7).ceil(), (weekIndex) {
          final weekDays = days.skip(weekIndex * 7).take(7).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weekDays.map((date) {
                final isCurrentMonth = date.month == selectedMonth.month;
                final isToday = isTodayHighlight &&
                    date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isSelected = selectedDate != null &&
                    date.year == selectedDate!.year &&
                    date.month == selectedDate!.month &&
                    date.day == selectedDate!.day;

                final allItems = ref.watch(dailyScheduleProvider(date)).allItems;
                final visibleItems = allItems.take(maxChipsPerCell).toList();
                final hasMore = allItems.length > maxChipsPerCell;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: GestureDetector(
                      key: ValueKey(date.toIso8601String()),
                      onTap: () => onDayTap(date),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentColor(context).withValues(alpha: 0.2)
                              : (isToday
                                  ? AppTheme.accentColor(context).withValues(alpha: 0.1)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(4),
                          border: isSelected
                              ? Border.all(color: AppTheme.accentColor(context), width: 1.5)
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${date.day}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : (isToday ? FontWeight.w600 : FontWeight.normal),
                                  color: isSelected
                                      ? AppTheme.accentColor(context)
                                      : (isToday
                                          ? AppTheme.accentColor(context)
                                          : (isCurrentMonth
                                              ? AppTheme.textPrimaryColor(context)
                                              : AppTheme.textMutedColor(context)
                                                  .withValues(alpha: 0.5))),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isCurrentMonth) ...[
                                // Compact dots for items
                                Wrap(
                                  spacing: 2,
                                  runSpacing: 2,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ...visibleItems.map((item) => Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: item.color,
                                        shape: BoxShape.circle,
                                      ),
                                    )),
                                    if (hasMore)
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
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }
}
