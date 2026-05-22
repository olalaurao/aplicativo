// lib/ui/screens/scheduler_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/goal_model.dart';
import '../../models/scheduler.dart';
import '../theme.dart';
import '../forms/scheduler_picker.dart';

class SchedulerManagementScreen extends ConsumerWidget {
  const SchedulerManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    final goals = ref.watch(goalsProvider);
    // final reminders = ref.watch(remindersProvider); // If exists

    final scheduledObjects = [
      ...tasks.where((t) => t.scheduler != null),
      ...habits.where((h) => h.scheduler != null),
      ...goals.where((g) => g.schedulers.isNotEmpty),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Schedule Management',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: scheduledObjects.isEmpty
          ? const Center(
              child: Text(
                'Nenhum agendamento ativo.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: scheduledObjects.length,
              itemBuilder: (context, index) {
                final obj = scheduledObjects[index];
                final title = (obj as dynamic).title as String;
                final type = (obj as dynamic).type as String;
                final scheduler = type == 'goal'
                    ? (obj as Goal).schedulers.first
                    : (obj is Task ? obj.scheduler : (obj as Habit).scheduler);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: AppTheme.cardDecoration(context),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _typeColor(type).withValues(alpha: 0.1),
                      child: Icon(
                        _typeIcon(type),
                        color: _typeColor(type),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _getSchedulerSummary(scheduler!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.edit_calendar_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: () =>
                          _editScheduler(context, ref, obj, scheduler),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'task':
        return AppColors.info;
      case 'habit':
        return AppColors.habitGreen;
      case 'goal':
        return AppColors.habitOrange;
      default:
        return AppColors.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline;
      case 'habit':
        return Icons.cached_rounded;
      case 'goal':
        return Icons.flag_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  String _getSchedulerSummary(Scheduler s) {
    if (s.rules.isEmpty) return 'Sem regras';
    final r = s.rules.first;
    switch (r.repeatType) {
      case RepeatType.numberOfDays:
        return 'A cada ${r.interval} dias';
      case RepeatType.daysOfWeek:
        return 'Weekl: ${r.daysOfWeek?.join(', ')}';
      case RepeatType.numberOfWeeks:
        return 'A cada ${r.interval} semanas';
      case RepeatType.numberOfMonths:
        return 'A cada ${r.interval} meses';
      default:
        return r.repeatType.name;
    }
  }

  Future<void> _editScheduler(
    BuildContext context,
    WidgetRef ref,
    dynamic obj,
    Scheduler current,
  ) async {
    final result = await Navigator.push<Scheduler>(
      context,
      MaterialPageRoute(
        builder: (_) => SchedulerPicker(initialScheduler: current),
      ),
    );

    if (result != null) {
      // Logic to update the object's scheduler in the vault
      if (obj is Task) {
        obj.scheduler = result;
        ref.read(tasksProvider.notifier).updateTask(obj);
      } else if (obj is Habit) {
        obj.scheduler = result;
        ref.read(habitsProvider.notifier).updateHabit(obj);
      } else if (obj is Goal) {
        obj.schedulers = [result];
        ref.read(goalsProvider.notifier).updateGoal(obj);
      }
    }
  }
}
