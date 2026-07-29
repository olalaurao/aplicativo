// lib/ui/screens/planner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/settings_provider.dart';
import '../../providers/today_aggregation_provider.dart';
import '../../providers/daily_schedule_provider.dart';
import '../../providers/vault_provider.dart';
import '../../providers/overdue_provider.dart' show overdueProvider, overdueCountProvider, OverdueItem;
import '../../services/daily_schedule_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/organizer_model.dart';
import '../../models/shared_types.dart';
import '../theme.dart';
import '../../models/task_model.dart';
import '../../models/idea_model.dart';
import '../../models/project_model.dart';
import '../../models/goal_model.dart';
import '../../models/inbox_model.dart';
import '../widgets/timeline_day_view.dart';
import '../utils/object_icons.dart';
import '../../services/scheduler_service.dart';
import '../../providers/google_calendar_provider.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;
import '../../providers/pomodoro_provider.dart';
import '../../models/habit_model.dart';
import '../../services/undo_service.dart';
import '../../services/rotation_service.dart';
import '../widgets/object_action_wrapper.dart';
import 'pomodoro_screen.dart';
import 'google_event_detail_screen.dart';
import '../../models/content_object.dart';
import 'universal_detail_view.dart';
import '../widgets/triple_check_sheet.dart';
import '../widgets/capture_bubble_fab.dart';
import '../widgets/create_menu_sheet.dart';

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
  int _viewMode = 0; // 0=Day, 1=Week, 2=Month
  late DateTime _selectedDate;
  late DateTime _selectedMonth;
  final ScrollController _scrollController = ScrollController();
  bool _showJumpToNowFab = false;
  final int _gridGranularity = 30; // 15, 30, or 60 minutes

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
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
    if (_isSameDay(_selectedDate, DateTime.now()) && _viewMode == 0) {
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
      setState(() { _showJumpToNowFab = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final organizers = ref.watch(organizersListProvider);
    final dayThemes = organizers.where((o) => o.organizerType == OrganizerType.dayTheme).toList();
    final googleEvents = ref.watch(googleCalendarEventsProvider(_selectedDate));
    final overdueCount = ref.watch(overdueCountProvider);
    final inboxCount = ref.watch(inboxCountProvider);

    final dayName = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][_selectedDate.weekday - 1];

    final dayAggregation = ref.watch(todayAggregationProvider(_selectedDate));
    final dayTasks = dayAggregation.allTasks;
    final activeTimeBlocks = dayAggregation.timeBlocks;
    final dailySchedule = ref.watch(dailyScheduleProvider(_selectedDate));

    final activeTheme = dayThemes.cast<Organizer?>().firstWhere(
      (theme) => theme != null && theme.daysOfWeek.contains(dayName),
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
          SliverAppBar(
            toolbarHeight: 48.0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: AppTheme.textPrimaryColor(context),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: const Text(
                    'Planner',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            pinned: true,
            actions: [
              // Overdue icon – hardcoded red per spec
              if (overdueCount > 0)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                      tooltip: 'Overdue ($overdueCount)',
                      onPressed: _showOverduePopup,
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          overdueCount > 99 ? '99+' : '$overdueCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              // Inbox icon with count badge
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.inbox_rounded, color: inboxCount > 0 ? AppTheme.accentColor(context) : AppTheme.textMutedColor(context)),
                    tooltip: 'Inbox ($inboxCount)',
                    onPressed: _showInboxPopup,
                  ),
                  if (inboxCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: AppTheme.accentColor(context), shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          inboxCount > 99 ? '99+' : '$inboxCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              // Jump to now button
              if (_viewMode == 0)
                IconButton(
                  icon: const Icon(Icons.access_time_rounded),
                  tooltip: 'Jump to now',
                  onPressed: () => _scrollToNow(animate: true),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(_viewMode == 0 ? 130 : 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    // Hourly timeline (includes toggleable untimed section)
                    TimeLineDayView(
                      tasks: dayTasks,
                      selectedDate: _selectedDate,
                      allDayEvents: dailySchedule.allDayItems,
                      googleEvents: googleEvents.maybeWhen(
                        data: (events) => events,
                        orElse: () => [],
                      ),
                      timeBlocks: activeTimeBlocks,
                      activeTheme: activeTheme,
                      gridGranularity: _gridGranularity,
                      pomodoroSessions: ref.watch(pomodoroProvider.select((p) => p.history)),
                      onDurationChange: (item, newDuration) {
                        if (item is Task) {
                          ref.read(vaultProvider.notifier).updateObject(item.copyWith(duration: newDuration));
                        }
                      },
                      onToggleComplete: _toggleTaskCompletion,
                      onPlay: _handlePlay,
                      onHabitToggle: (habit, slotIndex) async {
                        await ref.read(habitsProvider.notifier).toggleHabit(habit, _selectedDate, slotIndex: slotIndex);
                      },
                      colorMode: ref.watch(settingsProvider.select((s) => s.plannerColorMode)),
                      rotationProjects: dayAggregation.rotationProjects,
                      rotationTasks: dayAggregation.rotationTasks,
                      onTaskDrop: null,
                      onHabitDrop: null,
                    ),
                  ],
                ),
              ),
            )
          else if (_viewMode == 1)
            _buildWeekView()
          else if (_viewMode == 2)
            _buildMonthView(),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        )),
        ],
      ),
      floatingActionButton: CaptureBubbleFab(
        tooltip: 'Quick add',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const CreateMenuSheet(),
          );
        },
      ),
    );
  }

  Widget _buildViewToggle() {
    const labels = ['Day', 'Week', 'Month'];
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
                      ? AppTheme.accentColor(context).withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppTheme.accentColor(context).withValues(alpha: 0.1),
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
                        ? AppTheme.accentColor(context)
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
            () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _pickCustomDate,
            child: Text(
              DateFormat('EEEE, MMMM d').format(_selectedDate),
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
              'Today',
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

  void _showInboxPopup() {
    final inboxQueue = ref.read(unifiedInboxQueueProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.inbox_rounded, color: AppTheme.accentColor(context)),
                    const SizedBox(width: 8),
                    Text(
                      'Inbox (${inboxQueue.length})',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (inboxQueue.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'Inbox is empty',
                    style: TextStyle(
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: inboxQueue.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = inboxQueue[index];
                      return _buildInboxQueueItem(ctx, item);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInboxQueueItem(BuildContext ctx, InboxQueueItem item) {
    final pomodoroCount = _getPomodoroCount(item.source);
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        context.push('/detail/${item.source.id}', extra: item.source);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForInboxKind(item.kind), size: 20, color: AppTheme.accentColor(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pomodoroCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(
                          '$pomodoroCount',
                          style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
            ),
            if (item.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addInboxItemToToday(item);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Add today', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _chooseDateForInboxItem(item);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Choose date', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _getPomodoroCount(ContentObject source) {
    if (source is Task) {
      return source.pomodoroCount ?? 0;
    }
    return 0;
  }

  IconData _iconForInboxKind(InboxQueueKind kind) {
    switch (kind) {
      case InboxQueueKind.inbox:
        return Icons.inbox_rounded;
      case InboxQueueKind.idea:
        return Icons.lightbulb_rounded;
      case InboxQueueKind.task:
        return Icons.task_alt_rounded;
      case InboxQueueKind.project:
        return Icons.folder_rounded;
      case InboxQueueKind.goal:
        return Icons.flag_rounded;
    }
  }

  void _addInboxItemToToday(InboxQueueItem item) {
    final today = DateTime.now();
    if (item.source is InboxItem) {
      // Convert raw capture to Task scheduled for today
      final inboxItem = item.source as InboxItem;
      final task = Task(
        title: inboxItem.title.isNotEmpty ? inboxItem.title : 'Untitled',
        startDate: today,
        endDate: today,
        stage: TaskStage.todo,
      );
      ref.read(vaultProvider.notifier).createObject(task);
      // Archive the original inbox item
      ref.read(vaultProvider.notifier).updateObject(inboxItem);
    } else if (item.source is Task) {
      final task = item.source as Task;
      final updated = task.copyWith(
        startDate: today,
        endDate: today,
        stage: TaskStage.todo,
      );
      ref.read(vaultProvider.notifier).updateObject(updated);
    } else if (item.source is IdeaDefinition) {
      final idea = item.source as IdeaDefinition;
      final task = Task(
        title: idea.title,
        startDate: today,
        endDate: today,
        stage: TaskStage.todo,
      );
      ref.read(vaultProvider.notifier).createObject(task);
    } else if (item.source is Project) {
      final project = item.source as Project;
      final updated = project.copyWith(startDate: today);
      ref.read(vaultProvider.notifier).updateObject(updated);
    } else if (item.source is Goal) {
      final goal = item.source as Goal;
      final updated = goal.copyWith(startDate: today);
      ref.read(vaultProvider.notifier).updateObject(updated);
    }
  }

  void _chooseDateForInboxItem(InboxQueueItem item) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      if (item.source is InboxItem) {
        final inboxItem = item.source as InboxItem;
        final task = Task(
          title: inboxItem.title.isNotEmpty ? inboxItem.title : 'Untitled',
          startDate: date,
          endDate: date,
          stage: TaskStage.todo,
        );
        ref.read(vaultProvider.notifier).createObject(task);
        ref.read(vaultProvider.notifier).updateObject(inboxItem);
      } else if (item.source is Task) {
        final task = item.source as Task;
        final updated = task.copyWith(
          startDate: date,
          endDate: date,
          stage: TaskStage.todo,
        );
        ref.read(vaultProvider.notifier).updateObject(updated);
      } else if (item.source is IdeaDefinition) {
        final idea = item.source as IdeaDefinition;
        final task = Task(
          title: idea.title,
          startDate: date,
          endDate: date,
          stage: TaskStage.todo,
        );
        ref.read(vaultProvider.notifier).createObject(task);
      } else if (item.source is Project) {
        final project = item.source as Project;
        final updated = project.copyWith(startDate: date);
        ref.read(vaultProvider.notifier).updateObject(updated);
      } else if (item.source is Goal) {
        final goal = item.source as Goal;
        final updated = goal.copyWith(startDate: date);
        ref.read(vaultProvider.notifier).updateObject(updated);
      }
    }
  }

  void _showOverduePopup() {
    final overdueItems = ref.read(overdueProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor(ctx),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    'Overdue Tasks (${overdueItems.length})',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: overdueItems.isEmpty
                  ? const Center(child: Text('No overdue items.'))
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: overdueItems.length,
                      itemBuilder: (_, i) => _buildOverdueRow(ctx, overdueItems[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueRow(BuildContext ctx, OverdueItem item) {
    final daysText = item.daysLate == 1 ? '1 day overdue' : '${item.daysLate} days overdue';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(ctx),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Colored radio button based on category
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getCategoryColor(item.object),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/detail/${item.object.id}', extra: item.object);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.object.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        daysText,
                        style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _moveOverdueToToday(item);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor(ctx),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Move to today', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) _rescheduleOverdue(item, date);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('New date', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(ContentObject object) {
    // Return color based on organizer/category
    if (object.organizers.isNotEmpty) {
      // You can customize this logic based on your category color mapping
      return AppTheme.accentColor(context);
    }
    return AppColors.error;
  }

  void _moveOverdueToToday(OverdueItem item) {
    final today = DateTime.now();
    final obj = item.object;
    if (obj is Task) {
      ref.read(vaultProvider.notifier).updateObject(
        obj.copyWith(startDate: today, endDate: today),
      );
    } else {
      ref.read(vaultProvider.notifier).updateObject(obj);
    }
  }

  void _rescheduleOverdue(OverdueItem item, DateTime date) {
    final obj = item.object;
    if (obj is Task) {
      ref.read(vaultProvider.notifier).updateObject(
        obj.copyWith(startDate: date, endDate: date),
      );
    } else {
      ref.read(vaultProvider.notifier).updateObject(obj);
    }
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
                          : (isBlocked ? AppColors.error : AppTheme.textMutedColor(context)),
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
                                    ? AppTheme.textMutedColor(context)
                                    : AppTheme.textPrimaryColor(context),
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
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMutedColor(context),
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
                  color: isDone ? AppColors.habitGreen : AppTheme.textMutedColor(context),
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

  Widget _buildWeekView() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Week range header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatWeekRange(startOfWeek, endOfWeek),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.today_rounded),
                  onPressed: () {
                    setState(() {
                      _selectedDate = today;
                      _viewMode = 0;
                    });
                  },
                  tooltip: 'Go to today',
                ),
              ],
            ),
          ),
          // Progress row
          _buildWeekProgressRow(),
          const SizedBox(height: 8),
          // Day sections
          ...List.generate(7, (index) {
            final dayDate = startOfWeek.add(Duration(days: index));
            return _buildWeekDaySection(dayDate, today);
          }),
        ]),
      ),
    );
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    final format = DateFormat('MMM d');
    return '${format.format(start)} - ${format.format(end)}';
  }

  Widget _buildWeekProgressRow() {
    // Calculate completion progress for the week
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    
    int completed = 0;
    int total = 0;
    
    for (int i = 0; i < 7; i++) {
      final dayDate = startOfWeek.add(Duration(days: i));
      if (dayDate.isAfter(today)) break;
      
      final daySchedule = ref.read(dailyScheduleProvider(dayDate));
      final completableItems = daySchedule.completableItems;
      total += completableItems.length;
      completed += completableItems.where((item) => item.isCompleted).length;
    }
    
    final progress = total > 0 ? completed / total : 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              Text(
                '$completed/$total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.surfaceVariantColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor(context)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDaySection(DateTime dayDate, DateTime today) {
    final isToday = _isSameDay(dayDate, today);
    final daySchedule = ref.watch(dailyScheduleProvider(dayDate));
    final items = daySchedule.allItems;
    
    final weekdayLabel = DateFormat('EEE').format(dayDate);
    final dayLabel = DateFormat('d').format(dayDate);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isToday ? AppTheme.accentColor(context).withValues(alpha: 0.08) : AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDate = dayDate;
            _viewMode = 0;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Day badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isToday ? AppTheme.accentColor(context) : AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isToday ? Colors.white : AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Weekday label
                  Text(
                    weekdayLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isToday ? AppTheme.accentColor(context) : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const Spacer(),
                  // Item count
                  if (items.isNotEmpty)
                    Text(
                      '${items.length} tasks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Plus button
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedDate = dayDate;
                        _viewMode = 0;
                      });
                    },
                    tooltip: 'Add item',
                  ),
                ],
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...(() {
                  final untimedItems = items.where((i) => i.time == null).toList();
                  final timedItems = items.where((i) => i.time != null).toList();
                  final untimedCount = untimedItems.length > 5 ? 5 : untimedItems.length;
                  final timedCount = timedItems.length > 3 ? 3 : timedItems.length;
                  
                  return [
                    // Untimed/habit chip row
                    if (untimedItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: untimedItems.take(5).map((item) => _buildWeekItemChip(item)).toList(),
                        ),
                      ),
                    // Timed items with vertical bars
                    if (timedItems.isNotEmpty)
                      ...timedItems.take(3).map((item) => _buildWeekTaskItem(item)),
                    if (items.length > untimedCount + timedCount)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+${items.length - untimedCount - timedCount} more',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                      ),
                  ];
                })(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekTaskItem(DailyScheduleItem item) {
    final timeStr = item.time;
    final isCompleted = item.isCompleted;
    
    final child = InkWell(
      onTap: () {
        if (item.source != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: item.source!),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // Completion checkbox
            if (item.kind == DailyScheduleKind.task || item.kind == DailyScheduleKind.habit)
              GestureDetector(
                onTap: () {
                  if (item.source is Task) {
                    final task = item.source as Task;
                    final updated = task.copyWith(
                      stage: task.stage == TaskStage.finalized
                          ? TaskStage.todo
                          : TaskStage.finalized,
                    );
                    ref.read(vaultProvider.notifier).updateObject(updated);
                  } else if (item.source is Habit) {
                    final habit = item.source as Habit;
                    ref.read(habitsProvider.notifier).toggleHabit(habit, _selectedDate);
                  }
                },
                child: Icon(
                  isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: isCompleted ? AppColors.habitGreen : AppTheme.textMutedColor(context),
                ),
              ),
            if (item.kind == DailyScheduleKind.task || item.kind == DailyScheduleKind.habit)
              const SizedBox(width: 8),
            // Colored vertical bar
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timeStr != null)
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                ],
              ),
            ),
            if (item.subtitle != null)
              Text(
                item.subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: item.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );

    if (item.source != null) {
      return ObjectActionWrapper(
        object: item.source!,
        child: child,
      );
    }
    return child;
  }

  Widget _buildWeekItemChip(DailyScheduleItem item) {
    final isCompleted = item.isCompleted;
    
    final child = InkWell(
      onTap: () {
        if (item.source != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: item.source!),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.iconData, size: 14, color: item.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor(context),
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (item.source != null) {
      return ObjectActionWrapper(
        object: item.source!,
        child: child,
      );
    }
    return child;
  }

  Widget _buildMonthView() {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday; // 1=Mon, 7=Sun
    const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Month navigation header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                    });
                  },
                  tooltip: 'Previous month',
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                    });
                  },
                  tooltip: 'Next month',
                ),
              ],
            ),
          ),
          // Week day headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: weekDayNames.map((day) => Expanded(
                child: Center(
                  child: Text(
                    day.substring(0, 1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Calendar grid - use Table for better overflow control
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
              5: FlexColumnWidth(1),
              6: FlexColumnWidth(1),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: _buildMonthTableRows(firstWeekday, daysInMonth, today, weekDayNames),
          ),
          const SizedBox(height: 16),
          // Inline day preview for selected date
          _buildMonthDayPreview(),
        ]),
      ),
    );
  }

  List<TableRow> _buildMonthTableRows(int firstWeekday, int daysInMonth, DateTime today, List<String> weekDayNames) {
    final rows = <TableRow>[];
    int dayCounter = 1;
    
    // Build 6 rows (6 weeks)
    for (int week = 0; week < 6; week++) {
      final cells = <Widget>[];
      
      for (int dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++) {
        if (week == 0 && dayOfWeek < firstWeekday - 1) {
          cells.add(const SizedBox.shrink());
        } else if (dayCounter > daysInMonth) {
          cells.add(const SizedBox.shrink());
        } else {
          final day = dayCounter;
          final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
          final isToday = _isSameDay(date, today);
          
          final daySchedule = ref.watch(dailyScheduleProvider(date));
          final items = daySchedule.allItems;
          const maxChipsPerCell = 2;

          cells.add(
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: Container(
                  height: 80,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppTheme.accentColor(context).withValues(alpha: 0.1)
                        : AppTheme.surfaceVariantColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(color: AppTheme.accentColor(context), width: 1.5)
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              weekDayNames[date.weekday - 1].substring(0, 3),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? AppTheme.accentColor(context)
                                    : AppTheme.textMutedColor(context),
                              ),
                            ),
                            Text(
                              day.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                                color: isToday
                                    ? AppTheme.accentColor(context)
                                    : AppTheme.textPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Compact item pills
                        ...items.take(maxChipsPerCell).map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          height: 3,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )),
                        if (items.length > maxChipsPerCell)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '+${items.length - maxChipsPerCell}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMutedColor(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          dayCounter++;
        }
      }
      
      rows.add(TableRow(children: cells));
    }
    
    return rows;
  }

  Widget _buildMonthDayPreview() {
    final daySchedule = ref.watch(dailyScheduleProvider(_selectedDate));
    final items = daySchedule.allItems;
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMM d').format(_selectedDate),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isToday ? AppTheme.accentColor(context) : AppTheme.textPrimaryColor(context),
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentColor(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'No items scheduled',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMutedColor(context),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    onTap: () {
                      if (item.source != null) {
                        context.push('/detail/${item.source!.id}', extra: item.source);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 32,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.time != null)
                                  Text(
                                    item.time!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMutedColor(context),
                                    ),
                                  ),
                              ],
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
    );
  }

  void _showDayDetailsSheet(
    DateTime date,
    List<Task> tasks,
    List<Habit> habits,
  ) {
    final projects = ref.read(projectsProvider);
    final baseDayTasks = tasks
        .where((t) =>
            (t.startDate != null && _isSameDay(t.startDate!, date)) ||
            (t.deadline != null && _isSameDay(t.deadline!, date)))
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
            (t.startDate != null && _isSameDay(t.startDate!, date)) ||
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'Nada agendado para este dia',
                    style: TextStyle(color: AppTheme.textMutedColor(context)),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...dayTasks.map((t) => _buildTaskCard(t)),
                    ...dayHabits.map((h) {
                      final slots = h.slots.isEmpty ? <HabitSlot>[HabitSlot()] : h.slots;
                      final isDone = _isHabitSlotDone(h, 0);
                      return _buildHabitCard(h, slots, isDone);
                    }),
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
            Text(
              'Reflection (optional)',
              style: TextStyle(fontSize: 13, color: AppTheme.textMutedColor(context)),
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


}
