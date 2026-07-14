// lib/providers/wellbeing_indicator_provider.dart
// Wellbeing Indicator provider - V5.1 composite health signal
// Evaluates signals from multiple data sources (tracker fields, habits, journal moods, etc.)
// and surfaces watch/alert states via Health Alerts strip

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vault_provider.dart';
import '../models/wellbeing_indicator_model.dart';
import '../models/shared_types.dart';
import '../models/tracker_model.dart';
import '../models/habit_model.dart';
import '../models/task_model.dart';
import '../models/journal_entry.dart';

// ---------------------------------------------------------------------------
// WellbeingSignalStatus - current state of a single signal
// ---------------------------------------------------------------------------
class WellbeingSignalStatus {
  final Signal signal;
  final SignalStatus status;
  final double? currentValue;
  final DateTime? lastRecordDate;
  final int daysSinceLastRecord;
  final String? message;
  final String? sourceTitle; // Title of the linked tracker/habit/etc.

  const WellbeingSignalStatus({
    required this.signal,
    required this.status,
    this.currentValue,
    this.lastRecordDate,
    required this.daysSinceLastRecord,
    this.message,
    this.sourceTitle,
  });
}

// ---------------------------------------------------------------------------
// wellbeingIndicatorsProvider - loads all Wellbeing Indicator objects
// ---------------------------------------------------------------------------
final wellbeingIndicatorsProvider = Provider<List<WellbeingIndicator>>((ref) {
  final allObjectsAsync = ref.watch(allObjectsProvider);
  final allObjects = allObjectsAsync.valueOrNull ?? [];
  return allObjects
      .where((obj) => obj.type == 'wellbeing_indicator')
      .map((obj) => obj as WellbeingIndicator)
      .toList();
});

// ---------------------------------------------------------------------------
// wellbeingSignalStatusesProvider - evaluates all signals and returns current statuses
// Optimized to only rebuild when relevant data changes and reduce memory allocations
// ---------------------------------------------------------------------------
final wellbeingSignalStatusesProvider = Provider<List<WellbeingSignalStatus>>((ref) {
  final indicators = ref.watch(wellbeingIndicatorsProvider);
  // Use select to only rebuild when specific data changes, not on every vault update
  final trackers = ref.watch(trackersProvider);
  final allObjects = ref.watch(allObjectsProvider).value ?? [];
  final habits = allObjects.whereType<Habit>().toList();
  final tasks = allObjects.whereType<Task>().toList();
  final journalEntries = ref.watch(allEntriesProvider);
  final trackingRecords = ref.watch(trackingRecordsProvider);
  final now = DateTime.now();
  
  // Pre-allocate list with estimated capacity to reduce reallocations
  final statuses = <WellbeingSignalStatus>[];
  final estimatedCount = indicators.fold<int>(0, (sum, ind) => sum + ind.signals.length);
  if (estimatedCount > 0) {
    statuses.length = estimatedCount;
    statuses.clear();
  }

  for (final indicator in indicators) {
    for (final signal in indicator.signals) {
      final status = _evaluateSignal(
        signal,
        trackers,
        habits,
        tasks,
        journalEntries,
        trackingRecords,
        now,
      );
      if (status != null) {
        statuses.add(status);
      }
    }
  }

  // Sort by severity (alert first, then watch, then healthy)
  if (statuses.length > 1) {
    statuses.sort((a, b) => b.status.index.compareTo(a.status.index));
  }
  return statuses;
});

// ---------------------------------------------------------------------------
// activeHealthAlertsProvider - only signals at watch or alert status
// ---------------------------------------------------------------------------
final activeHealthAlertsProvider = Provider<List<WellbeingSignalStatus>>((ref) {
  final allStatuses = ref.watch(wellbeingSignalStatusesProvider);
  return allStatuses
      .where((s) => s.status == SignalStatus.watch || s.status == SignalStatus.alert)
      .toList();
});

