// lib/models/day_dial_model.dart
/// Models for the circular day dial widget

/// The kind of activity filling an hour on the dial
enum DialHourKind {
  idle,
  sleep,
  pomodoroCompleted,
  pomodoroPlanned,
  event,
}

/// Represents the state of a single hour (0-23) on the day dial
class DayDialHourState {
  final int hour; // 0-23
  final DialHourKind kind;
  final double fillFraction; // 0.0-1.0, how much of this hour is covered
  final String? habitIconName; // set only if a habit is scheduled at this hour
  final String? habitId;

  DayDialHourState({
    required this.hour,
    required this.kind,
    required this.fillFraction,
    this.habitIconName,
    this.habitId,
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
  }) {
    return DayDialHourState(
      hour: hour ?? this.hour,
      kind: kind ?? this.kind,
      fillFraction: fillFraction ?? this.fillFraction,
      habitIconName: habitIconName ?? this.habitIconName,
      habitId: habitId ?? this.habitId,
    );
  }

  Map<String, dynamic> toMap() => {
    'hour': hour,
    'kind': kind.name,
    'fillFraction': fillFraction,
    if (habitIconName != null) 'habitIconName': habitIconName,
    if (habitId != null) 'habitId': habitId,
  };

  factory DayDialHourState.fromMap(Map<String, dynamic> map) {
    return DayDialHourState(
      hour: map['hour'] as int,
      kind: DialHourKind.values.firstWhere(
        (e) => e.name == map['kind'],
        orElse: () => DialHourKind.idle,
      ),
      fillFraction: (map['fillFraction'] as num).toDouble(),
      habitIconName: map['habitIconName'] as String?,
      habitId: map['habitId'] as String?,
    );
  }
}
