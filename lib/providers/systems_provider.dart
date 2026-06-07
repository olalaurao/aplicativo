import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/system_model.dart';
import 'vault_provider.dart';

class SystemsNotifier extends Notifier<List<SystemDefinition>> {
  @override
  List<SystemDefinition> build() {
    return ref.watch(objectsByTypeProvider('system')).cast<SystemDefinition>();
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
