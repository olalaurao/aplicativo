// lib/providers/health_alerts_provider.dart
// A8 — Reactive health alerts provider.
// Automatically calculates which tracker health fields are in alert state
// without any user action. Reacts when new records are saved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vault_provider.dart';
import '../models/tracker_model.dart';
import '../models/task_model.dart';

// ---------------------------------------------------------------------------
// HealthAlert data class
// ---------------------------------------------------------------------------
class HealthAlert {
  final TrackerDefinition tracker;
  final InputField field;
  final double? lastValue;
  final DateTime? lastRecordDate;
  final int daysSinceLastRecord;
  final FieldAlertLevel level;
  final String message;

  const HealthAlert({
    required this.tracker,
    required this.field,
    required this.lastValue,
    required this.lastRecordDate,
    required this.daysSinceLastRecord,
    required this.level,
    required this.message,
  });
}

// ---------------------------------------------------------------------------
// healthAlertsProvider
// ---------------------------------------------------------------------------
final healthAlertsProvider = Provider<List<HealthAlert>>((ref) {
  final trackers = ref.watch(trackersProvider);
  final allRecords = ref.watch(trackingRecordsProvider);
  final habits = ref.watch(habitsProvider);
  final tasks = ref.watch(tasksProvider);
  final now = DateTime.now();
  final alerts = <HealthAlert>[];

  for (final tracker in trackers.where((t) => t.isHealthTracker)) {
    for (final section in tracker.sections) {
      for (final field in section.inputFields) {
        if (field.alertLevel == FieldAlertLevel.none && !field.alwaysAlert) {
          continue;
        }

        DateTime? lastDate;
        double? lastVal;
        var hasRecord = false;

        switch (field.dataSource) {
          case FieldDataSource.habit:
            final linkedHabitId = field.linkedHabitId;
            final linkedHabits = linkedHabitId == null
                ? const []
                : habits.where((h) => h.id == linkedHabitId).toList();
            final linkedHabit = linkedHabits.isEmpty
                ? null
                : linkedHabits.first;
            if (linkedHabit != null) {
              final sortedHistory = [...linkedHabit.completionHistory]
                ..sort((a, b) => b.date.compareTo(a.date));
              final lastCompletion = sortedHistory.isNotEmpty
                  ? sortedHistory.first
                  : null;
              lastDate = lastCompletion?.date;
              lastVal = lastCompletion?.successful == true ? 1.0 : 0.0;
              hasRecord = lastCompletion != null;
            }
            break;
          case FieldDataSource.recurringTask:
            final query = field.linkedTaskTitle?.trim().toLowerCase();
            if (query != null && query.isNotEmpty) {
              final relatedTasks =
                  tasks
                      .where(
                        (task) =>
                            task.title.toLowerCase().contains(query) &&
                            task.stage == TaskStage.finalized,
                      )
                      .toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              final lastTask = relatedTasks.isNotEmpty
                  ? relatedTasks.first
                  : null;
              lastDate = lastTask?.updatedAt;
              lastVal = lastTask == null ? null : 1.0;
              hasRecord = lastTask != null;
            }
            break;
          case FieldDataSource.tracker:
            // Find most recent record for this tracker that has this field.
            final fieldRecords =
                allRecords
                    .where(
                      (r) =>
                          r.trackerId == tracker.id &&
                          r.fieldValues.containsKey(field.id),
                    )
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

            final last = fieldRecords.isNotEmpty ? fieldRecords.first : null;
            lastDate = last?.date;
            lastVal = _toDouble(last?.fieldValues[field.id]);
            hasRecord = last != null;
            break;
        }

        final daysSince = lastDate != null
            ? now
                  .difference(
                    DateTime(lastDate.year, lastDate.month, lastDate.day),
                  )
                  .inDays
            : 999;

        FieldAlertLevel level = FieldAlertLevel.none;
        String message = '';

        if (field.alwaysAlert && hasRecord) {
          level = FieldAlertLevel.critical;
          message = field.alertNote ?? 'Verificar ${field.title}';
        } else if (field.alertThreshold != null &&
            lastVal != null &&
            lastVal <= field.alertThreshold!) {
          level = field.alertLevel;
          message =
              field.alertNote ??
              '${field.title}: $lastVal (abaixo de ${field.alertThreshold})';
        } else if (daysSince >= 3 && field.alertLevel != FieldAlertLevel.none) {
          level = FieldAlertLevel.warning;
          message = '${field.title}: sem registro há $daysSince dias';
        }

        if (level != FieldAlertLevel.none) {
          alerts.add(
            HealthAlert(
              tracker: tracker,
              field: field,
              lastValue: lastVal,
              lastRecordDate: lastDate,
              daysSinceLastRecord: daysSince,
              level: level,
              message: message,
            ),
          );
        }
      }
    }
  }

  // Sort by severity (critical first)
  alerts.sort((a, b) => b.level.index.compareTo(a.level.index));
  return alerts;
});

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is bool) return value ? 1.0 : 0.0;
  return double.tryParse(value?.toString() ?? '');
}
