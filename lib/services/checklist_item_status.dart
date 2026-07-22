import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit_model.dart';
import '../models/task_model.dart';
import '../models/tracker_model.dart';
import '../models/pomodoro_session.dart';
import '../providers/vault_provider.dart';
import '../providers/pomodoro_provider.dart';

/// Returns whether a checklist item is "done" based on its linked object.
/// For plain items, the caller should provide local state instead.
bool computeChecklistItemDone({
  required String kind,
  required String? linkedObjectSlug,
  required String? trackerFieldId,
  required DateTime date,
  required WidgetRef ref,
  required String parentObjectId,
  required String itemId,
  List<Habit>? habits,
  List<Task>? tasks,
  List<TrackingRecord>? trackingRecords,
  PomodoroState? pomodoroState,
}) {
  final dateStr = date.toIso8601String().split('T').first;

  switch (kind) {
    case 'plain':
      // Caller should provide local state for plain items
      return false;

    case 'habit':
      if (linkedObjectSlug == null) return false;
      final habitList = habits ?? ref.read(habitsProvider);
      if (habitList == null) return false;
      final habit = habitList.where((h) => h.slug == linkedObjectSlug).firstOrNull;
      if (habit == null) return false;
      return habit.completionHistory.any((r) =>
        r.date.toIso8601String().split('T').first == dateStr &&
        r.successful,
      );

    case 'task':
      if (linkedObjectSlug == null) return false;
      final taskList = tasks ?? ref.read(tasksProvider);
      if (taskList == null) return false;
      final task = taskList.where((t) => t.slug == linkedObjectSlug).firstOrNull;
      if (task == null) return false;
      return task.stage == TaskStage.finalized;

    case 'tracker_entry':
      if (linkedObjectSlug == null || trackerFieldId == null) return false;
      final recordList = trackingRecords ?? ref.read(trackingRecordsProvider);
      if (recordList == null) return false;
      return recordList.any((r) =>
        r.trackerId == linkedObjectSlug &&
        r.date.toIso8601String().split('T').first == dateStr &&
        r.fieldValues[trackerFieldId] != null &&
        r.fieldValues[trackerFieldId].toString().isNotEmpty,
      );

    case 'pomodoro':
      final state = pomodoroState ?? ref.read(pomodoroProvider);
      if (state == null) return false;
      final expectedSlug = 'checklist:$parentObjectId:$itemId';
      return state.history.any((s) =>
        s.linkedItemSlug == expectedSlug &&
        s.state == PomodoroSessionState.completed &&
        (s.occurredAt ?? s.date).toIso8601String().split('T').first == dateStr,
      );

    default:
      return false;
  }
}
