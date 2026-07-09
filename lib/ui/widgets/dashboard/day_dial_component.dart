import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/day_dial_model.dart';
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
import '../../../providers/settings_provider.dart';
import '../../theme.dart';
import '../day_dial_widget.dart';

class DayDialComponent extends ConsumerStatefulWidget {
  final DashboardBlock block;

  const DayDialComponent({super.key, required this.block});

  @override
  ConsumerState<DayDialComponent> createState() => _DayDialComponentState();
}

class _DayDialComponentState extends ConsumerState<DayDialComponent> {
  final ScrollController _legendScrollController = ScrollController();

  @override
  void dispose() {
    _legendScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final showLegend = widget.block.metadata['showLegend'] as bool? ?? true;
    final showLegendSetting = ref.watch(settingsProvider).showDayDialLegend;

    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/planner?date=today'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.donut_large_rounded, color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.block.title.isNotEmpty ? widget.block.title : 'Day Dial',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (snapshot.nextUpcoming != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildNextUpcoming(context, snapshot.nextUpcoming!, DateTime.now()),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                height: 280,
                child: DayDialWidget(
                  snapshot: snapshot,
                  selectedDate: today,
                  onSegmentTap: (segment) {
                    if (segment.sourceSlug != null) {
                      context.push('/detail/${segment.sourceSlug}');
                    }
                    // Scroll legend to this segment
                    final index = snapshot.segments.indexOf(segment);
                    if (index >= 0 && showLegend) {
                      _legendScrollController.animateTo(
                        index * 32.0, // Approximate item height
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ),
            if (snapshot.segments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Schedule',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            showLegendSetting ? Icons.visibility : Icons.visibility_off,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () {
                            ref.read(settingsProvider.notifier).updateDayDialLegend(!showLegendSetting);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (showLegendSetting)
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          controller: _legendScrollController,
                          itemCount: snapshot.segments.length,
                          itemBuilder: (context, index) {
                            final segment = snapshot.segments[index];
                            final segColor = Color(int.parse(segment.colorHex.replaceAll('#', '0xFF')));
                            final timeStr = DateFormat('HH:mm').format(segment.start);
                            final emoji = _getEmojiForSegment(segment);
                            return InkWell(
                              onTap: () {
                                if (segment.sourceSlug != null) {
                                  context.push('/detail/${segment.sourceSlug}');
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        timeStr,
                                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: segColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        segment.title,
                                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextUpcoming(BuildContext context, DialSegment next, DateTime now) {
    final diff = next.start.difference(now);
    String timeText;
    if (diff.isNegative) {
      timeText = 'Now — ${next.title}';
    } else if (diff.inMinutes < 60) {
      timeText = 'in ${diff.inMinutes}m — ${next.title}';
    } else {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      timeText = 'in ${h}h ${m}m — ${next.title}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: AppTheme.accentColor(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              timeText,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.accentColor(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getEmojiForSegment(DialSegment segment) {
    if (segment.emoji != null) return segment.emoji!;
    
    // Fallback emojis based on segment kind
    switch (segment.kind) {
      case DialSegmentKind.taskPlanned:
        return '✅';
      case DialSegmentKind.habitSlot:
        return '🔄';
      case DialSegmentKind.event:
        return '📅';
      case DialSegmentKind.pomodoroPlanned:
      case DialSegmentKind.pomodoroCompleted:
        return '🍅';
      case DialSegmentKind.timeBlock:
        return '⏱️';
      case DialSegmentKind.reminder:
        return '⏰';
      case DialSegmentKind.dayTheme:
        return '🌅';
      case DialSegmentKind.sleep:
        return '�';
      default:
        return '📌';
    }
  }
}
