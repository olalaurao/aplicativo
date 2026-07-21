// lib/ui/widgets/habit_row.dart
import 'package:flutter/material.dart';
export 'habit_check_handler.dart' show handleHabitCheckTap;
import '../../models/habit_model.dart';
import '../theme.dart';
import 'habit_detail_sheet.dart';
import '../utils/object_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

class HabitRow extends ConsumerWidget {
  final Habit habit;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  const HabitRow({super.key, required this.habit, this.onTap, this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _getHabitColor(habit, ref);
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

    final isPact = habit.habitMode == HabitMode.pact;
    int remainingDays = 0;
    int dayCount = 0;
    if (isPact && habit.startedAt != null) {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final startedAtDate = DateTime(
        habit.startedAt!.year,
        habit.startedAt!.month,
        habit.startedAt!.day,
      );
      dayCount = todayDate.difference(startedAtDate).inDays + 1;
      if (habit.endsAt != null) {
        final endsAtDate = DateTime(
          habit.endsAt!.year,
          habit.endsAt!.month,
          habit.endsAt!.day,
        );
        remainingDays = endsAtDate.difference(todayDate).inDays;
      }
    }

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
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      habit.displayTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPact) ...[
                    const SizedBox(width: 6),
                    _buildBadge('PACT', color),
                  ],
                ],
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

            // Streak badge or Pact Day Count
            if (!isPact && habit.streak > 0)
              _buildBadge('🔥 ${habit.streak}', color),

            if (isPact && dayCount > 0) _buildBadge('Dia $dayCount', color),

            if (isPact && habit.endsAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    remainingDays >= 0 ? '$remainingDays d rest.' : 'Expirou',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),

            // Days since badge
            if (daysSince >= 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _buildDaysSinceBadge(context, daysSince, color),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysSinceBadge(BuildContext context, int days, Color habitColor) {
    if (days == 0) {
      // F3.10: Add checkmark icon for "Done today" state
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: habitColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              size: 10,
              color: habitColor,
            ),
            SizedBox(width: 4),
            Text(
              'Done today',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: habitColor,
              ),
            ),
          ],
        ),
      );
    }

    const color = AppColors.error;
    final text = days == 1 ? '1 day ago' : '$days days ago';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
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

  Color _getHabitColor(Habit habit, WidgetRef ref) {
    final customColor = _parseColor(habit.color);
    if (customColor != AppColors.primary) return customColor;
    
    // Use typeSignatures color if configured
    final settings = ref.read(settingsProvider);
    final signatureColor = ObjectIcons.colorForTypeWithSignatures('habit', settings.typeSignatures);
    if (signatureColor != ObjectIcons.defaultColorForType('habit')) {
      return signatureColor;
    }
    
    return AppColors.primary;
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
class HabitProgressRow extends ConsumerWidget {
  final Habit habit;
  final VoidCallback? onTap;

  const HabitProgressRow({super.key, required this.habit, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _getHabitColor(habit, ref);
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

    final isPact = habit.habitMode == HabitMode.pact;
    int remainingDays = 0;
    int dayCount = 0;
    if (isPact && habit.startedAt != null) {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final startedAtDate = DateTime(
        habit.startedAt!.year,
        habit.startedAt!.month,
        habit.startedAt!.day,
      );
      dayCount = todayDate.difference(startedAtDate).inDays + 1;
      if (habit.endsAt != null) {
        final endsAtDate = DateTime(
          habit.endsAt!.year,
          habit.endsAt!.month,
          habit.endsAt!.day,
        );
        remainingDays = endsAtDate.difference(todayDate).inDays;
      }
    }

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
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          habit.displayTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPact) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PACT',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                if (!isPact)
                  Text(
                    '🔥 ${habit.streak}',
                    style: const TextStyle(fontSize: 12),
                  )
                else
                  Text(
                    'Dia $dayCount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
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
            if (isPact && habit.endsAt != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pacto termina em: ${habit.endsAt!.toIso8601String().split('T').first}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                  Text(
                    remainingDays >= 0
                        ? '$remainingDays dias restantes'
                        : 'Expirado',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getHabitColor(Habit habit, WidgetRef ref) {
    final customColor = _parseColor(habit.color);
    if (customColor != AppColors.primary) return customColor;
    
    // Use typeSignatures color if configured
    final settings = ref.read(settingsProvider);
    final signatureColor = ObjectIcons.colorForTypeWithSignatures('habit', settings.typeSignatures);
    if (signatureColor != ObjectIcons.defaultColorForType('habit')) {
      return signatureColor;
    }
    
    return AppColors.primary;
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
