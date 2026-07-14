// lib/ui/widgets/week_time_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../theme.dart';

class WeekTimeGrid extends ConsumerWidget {
  final List<Task> tasks;
  final List<Habit> habits;
  final DateTime startOfWeek;
  final Function(Task, DateTime)? onTaskTap;
  final Function(Habit)? onHabitTap;

  const WeekTimeGrid({
    super.key,
    required this.tasks,
    required this.habits,
    required this.startOfWeek,
    this.onTaskTap,
    this.onHabitTap,
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
                  return Expanded(
                    child: Center(
                      child: Column(
                        children: [
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

    if (hourTasks.isEmpty && hourHabits.isEmpty) {
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
          if (hourTasks.isNotEmpty)
            ...hourTasks.take(2).map((task) => _buildMiniTaskBlock(context, task)),
          if (hourHabits.isNotEmpty)
            ...hourHabits.take(1).map((habit) => _buildMiniHabitBlock(context, habit)),
        ],
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
}
