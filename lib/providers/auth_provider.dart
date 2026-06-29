// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lockProvider = StateNotifierProvider<LockNotifier, bool>((ref) {
  return LockNotifier(ref);
});

class LockNotifier extends StateNotifier<bool> {
  LockNotifier(Ref ref) : super(false);

  Future<void> unlock() async {}

  void lock() {}
}
