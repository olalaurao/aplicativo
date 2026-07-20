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

class SyncProgress {
  final int current;
  final int total;
  final String message;

  const SyncProgress({
    required this.current,
    required this.total,
    required this.message,
  });

  double get percentage => total > 0 ? current / total : 0.0;

  SyncProgress copyWith({
    int? current,
    int? total,
    String? message,
  }) {
    return SyncProgress(
      current: current ?? this.current,
      total: total ?? this.total,
      message: message ?? this.message,
    );
  }
}

class SyncProgressNotifier extends Notifier<SyncProgress> {
  @override
  SyncProgress build() {
    return const SyncProgress(
      current: 0,
      total: 0,
      message: '',
    );
  }

  void start(int total, String message) {
    state = SyncProgress(
      current: 0,
      total: total,
      message: message,
    );
  }

  void update(int current, {String? message}) {
    state = state.copyWith(
      current: current,
      message: message ?? state.message,
    );
  }

  void reset() {
    state = const SyncProgress(
      current: 0,
      total: 0,
      message: '',
    );
  }
}

final syncProgressProvider =
    NotifierProvider<SyncProgressNotifier, SyncProgress>(() {
      return SyncProgressNotifier();
    });
