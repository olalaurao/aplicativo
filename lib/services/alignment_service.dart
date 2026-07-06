// lib/services/alignment_service.dart
import 'package:intl/intl.dart';
import '../models/alignment_log_entry.dart';
import '../models/task_model.dart';
import '../models/habit_model.dart';
import '../models/journal_entry.dart';

/// Service for tracking alignment (planned vs actual timing) for tasks and habits
class AlignmentService {
  /// Log an alignment entry when a task is completed
  static AlignmentLogEntry logTaskAlignment({
    required Task task,
    required DateTime actualTime,
  }) {
    if (!task.isAlignmentTrackable || task.scheduledTime == null) {
      throw ArgumentError('Task must have alignment tracking enabled and a scheduled time');
    }

    final plannedTime = task.scheduledTime!;
    final actualTimeStr = DateFormat('HH:mm').format(actualTime);
    final dateStr = DateFormat('yyyy-MM-dd').format(actualTime);
    
    // Calculate delta in minutes
    final plannedParts = plannedTime.split(':');
    final plannedDateTime = DateTime(
      actualTime.year,
      actualTime.month,
      actualTime.day,
      int.parse(plannedParts[0]),
      int.parse(plannedParts[1]),
    );
    
    final deltaMinutes = actualTime.difference(plannedDateTime).inMinutes;
    
    // Calculate alignment state
    final flexibilityWindow = task.flexibilityWindowMinutes ?? 15; // default fallback
    final state = AlignmentLogEntry.calculateState(
      deltaMinutes: deltaMinutes,
      flexibilityWindowMinutes: flexibilityWindow,
    );

    return AlignmentLogEntry(
      itemId: task.id,
      date: dateStr,
      plannedTime: plannedTime,
      actualTime: actualTimeStr,
      deltaMinutes: deltaMinutes,
      state: state,
    );
  }

  /// Log an alignment entry when a habit slot is completed
  static AlignmentLogEntry logHabitAlignment({
    required Habit habit,
    required DateTime actualTime,
    required int slotIndex,
  }) {
    if (!habit.isAlignmentTrackable || habit.slots.isEmpty) {
      throw ArgumentError('Habit must have alignment tracking enabled and slots');
    }

    final slot = habit.slots[slotIndex];
    if (slot.time == null) {
      throw ArgumentError('Habit slot must have a scheduled time');
    }

    final plannedTime = DateFormat('HH:mm').format(slot.time!);
    final actualTimeStr = DateFormat('HH:mm').format(actualTime);
    final dateStr = DateFormat('yyyy-MM-dd').format(actualTime);
    
    // Calculate delta in minutes
    final plannedDateTime = DateTime(
      actualTime.year,
      actualTime.month,
      actualTime.day,
      slot.time!.hour,
      slot.time!.minute,
    );
    
    final deltaMinutes = actualTime.difference(plannedDateTime).inMinutes;
    
    // Calculate alignment state
    final flexibilityWindow = habit.flexibilityWindowMinutes ?? 15; // default fallback
    final state = AlignmentLogEntry.calculateState(
      deltaMinutes: deltaMinutes,
      flexibilityWindowMinutes: flexibilityWindow,
    );

    return AlignmentLogEntry(
      itemId: habit.id,
      date: dateStr,
      plannedTime: plannedTime,
      actualTime: actualTimeStr,
      deltaMinutes: deltaMinutes,
      state: state,
    );
  }

  /// Add alignment entry to a journal entry (daily note)
  static JournalEntry addAlignmentToEntry(
    JournalEntry entry,
    AlignmentLogEntry alignmentLog,
  ) {
    final updatedLogs = List<AlignmentLogEntry>.from(entry.alignmentLogEntries);
    
    // Remove existing log for same item/date if exists
    updatedLogs.removeWhere((log) => 
      log.itemId == alignmentLog.itemId && log.date == alignmentLog.date
    );
    
    // Add new log
    updatedLogs.add(alignmentLog);
    
    return entry.copyWith(alignmentLogEntries: updatedLogs);
  }

