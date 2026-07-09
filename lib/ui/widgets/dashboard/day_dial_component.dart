import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/event_model.dart';
import '../../../models/habit_model.dart';
import '../../../models/journal_entry.dart';
import '../../../models/mood_model.dart';
import '../../../models/organizer_model.dart';
import '../../../models/pomodoro_session.dart';
import '../../../models/reminder_model.dart';
import '../../../models/task_model.dart';
import '../../../services/day_dial_aggregator.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../day_dial_widget.dart';

class DayDialComponent extends ConsumerWidget {
  final DashboardBlock block;

  const DayDialComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];

    final snapshot = DayDialAggregator.aggregateForDate(
      date: today,
      tasks: allObjects.whereType<Task>().toList(),
      habits: allObjects.whereType<Habit>().toList(),
      pomodoroSessions: allObjects.whereType<PomodoroSession>().toList(),
      googleEvents: const [],
      localEvents: allObjects.whereType<Event>().toList(),
      reminders: allObjects.whereType<Reminder>().toList(),
      timeBlocks: allObjects.whereType<Organizer>().where((o) => o.organizerType == OrganizerType.timeBlock).toList(),
      journalEntries: allObjects.whereType<JournalEntry>().toList(),
      moodCatalog: allObjects.whereType<MoodDefinition>().toList(),
    );

    final showLegend = block.metadata['showLegend'] as bool? ?? true;

    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/planner?date=today'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.donut_large_rounded, color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    block.title.isNotEmpty ? block.title : 'Day Dial',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 180,
                child: IgnorePointer(
                  child: DayDialWidget(
                    snapshot: snapshot,
                    selectedDate: today,
                  ),
                ),
              ),
            ),
            if (showLegend && snapshot.segments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: snapshot.segments.take(5).map((segment) {
                      final duration = segment.end.difference(segment.start);
                      final hours = duration.inMinutes / 60.0;
                      final segColor = Color(int.parse(segment.colorHex.replaceAll('#', '0xFF')));
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: segColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${segment.title.length > 10 ? segment.title.substring(0, 10) : segment.title} ${hours.toStringAsFixed(1)}h',
                              style: Theme.of(context).textTheme.bodySmall!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
