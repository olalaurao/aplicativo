// lib/ui/widgets/timeline_day_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../models/day_theme_model.dart';
import '../../providers/vault_provider.dart';
import '../../providers/pomodoro_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;
import '../../models/habit_model.dart';
import 'object_action_wrapper.dart';
import '../screens/google_event_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/universal_detail_view.dart';
import '../screens/pomodoro_screen.dart';
import '../forms/create_task_form.dart';
import '../../models/pomodoro_session.dart';

class TimeLineDayView extends ConsumerStatefulWidget {
  final List<Task> tasks;
  final List<google_calendar.Event> googleEvents;
  final List<dynamic> allDayEvents; // Can be tasks, habits, etc.
  final List<TimeBlock> timeBlocks;
  final DateTime selectedDate;
  final Function(Task, DateTime)? onTaskDrop;
  final Function(Habit, DateTime)? onHabitDrop;
  final Function(dynamic, int)? onDurationChange;
  final Function(Task)? onToggleComplete;
  final Function(dynamic)? onPlay;
  final Function(Habit, int)? onHabitToggle;
  final String colorMode;
  final int gridGranularity; // 15, 30, or 60 minutes
  final List<PomodoroSession> pomodoroSessions;

  const TimeLineDayView({
    super.key,
    required this.selectedDate,
    this.tasks = const [],
    this.googleEvents = const [],
    this.allDayEvents = const [],
    this.timeBlocks = const [],
    this.onTaskDrop,
    this.onHabitDrop,
    this.onDurationChange,
    this.onToggleComplete,
    this.onPlay,
    this.onHabitToggle,
    this.colorMode = 'category',
    this.gridGranularity = 30,
    this.pomodoroSessions = const [],
  });

  @override
  ConsumerState<TimeLineDayView> createState() => _TimeLineDayViewState();
}

