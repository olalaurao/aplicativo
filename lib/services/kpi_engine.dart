import 'dart:convert';

import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/kpi_model.dart';
import '../models/habit_model.dart';
import '../models/tracker_model.dart';
import '../models/journal_entry.dart';
import '../models/mood_model.dart';
import '../models/note_model.dart';

class KPIEngine {
  static double calculateProjectProgress(Project project, List<Task> allTasks) {
    if (project.taskLinks.isEmpty) return 0.0;

    // Find tasks linked to this project
    // Either by project.taskLinks (IDs) or tasks having project in their organizers
    final linkedTasks = allTasks
        .where(
          (task) =>
              project.taskLinks.contains(task.id) ||
              task.organizers.any((org) => org.slug == project.id),
        )
        .toList();

    if (linkedTasks.isEmpty) return 0.0;

    final completedTasks = linkedTasks
        .where((t) => t.stage == TaskStage.finalized)
        .length;
    return (completedTasks / linkedTasks.length);
  }

  static double sum(List<double> values) => values.fold(0, (a, b) => a + b);
  static double average(List<double> values) =>
      values.isEmpty ? 0 : sum(values) / values.length;
  static double max(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
  static double min(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b);

  static double calculateKPIValue({
    required KPI kpi,
    required List<Habit> habits,
    required List<TrackingRecord> trackerRecords,
    required List<JournalEntry> entries,
    required List<MoodDefinition> moods,
    required List<Note> notes,
  }) {
    switch (kpi.sourceType) {
      // ─── HABITS ───
      case KPISourceType.habitCompletionCount:
        final habit = habits.where((h) => h.id == kpi.sourceId).firstOrNull;
        return habit?.completionHistory
                .where((c) => c.successful)
                .length
                .toDouble() ??
            0;
      case KPISourceType.habitStreak:
        final habit = habits.where((h) => h.id == kpi.sourceId).firstOrNull;
        return habit?.streak.toDouble() ?? 0;
      case KPISourceType.habitSuccessRate:
        final habit = habits.where((h) => h.id == kpi.sourceId).firstOrNull;
        if (habit == null || habit.completionHistory.isEmpty) return 0;
        final successCount = habit.completionHistory
            .where((c) => c.successful)
            .length;
        return (successCount / habit.completionHistory.length) * 100;

      // ─── TRACKERS ───
      case KPISourceType.trackerFieldSum:
        final values = _getTrackerValues(kpi, trackerRecords);
        return sum(values);
      case KPISourceType.trackerFieldAverage:
        final values = _getTrackerValues(kpi, trackerRecords);
        return average(values);
      case KPISourceType.trackerFieldMax:
        final values = _getTrackerValues(kpi, trackerRecords);
        return max(values);
      case KPISourceType.trackerFieldMin:
        final values = _getTrackerValues(kpi, trackerRecords);
        return min(values);

      // ─── TIME / TASKS ───
      case KPISourceType.plannerTaskDuration:
        return 0; // Sessions deprecated, refactor if needed for task duration later

      // ─── MOOD ───
      case KPISourceType.moodAverage:
        final dayMoods = entries.where((e) => e.moodSlug != null).map((e) {
          final m = moods.where((m) => m.id == e.moodSlug).firstOrNull;
          return m?.numericValue.toDouble() ?? 0.0;
        }).toList();
        return average(dayMoods);

      // ─── ENTRIES ───
      case KPISourceType.entryCount:
        if (kpi.sourceId == null) return entries.length.toDouble();
        return entries
            .where(
              (e) =>
                  e.body.contains('[[${kpi.sourceId}]]') ||
                  e.organizers.any((o) => o.slug == kpi.sourceId),
            )
            .length
            .toDouble();

      // ─── COLLECTIONS ───
      case KPISourceType.collectionItemCount:
        final note = notes
            .where(
              (n) =>
                  n.id == kpi.sourceId && n.subtype == NoteSubtype.collection,
            )
            .firstOrNull;
        if (note == null) return 0;
        final body = note.body.trim();
        if (body.startsWith('[')) {
          try {
            final decoded = jsonDecode(body);
            if (decoded is List) return decoded.length.toDouble();
          } on FormatException {
            return 0;
          }
        }
        return body
            .split('\n')
            .where((line) {
              final trimmed = line.trim();
              return trimmed.startsWith('- [ ]') ||
                  trimmed.startsWith('- [x]') ||
                  trimmed.startsWith('- [X]') ||
                  trimmed.startsWith('- ');
            })
            .length
            .toDouble();

      // ─── CUSTOM ───
      case KPISourceType.customNumericInput:
        return kpi.currentValue;

      default:
        return 0;
    }
  }

  static List<double> _getTrackerValues(KPI kpi, List<TrackingRecord> records) {
    return records
        .where((r) => r.trackerId == kpi.sourceId)
        .map((r) => (r.fieldValues[kpi.fieldId] as num?)?.toDouble() ?? 0.0)
        .toList();
  }

  /// Updates all KPI current values for a goal and returns whether all primary KPIs are met.
  static bool updateKPIValues({
    required List<KPI> kpis,
    required List<Habit> habits,
    required List<TrackingRecord> trackerRecords,
    required List<JournalEntry> entries,
    required List<MoodDefinition> moods,
    required List<Note> notes,
  }) {
    bool allMet = true;
    for (final kpi in kpis) {
      kpi.currentValue = calculateKPIValue(
        kpi: kpi,
        habits: habits,
        trackerRecords: trackerRecords,
        entries: entries,
        moods: moods,
        notes: notes,
      );
      if (kpi.currentValue < kpi.targetValue) {
        allMet = false;
      }
    }
    return allMet;
  }

  /// Checks if a single KPI has met its target
  static bool isKPIComplete(KPI kpi) {
    return kpi.currentValue >= kpi.targetValue;
  }
}
