// test/vibration_pattern_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quartzo/providers/settings_provider.dart';
import 'package:quartzo/services/vibration_pattern_helper.dart';

void main() {
  group('VibrationPatternHelper', () {
    test('getPattern returns correct Int64List for valid pattern name', () {
      final pattern = VibrationPatternHelper.getPattern('gentle');
      expect(pattern, isNotNull);
      expect(pattern.length, 4);
      expect(pattern[0], 0);
      expect(pattern[1], 150);
    });

    test('getPattern returns normal pattern for invalid name', () {
      final pattern = VibrationPatternHelper.getPattern('invalid');
      expect(pattern, isNotNull);
      expect(pattern.length, 4);
      expect(pattern[0], 0);
      expect(pattern[1], 250);
    });

    test('getAllPatterns returns all preset patterns', () {
      final patterns = VibrationPatternHelper.getAllPatterns();
      expect(patterns.length, 5);
      expect(patterns.containsKey('gentle'), true);
      expect(patterns.containsKey('normal'), true);
      expect(patterns.containsKey('strong'), true);
      expect(patterns.containsKey('pulsing'), true);
      expect(patterns.containsKey('urgent'), true);
    });

    test('getPatternLabel returns user-friendly label', () {
      expect(VibrationPatternHelper.getPatternLabel('gentle'), 'Gentle');
      expect(VibrationPatternHelper.getPatternLabel('normal'), 'Normal');
      expect(VibrationPatternHelper.getPatternLabel('strong'), 'Strong');
      expect(VibrationPatternHelper.getPatternLabel('invalid'), 'Normal');
    });

    test('isValidPattern validates pattern names correctly', () {
      expect(VibrationPatternHelper.isValidPattern('gentle'), true);
      expect(VibrationPatternHelper.isValidPattern('normal'), true);
      expect(VibrationPatternHelper.isValidPattern('invalid'), false);
    });
  });

  group('VibrationPattern Settings Persistence', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('vibration pattern settings persist correctly', () async {
      final notifier = SettingsNotifier(prefs);
      
      await notifier.updateVibrationPattern(type: 'alarm', pattern: 'strong');
      expect(notifier.state.alarmVibrationPattern, 'strong');
      
      await notifier.updateVibrationPattern(type: 'popup', pattern: 'gentle');
      expect(notifier.state.popupVibrationPattern, 'gentle');
      
      await notifier.updateVibrationPattern(type: 'reminder', pattern: 'pulsing');
      expect(notifier.state.reminderVibrationPattern, 'pulsing');
    });

    test('vibration pattern settings load from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'alarmVibrationPattern': 'urgent',
        'popupVibrationPattern': 'strong',
        'reminderVibrationPattern': 'gentle',
      });
      prefs = await SharedPreferences.getInstance();
      
      final notifier = SettingsNotifier(prefs);
      expect(notifier.state.alarmVibrationPattern, 'urgent');
      expect(notifier.state.popupVibrationPattern, 'strong');
      expect(notifier.state.reminderVibrationPattern, 'gentle');
    });

    test('vibration pattern settings have correct defaults', () async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      
      final notifier = SettingsNotifier(prefs);
      expect(notifier.state.alarmVibrationPattern, 'normal');
      expect(notifier.state.popupVibrationPattern, 'normal');
      expect(notifier.state.reminderVibrationPattern, 'normal');
    });
  });

  group('Sound Settings Persistence', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('sound enabled settings persist correctly', () async {
      final notifier = SettingsNotifier(prefs);
      
      await notifier.updateSoundEnabled(type: 'alarm', enabled: false);
      expect(notifier.state.alarmSoundEnabled, false);
      
      await notifier.updateSoundEnabled(type: 'popup', enabled: false);
      expect(notifier.state.popupSoundEnabled, false);
      
      await notifier.updateSoundEnabled(type: 'reminder', enabled: false);
      expect(notifier.state.reminderSoundEnabled, false);
    });

    test('sound enabled settings load from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'alarmSoundEnabled': false,
        'popupSoundEnabled': true,
        'reminderSoundEnabled': false,
      });
      prefs = await SharedPreferences.getInstance();
      
      final notifier = SettingsNotifier(prefs);
      expect(notifier.state.alarmSoundEnabled, false);
      expect(notifier.state.popupSoundEnabled, true);
      expect(notifier.state.reminderSoundEnabled, false);
    });

    test('sound enabled settings have correct defaults', () async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      
      final notifier = SettingsNotifier(prefs);
      expect(notifier.state.alarmSoundEnabled, true);
      expect(notifier.state.popupSoundEnabled, true);
      expect(notifier.state.reminderSoundEnabled, true);
    });
  });

  group('Settings copyWith', () {
    test('copyWith updates vibration pattern fields', () {
      final settings = AppSettings(
        vaultName: 'Test',
        alarmVibrationPattern: 'normal',
        popupVibrationPattern: 'normal',
        reminderVibrationPattern: 'normal',
      );
      
      final updated = settings.copyWith(
        alarmVibrationPattern: 'strong',
        popupVibrationPattern: 'gentle',
      );
      
      expect(updated.alarmVibrationPattern, 'strong');
      expect(updated.popupVibrationPattern, 'gentle');
      expect(updated.reminderVibrationPattern, 'normal');
    });

    test('copyWith updates sound enabled fields', () {
      final settings = AppSettings(
        vaultName: 'Test',
        alarmSoundEnabled: true,
        popupSoundEnabled: true,
        reminderSoundEnabled: true,
      );
      
      final updated = settings.copyWith(
        alarmSoundEnabled: false,
        popupSoundEnabled: false,
      );
      
      expect(updated.alarmSoundEnabled, false);
      expect(updated.popupSoundEnabled, false);
      expect(updated.reminderSoundEnabled, true);
    });
  });
}
