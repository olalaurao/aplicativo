// lib/ui/screens/planner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../services/undo_service.dart';
import '../theme.dart';
import '../../models/journal_entry.dart';
import '../../models/tracker_model.dart';
import '../../models/reminder_model.dart';
import '../widgets/timeline_day_view.dart';
import '../../services/scheduler_service.dart';
import '../../providers/google_calendar_provider.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;
import '../../providers/pomodoro_provider.dart';
import '../../models/people_model.dart';
import '../../models/day_theme_model.dart';
import '../widgets/object_action_wrapper.dart';
import 'pomodoro_screen.dart';
import 'google_event_detail_screen.dart';
import '../forms/create_task_form.dart';
import '../forms/create_habit_form.dart';
import '../../models/content_object.dart';
import 'universal_detail_view.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final bool showPopup;

  const PlannerScreen({super.key, this.initialDate, this.showPopup = false});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  int _viewMode = 0; // 0=Day, 1=Week, 2=Month
  bool _isTimeline = true;
  late DateTime _selectedDate;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    if (widget.initialDate != null) {
      _viewMode = 0; // Default to day view to show the timeline block
    }

    if (widget.showPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final tasks = ref.read(tasksProvider);
        final habits = ref.read(habitsProvider);
        _showDayDetailsSheet(_selectedDate, tasks, habits);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    final people = ref.watch(peopleProvider);
    final dayThemes = ref.watch(dayThemesProvider);
    final timeBlocks = ref.watch(timeBlocksProvider);
    final googleEvents = ref.watch(googleCalendarEventsProvider(_selectedDate));

    final dayName = const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][_selectedDate.weekday - 1];
    final activeTheme = dayThemes.cast<DayTheme?>().firstWhere(
      (theme) => theme != null && theme.daysOfWeek.contains(dayName),
      orElse: () => null,
    );
    final activeTimeBlocks =
        activeTheme == null
              ? <TimeBlock>[]
              : timeBlocks
                    .where((block) => activeTheme.blockIds.contains(block.id))
                    .toList()
          ..sort((a, b) {
            final aStart = a.timeRanges.isEmpty
                ? 24 * 60
                : (a.timeRanges.first.startHour * 60) +
                      a.timeRanges.first.startMinute;
            final bStart = b.timeRanges.isEmpty
                ? 24 * 60
                : (b.timeRanges.first.startHour * 60) +
                      b.timeRanges.first.startMinute;
            return aStart.compareTo(bStart);
          });

    bool isThemeActive(String themeId, DateTime date) {
      const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = weekDayNames[date.weekday - 1];
      return dayThemes.any(
        (theme) => theme.id == themeId && theme.daysOfWeek.contains(dayName),
      );
    }

    bool isBlockActive(String blockId, DateTime date) {
      return timeBlocks.any((block) {
        if (block.id != blockId) return false;
        return dayThemes.any((theme) {
          if (!theme.blockIds.contains(blockId)) return false;
          return isThemeActive(theme.id, date);
        });
      });
    }

    bool isItemScheduled(String linkedItemId, DateTime date) {
      final targetSlug = linkedItemId
          .replaceAll('[[', '')
          .replaceAll(']]', '')
          .trim()
          .toLowerCase();
      final reminders = ref.read(remindersProvider);

      final hasLinkedTask = tasks.any((t) {
        final isScheduled =
            (t.deadline != null && _isSameDay(t.deadline!, date)) ||
            (t.scheduler != null &&
                SchedulerService.shouldFire(
                  t.scheduler!,
                  date,
                  isThemeActive: isThemeActive,
                  isBlockActive: isBlockActive,
                ));
        if (!isScheduled) return false;
        return t.id == linkedItemId ||
            t.slug == targetSlug ||
            t.organizers.any(
              (o) =>
                  o.slug == targetSlug || o.title.toLowerCase() == targetSlug,
            );
      });
      if (hasLinkedTask) return true;

      final hasLinkedReminder = reminders.any((r) {
        final isScheduled =
            _isSameDay(r.time, date) ||
            (r.scheduler != null &&
                SchedulerService.shouldFire(
                  r.scheduler!,
                  date,
                  isThemeActive: isThemeActive,
                  isBlockActive: isBlockActive,
                ));
        if (!isScheduled) return false;
        return r.id == linkedItemId ||
            r.slug == targetSlug ||
            r.organizers.any(
              (o) =>
                  o.slug == targetSlug || o.title.toLowerCase() == targetSlug,
            );
      });
      return hasLinkedReminder;
    }

    final dayTasks = tasks.where((t) {
      if (t.deadline != null && _isSameDay(t.deadline!, _selectedDate)) {
        return true;
      }
      if (t.stage == TaskStage.finalized) return false;
      if (t.scheduler != null &&
          SchedulerService.shouldFire(
            t.scheduler!,
            _selectedDate,
            isThemeActive: isThemeActive,
            isBlockActive: isBlockActive,
            isItemScheduled: isItemScheduled,
          )) {
        return true;
      }
      return false;
    }).toList();

    final dayHabits = habits.where((h) {
      for (final s in h.schedulers) {
        if (SchedulerService.shouldFire(
          s,
          _selectedDate,
          isThemeActive: isThemeActive,
          isBlockActive: isBlockActive,
          isItemScheduled: isItemScheduled,
        )) {
          return true;
        }
      }
      return false;
    }).toList();

    final dayContactReminders = people.where((p) {
      if (p.lastContactDate == null || p.contactFrequency == null) return false;
      final nextContact = p.lastContactDate!.add(p.contactFrequency!);
      return _isSameDay(nextContact, _selectedDate);
    }).toList();

    final dayEntries = ref
        .watch(allEntriesProvider)
        .where((e) => _isSameDay(e.date, _selectedDate))
        .toList();
    final dayRecords = ref
        .watch(trackingRecordsProvider)
        .where((r) => _isSameDay(r.date, _selectedDate))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Planning',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                if (activeTheme != null)
                  Text(
                    activeTheme.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          _parsePlannerColor(activeTheme.color) ??
                          AppColors.primary,
                    ),
                  ),
              ],
            ),
            floating: true,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.inbox_rounded, color: AppColors.primary),
                tooltip: 'Backlog / Sem data',
                onPressed: _showBacklogSheet,
              ),
              if (_viewMode == 0)
                IconButton(
                  icon: Icon(
                    _isTimeline
                        ? Icons.view_agenda_outlined
                        : Icons.access_time_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () => setState(() => _isTimeline = !_isTimeline),
                ),
              IconButton(
                icon: const Icon(Icons.today_rounded, color: AppColors.primary),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime.now();
                    _viewMode = 0;
                  });
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToNow(animate: true),
                  );
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(_viewMode == 0 ? 120 : 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewToggle(),
                    if (_viewMode == 0) ...[
                      const SizedBox(height: 12),
                      _buildDateStrip(),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (_viewMode == 0)
            _isTimeline
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TimeLineDayView(
                        tasks: dayTasks,
                        selectedDate: _selectedDate,
                        allDayEvents: dayHabits,
                        googleEvents: googleEvents.maybeWhen(
                          data: (events) => events,
                          orElse: () => [],
                        ),
                        timeBlocks: activeTimeBlocks,
                        onTaskDrop: (task, time) {
                          final timeStr = DateFormat('HH:mm').format(time);
                          final isBacklog =
                              task.stage == TaskStage.idea ||
                              (task.startDate == null && task.endDate == null);

                          // Sugerir duração com base em estimatedMinutes se disponível
                          final targetDuration =
                              (task.estimatedMinutes != null &&
                                  task.estimatedMinutes! > 0)
                              ? task.estimatedMinutes!
                              : task.duration;

                          ref
                              .read(tasksProvider.notifier)
                              .updateTask(
                                task.copyWith(
                                  scheduledTime: timeStr,
                                  endDate: isBacklog
                                      ? _selectedDate
                                      : task.endDate,
                                  startDate: isBacklog
                                      ? _selectedDate
                                      : task.startDate,
                                  stage: TaskStage.todo,
                                  duration: targetDuration,
                                ),
                              );
                        },
                        onHabitDrop: (habit, time) async {
                          final updatedSlots = List<HabitSlot>.from(
                            habit.slots,
                          );
                          if (updatedSlots.isEmpty) {
                            updatedSlots.add(
                              HabitSlot(
                                reminderEnabled: true,
                                reminderTime: TimeOfDay(
                                  hour: time.hour,
                                  minute: time.minute,
                                ),
                              ),
                            );
                          } else {
                            updatedSlots[0] = HabitSlot(
                              time: updatedSlots[0].time,
                              completed: updatedSlots[0].completed,
                              label: updatedSlots[0].label,
                              reminderEnabled: true,
                              reminderTime: TimeOfDay(
                                hour: time.hour,
                                minute: time.minute,
                              ),
                              notificationType:
                                  updatedSlots[0].notificationType,
                              actions: updatedSlots[0].actions,
                            );
                          }
                          final updatedHabit = habit.copyWith(
                            slots: updatedSlots,
                          );
                          await ref
                              .read(habitsProvider.notifier)
                              .updateHabit(updatedHabit);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Hábito "${habit.displayTitle}" agendado para ${DateFormat('HH:mm').format(time)}',
                              ),
                            ),
                          );
                        },
                        onDurationChange: (item, newDuration) {
                          if (item is Task) {
                            ref
                                .read(tasksProvider.notifier)
                                .updateTask(
                                  item.copyWith(duration: newDuration),
                                );
                          }
                        },
                        onToggleComplete: _toggleTaskCompletion,
                        onPlay: _handlePlay,
                        onHabitToggle: (habit, slotIndex) async {
                          await ref
                              .read(habitsProvider.notifier)
                              .toggleHabit(
                                habit,
                                _selectedDate,
                                slotIndex: slotIndex,
                              );
                        },
                        colorMode: ref.watch(settingsProvider).plannerColorMode,
                      ),
                    ),
                  )
                : _buildDayAgendaView(
                    dayTasks,
                    dayHabits,
                    dayContactReminders,
                    dayEntries,
                    dayRecords,
                    googleEvents,
                  )
          else if (_viewMode == 1)
            _buildWeekView(tasks, habits)
          else
            _buildMonthView(tasks, habits),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    final labels = ['Day', 'Week', 'Month'];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(3, (i) {
          final selected = _viewMode == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.surfaceColor(context)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppTheme.textPrimaryColor(context)
                        : AppTheme.textMutedColor(context),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _scrollToNow({bool animate = false}) {
    if (!mounted ||
        !_scrollController.hasClients ||
        _viewMode != 0 ||
        !_isTimeline ||
        !_isSameDay(_selectedDate, DateTime.now())) {
      return;
    }
    const hourHeight = 80.0;
    const sliverHeaderEstimate = 190.0;
    final now = DateTime.now();
    final viewport = MediaQuery.of(context).size.height;
    final target =
        sliverHeaderEstimate +
        (now.hour * hourHeight) +
        (now.minute / 60 * hourHeight) -
        (viewport / 3);
    final max = _scrollController.position.maxScrollExtent;
    final offset = target.clamp(0.0, max);
    if (animate) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  Widget _buildDateStrip() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14, // 2 weeks
        itemBuilder: (context, index) {
          final date = DateTime.now()
              .subtract(Duration(days: DateTime.now().weekday - 1))
              .add(Duration(days: index));
          final isSelected = _isSameDay(date, _selectedDate);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: !isSelected
                    ? Border.all(
                        color: AppTheme.dividerColor(
                          context,
                        ).withValues(alpha: 0.5),
                        width: 1,
                      )
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppTheme.textMutedColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayAgendaView(
    List<Task> tasks,
    List<Habit> habits,
    List<Person> contactReminders,
    List<JournalEntry> entries,
    List<TrackingRecord> records,
    AsyncValue<List<google_calendar.Event>> googleEvents,
  ) {
    final dayThemes = ref.watch(dayThemesProvider);
    final timeBlocks = ref.watch(timeBlocksProvider);
    const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selectedDayName = weekDayNames[_selectedDate.weekday - 1];
    final activeThemeBlockIds = dayThemes
        .where((theme) => theme.daysOfWeek.contains(selectedDayName))
        .expand((theme) => theme.blockIds)
        .toSet();
    final activeBlocks =
        timeBlocks
            .where((block) => activeThemeBlockIds.contains(block.id))
            .toList()
          ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    final allDayTasks = tasks
        .where((t) => t.timeBlock == null || t.timeBlock!.isEmpty)
        .toList();
    final allDayHabits = habits
        .where((h) => h.timeBlock == null || h.timeBlock!.isEmpty)
        .toList();
    final pendingReminders =
        ref
            .watch(remindersProvider)
            .where(
              (r) =>
                  !r.isCompleted &&
                  (_isSameDay(r.time, _selectedDate) ||
                      (r.scheduler != null &&
                          SchedulerService.shouldFire(
                            r.scheduler!,
                            _selectedDate,
                          ))),
            )
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const Text(
            'Day Blocks',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildAllDaySection(allDayTasks, allDayHabits),
          if (activeBlocks.isNotEmpty) ...[
            ...activeBlocks.map((block) {
              final blockTasks = tasks
                  .where((t) => t.timeBlock == block.id)
                  .toList();
              final blockHabits = habits
                  .where((habit) => habit.timeBlock == block.id)
                  .toList();
              return _buildTimeBlockSection(block, blockTasks, blockHabits);
            }),
          ],
          const SizedBox(height: 24),

          googleEvents.when(
            data: (events) {
              if (events.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Google Calendar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...events.map((e) => _buildGoogleEventItem(e)),
                  const SizedBox(height: 24),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, stack) => const SizedBox.shrink(),
          ),

          if (contactReminders.isNotEmpty) ...[
            const Text(
              'Day Contacts',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...contactReminders.map((p) => _buildContactReminderItem(p)),
            const SizedBox(height: 24),
          ],
          if (pendingReminders.isNotEmpty) ...[
            const Text(
              'Lembretes pendentes',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...pendingReminders.map(_buildPendingReminderCard),
            const SizedBox(height: 24),
          ],
          if (entries.isNotEmpty || records.isNotEmpty) ...[
            const Text(
              "Day's Logs",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...entries.map((e) => _buildJournalEntryItem(e)),
            ...records.map((r) => _buildTrackingRecordItem(r)),
          ],
        ]),
      ),
    );
  }

  Widget _buildJournalEntryItem(JournalEntry entry) {
    final moodLabel = _journalMoodLabel(entry);
    return ObjectActionWrapper(
      object: entry,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: entry),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.habitPurple,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (moodLabel != null)
                      Text(
                        moodLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _journalMoodLabel(JournalEntry entry) {
    final raw = entry.moodSlug?.trim();
    if (raw == null || raw.isEmpty) return null;
    final moods = ref.read(moodsProvider);
    final mood = moods
        .where(
          (item) => item.id == raw || item.slug == raw || item.title == raw,
        )
        .firstOrNull;
    if (mood == null) return null;
    return '${mood.emoji} ${mood.title}';
  }

  Widget _buildPendingReminderCard(Reminder reminder) {
    return ObjectActionWrapper(
      object: reminder,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: reminder),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Não concluído • ${DateFormat('HH:mm').format(reminder.time)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingRecordItem(TrackingRecord record) {
    return ObjectActionWrapper(
      object: record,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: record),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: AppColors.habitOrange,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tracker Record',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${record.fieldValues.length} fields filled',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockAddButton(BuildContext context, String? blockId) {
    return GestureDetector(
      onTap: () {}, // Absorbs the tap so ExpansionTile doesn't toggle
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.add_circle_outline_rounded,
          size: 20,
          color: AppColors.primary,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onSelected: (value) {
          if (value == 'task') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTaskForm(initialTimeBlock: blockId),
              ),
            );
          } else if (value == 'habit') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateHabitForm(initialTimeBlock: blockId),
              ),
            );
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'task',
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text('Criar Tarefa'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'habit',
            child: Row(
              children: [
                Icon(Icons.loop_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Criar Hábito'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllDaySection(List<Task> tasks, List<Habit> habits) {
    final items = <ContentObject>[...tasks, ...habits]
      ..sort((a, b) => (a.order ?? 999).compareTo(b.order ?? 999));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecorationFlat(context),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Row(
            children: [
              const Icon(
                Icons.wb_sunny_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Dia Todo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              _buildBlockAddButton(context, null),
            ],
          ),
          children: [
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Nenhum item para o Dia Todo.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);

                    // Update orders in vault
                    for (int i = 0; i < items.length; i++) {
                      final obj = items[i];
                      if (obj.order != i) {
                        if (obj is Task) {
                          final updated = obj.copyWith(order: i);
                          await ref
                              .read(tasksProvider.notifier)
                              .updateTask(updated);
                        } else if (obj is Habit) {
                          final updated = obj.copyWith(order: i);
                          await ref
                              .read(habitsProvider.notifier)
                              .updateHabit(updated);
                        }
                      }
                    }
                  },
                  itemBuilder: (context, index) {
                    final item = items[index];
                    Widget child;
                    if (item is Task) {
                      child = _buildTaskItem(item);
                    } else {
                      child = _buildHabitItem(item as Habit);
                    }
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(item.id),
                      index: index,
                      child: child,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlockSection(
    TimeBlock block,
    List<Task> tasks,
    List<Habit> habits,
  ) {
    final ranges = block.timeRanges
        .map(
          (range) =>
              '${range.startHour.toString().padLeft(2, '0')}:${range.startMinute.toString().padLeft(2, '0')} - ${range.endHour.toString().padLeft(2, '0')}:${range.endMinute.toString().padLeft(2, '0')}',
        )
        .join(', ');
    final items = <ContentObject>[...tasks, ...habits]
      ..sort((a, b) => (a.order ?? 999).compareTo(b.order ?? 999));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecorationFlat(context),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Row(
            children: [
              const Icon(
                Icons.view_day_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (ranges.isNotEmpty) ...[
                Text(
                  ranges,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _buildBlockAddButton(context, block.id),
            ],
          ),
          children: [
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Nenhum item neste bloco.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);

                    // Update orders in vault
                    for (int i = 0; i < items.length; i++) {
                      final obj = items[i];
                      if (obj.order != i) {
                        if (obj is Task) {
                          final updated = obj.copyWith(order: i);
                          await ref
                              .read(tasksProvider.notifier)
                              .updateTask(updated);
                        } else if (obj is Habit) {
                          final updated = obj.copyWith(order: i);
                          await ref
                              .read(habitsProvider.notifier)
                              .updateHabit(updated);
                        }
                      }
                    }
                  },
                  itemBuilder: (context, index) {
                    final item = items[index];
                    Widget child;
                    if (item is Task) {
                      child = _buildTaskItem(item);
                    } else {
                      child = _buildHabitItem(item as Habit);
                    }
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(item.id),
                      index: index,
                      child: child,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactReminderItem(Person person) {
    return ObjectActionWrapper(
      object: person,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: person),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            children: [
              const Icon(
                Icons.person_pin_rounded,
                color: AppColors.info,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact ${person.title}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Frequency: every ${person.contactFrequency?.inDays} days',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.habitGreen,
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  // Update lastContactDate to today
                  final updated = person.copyWith(
                    lastContactDate: DateTime.now(),
                  );
                  await ref.read(vaultProvider.notifier).updateObject(updated);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Contact with ${person.title} logged!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width - 40,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(
            context,
          ).copyWith(color: AppColors.primary.withValues(alpha: 0.9)),
          child: Text(
            task.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildTaskCard(task)),
      child: _buildTaskCard(task),
    );
  }

  Widget _buildTaskCard(Task task) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final isBlocked = task.isBlocked(allObjects);

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
        borderRadius: BorderRadius.circular(16),
        child: Semantics(
          label: 'Task: ${task.title}',
          value: task.stage == TaskStage.finalized
              ? 'Completed'
              : (isBlocked ? 'Blocked' : 'Pending'),
          button: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(context),
            child: Row(
              children: [
                GestureDetector(
                  onTap: isBlocked
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Esta tarefa está bloqueada por dependências incompletas.',
                              ),
                            ),
                          );
                        }
                      : () {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(tasksProvider.notifier)
                              .updateTask(
                                task.copyWith(
                                  stage: task.stage == TaskStage.finalized
                                      ? TaskStage.todo
                                      : TaskStage.finalized,
                                ),
                              );
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      task.stage == TaskStage.finalized
                          ? Icons.check_box_rounded
                          : (isBlocked
                                ? Icons.lock_rounded
                                : Icons.check_box_outline_blank_rounded),
                      size: 20,
                      color: task.stage == TaskStage.finalized
                          ? AppColors.habitGreen
                          : (isBlocked ? AppColors.error : AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            decoration: task.stage == TaskStage.finalized
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.stage == TaskStage.finalized
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (task.scheduledTime != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.primary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.scheduledTime!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      if (task.subtasks.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${task.subtasks.where((s) => s.completed).length}/${task.subtasks.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (task.untilDone)
                  const Icon(
                    Icons.all_inclusive_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitItem(Habit habit) {
    final slots = habit.slots.isEmpty ? <HabitSlot>[HabitSlot()] : habit.slots;
    final isDone = _isHabitSlotDone(habit, 0);
    return LongPressDraggable<Habit>(
      data: habit,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width - 40,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(
            context,
          ).copyWith(color: AppColors.habitGreen.withValues(alpha: 0.9)),
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
        child: _buildHabitCard(habit, slots, isDone),
      ),
      child: _buildHabitCard(habit, slots, isDone),
    );
  }

  Widget _buildHabitCard(Habit habit, List<HabitSlot> slots, bool isDone) {
    return ObjectActionWrapper(
      object: habit,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: habit),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      habit.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (habit.isNegative)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: habit.streak > 3
                            ? AppColors.habitGreen.withValues(alpha: 0.1)
                            : AppColors.priorityHigh.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${habit.streak} dias livres',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: habit.streak > 3
                              ? AppColors.habitGreen
                              : AppColors.priorityHigh,
                        ),
                      ),
                    )
                  else
                    Text(
                      '🔥 ${habit.streak}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.priorityHigh,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ...slots.asMap().entries.map((entry) {
                final slotIndex = entry.key;
                final slot = entry.value;
                final slotDone = _isHabitSlotDone(habit, slotIndex);
                return _buildHabitSlotRow(habit, slot, slotIndex, slotDone);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitSlotRow(
    Habit habit,
    HabitSlot slot,
    int slotIndex,
    bool isDone,
  ) {
    final time = slot.reminderTime;
    final label = slot.label?.trim();
    final slotTitle = label == null || label.isEmpty
        ? (habit.slots.length > 1 ? 'Slot ${slotIndex + 1}' : 'Concluir')
        : label;
    final timeLabel = time == null
        ? null
        : MaterialLocalizations.of(context).formatTimeOfDay(time);

    return Padding(
      padding: EdgeInsets.only(top: slotIndex == 0 ? 0 : 8),
      child: Row(
        children: [
          if (!habit.isNegative) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(habitsProvider.notifier)
                    .toggleHabit(habit, _selectedDate, slotIndex: slotIndex);
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isDone ? AppColors.habitGreen : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Hábito negativo "${habit.displayTitle}" registrado',
                    ),
                    action: SnackBarAction(
                      label: 'REGISTRAR',
                      onPressed: () {
                        ref
                            .read(habitsProvider.notifier)
                            .toggleHabit(
                              habit,
                              _selectedDate,
                              slotIndex: slotIndex,
                            );
                      },
                    ),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(
                  Icons.do_not_disturb_on_rounded,
                  size: 20,
                  color: AppColors.priorityHigh,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              timeLabel == null ? slotTitle : '$slotTitle • $timeLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  bool _isHabitSlotDone(Habit habit, int slotIndex) {
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    for (final record in habit.completionHistory) {
      final recordDay = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (recordDay != selectedDay) continue;
      final slotCompletions = record.slotCompletions;
      if (slotCompletions != null && slotIndex < slotCompletions.length) {
        return slotCompletions[slotIndex];
      }
      return record.successful || record.completions > 0;
    }
    return false;
  }

  void _showBacklogSheet() {
    final tasks = ref.read(tasksProvider);
    final backlog = tasks
        .where(
          (t) =>
              (t.stage == TaskStage.idea ||
                  (t.startDate == null && t.deadline == null)) &&
              t.stage != TaskStage.finalized,
        )
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Backlog / Idea Box',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (backlog.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'Nenhuma tarefa sem data.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: backlog.length,
                    itemBuilder: (context, index) {
                      return _buildTaskItem(backlog[index]);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekView(List<Task> tasks, List<Habit> habits) {
    final reminders = ref.watch(remindersProvider);
    final startOfWeek = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final date = startOfWeek.add(Duration(days: index));

          final dayTasks = tasks
              .where((t) => t.deadline != null && _isSameDay(t.deadline!, date))
              .toList();
          final dayHabits = habits.where((h) {
            for (final s in h.schedulers) {
              if (SchedulerService.shouldFire(
                s,
                date,
                // Although we don't have isThemeActive easily available in this scope,
                // we can pass them if we redefine them or just use null for the week view fallback.
                // But wait, actually _buildWeekView doesn't have isThemeActive...
              )) {
                return true;
              }
            }
            return false;
          }).toList();
          final dayReminders = reminders.where((r) {
            if (r.isCompleted) return false;
            return _isSameDay(r.time, date) ||
                (r.scheduler != null &&
                    SchedulerService.shouldFire(r.scheduler!, date));
          }).toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        index == 0
                            ? 'Today'
                            : DateFormat('EEEE, d MMM').format(date),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _isSameDay(date, DateTime.now())
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (dayTasks.isNotEmpty || dayReminders.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${dayTasks.length + dayReminders.length} itens',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (dayTasks.isEmpty &&
                    dayHabits.isEmpty &&
                    dayReminders.isEmpty)
                  Consumer(
                    builder: (context, ref, _) {
                      final googleEvents = ref
                          .watch(googleCalendarEventsProvider(date))
                          .maybeWhen(
                            data: (events) => events,
                            orElse: () => <google_calendar.Event>[],
                          );
                      if (googleEvents.isEmpty) {
                        return const Text(
                          'Nada agendado',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        );
                      }
                      return Column(
                        children: googleEvents
                            .map(
                              (e) => _buildCompactItem(
                                e.summary ?? '(Untitled)',
                                AppColors.info,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GoogleEventDetailScreen(event: e),
                                    ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      );
                    },
                  )
                else ...[
                  ...dayTasks.map((t) => _buildCompactTaskItem(t)),
                  ...dayHabits.map((h) => _buildCompactHabitItem(h, date)),
                  ...dayReminders.map(_buildCompactReminderItem),
                  Consumer(
                    builder: (context, ref, _) {
                      final googleEvents = ref
                          .watch(googleCalendarEventsProvider(date))
                          .maybeWhen(
                            data: (events) => events,
                            orElse: () => <google_calendar.Event>[],
                          );
                      return Column(
                        children: googleEvents
                            .map(
                              (e) => _buildCompactItem(
                                e.summary ?? '(Untitled)',
                                AppColors.info,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GoogleEventDetailScreen(event: e),
                                    ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        }, childCount: 7),
      ),
    );
  }

  Widget _buildCompactItem(String title, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTaskItem(Task task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: task),
            ),
          );
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (_) => _toggleTaskCompletion(task),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 12,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.isCompleted
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactReminderItem(Reminder reminder) {
    return _buildCompactItem(
      '${DateFormat('HH:mm').format(reminder.time)}  ${reminder.title}',
      AppColors.warning,
      () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UniversalDetailView(object: reminder),
          ),
        );
      },
    );
  }

  Widget _buildCompactHabitItem(Habit habit, DateTime date) {
    final completed = _isHabitCompletedOn(habit, date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: habit),
            ),
          );
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            children: [
              Checkbox(
                value: completed,
                onChanged: (_) =>
                    ref.read(habitsProvider.notifier).toggleHabit(habit, date),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: AppColors.habitGreen,
                shape: const CircleBorder(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  habit.displayTitle,
                  style: TextStyle(
                    fontSize: 12,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    color: completed
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthView(List<Task> tasks, List<Habit> habits) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday; // 1=Mon, 7=Sun

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final day = index - (firstWeekday - 1) + 1;
            if (day < 1 || day > daysInMonth) return const SizedBox.shrink();

            final date = DateTime(now.year, now.month, day);
            final hasTask = tasks.any(
              (t) => t.deadline != null && _isSameDay(t.deadline!, date),
            );
            final isToday = _isSameDay(date, DateTime.now());

            return InkWell(
              onTap: () => _showDayDetailsSheet(date, tasks, habits),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasTask) ...[
                          const SizedBox(width: 2),
                          _dot(AppColors.secondary),
                        ],
                        Consumer(
                          builder: (context, ref, _) {
                            final googleEvents = ref
                                .watch(googleCalendarEventsProvider(date))
                                .maybeWhen(
                                  data: (events) => events,
                                  orElse: () => <google_calendar.Event>[],
                                );
                            if (googleEvents.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: _dot(AppColors.info),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: 35, // 5 rows
        ),
      ),
    );
  }

  void _showDayDetailsSheet(
    DateTime date,
    List<Task> tasks,
    List<Habit> habits,
  ) {
    final dayTasks = tasks
        .where((t) => t.deadline != null && _isSameDay(t.deadline!, date))
        .toList();
    final dayThemes = ref.read(dayThemesProvider);
    final timeBlocks = ref.read(timeBlocksProvider);

    bool isThemeActive(String themeId, DateTime date) {
      const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = weekDayNames[date.weekday - 1];
      return dayThemes.any(
        (theme) => theme.id == themeId && theme.daysOfWeek.contains(dayName),
      );
    }

    bool isBlockActive(String blockId, DateTime date) {
      return timeBlocks.any((block) {
        if (block.id != blockId) return false;
        return dayThemes.any((theme) {
          if (!theme.blockIds.contains(blockId)) return false;
          return isThemeActive(theme.id, date);
        });
      });
    }

    bool isItemScheduled(String linkedItemId, DateTime date) {
      final targetSlug = linkedItemId
          .replaceAll('[[', '')
          .replaceAll(']]', '')
          .trim()
          .toLowerCase();
      final reminders = ref.read(remindersProvider);

      final hasLinkedTask = tasks.any((t) {
        final isScheduled =
            (t.deadline != null && _isSameDay(t.deadline!, date)) ||
            (t.scheduler != null &&
                SchedulerService.shouldFire(
                  t.scheduler!,
                  date,
                  isThemeActive: isThemeActive,
                  isBlockActive: isBlockActive,
                ));
        if (!isScheduled) return false;
        return t.id == linkedItemId ||
            t.slug == targetSlug ||
            t.organizers.any(
              (o) =>
                  o.slug == targetSlug || o.title.toLowerCase() == targetSlug,
            );
      });
      if (hasLinkedTask) return true;

      final hasLinkedReminder = reminders.any((r) {
        final isScheduled =
            _isSameDay(r.time, date) ||
            (r.scheduler != null &&
                SchedulerService.shouldFire(
                  r.scheduler!,
                  date,
                  isThemeActive: isThemeActive,
                  isBlockActive: isBlockActive,
                ));
        if (!isScheduled) return false;
        return r.id == linkedItemId ||
            r.slug == targetSlug ||
            r.organizers.any(
              (o) =>
                  o.slug == targetSlug || o.title.toLowerCase() == targetSlug,
            );
      });
      return hasLinkedReminder;
    }

    final dayHabits = habits.where((h) {
      for (final s in h.schedulers) {
        if (SchedulerService.shouldFire(
          s,
          date,
          isThemeActive: isThemeActive,
          isBlockActive: isBlockActive,
          isItemScheduled: isItemScheduled,
        )) {
          return true;
        }
      }
      return false;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM').format(date),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (dayTasks.isEmpty && dayHabits.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'Nada agendado para este dia',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...dayTasks.map((t) => _buildTaskItem(t)),
                    ...dayHabits.map((h) => _buildHabitItem(h)),
                    Consumer(
                      builder: (context, ref, _) {
                        final googleEvents = ref
                            .watch(googleCalendarEventsProvider(date))
                            .maybeWhen(
                              data: (events) => events,
                              orElse: () => <google_calendar.Event>[],
                            );
                        return Column(
                          children: googleEvents
                              .map((e) => _buildGoogleEventItem(e))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  bool _isHabitCompletedOn(Habit habit, DateTime date) {
    return habit.completionHistory.any(
      (record) => _isSameDay(record.date, date) && record.successful,
    );
  }

  Widget _buildGoogleEventItem(google_calendar.Event event) {
    final startTime = event.start?.dateTime ?? event.start?.date;
    final endTime = event.end?.dateTime ?? event.end?.date;
    final timeStr = startTime != null && endTime != null
        ? '${DateFormat('HH:mm').format(startTime.toLocal())} - ${DateFormat('HH:mm').format(endTime.toLocal())}'
        : 'Dia Inteiro';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoogleEventDetailScreen(event: event),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(context),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.info,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.summary ?? '(Untitled)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (value) async {
                if (value == 'google') {
                  final url = event.htmlLink;
                  if (url != null && await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'google',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Abrir no Google Agenda'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTaskCompletion(Task task) {
    final wasFinalized = task.stage == TaskStage.finalized;
    final newStage = wasFinalized ? TaskStage.todo : TaskStage.finalized;
    ref.read(tasksProvider.notifier).updateTask(task.copyWith(stage: newStage));

    if (newStage == TaskStage.finalized) {
      HapticFeedback.heavyImpact();
      // Show undo snackbar
      UndoService.showUndoSnackbar(
        context: context,
        message: '"${task.title}" completed!',
        onUndo: () {
          ref
              .read(tasksProvider.notifier)
              .updateTask(task.copyWith(stage: TaskStage.todo));
        },
      );
      // Offer reflection prompt after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showReflectionPrompt(task);
      });
    }
  }

  void _showReflectionPrompt(Task task) {
    final reflectionController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✅', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Reflection (optional)',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reflectionController,
              maxLines: 3,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Como foi? O que aprendeu?',
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final reflection = reflectionController.text.trim();
                  if (reflection.isNotEmpty) {
                    // Persist reflection in task notes
                    final updatedNotes = List<String>.from(task.notes);
                    updatedNotes.add('Reflection: $reflection');
                    ref
                        .read(tasksProvider.notifier)
                        .updateTask(
                          task.copyWith(
                            stage: TaskStage.finalized,
                            notes: updatedNotes,
                          ),
                        );
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('DONE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePlay(dynamic item) {
    String title = '';
    String? id;

    if (item is Task) {
      title = item.title;
      id = item.id;
    }

    ref.read(pomodoroProvider.notifier).setCurrentItem(id, title);

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PomodoroScreen()));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color? _parsePlannerColor(String? color) {
    if (color == null || color.trim().isEmpty) return null;
    try {
      final colorStr = color.trim().replaceAll('#', '');
      if (colorStr.length == 6) {
        return Color(int.parse('0xFF$colorStr'));
      }
      if (colorStr.length == 8) {
        return Color(int.parse('0x$colorStr'));
      }
    } catch (_) {
      debugPrint('Invalid planner color: $color');
    }
    return null;
  }
}
