// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/biometric_service.dart';
import 'settings_provider.dart';

final lockProvider = StateNotifierProvider<LockNotifier, bool>((ref) {
  return LockNotifier(ref);
});

class LockNotifier extends StateNotifier<bool> {
  final Ref _ref;
  final BiometricService _biometricService = BiometricService();

  LockNotifier(this._ref) : super(false) {
    _init();
  }

  void _init() {
    final settings = _ref.read(settingsProvider);
    if (settings.biometricsEnabled) {
      state = true;
    }
  }

  Future<void> unlock() async {
    final success = await _biometricService.authenticate();
    if (success) {
      state = false;
    }
  }

  void lock() {
    final settings = _ref.read(settingsProvider);
    if (settings.biometricsEnabled) {
      state = true;
    }
  }
}
