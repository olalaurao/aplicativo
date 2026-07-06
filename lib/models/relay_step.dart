// lib/models/relay_step.dart
import 'package:uuid/uuid.dart';

/// A single step in a Focus Relay (chained timer sequence)
class RelayStep {
  final String id;
  final String label; // e.g. "Research", "Draft", "Review"
  final int durationMinutes;
  final bool isBreak; // lets a step be a deliberate rest without being a full long-break cycle

  RelayStep({
    String? id,
    required this.label,
    required this.durationMinutes,
    this.isBreak = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'duration_minutes': durationMinutes,
      'is_break': isBreak,
    };
  }

  factory RelayStep.fromMap(Map<String, dynamic> map) {
    return RelayStep(
      id: map['id']?.toString() ?? const Uuid().v4(),
      label: map['label']?.toString() ?? 'Step',
      durationMinutes: map['duration_minutes'] is int
          ? map['duration_minutes'] as int
          : int.tryParse(map['duration_minutes']?.toString() ?? '') ?? 25,
      isBreak: map['is_break'] == true,
    );
  }

  RelayStep copyWith({
    String? id,
    String? label,
    int? durationMinutes,
    bool? isBreak,
  }) {
    return RelayStep(
      id: id ?? this.id,
      label: label ?? this.label,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isBreak: isBreak ?? this.isBreak,
    );
  }
}
