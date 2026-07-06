// lib/ui/screens/overdue_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../providers/overdue_provider.dart';
import '../../providers/vault_provider.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/goal_model.dart';
import 'package:intl/intl.dart';

class OverdueDetailScreen extends ConsumerWidget {
  const OverdueDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdueItems = ref.watch(overdueProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Atrasados'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: overdueItems.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.habitGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: AppColors.habitGreen,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Nenhum item atrasado',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tudo está em dia!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: overdueItems.length,
                itemBuilder: (context, index) {
                  final item = overdueItems[index];
                  return _OverdueItemCard(item: item);
                },
              ),
      ),
    );
  }
}

class _OverdueItemCard extends ConsumerWidget {
  final OverdueItem item;

  const _OverdueItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysLate = item.daysLate;
    final daysLateText = daysLate == 1 ? '1 dia' : '$daysLate dias';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      color: Theme.of(context).cardColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.object.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Atrasado $daysLateText',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (item.itemType == 'task')
              _TaskActionButtons(item: item)
            else if (item.itemType == 'habit')
              _HabitActionButtons(item: item)
            else if (item.itemType == 'goal')
              _GoalActionButtons(item: item)
            else
              _GenericActionButtons(item: item),
          ],
        ),
      ),
    );
  }
}

class _TaskActionButtons extends ConsumerWidget {
  final OverdueItem item;

  const _TaskActionButtons({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = item.object as Task;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.today_outlined,
            label: 'Para Hoje',
            onPressed: () => _moveToToday(context, ref, task),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.check_circle_outline_rounded,
            label: 'Feito Hoje',
            onPressed: () => _markAsDoneToday(context, ref, task),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.calendar_today_outlined,
            label: 'Escolher Data',
            onPressed: () => _pickDate(context, ref, task),
          ),
        ),
      ],
    );
  }

  Future<void> _moveToToday(BuildContext context, WidgetRef ref, Task task) async {
    try {
      final today = DateTime.now();
      final updatedTask = task.copyWith(endDate: today);
      await ref.read(vaultProvider.notifier).updateObject(updatedTask);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movido para hoje'),
            backgroundColor: AppColors.habitGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _markAsDoneToday(BuildContext context, WidgetRef ref, Task task) async {
    try {
      final today = DateTime.now();
      final updatedTask = task.copyWith(
        stage: TaskStage.finalized,
      );
      await ref.read(vaultProvider.notifier).updateObject(updatedTask);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marcado como feito hoje'),
            backgroundColor: AppColors.habitGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, Task task) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && context.mounted) {
      try {
        final updatedTask = task.copyWith(endDate: picked);
        await ref.read(vaultProvider.notifier).updateObject(updatedTask);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Movido para ${DateFormat('dd/MM/yyyy').format(picked)}'),
            backgroundColor: AppColors.habitGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _HabitActionButtons extends ConsumerWidget {
  final OverdueItem item;

  const _HabitActionButtons({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = item.object as Habit;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.check_circle_outline_rounded,
            label: 'Feito Hoje',
            onPressed: () => _markAsDoneToday(context, ref, habit),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.calendar_today_outlined,
            label: 'Escolher Data',
            onPressed: () => _pickDate(context, ref, habit),
          ),
        ),
      ],
    );
  }

  Future<void> _markAsDoneToday(BuildContext context, WidgetRef ref, Habit habit) async {
    try {
      final today = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(today);
      final updatedHabit = habit.copyWith(
        completionHistory: [
          ...habit.completionHistory,
          CompletionRecord(date: today, completions: 1, successful: true),
        ],
      );
      await ref.read(vaultProvider.notifier).updateObject(updatedHabit);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marcado como feito hoje'),
            backgroundColor: AppColors.habitGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, Habit habit) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && context.mounted) {
      try {
        final dateStr = DateFormat('yyyy-MM-dd').format(picked);
        final updatedHabit = habit.copyWith(
          completionHistory: [
            ...habit.completionHistory,
            CompletionRecord(date: picked, completions: 1, successful: true),
          ],
        );
        await ref.read(vaultProvider.notifier).updateObject(updatedHabit);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marcado como feito em ${DateFormat('dd/MM/yyyy').format(picked)}'),
            backgroundColor: AppColors.habitGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _GoalActionButtons extends ConsumerWidget {
  final OverdueItem item;

  const _GoalActionButtons({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = item.object as Goal;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.calendar_today_outlined,
            label: 'Nova Data',
            onPressed: () => _pickDate(context, ref, goal),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.check_circle_outline_rounded,
            label: 'Concluir',
            onPressed: () => _markAsCompleted(context, ref, goal),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, Goal goal) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: goal.deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null && context.mounted) {
      try {
        final updatedGoal = goal.copyWith(deadline: picked);
        await ref.read(vaultProvider.notifier).updateObject(updatedGoal);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prazo atualizado para ${DateFormat('dd/MM/yyyy').format(picked)}'),
            backgroundColor: AppColors.habitGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _markAsCompleted(BuildContext context, WidgetRef ref, Goal goal) async {
    try {
      final updatedGoal = goal.copyWith(state: GoalStatus.completed);
      await ref.read(vaultProvider.notifier).updateObject(updatedGoal);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meta concluída'),
            backgroundColor: AppColors.habitGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _GenericActionButtons extends ConsumerWidget {
  final OverdueItem item;

  const _GenericActionButtons({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.open_in_new_outlined,
            label: 'Ver Detalhes',
            onPressed: () {
              // Navigate to detail view
              // This would use the navigation system to open the detail view
            },
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        foregroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
