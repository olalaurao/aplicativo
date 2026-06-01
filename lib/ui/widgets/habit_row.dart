// lib/ui/widgets/habit_row.dart
import 'package:flutter/material.dart';
import '../../models/habit_model.dart';
import '../theme.dart';
import 'habit_detail_sheet.dart';

class HabitRow extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  const HabitRow({super.key, required this.habit, this.onTap, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(habit.color);
    final todayRecord = habit.completionHistory.where((r) {
      final now = DateTime.now();
      return r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day;
    });
    final completedToday = todayRecord.isNotEmpty
        ? todayRecord.first.completions
        : 0;
    final daysSince = habit.daysSinceLastCompletion;

    return InkWell(
      onTap:
          onTap ?? () => showHabitDetailSheet(context, habit, DateTime.now()),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // Habit name
            Expanded(
              flex: 3,
              child: Text(
                habit.displayTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),

            // Progress text
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$completedToday/${habit.dailyGoal} ${habit.completionUnit}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
            ),

            // Streak badge
            if (habit.streak > 0)
              _buildBadge('🔥 ${habit.streak}', AppColors.habitOrange),

            // Days since badge
            if (daysSince >= 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _buildDaysSinceBadge(context, daysSince),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysSinceBadge(BuildContext context, int days) {
    if (days == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.habitGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Feito hoje',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.habitGreen,
          ),
        ),
      );
    }

    final color = days >= 3
        ? AppColors.error
        : AppTheme.textMutedColor(context);
    final text = days == 1 ? '1 day ago' : '$days days ago';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: AppTheme.badgeDecoration(color),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

/// Compact version for the habits section card on Timeline
class HabitProgressRow extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onTap;

  const HabitProgressRow({super.key, required this.habit, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(habit.color);
    final todayRecord = habit.completionHistory.where((r) {
      final now = DateTime.now();
      return r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day;
    });
    final completedToday = todayRecord.isNotEmpty
        ? todayRecord.first.completions
        : 0;
    final progress = (completedToday / habit.dailyGoal).clamp(0.0, 1.0);

    return InkWell(
      onTap:
          onTap ?? () => showHabitDetailSheet(context, habit, DateTime.now()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    habit.displayTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  '$completedToday/${habit.dailyGoal} ${habit.completionUnit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '🔥 ${habit.streak}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
