import '../models/routine_model.dart';
import '../models/habit_model.dart';
import '../models/task_model.dart';
import '../models/content_object.dart';
import '../ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../providers/vault_provider.dart';

class RoutineExecutionService {
  /// Start a new routine execution
  static RoutineExecution startExecution(Routine routine) {
    return RoutineExecution(
      executedAt: DateTime.now(),
      itemCompletions: {},
    );
  }

  /// Toggle habit completion within an execution
  /// Updates the habit directly and tracks completion in execution
  static Future<void> toggleHabitInExecution(
    RoutineExecution execution,
    Habit habit,
    WidgetRef ref,
  ) async {
    // Toggle habit completion
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // Find if habit has completion record for today
    final existingRecord = habit.completionHistory
        .where((r) => r.date.year == todayDate.year && 
                     r.date.month == todayDate.month && 
                     r.date.day == todayDate.day)
        .firstOrNull;
    
    Habit updatedHabit;
    if (existingRecord != null) {
      // Toggle existing completion
      final newRecord = CompletionRecord(
        date: todayDate,
        completions: existingRecord.successful ? 0 : habit.dailyGoal,
        successful: !existingRecord.successful,
        completedAt: DateTime.now(),
      );
      final updatedHistory = [...habit.completionHistory];
      final index = updatedHistory.indexWhere((r) => r == existingRecord);
      if (index >= 0) {
        updatedHistory[index] = newRecord;
      }
      updatedHabit = habit.copyWith(completionHistory: updatedHistory);
    } else {
      // Add new completion record
      final newRecord = CompletionRecord(
        date: todayDate,
        completions: habit.dailyGoal,
        successful: true,
        completedAt: DateTime.now(),
      );
      updatedHabit = habit.copyWith(
        completionHistory: [...habit.completionHistory, newRecord],
      );
    }
    
    // Recalculate streak
    updatedHabit.calculateStreak();
    
    // Update habit in vault
    await ref.read(vaultProvider.notifier).updateObject(updatedHabit);
  }

  /// Complete a routine execution
  /// Shows dialog to choose between "leave incomplete items open" or "mark all as done"
  static Future<bool> completeExecution(
    Routine routine,
    RoutineExecution execution,
    WidgetRef ref,
    BuildContext context,
  ) async {
    // Calculate incomplete items
    final incompleteItems = routine.items
        .where((item) => execution.itemCompletions[item.id] != true)
        .toList();
    
    if (incompleteItems.isEmpty) {
      // All items completed, just save execution
      return await _saveExecution(routine, execution, ref, markAllAsDone: false);
    }
    
    // Show dialog for incomplete items
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Routine'),
        content: Text(
          'You have ${incompleteItems.length} incomplete item(s).\n\n'
          'Would you like to leave them open (they will become overdue) '
          'or mark all items as done?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Leave Open'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Mark All Done'),
          ),
        ],
      ),
    );
    
    if (result == null) return false; // User cancelled
    
    return await _saveExecution(routine, execution, ref, markAllAsDone: result);
  }

  /// Save execution to routine history
  static Future<bool> _saveExecution(
    Routine routine,
    RoutineExecution execution,
    WidgetRef ref, {
    required bool markAllAsDone,
  }) async {
    // If markAllAsDone, mark all items as completed
    if (markAllAsDone) {
      final updatedCompletions = Map<String, bool>.from(execution.itemCompletions);
      for (final item in routine.items) {
        updatedCompletions[item.id] = true;
      }
      execution = execution.copyWith(itemCompletions: updatedCompletions);
    }
    
    // Add execution to history
    final updatedRoutine = routine.copyWith(
      executionHistory: [...routine.executionHistory, execution],
    );
    
    // Save routine
    await ref.read(vaultProvider.notifier).updateObject(updatedRoutine);
    
    return true;
  }

  /// Get referenced object from WikiLink
  static ContentObject? getReferencedObject(
    String wikiLink,
    List<ContentObject> allObjects,
  ) {
    // Extract ID from WikiLink [[id]] or [[id|alias]]
    final idMatch = RegExp(r'\[\[([^\]|]+)\]\]').firstMatch(wikiLink);
    final objectId = idMatch?.group(1) ?? wikiLink;
    
    return allObjects.where((obj) => obj.id == objectId).firstOrNull;
  }

  /// Check if an item is a habit
  static bool isHabitItem(RoutineItem item, List<ContentObject> allObjects) {
    final obj = getReferencedObject(item.referencedObjectId, allObjects);
    return obj is Habit;
  }

  /// Check if an item is a task
  static bool isTaskItem(RoutineItem item, List<ContentObject> allObjects) {
    final obj = getReferencedObject(item.referencedObjectId, allObjects);
    return obj is Task;
  }

  /// Get habit completion status for display
  static bool isHabitCompletedToday(Habit habit) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    return habit.completionHistory.any((r) => 
      r.date.year == todayDate.year && 
      r.date.month == todayDate.month && 
      r.date.day == todayDate.day &&
      r.successful
    );
  }
}
