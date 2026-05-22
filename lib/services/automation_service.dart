import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit_model.dart';
import '../models/shared_types.dart';
import '../models/journal_entry.dart';
import '../models/task_model.dart';
import '../models/people_model.dart';
import '../providers/vault_provider.dart';
import '../services/kpi_engine.dart';
import '../models/goal_model.dart';
import 'notification_service.dart';

class AutomationService {
  static Future<void> executeHabitActions(
    Ref ref,
    Habit habit,
    DateTime date,
  ) async {
    for (final action in habit.actions) {
      if (action.trigger == 'day_complete') {
        await _executeAction(ref, action, habit, date);
      }
    }
  }

  static Future<void> _executeAction(
    Ref ref,
    ActionDef action,
    Habit habit,
    DateTime date,
  ) async {
    switch (action.type) {
      case 'add_entry':
        final journalNotifier = ref.read(todayJournalProvider.notifier);
        await journalNotifier.addEntry(
          JournalEntry(
            body: 'Automatic: Habit "${habit.title}" completed.',
            date: DateTime.now(),
            title: 'Habit Completion',
          ),
        );
        break;

      case 'create_task':
        final tasksNotifier = ref.read(tasksProvider.notifier);
        await tasksNotifier.addTask(
          Task(
            title: 'Acompanhamento: ${habit.title}',
            notes: ['Task created automatically after completing the habit.'],
            startDate: DateTime.now(),
            stage: TaskStage.todo,
          ),
        );
        break;
    }
  }

  static Future<void> checkPersonContacts(Ref ref, List<Person> people) async {
    final tasks = ref.read(tasksProvider);
    final now = DateTime.now();

    for (final person in people) {
      if (person.isDueForContact) {
        final taskTitle = 'Contatar ${person.title}';

        // Check if task already exists
        final exists = tasks.any(
          (t) => t.title == taskTitle && t.stage != TaskStage.finalized,
        );
        if (!exists) {
          final tasksNotifier = ref.read(tasksProvider.notifier);
          await tasksNotifier.addTask(
            Task(
              id: 'contact_${person.id}_${now.millisecondsSinceEpoch}',
              title: taskTitle,
              notes: [
                'Task created automatically from the configured contact frequency.',
              ],
              startDate: now,
              priority: person.contactPriority,
              stage: TaskStage.todo,
              organizers: [
                OrganizerReference(type: 'person', slug: person.slug, title: person.title),
              ],
            ),
          );
        }
      }
    }
  }

  static Future<void> updateAllKPIs(Ref ref) async {
    final goals = ref.read(goalsProvider);
    final habits = ref.read(habitsProvider);
    final trackers = ref.read(trackingRecordsProvider);
    final entries = ref.read(allEntriesProvider);
    final moods = ref.read(moodsProvider);
    final notes = ref.read(notesProvider);

    for (final goal in goals) {
      bool goalChanged = false;
      for (final kpi in goal.kpis) {
        final newValue = KPIEngine.calculateKPIValue(
          kpi: kpi,
          habits: habits,
          trackerRecords: trackers,
          entries: entries,
          moods: moods,
          notes: notes,
        );
        if (kpi.currentValue != newValue) {
          kpi.currentValue = newValue;
          goalChanged = true;
        }
      }
      if (goalChanged) {
        await ref.read(goalsProvider.notifier).updateGoal(goal);
        await checkKPIGoals(ref, goal);
      }
    }
  }

  static Future<void> checkKPIGoals(Ref ref, Goal goal) async {
    if (goal.state != GoalStatus.active) return;

    // If all KPIs are met, mark as completed
    if (goal.kpis.isNotEmpty &&
        goal.kpis.every((k) => k.currentValue >= k.targetValue)) {
      goal.state = GoalStatus.completed;
      await ref.read(goalsProvider.notifier).updateGoal(goal);

      // Optional: Show notification or trigger action
      await NotificationService().showImmediateNotification(
        id: goal.id.hashCode,
        title: 'Goal Reached!',
        body: 'Congratulations! You reached every target for "${goal.title}".',
      );
    }
  }
}
