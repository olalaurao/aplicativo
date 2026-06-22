// lib/services/biometric_service.dart
import 'dart:io';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  final LocalAuthentication auth = LocalAuthentication();

  /// Returns false on desktop platforms (Windows/Linux/macOS)
  /// where local_auth is not supported.
  static bool get _isSupported =>
      Platform.isAndroid || Platform.isIOS;

  Future<bool> isBiometricAvailable() async {
    if (!_isSupported) return false;
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (!_isSupported) return false;
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Autentique-se para acessar o Citrine',
        biometricOnly: false,
      );
      return didAuthenticate;
    } on Exception catch (e) {
      debugPrint('Biometric Error: $e');
      return false;
    }
  }
}
