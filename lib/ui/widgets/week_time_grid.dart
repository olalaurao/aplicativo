// lib/ui/widgets/week_time_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/organizer_model.dart';
import '../../models/project_model.dart';
import '../../services/rotation_service.dart';
import '../theme.dart';

class WeekTimeGrid extends ConsumerWidget {
  final List<Task> tasks;
  final List<Habit> habits;
  final DateTime startOfWeek;
  final Function(Task, DateTime)? onTaskTap;
  final Function(Habit)? onHabitTap;
  final Function(Project, DateTime)? onProjectTap;
  final List<Organizer>? dayThemes;
  final List<Organizer>? timeBlocks;
  final List<Project> projects;

  const WeekTimeGrid({
    super.key,
    required this.tasks,
    required this.habits,
    required this.startOfWeek,
    this.onTaskTap,
    this.onHabitTap,
    this.onProjectTap,
    this.dayThemes,
    this.timeBlocks,
    this.projects = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      ),
      child: Column(
        children: [
          // Header row with day names
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                const SizedBox(width: 40), // Time column
                ...List.generate(7, (index) {
                  final date = startOfWeek.add(Duration(days: index));
                  final isToday = _isSameDay(date, now);
                  final dayName = dayNames[index];
                  
                  // Find active day theme for this day
                  Organizer? activeTheme;
                  if (dayThemes != null) {
                    activeTheme = dayThemes!.where(
                      (theme) => theme.daysOfWeek.contains(dayName),
                    ).firstOrNull;
                  }
                  
                  return Expanded(
                    child: Center(
                      child: Column(
                        children: [
                          if (activeTheme != null)
                            GestureDetector(
                              onTap: () => _showDayThemePopup(context, activeTheme!),
                              child: Text(
                                activeTheme.icon ?? '📅',
                                style: const TextStyle(fontSize: 16),
                              ),
                            )
                          else
                            const SizedBox(height: 16),
                          Text(
                            dayNames[index],
                            style: TextStyle(
                              fontSize: AppTextSize.xs,
                              fontWeight: FontWeight.w700,
                              color: isToday 
                                  ? AppTheme.accentColor(context) 
                                  : AppTheme.textSecondaryColor(context),
                            ),
                          ),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: AppTextSize.lg,
                              fontWeight: FontWeight.w800,
                              color: isToday 
                                  ? AppTheme.accentColor(context) 
                                  : AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          // Time grid
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(24, (hour) {
                  return SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        // Time label
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: AppTextSize.xs,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMutedColor(context),
                            ),
                          ),
                        ),
                        // Day columns
                        ...List.generate(7, (dayIndex) {
                          final date = startOfWeek.add(Duration(days: dayIndex));
                          return Expanded(
                            child: _buildDayColumn(
                              context,
                              date,
                              hour,
                              tasks,
                              habits,
                              timeBlocks,
                              projects,
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    DateTime date,
    int hour,
    List<Task> tasks,
    List<Habit> habits,
    List<Organizer>? timeBlocks,
    List<Project> projects,
  ) {
    // Find tasks scheduled for this hour on this day
    final hourTasks = tasks.where((task) {
      if (task.scheduledTime == null) return false;
      final parts = task.scheduledTime!.split(':');
      if (parts.length < 2) return false;
      final taskHour = int.tryParse(parts[0]);
      if (taskHour == null) return false;
      return taskHour == hour && _isSameDay(task.startDate ?? date, date);
    }).toList();

    final hourRotationProjects = projects.where((project) {
      final status = RotationService.computeActiveStatus(project, now: date);
      if (status == null) return false;
      final dueTasks = RotationService.dueRotationTasksForStatus(
        project,
        status,
        tasks,
      ).where((task) => !task.archived && task.stage != TaskStage.finalized);
      if (dueTasks.isEmpty) return false;
      final time = RotationService.scheduleForStatus(
        project,
        status,
        date,
      ).time;
      final parts = time.split(':');
      if (parts.length < 2) return false;
      return int.tryParse(parts[0]) == hour;
    }).toList();

    // Find habits with reminders at this hour on this day
    final hourHabits = habits.where((habit) {
      for (final slot in habit.slots) {
        if (slot.hasReminders && slot.primaryReminderTime != null) {
          if (slot.primaryReminderTime!.hour == hour) {
            // Check if habit is active on this day
            if (habit.schedulers.isNotEmpty) {
              // Simple check - in production, use SchedulerService.shouldFire
              return true;
            }
          }
        }
      }
      return false;
    }).toList();

    // Find time blocks for this hour on this day
    final hourTimeBlocks = <Organizer>[];
    if (timeBlocks != null) {
      const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = weekDayNames[date.weekday - 1];
      
      for (final block in timeBlocks) {
        if (!block.daysOfWeek.contains(dayName)) continue;
        
        for (final range in block.timeRanges) {
          if (hour >= range.startHour && hour < range.endHour) {
            hourTimeBlocks.add(block);
            break;
          }
        }
      }
    }

    if (hourTasks.isEmpty &&
        hourHabits.isEmpty &&
        hourTimeBlocks.isEmpty &&
        hourRotationProjects.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppTheme.accentColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      ),
      child: Stack(
        children: [
          if (hourTimeBlocks.isNotEmpty)
            ...hourTimeBlocks.take(1).map((block) => _buildMiniTimeBlock(context, block)),
          if (hourRotationProjects.isNotEmpty)
            ...hourRotationProjects
                .take(1)
                .map((project) => _buildMiniRotationBlock(context, project, date)),
          if (hourTasks.isNotEmpty)
            ...hourTasks.take(2).map((task) => _buildMiniTaskBlock(context, task)),
          if (hourHabits.isNotEmpty)
            ...hourHabits.take(1).map((habit) => _buildMiniHabitBlock(context, habit)),
        ],
      ),
    );
  }

  Widget _buildMiniTimeBlock(BuildContext context, Organizer block) {
    final color = AppColors.info;
    
    return GestureDetector(
      onTap: () => _showDayThemePopup(context, block),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppBorderRadius.xs),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (block.icon != null)
              Text(block.icon!, style: const TextStyle(fontSize: 10)),
            if (block.icon != null) const SizedBox(width: 4),
            Text(
              block.title,
              style: TextStyle(
                color: color,
                fontSize: AppTextSize.xs,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniRotationBlock(
    BuildContext context,
    Project project,
    DateTime date,
  ) {
    final status = RotationService.computeActiveStatus(project, now: date);
    final title = status == null
        ? project.title
        : '${project.title} · ${status.group.name}';

    return GestureDetector(
      onTap: () => onProjectTap?.call(project, date),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.accentColor(context).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 9,
            color: AppTheme.accentColor(context),
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMiniTaskBlock(BuildContext context, Task task) {
    return GestureDetector(
      onTap: () => onTaskTap?.call(task, task.startDate ?? DateTime.now()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppTheme.accentColor(context),
          borderRadius: BorderRadius.circular(AppBorderRadius.xs),
        ),
        child: Text(
          task.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMiniHabitBlock(BuildContext context, Habit habit) {
    return GestureDetector(
      onTap: () => onHabitTap?.call(habit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.habitGreen,
          borderRadius: BorderRadius.circular(AppBorderRadius.xs),
        ),
        child: Text(
          habit.displayTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showDayThemePopup(BuildContext context, Organizer theme) {
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
}
