// lib/ui/widgets/calendar_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/content_object.dart';
import '../../models/reminder_model.dart';
import '../../providers/vault_provider.dart';
import '../../providers/google_calendar_provider.dart';
import '../../providers/widget_sync_provider.dart';
import '../theme.dart';
import '../screens/google_event_detail_screen.dart';
import 'create_menu_sheet.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;

class CalendarWidget extends ConsumerStatefulWidget {
  const CalendarWidget({super.key});

  @override
  ConsumerState<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends ConsumerState<CalendarWidget> {
  DateTime _selectedDay = DateTime.now();
  final CalendarView _currentView = CalendarView.week;

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    final reminders = ref.watch(remindersProvider);
    final organizerObjects =
        ref
            .watch(allObjectsProvider)
            .valueOrNull
            ?.where(
              (object) =>
                  object.type == 'organizer' ||
                  object.type == 'goal' ||
                  object.type == 'project' ||
                  object.type == 'person',
            )
            .toList() ??
        const <ContentObject>[];
    final googleEvents = ref
        .watch(googleCalendarEventsProvider(_selectedDay))
        .maybeWhen(
          data: (events) => events,
          orElse: () => <google_calendar.Event>[],
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    PhosphorIcons.calendarBlank(),
                    color: AppColors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Calendário',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Sincronizar',
                    onPressed: () async {
                      ref.invalidate(googleCalendarEventsProvider);
                      await forceWidgetSync(
                        ProviderScope.containerOf(context, listen: false),
                      );
                    },
                    icon: const Icon(Icons.sync_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Adicionar',
                    onPressed: () => showCreateMenu(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCalendarNavigation(),
          const SizedBox(height: 12),
          if (_currentView == CalendarView.month)
            _buildMonthGrid(allTasks, habits)
          else if (_currentView == CalendarView.week)
            _buildWeekAgenda(
              allTasks,
              habits,
              reminders,
              organizerObjects,
              googleEvents,
            )
          else
            _buildDayAgenda(allTasks, habits, organizerObjects),
        ],
      ),
    );
  }

