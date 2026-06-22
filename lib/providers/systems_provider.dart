import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/system_model.dart';
import '../models/task_model.dart';
import 'vault_provider.dart';

class SystemsNotifier extends Notifier<List<SystemDefinition>> {
  @override
  List<SystemDefinition> build() {
    final systems = ref.watch(objectsByTypeProvider('system')).cast<SystemDefinition>();
    final allTasks = ref.watch(tasksProvider);
    for (final system in systems) {
      _deriveSystemStats(system, allTasks);
    }
    return systems;
  }

  void _deriveSystemStats(SystemDefinition system, List<Task> allTasks) {
    final linked = allTasks.where(
      (t) => t.linkedSystem == system.id && t.stage == TaskStage.finalized,
    ).toList();
    system.runCount = linked.length;
    system.lastRun = linked.isEmpty
        ? null
        : linked
            .map((t) => t.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
    if (linked.isNotEmpty) {
      final totalMin = linked
          .where((t) => t.estimatedMinutes != null && t.estimatedMinutes! > 0)
          .map((t) => t.estimatedMinutes!)
          .fold(0, (a, b) => a + b);
      system.averageMinutes = totalMin ~/ linked.length;
    } else {
      system.averageMinutes = 0;
    }
  }

  Future<void> addSystem(SystemDefinition system) async {
    state = [...state, system];
    await ref.read(vaultProvider.notifier).createObject(system);
  }

  Future<void> updateSystem(SystemDefinition system) async {
    state = [
      for (final s in state)
        if (s.id == system.id) system else s,
    ];

    await ref.read(vaultProvider.notifier).updateObject(system);
  }

  Future<void> deleteSystem(SystemDefinition system) async {
    state = state.where((s) => s.id != system.id).toList();
    await ref.read(vaultProvider.notifier).deleteObject(system);
  }
}

final systemsProvider = NotifierProvider<SystemsNotifier, List<SystemDefinition>>(() {
  return SystemsNotifier();
});

/// Top 3 systems by run_count — used by Command Center for quick-run chips.
final topSystemsProvider = Provider<List<SystemDefinition>>((ref) {
  final all = ref.watch(systemsProvider);
  final sorted = [...all]..sort((a, b) => b.runCount.compareTo(a.runCount));
  return sorted.take(3).toList();
});

