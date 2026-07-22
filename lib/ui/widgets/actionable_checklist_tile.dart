import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/habit_model.dart';
import '../../models/task_model.dart';
import '../../models/tracker_model.dart';
import '../../models/note_model.dart';
import '../../models/shared_types.dart';
import '../../models/pomodoro_session.dart';
import '../../services/checklist_item_status.dart';
import '../../providers/vault_provider.dart';
import '../../providers/pomodoro_provider.dart';
import 'collection_item_picker_sheet.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class ActionableChecklistTile extends ConsumerWidget {
  final String itemId;
  final String title;
  final String kind;
  final String? linkedObjectSlug;
  final String? trackerFieldId;
  final String? attachedCollectionSlug;
  final DateTime date;
  final String parentObjectId;
  final bool? plainValue;
  final ValueChanged<bool>? onPlainToggle;
  final Function(String taskSlug)? onTaskCreated;

  const ActionableChecklistTile({
    super.key,
    required this.itemId,
    required this.title,
    required this.kind,
    this.linkedObjectSlug,
    this.trackerFieldId,
    this.attachedCollectionSlug,
    required this.date,
    required this.parentObjectId,
    this.plainValue,
    this.onPlainToggle,
    this.onTaskCreated,
  });

  IconData _getKindIcon() {
    switch (kind) {
      case 'habit':
        return Icons.check_circle_outline;
      case 'task':
        return Icons.task_alt;
      case 'tracker_entry':
        return Icons.bar_chart;
      case 'pomodoro':
        return Icons.timer;
      default:
        return Icons.circle_outlined;
    }
  }

  bool _isDone(
    WidgetRef ref, [
    List<Habit>? habits,
    List<Task>? tasks,
    List<TrackingRecord>? trackingRecords,
    PomodoroState? pomodoroState,
  ]) {
    if (kind == 'plain') return plainValue ?? false;
    return computeChecklistItemDone(
      kind: kind,
      linkedObjectSlug: linkedObjectSlug,
      trackerFieldId: trackerFieldId,
      date: date,
      ref: ref,
      parentObjectId: parentObjectId,
      itemId: itemId,
      habits: habits,
      tasks: tasks,
      trackingRecords: trackingRecords,
      pomodoroState: pomodoroState,
    );
  }

  Future<void> _handleTap(WidgetRef ref) async {
    switch (kind) {
      case 'plain':
        onPlainToggle?.call(!(plainValue ?? false));
        break;

      case 'habit':
        await _handleHabitTap(ref);
        break;

      case 'task':
        await _handleTaskTap(ref);
        break;

      case 'tracker_entry':
        await _handleTrackerTap(ref);
        break;

      case 'pomodoro':
        await _handlePomodoroTap(ref);
        break;
    }
  }

  Future<void> _handleHabitTap(WidgetRef ref) async {
    if (linkedObjectSlug == null) return;

    final habits = ref.read(habitsProvider);
    final habit = habits.where((h) => h.slug == linkedObjectSlug).firstOrNull;
    if (habit == null) return;

    final isDone = computeChecklistItemDone(
      kind: kind,
      linkedObjectSlug: linkedObjectSlug,
      trackerFieldId: trackerFieldId,
      date: date,
      ref: ref,
      parentObjectId: parentObjectId,
      itemId: itemId,
    );

    VaultLinkRef? pickedRef;
    if (attachedCollectionSlug != null) {
      pickedRef = await CollectionItemPickerSheet.show(
        ref.context,
        collectionNoteSlug: attachedCollectionSlug!,
      );
      // If user cancelled the picker, don't proceed
      if (pickedRef == null) return;
    }

    await ref.read(habitsProvider.notifier).toggleHabit(habit, date);

    if (pickedRef != null) {
      await ref.read(habitsProvider.notifier).setHabitCompletionRef(
        habit,
        date,
        pickedRef,
      );
    }
  }

  Future<void> _handleTaskTap(WidgetRef ref) async {
    if (linkedObjectSlug == null) {
      // Create new one-off task
      final task = Task(
        title: title,
        stage: TaskStage.finalized,
        linkedSystem: parentObjectId,
      );
      await ref.read(tasksProvider.notifier).addTask(task);
      // Notify caller to persist the new task's slug
      onTaskCreated?.call(task.slug);
      return;
    }

    final tasks = ref.read(tasksProvider);
    final task = tasks.where((t) => t.slug == linkedObjectSlug).firstOrNull;
    if (task == null) return;

    final isDone = task.stage == TaskStage.finalized;
    final updated = task.copyWith(
      stage: isDone ? TaskStage.todo : TaskStage.finalized,
    );
    await ref.read(tasksProvider.notifier).updateTask(updated);
  }

  Future<void> _handleTrackerTap(WidgetRef ref) async {
    if (linkedObjectSlug == null || trackerFieldId == null) return;

    final trackers = ref.read(trackersProvider);
    final tracker = trackers.where((t) => t.slug == linkedObjectSlug).firstOrNull;
    if (tracker == null) return;

    // Find the field definition
    InputField? field;
    for (final section in tracker.sections) {
      field = section.inputFields.where((f) => f.id == trackerFieldId).firstOrNull;
      if (field != null) break;
    }
    if (field == null) return;

    dynamic value;
    VaultLinkRef? pickedRef;

    if (attachedCollectionSlug != null) {
      pickedRef = await CollectionItemPickerSheet.show(
        ref.context,
        collectionNoteSlug: attachedCollectionSlug!,
      );
      if (pickedRef != null) {
        value = pickedRef.displayTitle;
      }
    } else {
      // Show inline input based on field type
      value = await _showInlineInput(ref, field);
    }

    if (value == null) return;

    if (trackerFieldId == null) return;
    final fieldPatch = <String, dynamic>{trackerFieldId!: value};
    if (pickedRef != null) {
      fieldPatch['${trackerFieldId!}_ref'] = pickedRef.toMap();
    }

    await ref.read(trackingRecordsProvider.notifier).upsertRecordForDate(
      linkedObjectSlug!,
      date,
      fieldPatch,
    );
  }

  Future<dynamic> _showInlineInput(WidgetRef ref, InputField field) async {
    switch (field.type) {
      case InputFieldType.quantity:
        return await _showQuantityPicker(ref, field);
      case InputFieldType.selection:
      case InputFieldType.checklist:
        return await _showSelectionPicker(ref, field);
      case InputFieldType.checkbox:
        return true;
      case InputFieldType.duration:
        return await _showDurationPicker(ref, field);
      default:
        return await _showTextInput(ref, field);
    }
  }

  Future<String?> _showTextInput(WidgetRef ref, InputField field) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: ref.context,
      builder: (context) => AlertDialog(
        title: Text(field.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter value'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<int?> _showQuantityPicker(WidgetRef ref, InputField field) async {
    int value = (field.defaultValue as num?)?.toInt() ?? 0;
    return showDialog<int>(
      context: ref.context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(field.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(() => value--),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$value ${field.unit ?? ''}'),
                  IconButton(
                    onPressed: () => setState(() => value++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, value),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showSelectionPicker(WidgetRef ref, InputField field) async {
    List<String> options = field.options ?? [];
    
    // Resolve options from collection if optionsSourceCollectionSlug is set
    if (field.optionsSourceCollectionSlug != null) {
      options = _getCollectionOptions(ref, field.optionsSourceCollectionSlug!);
    }
    
    if (options.isEmpty) return null;

    return showDialog<String>(
      context: ref.context,
      builder: (context) => AlertDialog(
        title: Text(field.title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(options[index]),
              onTap: () => Navigator.pop(context, options[index]),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getCollectionOptions(WidgetRef ref, String collectionSlug) {
    final notes = ref.read(notesProvider);
    final collection = notes.where((n) => n.slug == collectionSlug).firstOrNull;
    if (collection == null || collection.subtype != NoteSubtype.collection) {
      return [];
    }

    try {
      final data = jsonDecode(collection.body);
      final schemaData = data is Map ? data['schema'] : null;
      final itemData = data is Map ? data['items'] : null;
      
      if (schemaData is! List || itemData is! List) return [];

      final schema = schemaData
          .whereType<Map>()
          .map((e) => InputField.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      final options = <String>[];
      for (final item in itemData) {
        if (item is Map) {
          // Find first text-type property value by iterating schema
          for (final prop in schema) {
            if (prop.type != InputFieldType.text && prop.type != InputFieldType.selection) {
              continue;
            }
            final value = item[prop.id];
            if (value != null && value.toString().trim().isNotEmpty) {
              options.add(value.toString().trim());
              break;
            }
          }
        }
      }
      return options;
    } catch (e) {
      debugPrint('Error parsing Collection options: $e');
      return [];
    }
  }

  Future<int?> _showDurationPicker(WidgetRef ref, InputField field) async {
    int minutes = 25;
    return showDialog<int>(
      context: ref.context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(field.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(() => minutes = (minutes - 5).clamp(5, 120)),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$minutes min'),
                  IconButton(
                    onPressed: () => setState(() => minutes = (minutes + 5).clamp(5, 120)),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, minutes),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePomodoroTap(WidgetRef ref) async {
    final pomodoroState = ref.read(pomodoroProvider);
    final expectedSlug = 'checklist:$parentObjectId:$itemId';
    final existingSession = pomodoroState.history.where(
      (s) => s.linkedItemSlug == expectedSlug && s.state == PomodoroSessionState.completed,
    ).firstOrNull;

    if (existingSession != null) {
      // Navigate to Pomodoro screen to show session details
      GoRouter.of(ref.context).push('/pomodoro?sessionId=${existingSession.id}');
      return;
    }

    // Show action sheet
    final choice = await showDialog<String>(
      context: ref.context,
      builder: (context) => AlertDialog(
        title: const Text('Pomodoro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start Pomodoro now'),
              onTap: () => Navigator.pop(context, 'start'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Log a completed block'),
              onTap: () => Navigator.pop(context, 'log'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'start') {
      // Navigate to Pomodoro screen with linkedItemSlug preset
      GoRouter.of(ref.context).push('/pomodoro?linkedItemSlug=$expectedSlug');
    } else if (choice == 'log') {
      int duration = 25;
      await ref.read(pomodoroProvider.notifier).logRetroactiveSession(
        occurredAt: date,
        blocksCompleted: 1,
        minutesWorked: duration,
        linkedItemId: expectedSlug,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch providers to ensure reactive updates
    final habits = kind == 'habit' ? ref.watch(habitsProvider) : null;
    final tasks = kind == 'task' ? ref.watch(tasksProvider) : null;
    final trackingRecords = kind == 'tracker_entry' ? ref.watch(trackingRecordsProvider) : null;
    final pomodoroState = kind == 'pomodoro' ? ref.watch(pomodoroProvider) : null;
    
    final isDone = _isDone(ref, habits, tasks, trackingRecords, pomodoroState);
    final icon = _getKindIcon();

    return Semantics(
      label: "Mark '$title' as done",
      button: true,
      child: ListTile(
        leading: Icon(icon, size: 20),
        title: Text(title),
        trailing: Checkbox(
          value: isDone,
          onChanged: (_) => _handleTap(ref),
        ),
        onTap: () => _handleTap(ref),
      ),
    );
  }
}
