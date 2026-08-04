import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/vault_provider.dart';
import '../../models/goal_model.dart';
import '../../models/event_model.dart';
import '../theme.dart';

class YearOverviewScreen extends ConsumerStatefulWidget {
  const YearOverviewScreen({super.key});

  @override
  ConsumerState<YearOverviewScreen> createState() => _YearOverviewScreenState();
}

class _YearOverviewScreenState extends ConsumerState<YearOverviewScreen> {
  final int currentYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Year at a Glance - $currentYear'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.75,
                mainAxisSpacing: 16.0,
                crossAxisSpacing: 16.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final month = index + 1;
                  return _buildMonthBlock(context, ref, currentYear, month);
                },
                childCount: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBlock(BuildContext context, WidgetRef ref, int year, int month) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    
    // Find goals active in this month
    final activeGoals = allObjects.whereType<Goal>().where((g) {
      return g.activeMonths.any((m) => m == month);
    }).toList();

    // Find deadlines in this month
    final deadlineGoals = allObjects.whereType<Goal>().where((g) {
      return g.deadline != null && g.deadline!.year == year && g.deadline!.month == month;
    }).toList();

    // Find events in this month
    final monthEvents = allObjects.whereType<Event>().where((e) {
      return e.date.year == year && e.date.month == month;
    }).toList();

    final monthName = DateFormat('MMMM').format(DateTime(year, month));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                if (activeGoals.isNotEmpty) ...[
                  const Text('Focus Goals', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ...activeGoals.map((g) => _buildGoalStrip(g)),
                  const SizedBox(height: 4),
                ],
                if (deadlineGoals.isNotEmpty) ...[
                  const Text('Deadlines', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ...deadlineGoals.map((g) => _buildMarker(g.title, Icons.flag, Colors.red)),
                  const SizedBox(height: 4),
                ],
                if (monthEvents.isNotEmpty) ...[
                  const Text('Events', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ...monthEvents.map((e) => _buildMarker(e.title, Icons.event, AppColors.info)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStrip(Goal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Text(
        goal.title,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMarker(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 10, color: AppTheme.textPrimaryColor(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
