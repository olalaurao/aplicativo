import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal_model.dart';
import '../models/idea_model.dart';
import '../models/project_model.dart';
import '../models/resource_model.dart';
import '../models/routine_model.dart';
import '../models/content_object.dart';
import 'vault_provider.dart';
import 'settings_provider.dart';

class OverdueItem {
  final ContentObject object;
  final DateTime deadline;
  final int daysLate;
  final String itemType; // 'task' | 'goal' | 'project' | 'idea' | 'resource' | 'reminder' | 'routine'

  const OverdueItem({
    required this.object,
    required this.deadline,
    required this.daysLate,
    required this.itemType,
  });
}

final overdueProvider = Provider<List<OverdueItem>>((ref) {
  if (!ref.watch(settingsProvider).showOverdueSection) return [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  bool isOverdue(DateTime? dl) {
    if (dl == null) return false;
    return DateTime(dl.year, dl.month, dl.day).isBefore(today);
  }

  int daysLate(DateTime dl) =>
      today.difference(DateTime(dl.year, dl.month, dl.day)).inDays;

  final items = <OverdueItem>[];

  final tasks = ref.watch(tasksListProvider);
  for (final task in tasks) {
    if (task.isCompleted || task.archived) continue;
    final dl = task.endDate ?? task.startDate;
    if (!isOverdue(dl)) continue;
    items.add(OverdueItem(
      object: task,
      deadline: dl!,
      daysLate: daysLate(dl),
      itemType: 'task',
    ));
  }
  
  final goals = ref.watch(goalsListProvider);
  for (final goal in goals) {
    if (goal.state == GoalStatus.completed ||
        goal.state == GoalStatus.cancelled ||
        goal.archived) {
      continue;
    }
    if (!isOverdue(goal.deadline)) continue;
    items.add(OverdueItem(
      object: goal,
      deadline: goal.deadline!,
      daysLate: daysLate(goal.deadline!),
      itemType: 'goal',
    ));
  }
  
  for (final project in ref.watch(objectsByTypeProvider('project')).cast<Project>()) {
    if (project.state == ProjectState.completed ||
        project.state == ProjectState.archived ||
        project.archived) {
      continue;
    }
    if (!isOverdue(project.endDate)) continue;
    items.add(OverdueItem(
      object: project,
      deadline: project.endDate!,
      daysLate: daysLate(project.endDate!),
      itemType: 'project',
    ));
  }
  
  for (final idea in ref.watch(ideasProvider)) {
    if (idea.status == IdeaStatus.converted ||
        idea.status == IdeaStatus.dropped ||
        idea.archived) {
      continue;
    }
    if (!isOverdue(idea.targetDate)) continue;
    items.add(OverdueItem(
      object: idea,
      deadline: idea.targetDate!,
      daysLate: daysLate(idea.targetDate!),
      itemType: 'idea',
    ));
  }
  
  // Resources - overdue if readDate is set and passed, or if status is not completed/dropped
  final resources = ref.watch(resourcesListProvider);
  for (final resource in resources) {
    if (resource.status == ResourceStatus.completed ||
        resource.status == ResourceStatus.dropped ||
        resource.archived) {
      continue;
    }
    // Consider overdue if readDate is set and passed
    if (resource.readDate != null && isOverdue(resource.readDate!)) {
      items.add(OverdueItem(
        object: resource,
        deadline: resource.readDate!,
        daysLate: daysLate(resource.readDate!),
        itemType: 'resource',
      ));
    }
  }
  
  // Reminders - overdue if time is passed and not completed
  final reminders = ref.watch(remindersProvider);
  for (final reminder in reminders) {
    if (reminder.isCompleted || reminder.archived) continue;
    if (!isOverdue(reminder.time)) continue;
    items.add(OverdueItem(
      object: reminder,
      deadline: reminder.time,
      daysLate: daysLate(reminder.time),
      itemType: 'reminder',
    ));
  }
  
  // Routines - overdue if endDate is set and passed, and not archived
  final routines = ref.watch(organizersListProvider).whereType<Routine>();
  for (final routine in routines) {
    if (routine.archived) continue;
    if (routine.endDate != null && isOverdue(routine.endDate!)) {
      items.add(OverdueItem(
        object: routine,
        deadline: routine.endDate!,
        daysLate: daysLate(routine.endDate!),
        itemType: 'routine',
      ));
    }
  }

  items.sort((a, b) => b.daysLate.compareTo(a.daysLate));
  return items;
});

final overdueCountProvider =
    Provider<int>((ref) => ref.watch(overdueProvider).length);
