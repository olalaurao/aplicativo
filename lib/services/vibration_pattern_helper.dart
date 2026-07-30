// lib/services/vibration_pattern_helper.dart
import 'dart:typed_data';
import '../models/reminder_config.dart';

/// Centralized vibration pattern management for notifications.
/// Provides preset patterns and helper methods for pattern selection.
class VibrationPatternHelper {
  VibrationPatternHelper._();

  /// Preset vibration patterns with user-friendly labels
  static final Map<String, Int64List> _patterns = {
    'gentle': Int64List.fromList(<int>[0, 150, 100, 150]),
    'normal': Int64List.fromList(<int>[0, 250, 150, 250]),
    'strong': Int64List.fromList(<int>[0, 500, 200, 500]),
    'pulsing': Int64List.fromList(<int>[0, 200, 100, 200, 100, 200]),
    'urgent': Int64List.fromList(<int>[0, 100, 50, 100, 50, 100, 50, 300]),
  };

  /// User-friendly labels for vibration patterns
  static const Map<String, String> _labels = {
    'gentle': 'Gentle',
    'normal': 'Normal',
    'strong': 'Strong',
    'pulsing': 'Pulsing',
    'urgent': 'Urgent',
  };

  /// Default patterns per notification type
  static const Map<NotificationType, String> _defaults = {
    NotificationType.alarm: 'strong',
    NotificationType.popup: 'normal',
    NotificationType.push: 'normal',
  };

  /// Get vibration pattern Int64List for a pattern name
  static Int64List getPattern(String patternName) {
    return _patterns[patternName] ?? _patterns['normal']!;
  }

  /// Get all available patterns
  static Map<String, Int64List> getAllPatterns() {
    return Map.from(_patterns);
  }

  /// Get all available pattern names
  static List<String> getAllPatternNames() {
    return _patterns.keys.toList();
  }

  /// Get user-friendly label for a pattern name
  static String getPatternLabel(String patternName) {
    return _labels[patternName] ?? 'Normal';
  }

  /// Get default pattern for a notification type
  static String getDefaultPattern(NotificationType type) {
    return _defaults[type] ?? 'normal';
  }

  /// Get all pattern labels for dropdown display
  static Map<String, String> getAllPatternLabels() {
    return Map.from(_labels);
  }

  /// Validate if a pattern name is valid
  static bool isValidPattern(String patternName) {
    return _patterns.containsKey(patternName);
  }
}
