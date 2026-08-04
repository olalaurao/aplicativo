import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/pomodoro_session.dart';
import '../../../models/organizer_model.dart';
import '../../../models/content_object.dart';
import '../../../models/shared_types.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';

class FocusByOrganizerComponent extends ConsumerWidget {
  final DashboardBlock block;
  const FocusByOrganizerComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = block.metadata['typeFilter'] as String? ?? 'project';
    final daysBack = block.metadata['daysBack'] as int? ?? 7;
    
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final pomodoros = allObjects.whereType<PomodoroSession>().toList();
    final organizers = allObjects.whereType<Organizer>().toList();

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysBack));

    Map<String, double> focusByGroup = {};

    for (final session in pomodoros) {
      if (session.state != PomodoroSessionState.completed) continue;
      final effectiveDate = session.occurredAt ?? session.date;
      if (effectiveDate.isBefore(cutoff)) continue;
      if (session.linkedItemSlug == null) {
        focusByGroup['unassigned'] = (focusByGroup['unassigned'] ?? 0) + session.minutesWorked * 60.0;
        continue;
      }

      // Find linked object
      ContentObject? linkedObj;
      for (final o in allObjects) {
        if (o.id == session.linkedItemSlug || o.slug == session.linkedItemSlug) {
          linkedObj = o;
          break;
        }
      }

      if (linkedObj == null) {
        focusByGroup['unassigned'] = (focusByGroup['unassigned'] ?? 0) + session.minutesWorked * 60.0;
        continue;
      }

      // Find the specific organizer of the requested type
      String groupSlug = 'unassigned';
      if (typeFilter == 'task' && linkedObj.type == 'task') {
        groupSlug = linkedObj.slug;
      } else {
        OrganizerReference? orgRef;
        for (final o in linkedObj.organizers) {
          if (o.type == typeFilter) {
            orgRef = o;
            break;
          }
        }
        if (orgRef != null) groupSlug = orgRef.slug;
      }

      focusByGroup[groupSlug] = (focusByGroup[groupSlug] ?? 0) + session.minutesWorked * 60.0;
    }

    final sortedGroups = focusByGroup.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    double maxTime = 0;
    if (sortedGroups.isNotEmpty) {
      maxTime = sortedGroups.first.value;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.center_focus_strong_rounded, color: AppTheme.accentColor(context), size: 18),
              const SizedBox(width: 8),
              Text(
                block.title ?? 'Focus by $typeFilter',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedGroups.isEmpty)
            const Text('No focus data in this period', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            ...sortedGroups.map((entry) {
              final groupSlug = entry.key;
              String groupTitle = groupSlug;
              if (groupSlug != 'unassigned') {
                if (typeFilter == 'task') {
                  final task = allObjects.where((o) => o.slug == groupSlug).firstOrNull;
                  if (task != null) groupTitle = task.title;
                } else {
                  final org = organizers.where((o) => o.slug == groupSlug).firstOrNull;
                  groupTitle = org?.title ?? groupSlug;
                }
              }

              final hours = entry.value / 3600;
              final fraction = maxTime == 0 ? 0.0 : entry.value / maxTime;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            groupTitle,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${hours.toStringAsFixed(1)}h',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            color: Colors.grey.withOpacity(0.1),
                          ),
                          FractionallySizedBox(
                            widthFactor: fraction.clamp(0.0, 1.0),
                            child: Container(
                              height: 8,
                              color: AppTheme.accentColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
