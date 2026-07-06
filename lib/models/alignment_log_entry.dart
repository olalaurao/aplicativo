// lib/models/alignment_log_entry.dart
import 'package:flutter/material.dart';

enum AlignmentState { early, aligned, drifting, missed }

class AlignmentLogEntry {
  final String itemId;
  final String date; // yyyy-mm-dd
  final String plannedTime; // HH:mm
  final String actualTime; // HH:mm
  final int deltaMinutes; // actual - planned, signed
  final AlignmentState state;

  AlignmentLogEntry({
    required this.itemId,
    required this.date,
    required this.plannedTime,
    required this.actualTime,
    required this.deltaMinutes,
    required this.state,
  });

  /// Calculate alignment state based on delta and flexibility window
  static AlignmentState calculateState({
    required int deltaMinutes,
    required int flexibilityWindowMinutes,
  }) {
    final absDelta = deltaMinutes.abs();
    
    if (absDelta <= flexibilityWindowMinutes) {
      return AlignmentState.aligned;
    } else if (absDelta <= flexibilityWindowMinutes * 3) {
      return deltaMinutes > 0 ? AlignmentState.drifting : AlignmentState.early;
    } else {
      return AlignmentState.missed;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'date': date,
      'planned_time': plannedTime,
      'actual_time': actualTime,
      'delta_minutes': deltaMinutes,
      'state': state.name,
    };
  }

  factory AlignmentLogEntry.fromMap(Map<String, dynamic> map) {
    return AlignmentLogEntry(
      itemId: map['item_id']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      plannedTime: map['planned_time']?.toString() ?? '',
      actualTime: map['actual_time']?.toString() ?? '',
      deltaMinutes: map['delta_minutes'] is int
          ? map['delta_minutes'] as int
          : int.tryParse(map['delta_minutes']?.toString() ?? '') ?? 0,
      state: AlignmentState.values.firstWhere(
        (e) => e.name == map['state']?.toString(),
        orElse: () => AlignmentState.missed,
      ),
    );
  }

  /// Convert to markdown block for daily note storage
  String toDailyNoteBlock() {
    return '''
```alignment
${toMap().toString().replaceAll('{', '').replaceAll('}', '').replaceAll(', ', '\n  ')}
```
''';
  }

  /// Parse from markdown block in daily note
  static AlignmentLogEntry? fromDailyNoteBlock(String block) {
    try {
      final lines = block.split('\n');
      final map = <String, dynamic>{};
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('item_id:')) {
          map['item_id'] = trimmed.substring(8).trim();
        } else if (trimmed.startsWith('date:')) {
          map['date'] = trimmed.substring(5).trim();
        } else if (trimmed.startsWith('planned_time:')) {
          map['planned_time'] = trimmed.substring(13).trim();
        } else if (trimmed.startsWith('actual_time:')) {
          map['actual_time'] = trimmed.substring(12).trim();
        } else if (trimmed.startsWith('delta_minutes:')) {
          map['delta_minutes'] = trimmed.substring(14).trim();
        } else if (trimmed.startsWith('state:')) {
          map['state'] = trimmed.substring(6).trim();
        }
      }
      if (map.isNotEmpty) {
        return AlignmentLogEntry.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  AlignmentLogEntry copyWith({
    String? itemId,
    String? date,
    String? plannedTime,
    String? actualTime,
    int? deltaMinutes,
    AlignmentState? state,
  }) {
    return AlignmentLogEntry(
      itemId: itemId ?? this.itemId,
      date: date ?? this.date,
      plannedTime: plannedTime ?? this.plannedTime,
      actualTime: actualTime ?? this.actualTime,
      deltaMinutes: deltaMinutes ?? this.deltaMinutes,
      state: state ?? this.state,
    );
  }
}
