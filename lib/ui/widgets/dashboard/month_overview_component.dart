import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/organizer_model.dart';
import '../../../providers/today_provider.dart';
import '../../../providers/vault_provider.dart';
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

    final maxChipsPerCell = widget.block.metadata['maxChipsPerCell'] as int? ?? 2;

    // Item-kind filter: list of TodayItemKind.name strings; null/empty = show all
    final rawKinds = widget.block.metadata['visibleKinds'];
    final Set<String>? visibleKinds = (rawKinds is List && rawKinds.isNotEmpty)
        ? rawKinds.map((e) => e.toString()).toSet()
        : null;

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

    // Get day themes
    final organizers = ref.watch(organizersListProvider);
    final dayThemes = organizers.where((o) => o.organizerType == OrganizerType.dayTheme).toList();
    const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: [icon] [< Month Year >] ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Icon(Icons.calendar_view_month_rounded, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                  }),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'en_US').format(_currentMonth),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
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
                // Grid — built as static Column/Rows to avoid nested scroll semantics issues
                ...List.generate((days.length / 7).ceil(), (weekIndex) {
                  final weekDays = days.skip(weekIndex * 7).take(7).toList();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: weekDays.map((date) {
                        final isCurrentMonth = date.month == _currentMonth.month;
                        final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

                        final allItems = ref.watch(todayItemsProvider(date));
                        // Apply kind filter
                        final filteredItems = visibleKinds == null
                            ? allItems
                            : allItems.where((item) => visibleKinds.contains(item.kind.name)).toList();

                        final visibleItems = filteredItems.take(maxChipsPerCell).toList();
                        final hasMore = filteredItems.length > maxChipsPerCell;

                          // Find active day theme for this day
                          final dayName = weekDayNames[date.weekday - 1];
                          final activeTheme = dayThemes.cast<Organizer?>().firstWhere(
                            (theme) => theme != null && theme.daysOfWeek.contains(dayName),
                            orElse: () => null,
                          );

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: GestureDetector(
                                key: ValueKey(date.toIso8601String()),
                                onTap: () => context.push('/planner?date=${DateFormat('yyyy-MM-dd').format(date)}'),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isToday ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (activeTheme != null && isCurrentMonth)
                                        GestureDetector(
                                          onTap: () => _showDayThemePopup(context, activeTheme),
                                          child: Text(
                                            activeTheme.icon ?? '📅',
                                            style: const TextStyle(fontSize: 10),
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      else
                                        const SizedBox(height: 10),
                                      Text(
                                        '${date.day}',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                          color: isToday
                                            ? AppColors.accent
                                            : (isCurrentMonth ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.5)),
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (isCurrentMonth) ...[
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
                                          Center(
                                            child: Container(
                                              width: 4,
                                              height: 4,
                                              margin: const EdgeInsets.symmetric(vertical: 1),
                                              decoration: const BoxDecoration(
                                                color: AppColors.textMuted,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ],
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
            ),
          ),
        ],
      ),
    );
  }

  void _showDayThemePopup(BuildContext context, Organizer theme) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    theme.icon ?? '📅',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theme.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Days: ${theme.daysOfWeek.join(", ")}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
