// lib/services/vibration_service.dart
//
// Provides continuous/periodic vibration for alarm and popup screens.
// Uses HapticFeedback for cross-platform compat + a Method Channel for
// full Android vibrator access (bypasses DND/silent mode).
// The notification channel itself already handles the initial vibration;
// this service keeps the device vibrating while the screen is visible.

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class VibrationService {
  VibrationService._();

  static const _channel = MethodChannel('com.productivity.Quartzo/vibration');

  static Timer? _timer;
  static bool _running = false;

  /// Pattern durations map for label → repeat interval ms.
  static const Map<String, int> _intervalMs = {
    'gentle':  1800,
    'normal':  1400,
    'strong':  1200,
    'pulsing': 1000,
    'urgent':   800,
  };

  /// Start continuous vibration using [pattern] (e.g. 'strong').
  /// Vibrates [maxRepeats] times then stops automatically.
  /// Call [stop] to cancel early (e.g. on dismiss/done/dispose).
  static void start(String pattern, {int maxRepeats = 20}) {
    if (_running) stop();
    _running = true;

    final intervalMs = _intervalMs[pattern] ?? 1400;
    int count = 0;

    // Fire immediately
    _vibrate(pattern);

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      count++;
      if (!_running || count >= maxRepeats) {
        stop();
        return;
      }
      _vibrate(pattern);
    });
  }

  /// Stop the continuous vibration loop.
  static void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _cancelNativeVibration();
  }

  // ── Internal ──────────────────────────────────────────────────────────

  static void _vibrate(String pattern) {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      switch (pattern) {
        case 'gentle':
          HapticFeedback.lightImpact();
          break;
        case 'normal':
          HapticFeedback.mediumImpact();
          break;
        case 'strong':
        case 'urgent':
          HapticFeedback.heavyImpact();
          break;
        case 'pulsing':
          HapticFeedback.selectionClick();
          break;
        default:
          HapticFeedback.mediumImpact();
      }
    } catch (_) {}

    // On Android, additionally trigger the native vibrator with the pattern
    // (bypasses silent/DND because the alarm channel already has bypass).
    if (Platform.isAndroid) {
      _triggerNativeVibration(pattern);
    }
  }

  static void _triggerNativeVibration(String pattern) {
    try {
      _channel.invokeMethod('vibrate', {'pattern': pattern});
    } catch (_) {}
  }

  static void _cancelNativeVibration() {
    if (!Platform.isAndroid) return;
    try {
      _channel.invokeMethod('cancelVibration');
    } catch (_) {}
  }
}
