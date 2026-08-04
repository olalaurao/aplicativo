import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/pomodoro_session.dart';
import '../../../models/organizer_model.dart';
import '../../../models/shared_types.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';

class RhythmHeatmapComponent extends ConsumerWidget {
  final DashboardBlock block;
  const RhythmHeatmapComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysBack = block.metadata['daysBack'] as int? ?? 30;
    
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final pomodoros = allObjects.whereType<PomodoroSession>().toList();

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysBack));

    // matrix[weekday][hour], weekday: 0=Mon, 6=Sun
    List<List<double>> heatmap = List.generate(7, (_) => List.generate(24, (_) => 0.0));
    double maxConcentration = 0;

    for (final session in pomodoros) {
      if (session.state != PomodoroSessionState.completed) continue;
      final effectiveDate = session.occurredAt ?? session.date;
      if (effectiveDate.isBefore(cutoff)) continue;
      
      int weekday = effectiveDate.weekday - 1; // 0-6
      int hour = effectiveDate.hour;
      
      heatmap[weekday][hour] += session.minutesWorked.toDouble();
      if (heatmap[weekday][hour] > maxConcentration) {
        maxConcentration = heatmap[weekday][hour];
      }
    }

    final List<String> dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_on_rounded, color: AppTheme.accentColor(context), size: 18),
              const SizedBox(width: 8),
              Text(
                block.title ?? 'Rhythm Heatmap',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'Last $daysBack days',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(25, (hour) {
                    if (hour == 0) return const SizedBox(height: 20);
                    if ((hour - 1) % 6 != 0) return const SizedBox(height: 12);
                    return SizedBox(
                      height: 12,
                      child: Text('${hour-1}h', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(7, (day) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 20,
                            child: Text(dayLabels[day], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          ),
                          ...List.generate(24, (hour) {
                            final val = heatmap[day][hour];
                            final opacity = maxConcentration == 0 ? 0.0 : (val / maxConcentration).clamp(0.0, 1.0);
                            return Container(
                              width: 14,
                              height: 10,
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: val == 0 
                                    ? Colors.grey.withOpacity(0.1) 
                                    : AppTheme.accentColor(context).withOpacity(opacity),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
