import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/shared_types.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/task_model.dart';
import '../../../models/organizer_model.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';

class RechargeVsDrainComponent extends ConsumerWidget {
  final DashboardBlock block;
  const RechargeVsDrainComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    final organizers = allObjects.whereType<Organizer>().toList();

    // Map: Area Slug -> { recharge: min, flow: min, grind: min, drain: min }
    final Map<String, Map<String, double>> areaBreakdown = {};
    
    final now = DateTime.now();
    final startOfPeriod = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    for (final task in tasks) {
      if (task.duration == null || task.duration! <= 0) continue;
      final taskDate = task.startDate;
      if (taskDate == null || taskDate.isBefore(startOfPeriod)) continue;

      // Determine Area
      final linkedArea = task.organizers.firstWhere(
        (o) => o.type == 'area',
        orElse: () => OrganizerReference(type: 'area', slug: 'unassigned', title: 'Unassigned'),
      );
      
      final areaSlug = linkedArea.slug;

      // Determine energyImpact: instance override, then Area/Project default
      String impact = task.energyImpact ?? 'flow'; // default fallback if neither has it
      if (task.energyImpact == null) {
        // Find default from Area
        final areaObj = organizers.firstWhere((o) => o.slug == areaSlug, orElse: () => Organizer(id: '', title: areaSlug, organizerType: OrganizerType.area));
        impact = areaObj.energyImpact ?? 'flow';
      }

      if (!areaBreakdown.containsKey(areaSlug)) {
        areaBreakdown[areaSlug] = {'recharge': 0, 'flow': 0, 'grind': 0, 'drain': 0};
      }
      
      // Safety if impact string is unrecognized
      if (areaBreakdown[areaSlug]!.containsKey(impact)) {
        areaBreakdown[areaSlug]![impact] = areaBreakdown[areaSlug]![impact]! + task.duration!;
      } else {
        areaBreakdown[areaSlug]!['flow'] = areaBreakdown[areaSlug]!['flow']! + task.duration!;
      }
    }

    final sortedAreas = areaBreakdown.entries.toList()
      ..sort((a, b) {
        double sumA = a.value.values.fold(0, (prev, curr) => prev + curr);
        double sumB = b.value.values.fold(0, (prev, curr) => prev + curr);
        return sumB.compareTo(sumA);
      });

    final impactColors = {
      'recharge': Colors.greenAccent.shade400,
      'flow': Colors.blueAccent,
      'grind': Colors.orangeAccent,
      'drain': Colors.redAccent,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.battery_charging_full_rounded, color: AppTheme.accentColor(context), size: 18),
              const SizedBox(width: 8),
              Text(
                block.title ?? 'Recharge vs Drain',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedAreas.isEmpty)
            const Text('No data for the period', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            ...sortedAreas.map((entry) {
              final areaSlug = entry.key;
              final areaObj = organizers.firstWhere((o) => o.slug == areaSlug, orElse: () => Organizer(id: '', title: areaSlug, organizerType: OrganizerType.area));
              final total = entry.value.values.fold(0.0, (prev, curr) => prev + curr);
              
              if (total == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(areaObj.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${(total / 60).toStringAsFixed(1)}h', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: ['recharge', 'flow', 'grind', 'drain'].map((impact) {
                          final val = entry.value[impact]!;
                          if (val <= 0) return const SizedBox.shrink();
                          final flex = (val / total * 100).toInt();
                          return Expanded(
                            flex: flex,
                            child: Container(
                              height: 8,
                              color: impactColors[impact],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              _LegendItem(color: impactColors['recharge']!, label: 'Recharge'),
              _LegendItem(color: impactColors['flow']!, label: 'Flow'),
              _LegendItem(color: impactColors['grind']!, label: 'Grind'),
              _LegendItem(color: impactColors['drain']!, label: 'Drain'),
            ],
          )
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
