// lib/models/day_dial_model.dart
/// Models for the circular day dial widget
library;

import 'package:flutter/material.dart';

/// The kind of activity filling an hour on the dial
enum DialHourKind {
  idle,
  sleep,
  pomodoroCompleted,
  pomodoroPlanned,
  event,
  timeBlock,
}

/// The type of activity for the enhanced dial
enum DialActivityType {
  habit,
  mood,
  pomodoroCompleted,
  pomodoroPlanned,
  event,
  timeBlock,
  reminder,
  task,
}

/// Represents a single activity that can be displayed on the dial
class DialActivity {
  final String id;
  final DialActivityType type;
  final String title;
  final String? emoji; // For habits, moods
  final Color color;
  final DateTime startTime;
  final DateTime endTime;
  final double fillFraction; // 0.0-1.0
  final int zIndex; // For overlapping rendering order

  DialActivity({
    required this.id,
    required this.type,
    required this.title,
    this.emoji,
    required this.color,
    required this.startTime,
    required this.endTime,
    required this.fillFraction,
    this.zIndex = 0,
  });

  DialActivity copyWith({
    String? id,
    DialActivityType? type,
    String? title,
    String? emoji,
    Color? color,
    DateTime? startTime,
    DateTime? endTime,
    double? fillFraction,
    int? zIndex,
  }) {
    return DialActivity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      fillFraction: fillFraction ?? this.fillFraction,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    if (emoji != null) 'emoji': emoji,
    'color': color.toARGB32(),
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'fillFraction': fillFraction,
    'zIndex': zIndex,
  };

  factory DialActivity.fromMap(Map<String, dynamic> map) {
    return DialActivity(
      id: map['id'] as String,
      type: DialActivityType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DialActivityType.task,
      ),
      title: map['title'] as String,
      emoji: map['emoji'] as String?,
      color: Color(map['color'] as int).withAlpha(255),
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      fillFraction: (map['fillFraction'] as num).toDouble(),
      zIndex: map['zIndex'] as int? ?? 0,
    );
  }
}

/// Represents the state of a single hour (0-23) on the day dial
class DayDialHourState {
  final int hour; // 0-23
  final DialHourKind kind;
  final double fillFraction; // 0.0-1.0, how much of this hour is covered
  final String? habitIconName; // set only if a habit is scheduled at this hour
  final String? habitId;
  final String? reminderIconName; // set only if a reminder is scheduled at this hour
  final String? reminderId;
  final List<DialActivity> activities; // Multiple activities per hour (enhanced model)

  DayDialHourState({
    required this.hour,
    required this.kind,
    required this.fillFraction,
    this.habitIconName,
    this.habitId,
    this.reminderIconName,
    this.reminderId,
    this.activities = const [],
  });

  /// Create a default idle state for an hour
  factory DayDialHourState.idle(int hour) {
    return DayDialHourState(
      hour: hour,
      kind: DialHourKind.idle,
      fillFraction: 0.0,
    );
  }

  DayDialHourState copyWith({
    int? hour,
    DialHourKind? kind,
    double? fillFraction,
    String? habitIconName,
    String? habitId,
    String? reminderIconName,
    String? reminderId,
    List<DialActivity>? activities,
  }) {
    return DayDialHourState(
      hour: hour ?? this.hour,
      kind: kind ?? this.kind,
      fillFraction: fillFraction ?? this.fillFraction,
      habitIconName: habitIconName ?? this.habitIconName,
      habitId: habitId ?? this.habitId,
      reminderIconName: reminderIconName ?? this.reminderIconName,
      reminderId: reminderId ?? this.reminderId,
      activities: activities ?? this.activities,
    );
  }

  /// Add an activity to this hour's state
  DayDialHourState addActivity(DialActivity activity) {
    return copyWith(activities: [...activities, activity]);
  }

  /// Get activities by type
  List<DialActivity> getActivitiesByType(DialActivityType type) {
    return activities.where((a) => a.type == type).toList();
  }

  /// Get overlapping activities (activities that overlap in time)
  List<DialActivity> getOverlappingActivities() {
    if (activities.length < 2) return [];
    
    final overlapping = <DialActivity>[];
    for (int i = 0; i < activities.length; i++) {
      for (int j = i + 1; j < activities.length; j++) {
        final a = activities[i];
        final b = activities[j];
        if (a.startTime.isBefore(b.endTime) && a.endTime.isAfter(b.startTime)) {
          if (!overlapping.contains(a)) overlapping.add(a);
          if (!overlapping.contains(b)) overlapping.add(b);
        }
      }
    }
    return overlapping;
  }

  /// Get visible activities based on zIndex and space
  List<DialActivity> getVisibleActivities() {
    return activities..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  Map<String, dynamic> toMap() => {
    'hour': hour,
    'kind': kind.name,
    'fillFraction': fillFraction,
    if (habitIconName != null) 'habitIconName': habitIconName,
    if (habitId != null) 'habitId': habitId,
    if (reminderIconName != null) 'reminderIconName': reminderIconName,
    if (reminderId != null) 'reminderId': reminderId,
    'activities': activities.map((a) => a.toMap()).toList(),
  };

  factory DayDialHourState.fromMap(Map<String, dynamic> map) {
    final activitiesList = map['activities'] as List?;
    final activities = activitiesList != null
        ? activitiesList
            .map((e) => DialActivity.fromMap(e as Map<String, dynamic>))
            .toList()
        : <DialActivity>[];
    
    return DayDialHourState(
      hour: map['hour'] as int,
      kind: DialHourKind.values.firstWhere(
        (e) => e.name == map['kind'],
        orElse: () => DialHourKind.idle,
      ),
      fillFraction: (map['fillFraction'] as num).toDouble(),
      habitIconName: map['habitIconName'] as String?,
      habitId: map['habitId'] as String?,
      reminderIconName: map['reminderIconName'] as String?,
      reminderId: map['reminderId'] as String?,
      activities: activities,
    );
  }
}