  Widget _buildCalendarNavigation() {
    final title = _currentView == CalendarView.month
        ? DateFormat('MMMM yyyy', 'pt_BR').format(_selectedDay)
        : _currentView == CalendarView.week
        ? _weekRangeTitle(_selectedDay)
        : DateFormat("d 'de' MMMM", 'pt_BR').format(_selectedDay);
    final subtitle = DateFormat('EEEE', 'pt_BR').format(_selectedDay);

    return Row(
      children: [
        IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), size: 18),
          onPressed: () => setState(() {
            _selectedDay = _currentView == CalendarView.month
                ? DateTime(_selectedDay.year, _selectedDay.month - 1, 1)
                : _currentView == CalendarView.week
                ? _selectedDay.subtract(const Duration(days: 7))
                : _selectedDay.subtract(const Duration(days: 1));
          }),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (_currentView != CalendarView.month)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(PhosphorIcons.caretRight(), size: 18),
          onPressed: () => setState(() {
            _selectedDay = _currentView == CalendarView.month
                ? DateTime(_selectedDay.year, _selectedDay.month + 1, 1)
                : _currentView == CalendarView.week
                ? _selectedDay.add(const Duration(days: 7))
                : _selectedDay.add(const Duration(days: 1));
          }),
        ),
      ],
    );
  }

  Widget _buildDayAgenda(
    List<Task> tasks,
    List<Habit> habits,
    List<ContentObject> organizerObjects,
  ) {
    final tasksForSelectedDay = _tasksForDay(tasks, _selectedDay);
    final activeHabits = habits
        .where((h) => h.status == HabitStatus.active)
        .take(4)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tasksForSelectedDay.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nenhuma tarefa agendada',
              style: TextStyle(
                color: AppTheme.textMutedColor(context),
                fontSize: 13,
              ),
            ),
          )
        else
          ...tasksForSelectedDay.map(_buildAgendaTask),
        const SizedBox(height: 4),
        Text(
          'Hábitos do dia',
          style: TextStyle(
            color: AppTheme.textMutedColor(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        ...activeHabits.map((habit) => _buildHabitRow(habit, organizerObjects)),
      ],
    );
  }

  Widget _buildWeekAgenda(
    List<Task> tasks,
    List<Habit> habits,
    List<Reminder> reminders,
    List<ContentObject> organizerObjects,
    List<google_calendar.Event> googleEvents,
  ) {
    final start = _startOfWeek(_selectedDay);
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    final selectedTasks = _tasksForDay(tasks, _selectedDay);
    final selectedReminders =
        reminders
            .where((reminder) => _sameDay(reminder.time, _selectedDay))
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: days.map((date) {
            final isSelected = _sameDay(date, _selectedDay);
            final dayTasks = _tasksForDay(tasks, date);
            final hasHabits = habits.any(
              (habit) => habit.status == HabitStatus.active,
            );
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedDay = date),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat(
                          'E',
                          'pt_BR',
                        ).format(date).characters.first.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMutedColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? AppColors.accent
                              : AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (dayTasks.isNotEmpty) _weekDot(AppColors.accent),
                          if (dayTasks.length > 1) _weekDot(AppColors.error),
                          if (hasHabits) _weekDot(AppColors.secondary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Text(
          '${_sameDay(_selectedDay, DateTime.now()) ? 'Hoje' : DateFormat("d 'de' MMM", 'pt_BR').format(_selectedDay)} · ${selectedTasks.length} tarefas · ${selectedReminders.length} lembretes · ${googleEvents.length} eventos',
          style: TextStyle(
            color: AppTheme.textMutedColor(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        if (selectedTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Nenhuma tarefa agendada',
              style: TextStyle(
                color: AppTheme.textMutedColor(context),
                fontSize: 13,
              ),
            ),
          )
        else
          ...selectedTasks.map(_buildAgendaTask),
        if (googleEvents.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...googleEvents.map(_buildGoogleEventRow),
        ],
        if (selectedReminders.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...selectedReminders.map(_buildReminderRow),
        ],
        const SizedBox(height: 4),
        Text(
          'Hábitos',
          style: TextStyle(
            color: AppTheme.textMutedColor(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        ...habits
            .where((h) => h.status == HabitStatus.active)
            .take(4)
            .map((habit) => _buildHabitRow(habit, organizerObjects)),
      ],
    );
  }

  Widget _weekDot(Color color) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildAgendaTask(Task task) {
    final color = AppTheme.priorityColor(task.priority);
    final time = task.scheduledTime ?? '--:--';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        onTap: () => context.push('/detail/${task.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref
                    .read(tasksProvider.notifier)
                    .updateTask(
                      task.copyWith(
                        stage: task.isCompleted
                            ? TaskStage.todo
                            : TaskStage.finalized,
                      ),
                    );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 1),
                child: Icon(
                  task.isCompleted
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: task.isCompleted
                      ? AppColors.success
                      : AppTheme.dividerColor(context),
                  size: 20,
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                time,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 3,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    task.organizers.isNotEmpty
                        ? task.organizers.first.title
                        : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
  }

  Widget _buildGoogleEventRow(google_calendar.Event event) {
    final title = event.summary?.trim().isNotEmpty == true
        ? event.summary!.trim()
        : 'Evento do Google';
    final start = event.start?.dateTime ?? event.start?.date;
    final time = start == null ? '--:--' : DateFormat('HH:mm').format(start);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoogleEventDetailScreen(event: event),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_rounded,
              color: AppColors.secondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 42,
              child: Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderRow(Reminder reminder) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => context.push('/detail/${reminder.id}'),
        child: Row(
          children: [
            Icon(
              reminder.isCompleted
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_active_rounded,
              color: reminder.isCompleted
                  ? AppColors.success
                  : AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 42,
              child: Text(
                DateFormat('HH:mm').format(reminder.time),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: reminder.isCompleted
                      ? AppColors.success
                      : AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reminder.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitRow(
    Habit habit, [
    List<ContentObject> organizerObjects = const [],
  ]) {
    final done = _isHabitCompletedOn(habit, _selectedDay);
    final time = _habitTime(habit);
    final subtitle = _habitSubtitle(habit, time, organizerObjects);
    return InkWell(
      onTap: () => context.push('/detail/${habit.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(_habitIcon(habit), size: 19, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _habitTitle(habit),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref
                  .read(habitsProvider.notifier)
                  .toggleHabit(habit, _selectedDay, slotIndex: 0),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  done ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: done
                      ? AppColors.success
                      : AppTheme.dividerColor(context),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(List<Task> tasks, List<Habit> habits) {
    final first = DateTime(_selectedDay.year, _selectedDay.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday % 7));
    const weekDays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    return Column(
      children: [
        Row(
          children: weekDays
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final date = gridStart.add(Duration(days: index));
            final isThisMonth = date.month == _selectedDay.month;
            final isSelected = _sameDay(date, _selectedDay);
            final dayTasks = _tasksForDay(tasks, date);
            return InkWell(
              onTap: () {
                setState(() => _selectedDay = date);
                _showDaySheet(date, dayTasks, habits);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: isThisMonth
                            ? AppTheme.textPrimaryColor(context)
                            : AppTheme.textMutedColor(
                                context,
                              ).withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 3),
                    ...dayTasks
                        .take(2)
                        .map(
                          (task) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.priorityColor(
                                task.priority,
                              ).withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 7,
                                color: AppTheme.priorityColor(task.priority),
                              ),
                            ),
                          ),
                        ),
                    if (dayTasks.length > 2)
                      Text(
                        '+${dayTasks.length - 2} mais',
                        style: TextStyle(
                          fontSize: 7,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Task> _tasksForDay(List<Task> tasks, DateTime date) {
    final list =
        tasks.where((task) {
          final taskDate = task.endDate ?? task.startDate;
          return taskDate != null && _sameDay(taskDate, date);
        }).toList()..sort(
          (a, b) =>
              (a.baseTime ?? DateTime(0)).compareTo(b.baseTime ?? DateTime(0)),
        );
    return list;
  }

  void _showDaySheet(DateTime date, List<Task> tasks, List<Habit> habits) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat("d 'de' MMMM", 'pt_BR').format(date),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                DateFormat('EEEE', 'pt_BR').format(date),
                style: TextStyle(color: AppTheme.textMutedColor(context)),
              ),
              const SizedBox(height: 18),
              Text(
                'TAREFAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
              const SizedBox(height: 8),
              ...tasks.map(
                (t) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.priorityColor(
                      t.priority,
                    ).withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildAgendaTask(t),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'HÁBITOS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
              const SizedBox(height: 8),
              ...habits
                  .where((h) => h.status == HabitStatus.active)
                  .take(5)
                  .map(_buildHabitRow),
            ],
          ),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  String _weekRangeTitle(DateTime date) {
    final start = _startOfWeek(date);
    final end = start.add(const Duration(days: 6));
    final startLabel = DateFormat('d', 'pt_BR').format(start);
    final endLabel = DateFormat('d MMM', 'pt_BR').format(end);
    return '$startLabel - $endLabel';
  }

  bool _isHabitCompletedOn(Habit habit, DateTime date) {
    return habit.completionHistory.any((record) {
      return _sameDay(record.date, date) && record.successful;
    });
  }

  String? _habitTime(Habit habit) {
    for (final slot in habit.slots) {
      if (slot.time != null) {
        return DateFormat('HH:mm').format(slot.time!);
      }
      if (slot.reminderTime != null) {
        final reminder = slot.reminderTime!;
        return '${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')}';
      }
    }
    for (final scheduler in habit.schedulers) {
      if (scheduler.exactTime != null) {
        return DateFormat('HH:mm').format(scheduler.exactTime!);
      }
    }
    return null;
  }

  String _habitTitle(Habit habit) {
    final resolved = displayTitleFromValue(habit.displayTitle, id: habit.id);
    return resolved ?? 'Hábito';
  }

  String _habitSubtitle(
    Habit habit,
    String? time, [
    List<ContentObject> organizerObjects = const [],
  ]) {
    final organizer = habit.organizers
        .map((item) {
          final resolved = organizerObjects
              .where(
                (organizer) =>
                    item.matches(organizer.id, organizer.slug, organizer.title),
              )
              .firstOrNull;
          if (resolved != null) {
            return displayTitleFromValue(resolved.displayTitle) ?? '';
          }
          return displayTitleFromValue(item.title) ??
              displayTitleFromValue(item.slug) ??
              '';
        })
        .where((item) => item.isNotEmpty)
        .join(', ');
    final parts = [
      if (time != null && time.isNotEmpty) time,
      if (organizer.isNotEmpty) organizer,
    ];
    return parts.join(' · ');
  }

  IconData _habitIcon(Habit habit) {
    if (habit.icon == null) return Icons.directions_run_rounded;
    final code = int.tryParse(habit.icon!);
    if (code == Icons.water_drop_rounded.codePoint) {
      return Icons.water_drop_rounded;
    }
    if (code == Icons.medication_rounded.codePoint) {
      return Icons.medication_rounded;
    }
    return Icons.directions_run_rounded;
  }
}

enum CalendarView { day, week, month }
