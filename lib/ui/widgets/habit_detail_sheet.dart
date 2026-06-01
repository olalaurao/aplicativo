// lib/ui/widgets/habit_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/habit_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../forms/create_habit_form.dart';

class HabitDetailSheet extends ConsumerStatefulWidget {
  final Habit habit;
  final DateTime date;

  const HabitDetailSheet({super.key, required this.habit, required this.date});

  @override
  ConsumerState<HabitDetailSheet> createState() => _HabitDetailSheetState();
}

class _HabitDetailSheetState extends ConsumerState<HabitDetailSheet> {
  Color _parseColor(String hex) {
    try {
      String colorStr = hex.replaceAll('#', '');
      if (colorStr.length == 6) colorStr = 'FF$colorStr';
      return Color(int.parse(colorStr, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final currentHabit = habits.firstWhere(
      (h) => h.id == widget.habit.id,
      orElse: () => widget.habit,
    );

    final dateKey = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    final historyRecord = currentHabit.completionHistory.where((r) {
      return r.date.year == dateKey.year &&
          r.date.month == dateKey.month &&
          r.date.day == dateKey.day;
    });
    final completedCount = historyRecord.isNotEmpty
        ? historyRecord.first.completions
        : 0;

    final color = _parseColor(currentHabit.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ─── Stats Calculations ───
    final totalCompletions = currentHabit.completionHistory
        .where((r) => r.successful)
        .length;

    // Calculate consistency over last 30 days
    double consistencyRate = 0.0;
    if (currentHabit.completionHistory.isNotEmpty) {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentRecords = currentHabit.completionHistory
          .where((r) => r.date.isAfter(thirtyDaysAgo))
          .toList();
      final successfulRecent = recentRecords.where((r) => r.successful).length;
      consistencyRate = recentRecords.isNotEmpty
          ? (successfulRecent / recentRecords.length) * 100
          : 0.0;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Drag Indicator
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Header Section ───
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Icon(
                      currentHabit.icon != null && currentHabit.icon!.isNotEmpty
                          ? Icons.star_rounded // Placeholder for dynamic icons if needed
                          : Icons.repeat_rounded,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentHabit.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryColor(context),
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentHabit.description?.isNotEmpty == true
                              ? currentHabit.description!
                              : "Progresso hoje: $completedCount / ${currentHabit.dailyGoal}",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMutedColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateHabitForm(existingHabit: currentHabit),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.error,
                    ),
                    onPressed: () => _confirmDelete(context, currentHabit),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Stats Cards ───
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      context,
                      icon: Icons.local_fire_department_rounded,
                      label: 'Sequência',
                      value: '${currentHabit.streak} dias',
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStat(
                      context,
                      icon: Icons.trending_up_rounded,
                      label: 'Consistência',
                      value: '${consistencyRate.toStringAsFixed(0)}%',
                      color: AppColors.habitGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStat(
                      context,
                      icon: Icons.done_all_rounded,
                      label: 'Total',
                      value: '$totalCompletions vez${totalCompletions == 1 ? '' : 'es'}',
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Visual Grid Calendar (Histórico 35 Dias) ───
              Text(
                'HISTÓRICO RECENTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMutedColor(context),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildVisualHistoryGrid(context, currentHabit, color),
              const SizedBox(height: 24),

              // ─── Slots/Goal Section ───
              Text(
                currentHabit.dailyGoal > 1 ? 'METAS DIÁRIAS' : 'REGISTRO DIÁRIO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMutedColor(context),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: List.generate(currentHabit.dailyGoal, (index) {
                      final record = historyRecord.isNotEmpty ? historyRecord.first : null;
                      bool isCompleted = false;

                      if (record != null &&
                          record.slotCompletions != null &&
                          index < record.slotCompletions!.length) {
                        isCompleted = record.slotCompletions![index];
                      } else {
                        isCompleted = index < completedCount;
                      }

                      final slotConfig = index < currentHabit.slots.length
                          ? currentHabit.slots[index]
                          : HabitSlot();

                      return _buildSlotCard(
                        context,
                        index: index,
                        isCompleted: isCompleted,
                        slotConfig: slotConfig,
                        habitColor: color,
                        currentHabit: currentHabit,
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMutedColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualHistoryGrid(BuildContext context, Habit habit, Color color) {
    final now = DateTime.now();
    // 35 days grid (5 weeks), starting from Sunday, 34 days ago
    final startDate = now.subtract(Duration(days: 34 + (now.weekday % 7)));
    final days = List.generate(35, (i) => startDate.add(Duration(days: i)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1,
        ),
        itemCount: 35,
        itemBuilder: (context, idx) {
          final day = days[idx];
          final ds = day.toIso8601String().split('T').first;
          final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
          final isFuture = day.isAfter(now);

          // Check if successful on this day
          final record = habit.completionHistory
              .where((r) => r.date.toIso8601String().split('T').first == ds)
              .firstOrNull;
          final completed = record?.successful ?? false;

          Color cellColor;
          Border? cellBorder;

          if (isFuture) {
            cellColor = Colors.transparent;
          } else if (completed) {
            cellColor = color;
          } else if (isToday) {
            cellColor = Colors.transparent;
            cellBorder = Border.all(color: color, width: 2);
          } else {
            cellColor = isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03);
          }

          return Container(
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(8),
              border: cellBorder,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: completed
                      ? Colors.white
                      : (isToday ? color : AppTheme.textMutedColor(context)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context, {
    required int index,
    required bool isCompleted,
    required HabitSlot slotConfig,
    required Color habitColor,
    required Habit currentHabit,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? habitColor.withValues(alpha: 0.3)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(habitsProvider.notifier).toggleHabit(currentHabit, widget.date, slotIndex: index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCompleted ? habitColor : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: isCompleted ? habitColor : habitColor.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          slotConfig.label?.isNotEmpty == true
              ? slotConfig.label!
              : 'Etapa ${index + 1}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? AppTheme.textMutedColor(context) : AppTheme.textPrimaryColor(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: slotConfig.reminderEnabled && slotConfig.reminderTime != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    slotConfig.notificationType.name == 'alarm'
                        ? Icons.alarm_rounded
                        : Icons.notifications_active_outlined,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    slotConfig.reminderTime!.format(context),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              )
            : null,
        onTap: () {
          ref.read(habitsProvider.notifier).toggleHabit(currentHabit, widget.date, slotIndex: index);
        },
        trailing: slotConfig.actions.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: habitColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on_rounded, size: 12, color: habitColor),
                    const SizedBox(width: 4),
                    Text(
                      '${slotConfig.actions.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: habitColor,
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context, Habit habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Hábito?'),
        content: Text(
          'Tem certeza que deseja excluir "${habit.displayTitle}"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              ref.read(habitsProvider.notifier).deleteHabit(habit);
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close sheet
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
  }
}

void showHabitDetailSheet(BuildContext context, Habit habit, DateTime date) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, // Allow custom rounded container to show fully
    builder: (_) => HabitDetailSheet(habit: habit, date: date),
  );
}
