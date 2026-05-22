import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncStatus { synced, syncing, offline, error, conflict }

class SyncConflict {
  final String relativePath;
  final String localPath;
  final String remotePath;
  final DateTime detectedAt;

  const SyncConflict({
    required this.relativePath,
    required this.localPath,
    required this.remotePath,
    required this.detectedAt,
  });
}

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    // Initial state
    return SyncStatus.synced;
  }

  void setStatus(SyncStatus status) {
    state = status;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(() {
  return SyncStatusNotifier();
});

class SyncConflictNotifier extends Notifier<List<SyncConflict>> {
  @override
  List<SyncConflict> build() {
    return const [];
  }

  void addConflict(SyncConflict conflict) {
    state = [
      conflict,
      ...state.where((item) => item.relativePath != conflict.relativePath),
    ];
  }

  void clear() {
    state = const [];
  }

  void removeConflict(String relativePath) {
    state = [
      for (final item in state)
        if (item.relativePath != relativePath) item,
    ];
  }
}

final syncConflictsProvider =
    NotifierProvider<SyncConflictNotifier, List<SyncConflict>>(() {
      return SyncConflictNotifier();
    });
