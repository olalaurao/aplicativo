import '../models/routine_model.dart';
import '../models/mood_model.dart';
import '../models/journal_entry.dart';
import '../models/content_object.dart';

/// Service for suggesting routines based on current mood
class MoodRoutineService {
  /// Get routines that match the current mood
  static List<Routine> getRoutinesForMood(
    MoodDefinition currentMood,
    List<ContentObject> allObjects,
  ) {
    final routines = allObjects.whereType<Routine>().toList();

    return routines.where((routine) {
      if (routine.moodTrigger == null || routine.moodTrigger!.isEmpty) {
        return false;
      }

      // Check if routine's moodTrigger matches current mood's quadrant
      final triggerQuadrant = _parseMoodTrigger(routine.moodTrigger!);
      return triggerQuadrant == currentMood.quadrant;
    }).toList();
  }

  /// Get current mood from the most recent journal entry
  static MoodDefinition? getCurrentMood(
    List<JournalEntry> journalEntries,
    List<ContentObject> allObjects,
  ) {
    if (journalEntries.isEmpty) return null;

    // Sort by date descending and get the most recent entry with mood
    final sortedEntries = journalEntries
        .where((e) => e.moodEntries != null && e.moodEntries!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (sortedEntries.isEmpty) return null;

    final latestEntry = sortedEntries.first;
    final latestMoodId = latestEntry.moodEntries!.first;

    return allObjects
        .whereType<MoodDefinition>()
        .firstWhere((m) => m.id == latestMoodId, orElse: () => null as MoodDefinition);
  }

  /// Parse mood trigger string to MoodQuadrant
  /// Supports formats: "red", "yellow", "green", "blue" or quadrant names
  static MoodQuadrant? _parseMoodTrigger(String trigger) {
    final normalized = trigger.toLowerCase().trim();

    switch (normalized) {
      case 'red':
      case 'high_energy_low_pleasantness':
        return MoodQuadrant.red;
      case 'yellow':
      case 'high_energy_high_pleasantness':
        return MoodQuadrant.yellow;
      case 'green':
      case 'low_energy_high_pleasantness':
        return MoodQuadrant.green;
      case 'blue':
      case 'low_energy_low_pleasantness':
        return MoodQuadrant.blue;
      default:
        return null;
    }
  }

  /// Get human-readable label for mood quadrant
  static String getQuadrantLabel(MoodQuadrant quadrant) {
    switch (quadrant) {
      case MoodQuadrant.red:
        return 'High Energy / Low Pleasantness';
      case MoodQuadrant.yellow:
        return 'High Energy / High Pleasantness';
      case MoodQuadrant.green:
        return 'Low Energy / High Pleasantness';
      case MoodQuadrant.blue:
        return 'Low Energy / Low Pleasantness';
    }
  }

  /// Get emoji for mood quadrant
  static String getQuadrantEmoji(MoodQuadrant quadrant) {
    switch (quadrant) {
      case MoodQuadrant.red:
        return '😤';
      case MoodQuadrant.yellow:
        return '😄';
      case MoodQuadrant.green:
        return '😌';
      case MoodQuadrant.blue:
        return '😔';
    }
  }
}
