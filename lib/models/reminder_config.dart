import 'package:flutter/material.dart';

enum NotificationType { push, popup, alarm }

class ReminderConfig {
  final String id;
  DateTime? triggerTime;
  int? minutesBefore;
  int? daysBefore;
  String? timeOfDay;
  NotificationType type;
  String? notificationBody;
  String? sound;
  bool ringOnSilent;
  int snoozeMinutes;
  Color? popupColor;
  bool playSound;
  bool vibrate;

  ReminderConfig({
    required this.id,
    this.triggerTime,
    this.minutesBefore,
    this.daysBefore,
    this.timeOfDay,
    this.type = NotificationType.push,
    this.notificationBody,
    this.sound,
    this.ringOnSilent = true,
    this.snoozeMinutes = 10,
    this.popupColor,
    this.playSound = true,
    this.vibrate = true,
  });

  ReminderConfig copyWith({
    String? id,
    DateTime? triggerTime,
    bool clearTriggerTime = false,
    int? minutesBefore,
    bool clearMinutesBefore = false,
    int? daysBefore,
    bool clearDaysBefore = false,
    String? timeOfDay,
    bool clearTimeOfDay = false,
    NotificationType? type,
    String? notificationBody,
    bool clearNotificationBody = false,
    String? sound,
    bool clearSound = false,
    bool? ringOnSilent,
    int? snoozeMinutes,
    Color? popupColor,
    bool clearPopupColor = false,
    bool? playSound,
    bool? vibrate,
  }) {
    return ReminderConfig(
      id: id ?? this.id,
      triggerTime: clearTriggerTime ? null : (triggerTime ?? this.triggerTime),
      minutesBefore: clearMinutesBefore
          ? null
          : (minutesBefore ?? this.minutesBefore),
      daysBefore: clearDaysBefore ? null : (daysBefore ?? this.daysBefore),
      timeOfDay: clearTimeOfDay ? null : (timeOfDay ?? this.timeOfDay),
      type: type ?? this.type,
      notificationBody: clearNotificationBody
          ? null
          : (notificationBody ?? this.notificationBody),
      sound: clearSound ? null : (sound ?? this.sound),
      ringOnSilent: ringOnSilent ?? this.ringOnSilent,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      popupColor: clearPopupColor ? null : (popupColor ?? this.popupColor),
      playSound: playSound ?? this.playSound,
      vibrate: vibrate ?? this.vibrate,
    );
  }

  DateTime calculateTriggerTime(DateTime base) {
    if (triggerTime != null) return triggerTime!;
    if (daysBefore != null || timeOfDay != null) {
      final days = daysBefore ?? 0;
      final parts = (timeOfDay ?? '09:00').split(':');
      final hour = parts.length > 1 ? (int.tryParse(parts[0]) ?? 9) : 9;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final date = base.subtract(Duration(days: days));
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    if (minutesBefore != null) {
      return base.subtract(Duration(minutes: minutesBefore!));
    }
    return base;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trigger_time': triggerTime?.toIso8601String(),
      'minutes_before': minutesBefore,
      'days_before': daysBefore,
      'time_of_day': timeOfDay,
      'type': type.name,
      'notification_body': notificationBody,
      'sound': sound,
      'ring_on_silent': ringOnSilent,
      'snooze_minutes': snoozeMinutes,
      'popup_color': popupColor?.toARGB32().toRadixString(16),
      'play_sound': playSound,
      'vibrate': vibrate,
    };
  }

  factory ReminderConfig.fromMap(Map<String, dynamic> map) {
    Color? parsePopupColor(dynamic value) {
      if (value == null) return null;
      if (value is int) return Color(value);

      final raw = value.toString().trim();
      if (raw.isEmpty) return null;

      final normalized = raw.startsWith('#')
          ? 'ff${raw.substring(1)}'
          : (raw.startsWith('0x') || raw.startsWith('0X'))
          ? raw.substring(2)
          : raw;
      final parsed = int.tryParse(normalized, radix: 16);
      return parsed == null ? null : Color(parsed);
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    return ReminderConfig(
      id:
          map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      triggerTime: map['trigger_time'] != null
          ? DateTime.tryParse(map['trigger_time'] as String)
          : null,
      minutesBefore: parseInt(map['minutes_before']),
      daysBefore: parseInt(map['days_before']),
      timeOfDay: map['time_of_day'] as String?,
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.push,
      ),
      notificationBody: map['notification_body']?.toString(),
      sound: map['sound']?.toString(),
      ringOnSilent: map['ring_on_silent'] ?? true,
      snoozeMinutes: parseInt(map['snooze_minutes']) ?? 10,
      popupColor: parsePopupColor(map['popup_color']),
      playSound: map['play_sound'] as bool? ?? true,
      vibrate: map['vibrate'] as bool? ?? true,
    );
  }
}
