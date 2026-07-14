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
import '../../services/scheduler_service.dart';

class CalendarWidget extends ConsumerStatefulWidget {
  const CalendarWidget({super.key});

  @override
  ConsumerState<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends ConsumerState<CalendarWidget> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final allTasks = allObjects.whereType<Task>().toList();
    final habits = allObjects.whereType<Habit>().where((h) => !h.isQuitting).toList();
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
                    color: AppTheme.accentColor(context),
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
          _buildWeekAgenda(
            allTasks,
            habits,
            reminders,
            organizerObjects,
            googleEvents,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarNavigation() {
    final title = _weekRangeTitle(_selectedDay);
    final subtitle = DateFormat('EEEE', 'pt_BR').format(_selectedDay);

    return Row(
      children: [
        IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), size: 18),
          onPressed: () => setState(() {
            _selectedDay = _selectedDay.subtract(const Duration(days: 7));
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
            _selectedDay = _selectedDay.add(const Duration(days: 7));
          }),
        ),
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
            final dayHabits = habits.where((h) {
              if (h.status != HabitStatus.active) return false;
              for (final s in h.schedulers) {
                if (SchedulerService.shouldFire(s, date)) return true;
              }
              return false;
            });
            final hasHabits = dayHabits.isNotEmpty;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedDay = date),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentColor(context).withValues(alpha: 0.12)
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
                              ? AppTheme.accentColor(context)
                              : AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (dayTasks.isNotEmpty) _weekDot(AppTheme.accentColor(context)),
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
            .where((h) {
              if (h.status != HabitStatus.active) return false;
              for (final s in h.schedulers) {
                if (SchedulerService.shouldFire(s, _selectedDay)) return true;
              }
              return false;
            })
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
                final updated = task.copyWith(
                  stage: task.isCompleted
                      ? TaskStage.todo
                      : TaskStage.finalized,
                );
                ref.read(vaultProvider.notifier).updateObject(updated);
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
                        ? (displayTitleFromValue(
                                task.organizers.first.title) ??
                            '')
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
            Icon(_habitIcon(habit), size: 19, color: AppTheme.accentColor(context)),
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
      if (slot.primaryReminderTime != null) {
        final reminder = slot.primaryReminderTime!;
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


