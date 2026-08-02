// lib/providers/merge_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/merge_service.dart';

/// Provider for the merge service
final mergeServiceProvider = Provider<MergeService>((ref) {
  return MergeService(ref);
});

/// Async provider for merge operations state
final mergeOperationProvider = StateProvider<MergeOperationState>((ref) {
  return MergeOperationState.idle;
});

enum MergeOperationState {
  idle,
  inProgress,
  success,
  error,
}

class MergeOperationResult {
  final bool success;
  final String? errorMessage;
  final int? mergedCount;

  const MergeOperationResult({
    required this.success,
    this.errorMessage,
    this.mergedCount,
  });

  factory MergeOperationResult.success(int count) {
    return MergeOperationResult(
      success: true,
      mergedCount: count,
    );
  }

  factory MergeOperationResult.failure(String error) {
    return MergeOperationResult(
      success: false,
      errorMessage: error,
    );
  }
}