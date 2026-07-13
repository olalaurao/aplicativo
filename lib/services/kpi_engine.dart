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
    required List<Task> tasks,
  }) {
    switch (kpi.sourceType) {
      // ─── HABITS ───
      case KPISourceType.habit:
        final habit = habits.where((h) => h.id == kpi.sourceId || h.slug == kpi.sourceId).firstOrNull;
        if (habit == null) return 0;
        
        // Filter completion history by date range (except for streak)
        final filteredHistory = kpi.startDate == null && kpi.endDate == null
            ? habit.completionHistory
            : habit.completionHistory.where((c) {
                final recordDate = DateTime(c.date.year, c.date.month, c.date.day);
                if (kpi.startDate != null && recordDate.isBefore(kpi.startDate!)) return false;
                if (kpi.endDate != null && recordDate.isAfter(kpi.endDate!)) return false;
                return true;
              }).toList();
        
        if (kpi.calculationMode == 'streak') {
          // Streak is inherently about current consecutive days, don't filter by date range
          return habit.streak.toDouble();
        } else if (kpi.calculationMode == 'success_rate') {
          if (filteredHistory.isEmpty) return 0;
          final successCount = filteredHistory.where((c) => c.successful).length;
          return (successCount / filteredHistory.length) * 100;
        } else {
          return filteredHistory.where((c) => c.successful).length.toDouble();
        }

      // ─── TRACKERS ───
      case KPISourceType.trackerField:
        // Filter tracker records by date range
        final filteredRecords = kpi.startDate == null && kpi.endDate == null
            ? trackerRecords
            : trackerRecords.where((r) {
                final recordDate = DateTime(r.date.year, r.date.month, r.date.day);
                if (kpi.startDate != null && recordDate.isBefore(kpi.startDate!)) return false;
                if (kpi.endDate != null && recordDate.isAfter(kpi.endDate!)) return false;
                return true;
              }).toList();
        final values = _getTrackerValues(kpi, filteredRecords);
        if (kpi.calculationMode == 'average') {
          return average(values);
        } else if (kpi.calculationMode == 'max') {
          return max(values);
        } else if (kpi.calculationMode == 'min') {
          return min(values);
        } else if (kpi.calculationMode == 'count') {
          return values.length.toDouble();
        } else if (kpi.calculationMode == 'latest') {
          return values.isEmpty ? 0 : values.last;
        } else {
          return sum(values);
        }

      // ─── SUBTASKS ───
      case KPISourceType.subtasks:
        final linkedTasks = tasks.where((t) {
          return t.organizers.any((org) => org.slug == kpi.sourceId) ||
                 t.dependsOn.contains('[[${kpi.sourceId}]]');
        }).toList();
        if (linkedTasks.isEmpty) return 0;
        
        // Filter tasks by completion date within range
        final filteredTasks = kpi.startDate == null && kpi.endDate == null
            ? linkedTasks
            : linkedTasks.where((t) {
                final completionDate = t.stage == TaskStage.finalized ? t.endDate : null;
                if (completionDate == null) return false;
                if (kpi.startDate != null && completionDate.isBefore(kpi.startDate!)) return false;
                if (kpi.endDate != null && completionDate.isAfter(kpi.endDate!)) return false;
                return true;
              }).toList();
        
        final completed = filteredTasks.where((t) => t.stage == TaskStage.finalized).length;
        if (kpi.calculationMode == 'goal_percentage') {
          return (completed / filteredTasks.length) * 100;
        } else {
          return completed.toDouble();
        }

      // ─── COLLECTIONS ───
      case KPISourceType.collection:
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

      // ─── ENTRIES ───
      case KPISourceType.entry:
        final scopedEntries = kpi.sourceId == null
            ? entries
            : entries.where((e) =>
                e.body.contains('[[${kpi.sourceId}]]') ||
                e.organizers.any((o) => o.slug == kpi.sourceId));
        // Filter entries by date range
        final filteredEntries = kpi.startDate == null && kpi.endDate == null
            ? scopedEntries
            : scopedEntries.where((e) {
                final entryDate = DateTime(e.date.year, e.date.month, e.date.day);
                if (kpi.startDate != null && entryDate.isBefore(kpi.startDate!)) return false;
                if (kpi.endDate != null && entryDate.isAfter(kpi.endDate!)) return false;
                return true;
              }).toList();
        if (kpi.calculationMode == 'word_count') {
          return filteredEntries.fold<double>(0, (sumVal, e) {
            final words = e.body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
            return sumVal + words;
          });
        } else {
          return filteredEntries.length.toDouble();
        }

      // ─── TIME SPENT ───
      case KPISourceType.timeSpent:
        final matchedTasks = tasks.where((t) {
          if (kpi.sourceId == null) return true;
          return t.organizers.any((o) => o.slug == kpi.sourceId);
        });
        // Filter tasks by date range (using completion date or end date)
        final filteredTasks = kpi.startDate == null && kpi.endDate == null
            ? matchedTasks
            : matchedTasks.where((t) {
                final taskDate = t.stage == TaskStage.finalized ? t.endDate : null;
                if (taskDate == null) return false;
                if (kpi.startDate != null && taskDate.isBefore(kpi.startDate!)) return false;
                if (kpi.endDate != null && taskDate.isAfter(kpi.endDate!)) return false;
                return true;
              }).toList();
        
        // Filter by category/dimension if fieldId is set (for category_duration mode)
        final categoryFilteredTasks = kpi.calculationMode == 'category_duration' && kpi.fieldId != null
            ? filteredTasks.where((t) => t.categories.contains(kpi.fieldId))
            : filteredTasks;
        
        final totalTaskMinutes = categoryFilteredTasks.fold<double>(0, (sumVal, t) => sumVal + t.timerSessions);
        return totalTaskMinutes;

      // ─── MANUAL QUANTITY ───
      case KPISourceType.manualQuantity:
        return kpi.currentValue;

      // ─── OTHERS ───
      case KPISourceType.others:
        // Filter entries by date range for mood-based modes
        final filteredEntries = kpi.startDate == null && kpi.endDate == null
            ? entries
            : entries.where((e) {
                final entryDate = DateTime(e.date.year, e.date.month, e.date.day);
                if (kpi.startDate != null && entryDate.isBefore(kpi.startDate!)) return false;
                if (kpi.endDate != null && entryDate.isAfter(kpi.endDate!)) return false;
                return true;
              }).toList();
        
        // Filter tasks by date range for task-based modes
        final filteredTasks = kpi.startDate == null && kpi.endDate == null
            ? tasks
            : tasks.where((t) {
                final taskDate = t.stage == TaskStage.finalized ? t.endDate : null;
                if (taskDate == null) return false;
                if (kpi.startDate != null && taskDate.isBefore(kpi.startDate!)) return false;
                if (kpi.endDate != null && taskDate.isAfter(kpi.endDate!)) return false;
                return true;
              }).toList();
        
        if (kpi.calculationMode == 'mood_average') {
          // Sistema de 2 eixos: pleasantness (padrão) ou energy
          final useEnergy = kpi.fieldId == 'energy';
          
          // F2.14: Collect all mood entries from moodEntries array
          final allMoodEntries = <MoodEntry>[];
          for (final entry in filteredEntries) {
            if (entry.moodEntries.isNotEmpty) {
              allMoodEntries.addAll(entry.moodEntries);
            } else if (entry.moodSlug != null) {
              // Legacy fallback
              allMoodEntries.add(MoodEntry(
                moodSlug: entry.moodSlug!,
                timestamp: entry.date,
              ));
            }
          }
          
          final dayMoods = allMoodEntries.map((moodEntry) {
            final m = moods.where((m) => m.id == moodEntry.moodSlug).firstOrNull;
            if (useEnergy) {
              // Use energy from MoodEntry if available, else from MoodDefinition
              return (moodEntry.energy ?? m?.energy ?? 0).toDouble();
            }
            // Use pleasantness from MoodEntry if available, else from MoodDefinition
            return (moodEntry.pleasantness ?? m?.pleasantness ?? m?.numericValue ?? 0).toDouble();
          }).where((val) => val > 0).toList();
          return average(dayMoods);
        } else if (kpi.calculationMode == 'mood_trend') {
          // Diferença entre média da última semana vs semana anterior
          final now = DateTime.now();
          final cutoff = now.subtract(const Duration(days: 7));
          final prevCutoff = now.subtract(const Duration(days: 14));
          
          // F2.14: Collect all mood entries from moodEntries array
          final allMoodEntries = <MoodEntry>[];
          for (final entry in filteredEntries) {
            if (entry.moodEntries.isNotEmpty) {
              allMoodEntries.addAll(entry.moodEntries);
            } else if (entry.moodSlug != null) {
              // Legacy fallback
              allMoodEntries.add(MoodEntry(
                moodSlug: entry.moodSlug!,
                timestamp: entry.date,
              ));
            }
          }
          
          double moodVal(MoodEntry moodEntry) {
            final m = moods.where((m) => m.id == moodEntry.moodSlug).firstOrNull;
            return (moodEntry.pleasantness ?? m?.pleasantness ?? m?.numericValue ?? 0).toDouble();
          }
          
          final recentMoods = allMoodEntries
              .where((e) => e.timestamp.isAfter(cutoff))
              .map(moodVal)
              .where((v) => v > 0)
              .toList();
          final prevMoods = allMoodEntries
              .where((e) => e.timestamp.isAfter(prevCutoff) && !e.timestamp.isAfter(cutoff))
              .map(moodVal)
              .where((v) => v > 0)
              .toList();
          return average(recentMoods) - average(prevMoods);
        } else if (kpi.calculationMode == 'photo_count') {
          return filteredEntries.fold<double>(0, (sumVal, e) => sumVal + e.photos.length);
        } else if (kpi.calculationMode == 'comment_count') {
          return filteredEntries.fold<double>(0, (sumVal, e) => sumVal + e.comments.length);
        } else if (kpi.calculationMode == 'reflection_length') {
          return filteredTasks.fold<double>(0, (sumVal, t) => sumVal + (t.reflection?.length ?? 0));
        } else if (kpi.calculationMode == 'planner_task_count') {
          if (kpi.sourceId != null) {
            return filteredTasks
                .where((t) => t.organizers.any((o) => o.slug == kpi.sourceId))
                .length
                .toDouble();
          }
          return tasks.length.toDouble();
        } else if (kpi.calculationMode == 'planner_overdue_count') {
          final now = DateTime.now();
          return tasks
              .where((t) =>
                  t.endDate != null &&
                  t.endDate!.isBefore(now) &&
                  t.stage != TaskStage.finalized &&
                  (kpi.sourceId == null ||
                      t.organizers.any((o) => o.slug == kpi.sourceId)))
              .length
              .toDouble();
        } else if (kpi.calculationMode == 'organizer_association_count') {
          // Número de objetos associados a um organizer
          if (kpi.sourceId == null) return 0;
          return tasks
              .where((t) => t.organizers.any((o) => o.slug == kpi.sourceId))
              .length
              .toDouble();
        }
        return 0;

      // ─── TIME SPENT (planner_task_duration e category_duration) ───
      // Nota: o case principal já trata timeSpent acima; este bloco é
      // necessário apenas como extensão do switch para satisfazer o Dart.
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
    required List<Task> tasks,
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
        tasks: tasks,
      );
      if (kpi.currentValue >= kpi.targetValue) {
        kpi.completed = true;
      }
      if (kpi.currentValue < kpi.targetValue) {
        allMet = false;
      }
    }
    return allMet;
  }

  /// Checks if a single KPI has met its target
  static bool isKPIComplete(KPI kpi) {
    return kpi.completed || kpi.currentValue >= kpi.targetValue;
  }
}
