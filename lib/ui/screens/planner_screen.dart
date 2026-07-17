// lib/ui/screens/planner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/kpi_model.dart';
import '../../models/mood_model.dart';
import '../../models/note_model.dart';
import '../../models/organizer_model.dart';
import '../../models/routine_model.dart';
import '../../models/shared_types.dart';
import '../widgets/routine_execution_sheet.dart';
import '../theme.dart';
import '../../models/journal_entry.dart';
import '../../models/tracker_model.dart';
import '../../models/reminder_model.dart';
import '../../models/reminder_config.dart';
import '../../models/task_model.dart';
import '../../models/pomodoro_session.dart';
import '../../models/day_dial_model.dart';
import '../../models/event_model.dart';
import '../widgets/timeline_day_view.dart';
import '../widgets/week_time_grid.dart';
import '../widgets/day_dial_widget.dart';
import '../utils/object_icons.dart';

import '../../services/day_dial_aggregator.dart';
import '../../services/day_dial_legend_builder.dart';
import '../../services/scheduler_service.dart';
import '../../providers/google_calendar_provider.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;
import '../../providers/pomodoro_provider.dart';
import '../../models/people_model.dart';
import '../../models/habit_model.dart';
import '../../services/undo_service.dart';
import '../../models/project_model.dart';
import '../../services/rotation_service.dart';
import '../widgets/object_action_wrapper.dart';
import 'pomodoro_screen.dart';
import 'google_event_detail_screen.dart';
import '../forms/create_task_form.dart';
import '../forms/create_habit_form.dart';
import '../widgets/overdue_section.dart';
import '../../models/content_object.dart';
import 'universal_detail_view.dart';
import '../widgets/triple_check_sheet.dart';
import '../../providers/overdue_provider.dart';

List<Task> rotationTasksForDay(
  DateTime date,
  List<Task> tasks,
  List<Project> projects,
) {
  final result = <Task>[];
  final dateOnly = DateTime(date.year, date.month, date.day);

  for (final project in projects) {
    if (!project.hasRotation) continue;
    final status = RotationService.computeActiveStatus(project, now: dateOnly);
    if (status == null) continue;

    for (final task in tasks) {
      if (task.stage == TaskStage.finalized || task.archived) continue;
      if (!task.isRotationTask) continue;
      if (task.rotationGroupId != status.group.id) continue;
      final linkedToProject = task.organizers.any(
        (o) => o.type == 'project' && o.slug == project.slug,
      );
      if (!linkedToProject) continue;

      final include = switch (task.rotationFrequencyType) {
        RotationFrequencyType.daily => true,
        RotationFrequencyType.oncePerPeriod =>
          !RotationService.isDoneThisOccurrence(task, status),
        RotationFrequencyType.everyNRotations =>
          RotationService.isDueNow(task, status) &&
              !RotationService.isDoneThisOccurrence(task, status),
        RotationFrequencyType.none => false,
      };
      if (include) result.add(task);
    }
  }
  return result;
}

List<Task> mergeDayTasksWithRotation(
  List<Task> base,
  DateTime date,
  List<Task> allTasks,
  List<Project> projects,
) {
  final rotation = rotationTasksForDay(date, allTasks, projects);
  final ids = base.map((t) => t.id).toSet();
  return [...base, ...rotation.where((t) => !ids.contains(t.id))];
}

class PlannerScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final bool showPopup;

  const PlannerScreen({super.key, this.initialDate, this.showPopup = false});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen>
    with AutomaticKeepAliveClientMixin {
  int _viewMode = 0; // 0=Day, 1=Week, 2=Month, 3=Dial
  bool _isTimeline = true;
  late DateTime _selectedDate;
  final ScrollController _scrollController = ScrollController();
  bool _showJumpToNowFab = false;
  int _gridGranularity = 30; // 15, 30, or 60 minutes
  bool _showBacklogPanel = false;
  bool _showActionsPanel = false;

  @override
  bool get wantKeepAlive => true;

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
        final allObjects = ref.read(allObjectsProvider).value ?? [];
        final tasks = allObjects.whereType<Task>().toList();
        final habits = ref.read(habitsProvider);
        _showDayDetailsSheet(_selectedDate, tasks, habits);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    
    // Show FAB when scrolled away from current time
    if (_isSameDay(_selectedDate, DateTime.now()) && _isTimeline && _viewMode == 0) {
      const hourHeight = 80.0;
      const sliverHeaderEstimate = 190.0;
      final now = DateTime.now();
      final viewport = MediaQuery.of(context).size.height;
      final currentOffset = sliverHeaderEstimate +
          (now.hour * hourHeight) +
          (now.minute / 60 * hourHeight) -
          (viewport / 3);
      
      final currentScrollOffset = _scrollController.offset;
      const threshold = 100.0;
      
      setState(() {
        _showJumpToNowFab = (currentScrollOffset - currentOffset).abs() > threshold;
      });
    } else {
      setState(() {
        _showJumpToNowFab = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final tasks = ref.watch(tasksListProvider);
    final organizers = ref.watch(organizersListProvider);
    final projects = ref.watch(projectsProvider.select((projects) => projects.toList()));
    final habits = ref.watch(habitsProvider.select((habits) => habits.where((h) => !h.isQuitting && !h.isNegative).toList()));
    final people = ref.watch(peopleProvider.select((people) => people.toList()));
    final dayThemes = organizers.where((o) => o.organizerType == OrganizerType.dayTheme).toList();
    final timeBlocks = organizers.where((o) => o.organizerType == OrganizerType.timeBlock).toList();
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
    final activeTheme = dayThemes.cast<Organizer?>().firstWhere(
      (theme) => theme != null && theme.daysOfWeek.contains(dayName),
      orElse: () => null,
    );
    final activeTimeBlocks =
        activeTheme == null
              ? <Organizer>[]
              : timeBlocks
                    .where((block) => activeTheme.organizers.any((ref) => ref.matches(block.id, block.slug, block.title)))
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
          if (!theme.organizers.any((ref) => ref.matches(block.id, block.slug, block.title))) return false;
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

    final baseDayTasks = tasks.where((t) {
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

    final dayTasks = mergeDayTasksWithRotation(
      baseDayTasks,
      _selectedDate,
      tasks,
      projects,
    );

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
            toolbarHeight: activeTheme != null ? 60.0 : 48.0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Planning',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                if (activeTheme != null)
                  Text(
                    activeTheme.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          _parsePlannerColor(activeTheme.color) ??
                          AppTheme.accentColor(context),
                    ),
                  ),
              ],
            ),
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  _showActionsPanel ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.accentColor(context),
                ),
                tooltip: 'Ações',
                onPressed: () => setState(() => _showActionsPanel = !_showActionsPanel),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(
                _showActionsPanel 
                    ? (_viewMode == 0 ? 240 : 120)
                    : (_viewMode == 0 ? 180 : 60),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewToggle(),
                    if (_showActionsPanel) ...[
                      const SizedBox(height: 12),
                      _buildActionsPanel(activeTheme),
                    ],
                    if (_viewMode == 0) ...[
                      const SizedBox(height: 12),
                      _buildDateStrip(),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (_viewMode == 0) ...[
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
                        activeTheme: activeTheme,
                        gridGranularity: _gridGranularity,
                        pomodoroSessions: ref.watch(pomodoroProvider.select((p) => p.history)),
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

                          final updated = task.copyWith(
                            scheduledTime: timeStr,
                            endDate: isBacklog
                                ? _selectedDate
                                : task.endDate,
                            startDate: isBacklog
                                ? _selectedDate
                                : task.startDate,
                            stage: TaskStage.todo,
                            duration: targetDuration,
                          );
                          ref.read(vaultProvider.notifier).updateObject(updated);
                        },
                        onHabitDrop: (habit, time) async {
                          final updatedSlots = List<HabitSlot>.from(
                            habit.slots,
                          );
                          if (updatedSlots.isEmpty) {
                            updatedSlots.add(
                              HabitSlot(
                                reminders: [
                                  ReminderConfig(
                                    id: 'primary',
                                    timeOfDay:
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                  ),
                                ],
                              ),
                            );
                          } else {
                            final updatedSlot = HabitSlot(
                              time: updatedSlots[0].time,
                              completed: updatedSlots[0].completed,
                              label: updatedSlots[0].label,
                              reminders: List<ReminderConfig>.from(
                                updatedSlots[0].reminders,
                              ),
                              actions: updatedSlots[0].actions,
                            );
                            updatedSlot.enableDefaultReminder();
                            updatedSlot.setPrimaryReminderTime(
                              TimeOfDay(
                                hour: time.hour,
                                minute: time.minute,
                              ),
                            );
                            updatedSlot.setPrimaryReminderType(
                              updatedSlots[0].primaryReminderType,
                            );
                            updatedSlots[0] = HabitSlot(
                              time: updatedSlot.time,
                              completed: updatedSlot.completed,
                              label: updatedSlot.label,
                              reminders: updatedSlot.reminders,
                              actions: updatedSlot.actions,
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
                            final updated = item.copyWith(duration: newDuration);
                            ref.read(vaultProvider.notifier).updateObject(updated);
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
                        colorMode: ref.watch(settingsProvider.select((s) => s.plannerColorMode)),
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
                  ),
          ] else if (_viewMode == 1)
            _buildWeekView(tasks, habits)
          else if (_viewMode == 2)
            _buildMonthView(tasks, habits)
          else if (_viewMode == 3)
            _buildDialView(tasks, habits, googleEvents),

          if (_showBacklogPanel)
            SliverToBoxAdapter(child: _buildBacklogPanel()),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _showJumpToNowFab && _isTimeline && _viewMode == 0
          ? FloatingActionButton.extended(
              onPressed: () => _scrollToNow(animate: true),
              icon: const Icon(Icons.access_time_rounded),
              label: const Text('Jump to now'),
              backgroundColor: AppTheme.accentColor(context),
            )
          : null,
    );
  }

  Widget _buildBacklogPanel() {
    final allObjects = ref.read(allObjectsProvider).value ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    final routines = allObjects
        .whereType<Routine>()
        .where(
          (routine) => routine.showInPlanner,
        )
        .toList();
    final backlog = tasks
        .where(
          (t) =>
              (t.stage == TaskStage.idea ||
                  (t.startDate == null && t.deadline == null)) &&
              t.stage != TaskStage.finalized,
        )
        .toList();

    final isTablet = MediaQuery.of(context).size.width > 600;

    if (isTablet) {
      // Side drawer for tablet/desktop
      return Drawer(
        width: 350,
        child: Container(
          color: AppTheme.surfaceColor(context),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantColor(context),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Backlog / Idea Box',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _showBacklogPanel = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: backlog.isEmpty && routines.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text(
                            'Nenhuma tarefa sem data.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ...backlog.map(_buildTaskItem),
                          ...routines.map(_buildRoutineItem),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Bottom strip for mobile
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor(context),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Backlog',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _showBacklogPanel = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: backlog.isEmpty && routines.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma tarefa sem data.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        ...backlog.take(5).map(_buildTaskItem),
                        ...routines.take(3).map(_buildRoutineItem),
                      ],
                    ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildViewToggle() {
    const labels = ['Day', 'Week', 'Month', 'Dial'];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(4, (i) {
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

  Widget _buildActionsPanel(Organizer? activeTheme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Day theme emojis
          if (activeTheme != null)
            _buildDayThemeEmojiButton(activeTheme),
          // Overdue button
          _buildOverdueButton(),
          // Backlog button
          IconButton(
            icon: Icon(Icons.inbox_rounded, color: AppTheme.accentColor(context)),
            tooltip: 'Backlog / Sem data',
            onPressed: () => setState(() => _showBacklogPanel = !_showBacklogPanel),
          ),
          // Grid density button
          if (_viewMode == 0 && _isTimeline)
            IconButton(
              icon: Icon(Icons.grid_view_rounded, color: AppTheme.textMutedColor(context)),
              tooltip: 'Grid density',
              onPressed: () {
                setState(() {
                  if (_gridGranularity == 30) {
                    _gridGranularity = 15;
                  } else if (_gridGranularity == 15) {
                    _gridGranularity = 60;
                  } else {
                    _gridGranularity = 30;
                  }
                });
              },
            ),
          // View toggle button
          if (_viewMode == 0)
            IconButton(
              icon: Icon(
                _isTimeline
                    ? Icons.view_list_rounded
                    : Icons.view_timeline_rounded,
                size: 22,
                color: AppTheme.textMutedColor(context),
              ),
              tooltip: _isTimeline ? 'Ver como lista' : 'Ver como timeline',
              onPressed: () => setState(() => _isTimeline = !_isTimeline),
            ),
          // Today button
          IconButton(
            icon: Icon(Icons.today_rounded, color: AppTheme.accentColor(context)),
            tooltip: 'Hoje',
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

  Future<void> _pickCustomDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToNow(animate: true),
      );
    }
  }

  Widget _buildDateStrip() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => setState(
            () =>
                _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _pickCustomDate,
            child: Text(
              DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDate),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => setState(
            () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
          ),
        ),
        if (!_isSameDay(_selectedDate, DateTime.now()))
          TextButton(
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToNow(animate: true),
              );
            },
            child: Text(
              'Hoje',
              style: TextStyle(
                color: AppTheme.accentColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverdueButton() {
    final overdueCount = ref.watch(overdueCountProvider.select((count) => count));
    if (overdueCount == 0) return const SizedBox.shrink();
    
    return IconButton(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.error,
      ),
      tooltip: 'Atrasados ($overdueCount)',
      onPressed: () => _showOverduePopup(),
    );
  }

  void _showOverduePopup() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantColor(context),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Atrasados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: const OverdueSection(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayThemeEmojiButton(Organizer theme) {
    final emoji = theme.icon ?? '📅';
    return IconButton(
      icon: Text(
        emoji,
        style: const TextStyle(fontSize: 20),
      ),
      tooltip: theme.title,
      onPressed: () => _showDayThemePopup(theme),
    );
  }

  void _showDayThemePopup(Organizer theme) {
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
                          'Dias: ${theme.daysOfWeek.join(", ")}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMutedColor(context),
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

  Widget _buildDayAgendaView(
    List<Task> tasks,
    List<Habit> habits,
    List<Person> contactReminders,
    List<JournalEntry> entries,
    List<TrackingRecord> records,
    AsyncValue<List<google_calendar.Event>> googleEvents,
  ) {
    final organizers = ref.watch(organizersListProvider);
    final dayThemes = organizers.where((o) => o.organizerType == OrganizerType.dayTheme).toList();
    final timeBlocks = organizers.where((o) => o.organizerType == OrganizerType.timeBlock).toList();
    const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selectedDayName = weekDayNames[_selectedDate.weekday - 1];
    final activeThemeBlockIds = dayThemes
        .where((theme) => theme.daysOfWeek.contains(selectedDayName))
        .expand((theme) => theme.organizers.map((ref) => ref.slug))
        .toSet();
    final activeBlocks =
        timeBlocks
            .where((block) => activeThemeBlockIds.any((slug) =>
                slug == block.id || slug == block.slug))
            .toList()
          ..sort((a, b) {
            final aStart = a.timeRanges.isEmpty ? 24 * 60 : (a.timeRanges.first.startHour * 60) + a.timeRanges.first.startMinute;
            final bStart = b.timeRanges.isEmpty ? 24 * 60 : (b.timeRanges.first.startHour * 60) + b.timeRanges.first.startMinute;
            return aStart.compareTo(bStart);
          });

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
                    Consumer(
                      builder: (ctx, ref, _) {
                        final tracker = ref.watch(
                          trackersProvider.select((trackers) => trackers.cast<dynamic>().firstWhere(
                            (t) => t.id == record.trackerId,
                            orElse: () => null,
                          ))
                        );
                        return Text(
                          tracker?.title ?? 'Registro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
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
        icon: Icon(
          Icons.add_circle_outline_rounded,
          size: 20,
          color: AppTheme.accentColor(context),
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
          PopupMenuItem(
            value: 'task',
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: AppTheme.accentColor(context),
                ),
                SizedBox(width: 8),
                Text('Criar Tarefa'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'habit',
            child: Row(
              children: [
                Icon(Icons.loop_rounded, size: 18, color: AppTheme.accentColor(context)),
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
              Icon(
                Icons.wb_sunny_rounded,
                size: 18,
                color: AppTheme.accentColor(context),
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
                          await ref.read(vaultProvider.notifier).updateObject(updated);
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
    Organizer block,
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
    final energyLevel = block.energyLevel;
    final energyColor = energyLevel == null
        ? null
        : _energyTintColor(energyLevel);
    final isHighEnergyBlock = energyLevel != null && energyLevel >= 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecorationFlat(
        context,
      ).copyWith(color: energyColor?.withValues(alpha: 0.08)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Row(
            children: [
              Icon(
                Icons.view_day_rounded,
                size: 18,
                color: AppTheme.accentColor(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isHighEnergyBlock) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '⚡ High energy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
                          await ref.read(vaultProvider.notifier).updateObject(updated);
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
                      child = _buildTaskItem(
                        item,
                        isHighEnergyBlock: isHighEnergyBlock,
                      );
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

  Color _energyTintColor(int level) {
    // Convert 0-10 scale to color
    // 0-3: low (orange), 4-6: medium (yellow), 7-10: high (green)
    if (level <= 3) return AppColors.habitOrange;
    if (level <= 6) return AppColors.warning;
    return AppColors.success;
  }

  Widget _buildTaskItem(Task task, {bool isHighEnergyBlock = false}) {
    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width - 40,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(
            context,
          ).copyWith(color: AppTheme.accentColor(context).withValues(alpha: 0.9)),
          child: Text(
            task.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTaskCard(task, isHighEnergyBlock: isHighEnergyBlock),
      ),
      child: _buildTaskCard(task, isHighEnergyBlock: isHighEnergyBlock),
    );
  }

  Widget _buildTaskCard(Task task, {bool isHighEnergyBlock = false}) {
    final tasks = ref.watch(tasksListProvider);
    final isBlocked = task.isBlocked(tasks.cast<ContentObject>());
    final isBestTime =
        isHighEnergyBlock &&
        (task.priority == TaskPriority.high || task.duration >= 60);

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
                          final updated = task.copyWith(
                            stage: task.stage == TaskStage.finalized
                                ? TaskStage.todo
                                : TaskStage.finalized,
                          );
                          ref.read(vaultProvider.notifier).updateObject(updated);
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            if (task.tripleCheck != null) ...[
                              const SizedBox(height: 4),
                              TripleCheckIconRow(
                                tripleCheck: task.tripleCheck!,
                                onTap: () => showTripleCheckSheet(
                                  context,
                                  ref,
                                  task,
                                  readOnly: true,
                                ),
                              ),
                            ],
                            if (isBestTime) ...[
                              const SizedBox(height: 4),
                              const Text(
                                '↑ Best time',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (task.needsTripleCheckBadge) ...[
                        const SizedBox(width: 8),
                        TripleCheckBadge(
                          onTap: () => showTripleCheckSheet(context, ref, task),
                        ),
                      ],
                      if (task.scheduledTime != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppTheme.accentColor(context).withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.scheduledTime!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentColor(context).withValues(alpha: 0.8),
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
                  Icon(
                    Icons.all_inclusive_rounded,
                    size: 14,
                    color: AppTheme.accentColor(context),
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
    final time = slot.primaryReminderTime;
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
    final allObjects = ref.read(allObjectsProvider).value ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    final routines = allObjects
        .whereType<Routine>()
        .where(
          (routine) => routine.showInPlanner,
        )
        .toList();
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
              if (backlog.isEmpty && routines.isEmpty)
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
                  child: ListView(
                    children: [
                      if (routines.isNotEmpty) ...[
                        _buildBacklogSectionTitle('Rotinas'),
                        ...routines.map(_buildRoutineItem),
                        const SizedBox(height: 12),
                      ],
                      if (backlog.isNotEmpty) ...[
                        _buildBacklogSectionTitle('Tarefas'),
                        ...backlog.map(_buildTaskItem),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBacklogSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildRoutineItem(Routine routine) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.repeat_rounded, color: AppColors.info),
      title: Text(
        routine.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Rotina',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        Navigator.pop(context);
        showRoutineExecutionSheet(context, routine);
      },
      trailing: IconButton(
        icon: const Icon(Icons.info_outline, size: 18),
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UniversalDetailView(object: routine)),
          );
        },
      ),
    );
  }

  Widget _buildWeekView(List<Task> tasks, List<Habit> habits) {
    final organizers = ref.watch(organizersListProvider);
    final dayThemes = organizers.where((o) => o.organizerType == OrganizerType.dayTheme).toList();
    final timeBlocks = organizers.where((o) => o.organizerType == OrganizerType.timeBlock).toList();
    final startOfWeek = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 600,
          child: WeekTimeGrid(
            tasks: tasks,
            habits: habits,
            startOfWeek: startOfWeek,
            dayThemes: dayThemes,
            timeBlocks: timeBlocks,
            onTaskTap: (task, date) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversalDetailView(object: task),
                ),
              );
            },
            onHabitTap: (habit) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversalDetailView(object: habit),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDialView(
    List<Task> tasks,
    List<Habit> habits,
    AsyncValue<List<google_calendar.Event>> googleEvents,
  ) {
    final pomodoroSessions = ref.watch(pomodoroProvider.select((p) => p.history));
    final events = googleEvents.maybeWhen(
      data: (events) => events,
      orElse: () => <google_calendar.Event>[],
    );

    final allOrganizers = ref.watch(organizersProvider.select((orgs) => orgs.where((o) => o.organizerType == OrganizerType.timeBlock).toList()));
    final timeBlocks = allOrganizers;
    
    final allObjects = ref.watch(allObjectsProvider.select((async) => async.valueOrNull ?? []));
    
    final reminders = ref.watch(aggregatedRemindersProvider).where((r) => 
      !r.isCompleted && 
      _isSameDay(r.time, _selectedDate)
    ).toList();
    
    final journalEntries = ref.watch(journalEntriesListProvider).where((j) =>
      _isSameDay(j.date, _selectedDate)
    ).toList();
    
    final moodDefinitions = ref.watch(moodsProvider.select((moods) => moods.toList()));
    final settings = ref.watch(settingsProvider.select((s) => s));
    final typeSignatures = settings.typeSignatures;
    
    // Get day theme for selected date
    const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = weekDayNames[_selectedDate.weekday - 1];
    final dayThemes = allOrganizers.where((o) => o.organizerType == OrganizerType.dayTheme).toList();
    final activeTheme = dayThemes.cast<Organizer?>().firstWhere(
      (theme) => theme != null && theme.daysOfWeek.contains(dayName),
      orElse: () => null,
    );
    
    final snapshot = DayDialAggregator.aggregateForDate(
      date: _selectedDate,
      tasks: tasks,
      habits: habits,
      pomodoroSessions: pomodoroSessions,
      googleEvents: events,
      localEvents: ref.watch(allObjectsProvider.select((async) => async.valueOrNull ?? [])).whereType<Event>().where((e) => _isSameDay(e.date, _selectedDate)).toList(),
      reminders: reminders,
      timeBlocks: timeBlocks,
      journalEntries: journalEntries,
      moodCatalog: moodDefinitions,
      typeSignatures: typeSignatures,
    );

    final showLegendSetting = settings.showDayDialLegend;

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot.nextUpcoming != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: _buildNextUpcoming(snapshot.nextUpcoming!, DateTime.now()),
              ),
            if (activeTheme != null)
              GestureDetector(
                onTap: () => _showDayThemePopup(activeTheme),
                child: Text(
                  activeTheme.icon ?? '📅',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            if (activeTheme != null) const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: Builder(builder: (ctx) {
                final settings = ref.watch(settingsProvider);
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                final hexStr = isDark ? settings.darkBackgroundColor : settings.backgroundColor;
                Color dialBg = Theme.of(ctx).colorScheme.surface;
                if (hexStr != null && hexStr.isNotEmpty) {
                  final clean = hexStr.trim().replaceAll('#', '');
                  if (clean.length == 6) {
                    try { dialBg = Color(int.parse('0xFF$clean')); } catch (_) {}
                  }
                }
                return DayDialWidget(
                  snapshot: snapshot,
                  selectedDate: _selectedDate,
                  backgroundColor: dialBg,
                  iconColor: Theme.of(ctx).colorScheme.onSurface,
                  onHourTap: (hour) {
                    setState(() {
                      _viewMode = 0;
                      _isTimeline = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      const hourHeight = 80.0;
                      const sliverHeaderEstimate = 190.0;
                      final viewport = MediaQuery.of(context).size.height;
                      final targetOffset = sliverHeaderEstimate +
                          (hour * hourHeight) -
                          (viewport / 3);
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          targetOffset,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      }
                    });
                  },
                  onSegmentTap: (segment) {
                    if (segment.sourceSlug == null) return;
                    final objIndex = allObjects.indexWhere((o) => o.id == segment.sourceSlug || o.slug == segment.sourceSlug);
                    if (objIndex != -1) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UniversalDetailView(object: allObjects[objIndex])),
                      );
                    }
                  },
                  onSegmentMove: (segment, newStart) => _persistMove(segment, newStart),
                  onSegmentResize: (segment, newEnd) => _persistResize(segment, newEnd),
                );
              }),
            ),
            if (showLegendSetting)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
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
                    _buildDialLegend(snapshot.segments),
                    const SizedBox(height: 12),
                    _buildDialChronologicalList(snapshot.segments, allObjects, typeSignatures),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextUpcoming(DialSegment next, DateTime now) {
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

  Widget _buildDialLegend(List<DialSegment> segments) {
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
          if (entry.icon != null) ...[
            Icon(
              entry.icon,
              size: 12,
              color: entry.color,
            ),
            const SizedBox(width: 4),
          ] else ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
          ],
          Text(
            '${entry.categoryLabel} ${entry.totalHours.toStringAsFixed(1)}h',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      )).toList(),
    );
  }

  Widget _buildDialChronologicalList(List<DialSegment> segments, List<dynamic> allObjects, Map<String, TypeSignature> typeSignatures) {
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Sort by start time
    final sortedSegments = List<DialSegment>.from(segments)..sort((a, b) => a.start.compareTo(b.start));
    
    return SizedBox(
      height: 200,
      child: ListView.builder(
        itemCount: sortedSegments.length,
        itemBuilder: (context, index) {
          final segment = sortedSegments[index];
          final timeStr = DateFormat('HH:mm').format(segment.start);
          final emoji = _getIconForSegment(segment, typeSignatures);
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
                final objIndex = allObjects.indexWhere((o) => o.id == segment.sourceSlug || o.slug == segment.sourceSlug);
                if (objIndex != -1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UniversalDetailView(object: allObjects[objIndex])),
                  );
                }
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
                  Icon(
                    emoji,
                    size: 14,
                    color: segColor,
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
                              completedAt: DateTime.now(),
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

  IconData _getIconForSegment(DialSegment segment, Map<String, TypeSignature> typeSignatures) {
    // Fallback icons based on segment kind using ObjectIcons
    IconData? icon;
    switch (segment.kind) {
      case DialSegmentKind.taskPlanned:
        icon = ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.task, typeSignatures);
        break;
      case DialSegmentKind.habitSlot:
        icon = ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.habit, typeSignatures);
        break;
      case DialSegmentKind.event:
        icon = ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.event, typeSignatures);
        break;
      case DialSegmentKind.pomodoroPlanned:
      case DialSegmentKind.pomodoroCompleted:
        icon = Icons.timer;
        break;
      case DialSegmentKind.timeBlock:
        icon = ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.timeBlock, typeSignatures);
        break;
      case DialSegmentKind.reminder:
        icon = ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.reminder, typeSignatures);
        break;
      case DialSegmentKind.dayTheme:
        icon = ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.dayTheme, typeSignatures);
        break;
      case DialSegmentKind.sleep:
        icon = Icons.bedtime;
        break;
    }
    
    // Fallback to default icons if null
    return icon ?? switch (segment.kind) {
      DialSegmentKind.taskPlanned => Icons.check_circle_outline,
      DialSegmentKind.habitSlot => Icons.refresh,
      DialSegmentKind.event => Icons.calendar_today,
      DialSegmentKind.pomodoroPlanned || DialSegmentKind.pomodoroCompleted => Icons.timer,
      DialSegmentKind.timeBlock => Icons.access_time,
      DialSegmentKind.reminder => Icons.notifications,
      DialSegmentKind.dayTheme => Icons.wb_sunny,
      DialSegmentKind.sleep => Icons.bedtime,
    };
  }

  void _persistMove(DialSegment segment, DateTime newStart) {
    final vault = ref.read(vaultProvider.notifier);
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    
    if (segment.kind == DialSegmentKind.taskPlanned) {
      final idx = allObjects.indexWhere((o) => o is Task && (o.id == segment.sourceSlug || o.slug == segment.sourceSlug));
      if (idx != -1) {
        final task = allObjects[idx] as Task;
        final formattedTime = DateFormat('HH:mm').format(newStart);
        vault.updateObject(task.copyWith(scheduledTime: formattedTime));
      }
    } else if (segment.kind == DialSegmentKind.pomodoroPlanned) {
      final sessionParts = segment.id.split(':');
      if (sessionParts.length >= 2) {
        final sessionId = sessionParts[1];
        final idx = allObjects.indexWhere((o) => o is PomodoroSession && o.id == sessionId);
        if (idx != -1) {
          final session = allObjects[idx] as PomodoroSession;
          session.date = newStart;
          vault.updateObject(session);
        }
      }
    } else if (segment.kind == DialSegmentKind.event) {
      final idx = allObjects.indexWhere((o) => o is Event && (o.id == segment.sourceSlug || o.slug == segment.sourceSlug));
      if (idx != -1) {
        final ev = allObjects[idx] as Event;
        vault.updateObject(ev.copyWith(
          date: newStart, 
          timeOfDay: '${newStart.hour.toString().padLeft(2, '0')}:${newStart.minute.toString().padLeft(2, '0')}'
        ));
      }
    } else if (segment.kind == DialSegmentKind.reminder) {
      final idx = allObjects.indexWhere((o) => o is Reminder && (o.id == segment.sourceSlug || o.slug == segment.sourceSlug));
      if (idx != -1) {
        final rem = allObjects[idx] as Reminder;
        vault.updateObject(rem.copyWith(time: newStart));
      }
    } else if (segment.kind == DialSegmentKind.habitSlot) {
      final idx = allObjects.indexWhere((o) => o is Habit && (o.id == segment.sourceSlug || o.slug == segment.sourceSlug));
      if (idx != -1) {
        final habit = allObjects[idx] as Habit;
        final parts = segment.id.split(':');
        if (parts.length >= 3) {
          final slotIdx = int.tryParse(parts[2]);
          if (slotIdx != null && slotIdx < habit.slots.length) {
            final slot = habit.slots[slotIdx];
            final updatedSlots = List<HabitSlot>.from(habit.slots);
            final timeStr = '${newStart.hour.toString().padLeft(2, '0')}:${newStart.minute.toString().padLeft(2, '0')}';
            if (slot.reminders.isNotEmpty) {
              slot.reminders.first.timeOfDay = timeStr;
            } else {
              slot.reminders = [ReminderConfig(id: 'primary', timeOfDay: timeStr, type: NotificationType.push)];
            }
            updatedSlots[slotIdx] = slot;
            vault.updateObject(habit.copyWith(slots: updatedSlots));
          }
        }
      }
    }
  }

  void _persistResize(DialSegment segment, DateTime newEnd) {
    final vault = ref.read(vaultProvider.notifier);
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    
    if (segment.kind == DialSegmentKind.taskPlanned) {
      final idx = allObjects.indexWhere((o) => o is Task && (o.id == segment.sourceSlug || o.slug == segment.sourceSlug));
      if (idx != -1) {
        final task = allObjects[idx] as Task;
        int durationMins = newEnd.difference(segment.start).inMinutes;
        if (durationMins <= 0) durationMins += 24 * 60;
        vault.updateObject(task.copyWith(duration: durationMins));
      }
    } else if (segment.kind == DialSegmentKind.pomodoroPlanned) {
      final sessionParts = segment.id.split(':');
      if (sessionParts.length >= 2) {
        final sessionId = sessionParts[1];
        final idx = allObjects.indexWhere((o) => o is PomodoroSession && o.id == sessionId);
        if (idx != -1) {
          final session = allObjects[idx] as PomodoroSession;
          int durationMins = newEnd.difference(segment.start).inMinutes;
          if (durationMins <= 0) durationMins += 24 * 60;
          session.workDuration = durationMins;
          vault.updateObject(session);
        }
      }
    } else if (segment.kind == DialSegmentKind.event) {
      final idx = allObjects.indexWhere((o) => o is Event && (o.id == segment.sourceSlug || o.slug == segment.sourceSlug));
      if (idx != -1) {
        final ev = allObjects[idx] as Event;
        vault.updateObject(ev.copyWith(endTime: '${newEnd.hour.toString().padLeft(2, '0')}:${newEnd.minute.toString().padLeft(2, '0')}'));
      }
    }
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
    
    final organizers = ref.watch(organizersListProvider);
    final dayThemes = organizers.where((o) => o.organizerType == OrganizerType.dayTheme).toList();
    const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
            
            // Find active day theme for this day
            final dayName = weekDayNames[date.weekday - 1];
            final activeTheme = dayThemes.cast<Organizer?>().firstWhere(
              (theme) => theme != null && theme.daysOfWeek.contains(dayName),
              orElse: () => null,
            );

            return InkWell(
              onTap: () => _showDayDetailsSheet(date, tasks, habits),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? AppTheme.accentColor(context).withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday
                      ? Border.all(color: AppTheme.accentColor(context), width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (activeTheme != null)
                      GestureDetector(
                        onTap: () => _showDayThemePopup(activeTheme),
                        child: Text(
                          activeTheme.icon ?? '📅',
                          style: const TextStyle(fontSize: 14),
                        ),
                      )
                    else
                      const SizedBox(height: 14),
                    Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? AppTheme.accentColor(context)
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
    final projects = ref.read(projectsProvider);
    final baseDayTasks = tasks
        .where((t) => t.deadline != null && _isSameDay(t.deadline!, date))
        .toList();
    final dayTasks = mergeDayTasksWithRotation(
      baseDayTasks,
      date,
      tasks,
      projects,
    );
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
          if (!theme.organizers.any((ref) => ref.matches(block.id, block.slug, block.title))) return false;
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
    final updated = task.copyWith(stage: newStage);
    ref.read(vaultProvider.notifier).updateObject(updated);

    if (newStage == TaskStage.finalized) {
      HapticFeedback.heavyImpact();
      // Show undo snackbar
      UndoService.showUndoSnackbar(
        context: context,
        message: '"${task.title}" completed!',
        onUndo: () {
          final updated = task.copyWith(stage: TaskStage.todo);
          ref.read(vaultProvider.notifier).updateObject(updated);
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
                Builder(
                  builder: (context) {
                    final iconData = ObjectIcons.iconDataForTypeWithSignatures(ObjectTypes.task, ref.read(settingsProvider).typeSignatures);
                    return Icon(iconData ?? Icons.check_circle_outline, size: 24, color: AppTheme.accentColor(context));
                  },
                ),
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
                    final updated = task.copyWith(
                      stage: TaskStage.finalized,
                      notes: updatedNotes,
                    );
                    ref.read(vaultProvider.notifier).updateObject(updated);
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor(context),
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
