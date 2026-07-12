import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../services/day_dial_legend_builder.dart';
import '../../../providers/vault_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/pomodoro_provider.dart';
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
                  Expanded(
                    child: Text(
                      widget.block.title.isNotEmpty ? widget.block.title : 'Day Dial',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
            if (showLegendSetting)
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
                    _buildLegend(context, snapshot.segments),
                    const SizedBox(height: 12),
                    _buildChronologicalList(context, snapshot.segments, allObjects),
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

  Widget _buildLegend(BuildContext context, List<DialSegment> segments) {
    final legendEntries = buildDialLegend(segments);
    
    if (legendEntries.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: legendEntries.take(6).map((entry) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(
            '${entry.categoryLabel} ${entry.totalHours.toStringAsFixed(1)}h',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      )).toList(),
    );
  }

  Widget _buildChronologicalList(BuildContext context, List<DialSegment> segments, List<dynamic> allObjects) {
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Sort by start time
    final sortedSegments = List<DialSegment>.from(segments)..sort((a, b) => a.start.compareTo(b.start));
    
    return SizedBox(
      height: 200,
      child: ListView.builder(
        controller: _legendScrollController,
        itemCount: sortedSegments.length,
        itemBuilder: (context, index) {
          final segment = sortedSegments[index];
          final timeStr = DateFormat('HH:mm').format(segment.start);
          final emoji = _getEmojiForSegment(segment);
          final segColor = Color(int.parse(segment.colorHex.replaceAll('#', '0xFF')));
          
          // Check if segment is completable (task or habit)
          final isCompletable = segment.kind == DialSegmentKind.taskPlanned || 
                                segment.kind == DialSegmentKind.habitSlot;
          
          // Check if segment is playable (task)
          final isPlayable = segment.kind == DialSegmentKind.taskPlanned;
          
          // Find completion status
          bool isCompleted = false;
          if (segment.kind == DialSegmentKind.taskPlanned && segment.sourceSlug != null) {
            final task = allObjects.whereType<Task>().firstWhere(
              (t) => t.slug == segment.sourceSlug,
              orElse: () => allObjects.whereType<Task>().firstWhere(
                (t) => t.id == segment.sourceSlug,
                orElse: () => Task(id: '', title: '', stage: TaskStage.todo),
              ),
            );
            isCompleted = task.stage == TaskStage.finalized;
          } else if (segment.kind == DialSegmentKind.habitSlot && segment.sourceSlug != null) {
            final habit = allObjects.whereType<Habit>().firstWhere(
              (h) => h.slug == segment.sourceSlug,
              orElse: () => allObjects.whereType<Habit>().firstWhere(
                (h) => h.id == segment.sourceSlug,
                orElse: () => Habit(id: '', title: '', color: '', slots: []),
              ),
            );
            final today = DateTime.now();
            isCompleted = habit.completionHistory.any((c) => 
              c.date.year == today.year && c.date.month == today.month && c.date.day == today.day);
          }
          
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
                        color: isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPlayable)
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        ref.read(pomodoroProvider.notifier).setCurrentItem(segment.sourceSlug, segment.title);
                        ref.read(pomodoroProvider.notifier).start();
                      },
                      tooltip: 'Start Pomodoro',
                    ),
                  if (isCompletable)
                    Checkbox(
                      value: isCompleted,
                      onChanged: (checked) {
                        if (checked == null) return;
                        HapticFeedback.lightImpact();
                        
                        if (segment.kind == DialSegmentKind.taskPlanned && segment.sourceSlug != null) {
                          final task = allObjects.whereType<Task>().firstWhere(
                            (t) => t.slug == segment.sourceSlug,
                            orElse: () => allObjects.whereType<Task>().firstWhere(
                              (t) => t.id == segment.sourceSlug,
                              orElse: () => Task(id: '', title: '', stage: TaskStage.todo),
                            ),
                          );
                          ref.read(vaultProvider.notifier).updateObject(
                            task.copyWith(stage: checked ? TaskStage.finalized : TaskStage.todo),
                          );
                        } else if (segment.kind == DialSegmentKind.habitSlot && segment.sourceSlug != null) {
                          final habit = allObjects.whereType<Habit>().firstWhere(
                            (h) => h.slug == segment.sourceSlug,
                            orElse: () => allObjects.whereType<Habit>().firstWhere(
                              (h) => h.id == segment.sourceSlug,
                              orElse: () => Habit(id: '', title: '', color: '', slots: []),
                            ),
                          );
                          final today = DateTime.now();
                          final history = List<CompletionRecord>.from(habit.completionHistory);
                          if (checked) {
                            history.add(CompletionRecord(
                              date: today,
                              completions: 1,
                              successful: true,
                            ));
                          } else {
                            history.removeWhere((c) => 
                              c.date.year == today.year && c.date.month == today.month && c.date.day == today.day);
                          }
                          ref.read(vaultProvider.notifier).updateObject(
                            habit.copyWith(completionHistory: history),
                          );
                        }
                      },
                      activeColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
          );
        },
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