  /// Get alignment entries for a specific item from a journal entry
  static List<AlignmentLogEntry> getAlignmentForItem(
    JournalEntry entry,
    String itemId,
  ) {
    return entry.alignmentLogEntries
        .where((log) => log.itemId == itemId)
        .toList();
  }

  /// Calculate alignment statistics for an item over a period
  static Map<String, dynamic> calculateAlignmentStats(
    List<AlignmentLogEntry> logs,
  ) {
    if (logs.isEmpty) {
      return {
        'total': 0,
        'aligned': 0,
        'drifting': 0,
        'early': 0,
        'missed': 0,
        'averageDelta': 0,
        'alignmentRate': 0.0,
      };
    }

    final aligned = logs.where((l) => l.state == AlignmentState.aligned).length;
    final drifting = logs.where((l) => l.state == AlignmentState.drifting).length;
    final early = logs.where((l) => l.state == AlignmentState.early).length;
    final missed = logs.where((l) => l.state == AlignmentState.missed).length;
    
    final totalDelta = logs.fold<int>(0, (sum, log) => sum + log.deltaMinutes.abs());
    final averageDelta = totalDelta / logs.length;
    
    final alignmentRate = (aligned / logs.length) * 100;

    return {
      'total': logs.length,
      'aligned': aligned,
      'drifting': drifting,
      'early': early,
      'missed': missed,
      'averageDelta': averageDelta,
      'alignmentRate': alignmentRate,
    };
  }

  /// Generate insight sentence based on alignment data
  static String generateInsightSentence(
    String itemTitle,
    Map<String, dynamic> stats,
  ) {
    final total = stats['total'] as int;
    if (total == 0) return 'No alignment data yet for $itemTitle';
    
    final alignmentRate = stats['alignmentRate'] as double;
    final averageDelta = stats['averageDelta'] as double;
    final missed = stats['missed'] as int;
    
    if (alignmentRate >= 80) {
      return '$itemTitle is well-aligned with your schedule (${alignmentRate.toStringAsFixed(0)}% on time).';
    } else if (alignmentRate >= 60) {
      return '$itemTitle is mostly on schedule (${alignmentRate.toStringAsFixed(0)}% on time), with an average drift of ${averageDelta.toStringAsFixed(0)} minutes.';
    } else if (alignmentRate >= 40) {
      return '$itemTitle is frequently off schedule (${alignmentRate.toStringAsFixed(0)}% on time), averaging ${averageDelta.toStringAsFixed(0)} minutes ${averageDelta > 0 ? "late" : "early"}.';
    } else {
      // RA-P3-1: Distress/nudge-style copy for missed alignment
      if (missed >= total * 0.7) {
        return '$itemTitle is consistently missing its schedule. Your routine might need a reset—try a different time or shorter flexibility window.';
      } else if (missed >= total * 0.5) {
        return '$itemTitle is struggling to stick to its schedule (${alignmentRate.toStringAsFixed(0)}% on time). Small adjustments to timing can make a big difference.';
      } else {
        return '$itemTitle is rarely on schedule (${alignmentRate.toStringAsFixed(0)}% on time). Consider adjusting the planned time or flexibility window.';
      }
    }
  }
  
  /// Generate nudge copy for a single missed alignment
  static String generateMissedAlignmentNudge(
    String itemTitle,
    AlignmentState state,
    int deltaMinutes,
  ) {
    switch (state) {
      case AlignmentState.missed:
        if (deltaMinutes > 60) {
          return '$itemTitle was way off schedule today. Tomorrow, try starting earlier or giving yourself more flexibility.';
        } else {
          return '$itemTitle missed its window today. Life happens—adjust the timing if this keeps occurring.';
        }
      case AlignmentState.drifting:
        return '$itemTitle drifted today. You\'re close—small timing tweaks can get you back on track.';
      case AlignmentState.early:
        return '$itemTitle was completed early. That\'s great momentum—consider moving the scheduled time earlier.';
      case AlignmentState.aligned:
        return '$itemTitle hit its schedule perfectly. Keep this rhythm going!';
    }
  }
}
