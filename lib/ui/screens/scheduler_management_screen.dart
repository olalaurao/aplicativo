// lib/ui/screens/scheduler_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/goal_model.dart';
import '../../models/scheduler.dart';
import '../../services/scheduler_service.dart';
import '../theme.dart';
import '../forms/scheduler_picker.dart';
import '../widgets/universal_search_picker.dart';

class SchedulerManagementScreen extends ConsumerWidget {
  const SchedulerManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    final habits = allObjects.whereType<Habit>().toList();
    final goals = allObjects.whereType<Goal>().toList();
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addScheduler(context, ref),
        child: const Icon(Icons.add_rounded),
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
                final next = SchedulerService.nextOccurrence(
                  scheduler!,
                  after: DateTime.now().subtract(const Duration(days: 1)),
                );

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
                      [
                        _getSchedulerSummary(scheduler),
                        if (next != null)
                          'Próxima: ${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.edit_calendar_rounded,
                        color: AppTheme.accentColor(context),
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

  Future<void> _addScheduler(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UniversalSearchPickerSheet(
        title: 'Adicionar scheduler',
        initialFilter: 'all',
        showClear: false,
        onSelected: (object) async {
          Navigator.pop(context);
          if (object is! Task && object is! Habit && object is! Goal) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Escolha uma tarefa, hábito ou objetivo.'),
              ),
            );
            return;
          }
          final current = object is Goal
              ? (object.schedulers.isNotEmpty ? object.schedulers.first : null)
              : (object is Task ? object.scheduler : (object as Habit).scheduler);
          final scheduler = await Navigator.push<Scheduler>(
            context,
            MaterialPageRoute(
              builder: (_) => SchedulerPicker(initialScheduler: current),
            ),
          );
          if (scheduler == null) return;
          await _saveScheduler(ref, object, scheduler);
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
      await _saveScheduler(ref, obj, result);
    }
  }

  Future<void> _saveScheduler(
    WidgetRef ref,
    dynamic obj,
    Scheduler scheduler,
  ) async {
    if (obj is Task) {
      obj.scheduler = scheduler;
      await ref.read(vaultProvider.notifier).updateObject(obj);
    } else if (obj is Habit) {
      obj.scheduler = scheduler;
      await ref.read(habitsProvider.notifier).updateHabit(obj);
    } else if (obj is Goal) {
      obj.schedulers = [scheduler];
      await ref.read(goalsProvider.notifier).updateGoal(obj);
    }
  }
}