class _TimeLineDayViewState extends ConsumerState<TimeLineDayView> {
  // Store local durations during active dragging to avoid continuous DB writes
  final Map<String, int> _localDurations = {};

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void didUpdateWidget(covariant TimeLineDayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the tasks list changed, clean up local durations that now match the actual task duration
    for (final task in widget.tasks) {
      if (_localDurations.containsKey(task.id) &&
          _localDurations[task.id] == task.duration) {
        _localDurations.remove(task.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double hourHeight = widget.gridGranularity == 15 ? 40.0 
                          : widget.gridGranularity == 30 ? 80.0 
                          : 160.0; // 60 min
    const double leftColumnWidth = 60.0;
    final int slotsPerHour = 60 ~/ widget.gridGranularity;

    return Container(
      color: AppTheme.backgroundColor(context),
      child: Column(
        children: [
          // ─── All-Day Strip ───
          if (widget.allDayEvents.isNotEmpty) _buildAllDayStrip(context),

          SizedBox(
            height: 24 * hourHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableWidth =
                    constraints.maxWidth - leftColumnWidth - 24;

                final List<TimelineItem> items = [];

                // 1. Scheduled Tasks
                for (final task in widget.tasks.where(
                  (t) => t.scheduledTime != null,
                )) {
                  final parts = task.scheduledTime!.split(':');
                  if (parts.length < 2) continue;
                  final hour = int.tryParse(parts[0]) ?? 0;
                  final minute = int.tryParse(parts[1]) ?? 0;
                  final start = hour * 60 + minute;
                  final duration = _localDurations[task.id] ?? task.duration;
                  items.add(
                    TimelineItem(
                      originalItem: task,
                      startMinutes: start,
                      endMinutes: start + duration,
                      id: task.id,
                    ),
                  );
                }

                // 2. Scheduled Habits
                for (final habit in widget.allDayEvents.whereType<Habit>()) {
                  for (
                    int slotIndex = 0;
                    slotIndex < habit.slots.length;
                    slotIndex++
                  ) {
                    final slot = habit.slots[slotIndex];
                    if (slot.hasReminders && slot.primaryReminderTime != null) {
                      final rTime = slot.primaryReminderTime!;
                      final start = rTime.hour * 60 + rTime.minute;
                      items.add(
                        TimelineItem(
                          originalItem: habit,
                          startMinutes: start,
                          endMinutes: start + 30,
                          id: '${habit.id}_slot_$slotIndex',
                          slotIndex: slotIndex,
                        ),
                      );
                    }
                  }
                }

                // 3. Google Calendar Events
                for (final event in widget.googleEvents) {
                  final start = event.start?.dateTime ?? event.start?.date;
                  final end = event.end?.dateTime ?? event.end?.date;
                  if (start == null || end == null) continue;

                  final bool isAllDay = event.start?.date != null;
                  if (isAllDay) continue;

                  final startTime = start.toLocal();
                  final endTime = end.toLocal();

                  final startMinutes = startTime.hour * 60 + startTime.minute;
                  final duration = endTime.difference(startTime).inMinutes;
                  items.add(
                    TimelineItem(
                      originalItem: event,
                      startMinutes: startMinutes,
                      endMinutes:
                          startMinutes + (duration < 20 ? 20 : duration),
                      id: event.id ?? event.hashCode.toString(),
                    ),
                  );
                }

                // Sort items by startMinutes ascending, then by duration descending
                items.sort((a, b) {
                  if (a.startMinutes != b.startMinutes) {
                    return a.startMinutes.compareTo(b.startMinutes);
                  }
                  return (b.endMinutes - b.startMinutes).compareTo(
                    a.endMinutes - a.startMinutes,
                  );
                });

                // Group items into groups of overlapping items
                final List<List<TimelineItem>> groups = [];
                List<TimelineItem> currentGroup = [];
                int maxEnd = 0;

                for (final item in items) {
                  if (currentGroup.isEmpty) {
                    currentGroup.add(item);
                    maxEnd = item.endMinutes;
                  } else if (item.startMinutes < maxEnd) {
                    currentGroup.add(item);
                    if (item.endMinutes > maxEnd) {
                      maxEnd = item.endMinutes;
                    }
                  } else {
                    groups.add(currentGroup);
                    currentGroup = [item];
                    maxEnd = item.endMinutes;
                  }
                }
                if (currentGroup.isNotEmpty) {
                  groups.add(currentGroup);
                }

                // Assign columns within each group
                for (final group in groups) {
                  final List<List<TimelineItem>> columns = [];
                  for (final item in group) {
                    int assignedCol = -1;
                    for (int i = 0; i < columns.length; i++) {
                      final colItems = columns[i];
                      final lastItem = colItems.last;
                      if (item.startMinutes >= lastItem.endMinutes) {
                        assignedCol = i;
                        break;
                      }
                    }
                    if (assignedCol == -1) {
                      columns.add([item]);
                      assignedCol = columns.length - 1;
                    } else {
                      columns[assignedCol].add(item);
                    }
                    item.column = assignedCol;
                  }

                  final totalCols = columns.length;
                  for (final item in group) {
                    item.totalColumnsInGroup = totalCols;
                  }
                }

                return Stack(
                  children: [
                    // ─── Hour Markers ───
                    Column(
                      children: List.generate(24, (index) {
                        return SizedBox(
                          height: hourHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: leftColumnWidth,
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  right: 8,
                                ),
                                child: Text(
                                  widget.gridGranularity == 60 
                                      ? '${index.toString().padLeft(2, '0')}:00'
                                      : widget.gridGranularity == 30
                                          ? '${index.toString().padLeft(2, '0')}:00'
                                          : '${index.toString().padLeft(2, '0')}:00',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMutedColor(context),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: AppTheme.dividerColor(
                                          context,
                                        ).withValues(alpha: 0.5),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                    ..._buildTimeBlockBands(hourHeight, leftColumnWidth),

                    // Drop targets stay behind the scheduled cards so taps open items.
                    ..._buildDropTargets(hourHeight, leftColumnWidth),

                    // ─── Scheduled Blocks (Tasks, Habits, Google Events) ───
                    ...items.map((item) {
                      final startHour = item.startMinutes ~/ 60;
                      final startMinute = item.startMinutes % 60;
                      final durationMinutes =
                          item.endMinutes - item.startMinutes;

                      final topOffset =
                          (startHour * hourHeight) +
                          (startMinute / 60 * hourHeight);
                      final height = (durationMinutes / 60 * hourHeight);

                      final double colWidth =
                          availableWidth / item.totalColumnsInGroup;
                      final double leftOffset =
                          leftColumnWidth + 8 + (item.column * colWidth);

                      if (item.originalItem is Task) {
                        final task = item.originalItem as Task;
                        
                        // Find completed Pomodoro session for this task on this day
                        PomodoroSession? completedSession;
                        try {
                          completedSession = widget.pomodoroSessions.firstWhere(
                            (session) => 
                              session.linkedItemSlug == task.slug &&
                              session.state == PomodoroSessionState.completed &&
                              _isSameDay(session.date, widget.selectedDate),
                          );
                        } catch (e) {
                          completedSession = null;
                        }
                        
                        return Positioned(
                          top: topOffset,
                          left: leftOffset,
                          width: colWidth - 4,
                          height: height,
                          child: Stack(
                            children: [
                              // Planned task block
                              LongPressDraggable<Task>(
                                data: task,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: colWidth - 4,
                                    height: height,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentColor(context).withValues(
                                        alpha: 0.8,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      task.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildTaskBlock(context, task, height),
                                ),
                                child: _buildTaskBlock(context, task, height),
                              ),
                              // Plan-vs-actual overlay
                              if (completedSession != null)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: (completedSession.minutesWorked / 60 * hourHeight).clamp(0, height),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.4),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                      border: Border.all(
                                        color: AppColors.success,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${completedSession.minutesWorked}m',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      } else if (item.originalItem is Habit) {
                        final habit = item.originalItem as Habit;
                        final slotIndex = item.slotIndex ?? 0;
                        return Positioned(
                          top: topOffset,
                          left: leftOffset,
                          width: colWidth - 4,
                          height: height,
                          child: LongPressDraggable<Habit>(
                            data: habit,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Container(
                                width: colWidth - 4,
                                height: height,
                                decoration: BoxDecoration(
                                  color: _getHabitColor(
                                    habit,
                                  ).withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  habit.displayTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildHabitBlock(
                                context,
                                habit,
                                slotIndex,
                                height,
                              ),
                            ),
                            child: _buildHabitBlock(
                              context,
                              habit,
                              slotIndex,
                              height,
                            ),
                          ),
                        );
                      } else {
                        final event =
                            item.originalItem as google_calendar.Event;
                        final startTime =
                            event.start?.dateTime?.toLocal() ??
                            event.start?.date?.toLocal() ??
                            DateTime.now();
                        final endTime =
                            event.end?.dateTime?.toLocal() ??
                            event.end?.date?.toLocal() ??
                            DateTime.now();

                        return Positioned(
                          top: topOffset,
                          left: leftOffset,
                          width: colWidth - 4,
                          height: height < 20 ? 20 : height, // Minimum height
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GoogleEventDetailScreen(event: event),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: const Border(
                                  left: BorderSide(
                                    color: AppColors.info,
                                    width: 2,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.summary ?? '(Untitled)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.info,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (height > 40)
                                          Text(
                                            '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.info.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_horiz_rounded,
                                      size: 14,
                                      color: AppColors.info,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onSelected: (val) async {
                                      if (val == 'open_google') {
                                        final htmlLink = event.htmlLink;
                                        if (htmlLink != null) {
                                          launchUrl(
                                            Uri.parse(htmlLink),
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'open_google',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today_rounded,
                                              size: 16,
                                            ),
                                            Spacer(),
                                            Text('Abrir no Google Calendar'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    }),

                    // ─── Current Time Indicator ───
                    if (_isToday(widget.selectedDate))
                      _buildCurrentTimeIndicator(
                        hourHeight,
                        leftColumnWidth,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDropTargets(double hourHeight, double leftColumnWidth) {
    final int slotsPerHour = 60 ~/ widget.gridGranularity;
    return List.generate(24 * slotsPerHour, (index) {
      final slotIndex = index % slotsPerHour;
      final hour = index ~/ slotsPerHour;
      final minute = slotIndex * widget.gridGranularity;
      return Positioned(
        top: index * (hourHeight / slotsPerHour),
        left: leftColumnWidth,
        right: 0,
        height: hourHeight / slotsPerHour,
        child: GestureDetector(
          onLongPress: () {
            // Open CreateTaskForm with pre-filled date and time
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTaskForm(
                  initialDate: widget.selectedDate,
                  initialTime: TimeOfDay(hour: hour, minute: minute),
                  initialStage: TaskStage.todo,
                ),
              ),
            );
          },
          child: DragTarget<Object>(
            onWillAcceptWithDetails: (details) =>
                details.data is Task || details.data is Habit,
            onAcceptWithDetails: (details) {
              final dropTime = DateTime(
                widget.selectedDate.year,
                widget.selectedDate.month,
                widget.selectedDate.day,
                hour,
                minute,
              );

              if (details.data is Task) {
                widget.onTaskDrop?.call(details.data as Task, dropTime);
              } else if (details.data is Habit) {
                widget.onHabitDrop?.call(details.data as Habit, dropTime);
              }
            },
            builder: (context, candidateData, rejectedData) {
              if (candidateData.isEmpty) {
                return const SizedBox.shrink();
              }

              // Show ghost block with actual duration instead of time pill
              final data = candidateData.first;
              int duration = widget.gridGranularity; // Default to current granularity
              String title = '';

              if (data is Task) {
                duration = data.estimatedMinutes ?? data.duration;
                title = data.title;
              } else if (data is Habit) {
                duration = 30; // Habits default to 30 min
                title = data.displayTitle;
              }

              final ghostHeight = (duration / 60 * hourHeight);

              return Container(
                color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                child: Center(
                  child: Container(
                    height: ghostHeight,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.accentColor(context),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: title.isNotEmpty
                        ? Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  List<Widget> _buildTimeBlockBands(double hourHeight, double leftColumnWidth) {
    final bands = <Widget>[];

    for (final block in widget.timeBlocks) {
      for (final range in block.timeRanges) {
        final startMinutes =
            (range.startHour.clamp(0, 23) * 60) +
            range.startMinute.clamp(0, 59);
        final rawEndMinutes =
            (range.endHour.clamp(0, 24) * 60) + range.endMinute.clamp(0, 59);
        final endMinutes = rawEndMinutes.clamp(startMinutes + 1, 24 * 60);
        final topOffset = startMinutes / 60 * hourHeight;
        final height = (endMinutes - startMinutes) / 60 * hourHeight;
        final bandColor = _parseOptionalColor(block.color) ?? AppTheme.accentColor(context);

        bands.add(
          Positioned(
            top: topOffset,
            left: leftColumnWidth,
            right: 0,
            height: height,
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: bandColor.withValues(alpha: 0.06),
                  border: Border(
                    left: BorderSide(
                      color: bandColor.withValues(alpha: 0.45),
                      width: 3,
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    if (block.energyLevel != null)
                      Positioned.fill(
                        child: Container(
                          color: _energyColor(block.energyLevel!).withValues(alpha: 0.08),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 4),
                      child: Text(
                        block.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: bandColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return bands;
  }

  Widget _buildTaskBlock(BuildContext context, Task task, double height) {
    final isPomodoro = task.pomodoroCount != null && task.pomodoroCount! > 0;
    final isShort = height < 45;
    final isTiny = height < 34;

    if (isPomodoro) {
      const baseColor = AppColors.error;
      return Opacity(
        opacity: 0.75,
        child: ObjectActionWrapper(
          object: task,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _showPomodoroActionSheet(context, task);
              },
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                painter: DashedBorderPainter(
                  color: baseColor.withValues(alpha: 0.6),
                  borderRadius: 10,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isShort ? 8 : 12,
                          vertical: isTiny ? 0 : (isShort ? 2 : 12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '🍅',
                              style: TextStyle(fontSize: isTiny ? 12 : 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: isTiny ? 10 : (isShort ? 11 : 13),
                                      fontWeight: FontWeight.w800,
                                      color: baseColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (!isShort && !isTiny) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${task.scheduledTime} • ${task.pomodoroCount} ciclos (${task.duration} min)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: baseColor.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!isTiny)
                              IconButton(
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.error,
                                ),
                                iconSize: isShort ? 20 : 24,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () {
                                  ref.read(pomodoroProvider.notifier).setCurrentItem(
                                    task.id,
                                    task.title,
                                  );
                                  ref.read(pomodoroProvider.notifier).start();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const PomodoroScreen()),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Color baseColor;
    if (widget.colorMode == 'priority') {
      baseColor = _getPriorityColor(task.priority);
    } else {
      // Category mode - derive color from linked Organizer/Area
      if (task.organizers.isNotEmpty) {
        final organizer = task.organizers.first;
        // Try to use the organizer's own color field first
        if (organizer.color != null && organizer.color!.isNotEmpty) {
          baseColor = _parseColor(organizer.color!);
        } else {
          // Fall back to category colors from settings
          final settings = ref.watch(settingsProvider);
          final category = organizer.title;
          final colorHex = settings.categoryColors[category];
          baseColor = colorHex != null 
              ? _parseColor(colorHex) 
              : AppColors.textMuted; // Neutral gray for tasks with no color
        }
      } else {
        // No linked organizer - use neutral gray
        baseColor = AppColors.textMuted;
      }
    }

    return ObjectActionWrapper(
      object: task,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UniversalDetailView(object: task),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: baseColor, width: 4)),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isShort ? 8 : 12,
                    vertical: isTiny ? 0 : (isShort ? 2 : 12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: (isShort || isTiny)
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (!isTiny) ...[
                            SizedBox(
                              width: isShort ? 16 : 20,
                              height: isShort ? 16 : 20,
                              child:
                                  task.isBlocked(
                                    ref.watch(allObjectsProvider).value ?? [],
                                  )
                                  ? IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        Icons.lock_rounded,
                                        color: AppColors.error,
                                        size: isShort ? 12 : 16,
                                      ),
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Esta tarefa está bloqueada por dependências incompletas.',
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Checkbox(
                                      value: task.stage == TaskStage.finalized,
                                      onChanged: (v) =>
                                          widget.onToggleComplete?.call(task),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      activeColor: baseColor,
                                      side: BorderSide(
                                        color: baseColor,
                                        width: 1.5,
                                      ),
                                    ),
                            ),
                            SizedBox(width: isShort ? 6 : 8),
                          ],
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: isTiny ? 10 : (isShort ? 11 : 13),
                                fontWeight: FontWeight.w700,
                                color: baseColor,
                                decoration: task.stage == TaskStage.finalized
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isShort &&
                              !isTiny &&
                              task.subtasks.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${task.subtasks.where((s) => s.completed).length}/${task.subtasks.length}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: baseColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!isShort && !isTiny) ...[
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Text(
                            '${task.scheduledTime} (${task.duration} min)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: baseColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) {
                      setState(() {
                        _localDurations[task.id] = task.duration;
                      });
                    },
                    onVerticalDragUpdate: (details) {
                      final newHeight = height + details.delta.dy;
                      const hourHeight = 80.0;
                      final newDuration = (newHeight / hourHeight * 60)
                          .round()
                          .clamp(10, 480);
                      setState(() {
                        _localDurations[task.id] = newDuration;
                      });
                    },
                    onVerticalDragEnd: (_) {
                      final finalDuration =
                          _localDurations[task.id] ?? task.duration;
                      widget.onDurationChange?.call(task, finalDuration);
                    },
                    child: Container(
                      height: isTiny ? 12 : 24,
                      color: Colors.transparent,
                      child: Center(
                        child: Container(
                          width: isTiny ? 16 : 24,
                          height: isTiny ? 2 : 3,
                          decoration: BoxDecoration(
                            color: baseColor.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isTiny && height > 34)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: Icon(
                          Icons.play_circle_outline_rounded,
                          color: baseColor,
                          size: 24,
                        ),
                        onPressed: () => widget.onPlay?.call(task),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPomodoroActionSheet(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded, color: AppColors.error),
              title: const Text('Iniciar agora', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(pomodoroProvider.notifier).setCurrentItem(task.id, task.title);
                ref.read(pomodoroProvider.notifier).start();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PomodoroScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar agendamento'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PomodoroScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Excluir agendamento', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Excluir Pomodoro Agendado?'),
                    content: const Text('Tem certeza que deseja excluir este bloco pomodoro?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(vaultProvider.notifier).deleteObject(task);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitBlock(
    BuildContext context,
    Habit habit,
    int slotIndex,
    double height,
  ) {
    final baseColor = _getHabitColor(habit);
    final isShort = height < 45;
    final isCompleted = _isHabitSlotCompleted(
      habit,
      widget.selectedDate,
      slotIndex,
    );

    return ObjectActionWrapper(
      object: habit,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UniversalDetailView(object: habit),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: baseColor, width: 4)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isShort ? 8 : 12,
                vertical: isShort ? 2 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: isShort ? 16 : 20,
                    height: isShort ? 16 : 20,
                    child: Checkbox(
                      value: isCompleted,
                      onChanged: (v) =>
                          widget.onHabitToggle?.call(habit, slotIndex),
                      shape: const CircleBorder(),
                      activeColor: baseColor,
                      side: BorderSide(color: baseColor, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          habit.displayTitle,
                          style: TextStyle(
                            fontSize: isShort ? 11 : 13,
                            fontWeight: FontWeight.w700,
                            color: baseColor,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isShort) ...[
                          const SizedBox(height: 2),
                          Text(
                            '🔥 ${habit.streak} dias • Slot ${slotIndex + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: baseColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getHabitColor(Habit habit) {
    return _parseOptionalColor(habit.color) ?? AppColors.habitGreen;
  }

  Color? _parseOptionalColor(String? color) {
    if (color == null || color.trim().isEmpty) return null;
    try {
      final colorStr = color.trim().replaceAll('#', '');
      if (colorStr.length == 6) {
        return Color(int.parse('0xFF$colorStr'));
      } else if (colorStr.length == 8) {
        return Color(int.parse('0x$colorStr'));
      }
    } catch (_) {
      debugPrint('Invalid timeline color: $color');
    }
    return null;
  }

  bool _isHabitSlotCompleted(Habit habit, DateTime date, int slotIndex) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final record = habit.completionHistory.firstWhere((r) {
      final rDate = DateTime(r.date.year, r.date.month, r.date.day);
      return rDate == targetDate;
    }, orElse: () => CompletionRecord(date: targetDate));
    if (record.slotCompletions != null &&
        slotIndex < record.slotCompletions!.length) {
      return record.slotCompletions![slotIndex];
    }
    // Fallback if slotCompletions is null
    if (habit.dailyGoal == 1) {
      return record.successful;
    }
    return slotIndex < record.completions;
  }

  Widget _buildAllDayStrip(BuildContext context) {
    final allDayItems = widget.allDayEvents.where((event) {
      if (event is Habit) {
        final hasScheduledSlots = event.slots.any(
          (slot) => slot.hasReminders && slot.primaryReminderTime != null,
        );
        return !hasScheduledSlots;
      }
      return true;
    }).toList();

    if (allDayItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        children: allDayItems.map((event) {
          if (event is Habit) {
            return _buildHabitStripItem(context, event);
          } else if (event is Task) {
            return _buildTaskStripItem(context, event);
          }
          return const SizedBox.shrink();
        }).toList(),
      ),
    );
  }

  Widget _buildTaskStripItem(BuildContext context, Task task) {
    final isBlocked = task.isBlocked(ref.watch(allObjectsProvider).value ?? []);
    return ObjectActionWrapper(
      object: task,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: task),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: isBlocked
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: AppColors.error,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Esta tarefa está bloqueada por dependências incompletas.',
                              ),
                            ),
                          );
                        },
                      )
                    : Checkbox(
                        value: task.stage == TaskStage.finalized,
                        onChanged: (_) => widget.onToggleComplete?.call(task),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        activeColor: AppColors.secondary,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (task.stage == TaskStage.finalized)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.secondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitStripItem(BuildContext context, Habit habit) {
    final isDone = habit.daysSinceLastCompletion == 0;
    final hasSlots = habit.dailyGoal > 1;

    return ObjectActionWrapper(
      object: habit,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UniversalDetailView(object: habit)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: isDone ? AppColors.habitGreen : AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      habit.displayTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (habit.daysSinceLastCompletion > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.priorityHigh.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${habit.daysSinceLastCompletion}d ago',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.priorityHigh,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '🔥 ${habit.streak}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.priorityHigh,
                    ),
                  ),
                ],
              ),
              if (hasSlots)
                Padding(
                  padding: const EdgeInsets.only(left: 30, top: 8),
                  child: Row(
                    children: List.generate(habit.dailyGoal, (index) {
                      return Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.divider,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppColors.error;
      case TaskPriority.medium:
        return AppColors.warning;
      case TaskPriority.low:
        return AppColors.info;
      case TaskPriority.none:
        return AppColors.textMuted;
    }
  }

  Color _parseColor(String colorHex) {
    try {
      final colorStr = colorHex.trim().replaceAll('#', '');
      if (colorStr.length == 6) {
        return Color(int.parse('0xFF$colorStr'));
      }
      if (colorStr.length == 8) {
        return Color(int.parse('0x$colorStr'));
      }
    } catch (_) {
      debugPrint('Invalid color: $colorHex');
    }
    return AppColors.secondary;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildCurrentTimeIndicator(double hourHeight, double leftColumnWidth) {
    final now = DateTime.now();
    final topOffset = (now.hour * hourHeight) + (now.minute / 60 * hourHeight);

    return Positioned(
      top: topOffset - 1,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: leftColumnWidth,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.priorityHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  DateFormat('HH:mm').format(now),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: Divider(color: AppColors.priorityHigh, thickness: 1),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.priorityHigh,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineItem {
  final dynamic originalItem; // Task, Habit, or google_calendar.Event
  final int startMinutes;
  final int endMinutes;
  final String id;
  final int? slotIndex; // For Habit slots

  int column = 0;
  int totalColumnsInGroup = 1;

  TimelineItem({
    required this.originalItem,
    required this.startMinutes,
    required this.endMinutes,
    required this.id,
    this.slotIndex,
  });
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.dash = 6.0,
    this.borderRadius = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    // Draw dashed path
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, (distance + dash).clamp(0.0, metric.length)),
          Offset.zero,
        );
        distance += dash + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dash != dash ||
        oldDelegate.borderRadius != borderRadius;
  }
}

Color _energyColor(int level) {
  // Convert 0-10 scale to color
  // 0-3: low (orange), 4-6: medium (yellow), 7-10: high (green)
  if (level <= 3) return const Color(0xFFFF7043);
  if (level <= 6) return const Color(0xFFFFC107);
  return const Color(0xFF4CAF50);
}