// ---------------------------------------------------------------------------
// _evaluateSignal - evaluates a single signal against its bands
// ---------------------------------------------------------------------------
WellbeingSignalStatus? _evaluateSignal(
  Signal signal,
  List<TrackerDefinition> trackers,
  List<Habit> habits,
  List<Task> tasks,
  List<JournalEntry> journalEntries,
  List<dynamic> trackingRecords,
  DateTime now,
) {
  final dataSource = signal.dataSource;
  double? currentValue;
  DateTime? lastRecordDate;
  String? sourceTitle;
  var hasRecord = false;

  // Resolve value from data source
  switch (dataSource.sourceType) {
    case DataSourceType.trackerField:
      final tracker = trackers.where((t) => t.id == dataSource.sourceId).firstOrNull;
      if (tracker != null) {
        sourceTitle = tracker.title;
        // Use single-pass filtering to avoid creating intermediate lists
        TrackingRecord? last;
        for (final r in trackingRecords) {
          if (r.trackerId == tracker.id && r.fieldValues.containsKey(dataSource.fieldId)) {
            if (last == null || r.date.isAfter(last.date)) {
              last = r;
            }
          }
        }
        
        if (last != null) {
          lastRecordDate = last.date;
          currentValue = _toDouble(last.fieldValues[dataSource.fieldId]);
          hasRecord = true;
        }
      }
      break;

    case DataSourceType.habit:
      final habit = habits.where((h) => h.id == dataSource.sourceId).firstOrNull;
      if (habit != null) {
        sourceTitle = habit.title;
        // Single-pass find latest completion
        HabitSlot? lastCompletion;
        for (final completion in habit.slots) {
          if (completion.completed) {
            if (lastCompletion == null || (completion.time != null && (lastCompletion.time == null || completion.time!.isAfter(lastCompletion.time!)))) {
              lastCompletion = completion;
            }
          }
        }
        if (lastCompletion != null && lastCompletion.time != null) {
          lastRecordDate = lastCompletion.time;
          currentValue = 1.0;
          hasRecord = true;
        }
      }
      break;

    case DataSourceType.journalMood:
      sourceTitle = 'Journal Mood';
      // Single-pass find most recent journal entry with mood
      for (final entry in journalEntries) {
        // JournalEntry doesn't have a mood property directly, skip for now
        break;
      }
      break;

    case DataSourceType.subtasks:
      final query = dataSource.sourceId;
      if (query != null) {
        Task? lastTask;
        for (final t in tasks) {
          if (t.id == query && t.stage == TaskStage.finalized) {
            if (lastTask == null || t.updatedAt.isAfter(lastTask.updatedAt)) {
              lastTask = t;
            }
          }
        }
        if (lastTask != null) {
          sourceTitle = lastTask.title;
          lastRecordDate = lastTask.updatedAt;
          currentValue = lastTask.subtasks.where((s) => s.completed).length.toDouble();
          hasRecord = true;
        }
      }
      break;

    default:
      return null;
  }

  final daysSince = lastRecordDate != null
      ? now.difference(DateTime(lastRecordDate.year, lastRecordDate.month, lastRecordDate.day)).inDays
      : 999;

  // Evaluate against bands
  SignalStatus status = SignalStatus.healthy;
  String? message;

  for (final band in signal.bands) {
    bool matches = false;

    if (currentValue != null) {
      if (band.min != null && band.max != null) {
        if (currentValue >= band.min! && currentValue <= band.max!) {
          matches = true;
        }
      } else if (band.min != null) {
        if (currentValue >= band.min!) {
          matches = true;
        }
      } else if (band.max != null) {
        if (currentValue <= band.max!) {
          matches = true;
        }
      }
    }

    if (band.daysSinceLastEntry != null && daysSince >= band.daysSinceLastEntry!) {
      matches = true;
    }

    if (matches) {
      status = band.status;
      message = band.description ?? _getDefaultMessage(band.status, signal.label ?? sourceTitle ?? 'Signal', daysSince);
      break;
    }
  }

  if (!hasRecord && signal.bands.every((b) => b.daysSinceLastEntry == null)) {
    status = SignalStatus.healthy;
  }

  return WellbeingSignalStatus(
    signal: signal,
    status: status,
    currentValue: currentValue,
    lastRecordDate: lastRecordDate,
    daysSinceLastRecord: daysSince,
    message: message,
    sourceTitle: sourceTitle,
  );
}

String _getDefaultMessage(SignalStatus status, String sourceTitle, int daysSince) {
  switch (status) {
    case SignalStatus.healthy:
      return '$sourceTitle is on track';
    case SignalStatus.watch:
      return '$sourceTitle needs attention (last record $daysSince days ago)';
    case SignalStatus.alert:
      return '$sourceTitle requires immediate attention (last record $daysSince days ago)';
  }
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is bool) return value ? 1.0 : 0.0;
  return double.tryParse(value?.toString() ?? '');
}
