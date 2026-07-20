// lib/features/overdue/replanning/replanning_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../models/content_object.dart';
import '../../../models/task_model.dart';
import '../../../models/goal_model.dart';
import '../../../models/reminder_model.dart';
import '../../../providers/vault_provider.dart';
import '../../../providers/overdue_provider.dart';
import '../../../ui/theme.dart';

enum ReplanningAction {
  deferOneDay,
  deferOneWeek,
  pickDate,
  complete,
  discard,
}

class ReplanningActions {
  static void executeAction(
    BuildContext context,
    WidgetRef ref,
    OverdueItem overdueItem,
    ReplanningAction action,
  ) {
    final item = overdueItem.object;
    final vaultNotifier = ref.read(vaultProvider.notifier);

    switch (action) {
      case ReplanningAction.deferOneDay:
        _deferItem(item, vaultNotifier, days: 1);
        _showSuccessSnackBar(context, 'Adiado em 1 dia');
        break;
      case ReplanningAction.deferOneWeek:
        _deferItem(item, vaultNotifier, days: 7);
        _showSuccessSnackBar(context, 'Adiado em 1 semana');
        break;
      case ReplanningAction.pickDate:
        _showDatePicker(context, item, vaultNotifier);
        break;
      case ReplanningAction.complete:
        _completeItem(item, vaultNotifier);
        _showSuccessSnackBar(context, 'Marcado como concluído');
        break;
      case ReplanningAction.discard:
        _discardItem(item, vaultNotifier);
        _showSuccessSnackBar(context, 'Descartado');
        break;
    }
  }

  static void executeBatchAction(
    BuildContext context,
    WidgetRef ref,
    Set<String> Function(List<OverdueItem>) getSelectedIds,
    ReplanningAction action,
  ) {
    final overdueItems = ref.read(overdueProvider);
    final selectedIds = getSelectedIds(overdueItems);
    final selectedItems = overdueItems
        .where((item) => selectedIds.contains(item.object.id))
        .toList();

    final vaultNotifier = ref.read(vaultProvider.notifier);

    for (final overdueItem in selectedItems) {
      final item = overdueItem.object;

      switch (action) {
        case ReplanningAction.deferOneDay:
          _deferItem(item, vaultNotifier, days: 1);
          break;
        case ReplanningAction.deferOneWeek:
          _deferItem(item, vaultNotifier, days: 7);
          break;
        case ReplanningAction.pickDate:
          // Skip date picker for batch actions
          break;
        case ReplanningAction.complete:
          _completeItem(item, vaultNotifier);
          break;
        case ReplanningAction.discard:
          _discardItem(item, vaultNotifier);
          break;
      }
    }

    final actionLabel = _getActionLabel(action);
    _showSuccessSnackBar(context, '$actionLabel (${selectedItems.length} itens)');
  }

  static void _deferItem(ContentObject item, dynamic vaultNotifier, {required int days}) {
    final now = DateTime.now();
    final newDate = now.add(Duration(days: days));

    switch (item.type) {
      case 'task':
        final task = item as Task;
        vaultNotifier.updateObject(
          task.copyWith(
            endDate: task.endDate != null
                ? task.endDate!.add(Duration(days: days))
                : task.startDate?.add(Duration(days: days)),
            startDate: task.startDate?.add(Duration(days: days)),
          ),
        );
        break;
      case 'goal':
        final goal = item as Goal;
        if (goal.deadline != null) {
          vaultNotifier.updateObject(
            goal.copyWith(
              deadline: goal.deadline!.add(Duration(days: days)),
            ),
          );
        }
        break;
      case 'reminder':
        final reminder = item as Reminder;
        vaultNotifier.updateObject(
          reminder.copyWith(
            time: reminder.time.add(Duration(days: days)),
          ),
        );
        break;
      default:
        break;
    }
  }

  static void _showDatePicker(
    BuildContext context,
    ContentObject item,
    dynamic vaultNotifier,
  ) {
    showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    ).then((selectedDate) {
      if (selectedDate == null) return;

      switch (item.type) {
        case 'task':
          final task = item as Task;
          vaultNotifier.updateObject(
            task.copyWith(
              endDate: selectedDate,
            ),
          );
          break;
        case 'goal':
          final goal = item as Goal;
          vaultNotifier.updateObject(
            goal.copyWith(
              deadline: selectedDate,
            ),
          );
          break;
        case 'reminder':
          final reminder = item as Reminder;
          // Keep the time, change the date
          final newDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            reminder.time.hour,
            reminder.time.minute,
          );
          vaultNotifier.updateObject(
            reminder.copyWith(
              time: newDateTime,
            ),
          );
          break;
        default:
          break;
      }

      _showSuccessSnackBar(context, 'Data atualizada');
    });
  }

  static void _completeItem(ContentObject item, dynamic vaultNotifier) {
    switch (item.type) {
      case 'task':
        final task = item as Task;
        vaultNotifier.updateObject(
          task.copyWith(
            stage: TaskStage.finalized,
          ),
        );
        break;
      case 'goal':
        final goal = item as Goal;
        vaultNotifier.updateObject(
          goal.copyWith(
            state: GoalStatus.completed,
          ),
        );
        break;
      case 'reminder':
        final reminder = item as Reminder;
        vaultNotifier.updateObject(
          reminder.copyWith(
            isCompleted: true,
          ),
        );
        break;
      default:
        break;
    }
  }

  static void _discardItem(ContentObject item, dynamic vaultNotifier) {
    // Archive the item instead of deleting it
    item.archived = true;
    vaultNotifier.updateObject(item);
  }

  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _getActionLabel(ReplanningAction action) {
    switch (action) {
      case ReplanningAction.deferOneDay:
        return 'Adiado';
      case ReplanningAction.deferOneWeek:
        return 'Adiado';
      case ReplanningAction.pickDate:
        return 'Data atualizada';
      case ReplanningAction.complete:
        return 'Concluído';
      case ReplanningAction.discard:
        return 'Descartado';
    }
  }
}
