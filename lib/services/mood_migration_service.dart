// lib/services/mood_migration_service.dart
import '../models/mood_model.dart';
import 'obsidian_service.dart';

/// One-time migration service for existing mood files from old scalar to new 2-axis schema.
/// 
/// Migration rules (per gap-analysis.md §3.3):
/// - pleasantness = ((numeric_value - 1) / 14 * 10).round() — linear remap of old 1–15 scale to 0–10
/// - energy = 5 (neutral default — old model never captured this dimension)
/// - description = '' (empty, non-blocking per Rule 13)
/// - is_system = false (user-created moods)
/// - This is non-destructive: old file is rewritten with new fields added, nothing deleted
class MoodMigrationService {
  final ObsidianService _obsidianService;

  MoodMigrationService(this._obsidianService);

  /// Check if a mood definition needs migration (has old numeric_value but no energy/pleasantness)
  bool needsMigration(MoodDefinition mood) {
    // If it already has both energy and pleasantness, no migration needed
    if (mood.energy > 0 && mood.pleasantness > 0) {
      return false;
    }
    
    // If it has the old numericValue field (stored in pleasantness as fallback), needs migration
    // The old model stored numericValue in the pleasantness field as a fallback
    return mood.pleasantness > 0 || mood.numericValue > 0;
  }

  /// Migrate a single mood definition from old scalar to new 2-axis schema
  MoodDefinition migrateMood(MoodDefinition oldMood) {
    // Get the old numeric value (stored in pleasantness as fallback in old model)
    final oldNumericValue = oldMood.numericValue > 0 
        ? oldMood.numericValue 
        : oldMood.pleasantness;
    
    // Linear remap: old 1–15 scale to new 0–10 scale
    final newPleasantness = ((oldNumericValue - 1) / 14 * 10).round().clamp(0, 10);
    
    // Energy defaults to 5 (neutral) since old model never captured this dimension
    final newEnergy = 5;
    
    // Description defaults to empty (non-blocking per Rule 13)
    final newDescription = oldMood.description?.trim().isEmpty == true 
        ? '' 
        : (oldMood.description ?? '');
    
    // is_system = false for user-created moods
    final newSource = MoodSource.user;
    
    // Create migrated mood with new schema
    return oldMood.copyWith(
      pleasantness: newPleasantness,
      energy: newEnergy,
      description: newDescription.isEmpty ? null : newDescription,
      source: newSource,
    );
  }

  /// Run one-time migration for all mood definitions that need it
  /// Returns the number of moods migrated
  Future<int> migrateAllMoods(List<MoodDefinition> allMoods) async {
    int migratedCount = 0;
    
    for (final mood in allMoods) {
      if (needsMigration(mood) && mood.source == MoodSource.user) {
        // Only migrate user-created moods, not system moods
        final migrated = migrateMood(mood);
        
        // Write the migrated mood back to disk
        await _obsidianService.writeFile(
          migrated.obsidianPath ?? 'moods/${mood.id}.md',
          migrated.toMarkdown(),
        );
        
        migratedCount++;
      }
    }
    
    return migratedCount;
  }

  /// Check if migration has already been run by looking for a migration marker
  /// This could be stored in app settings or a marker file
  Future<bool> hasMigrationRun() async {
    // For now, we'll rely on checking individual moods for migration needs
    // In a production app, this would check a settings flag or marker file
    return false;
  }

  /// Mark migration as complete (store in settings or marker file)
  Future<void> markMigrationComplete() async {
    // In a production app, this would set a settings flag or create a marker file
    // For now, this is a no-op since we check individual moods
  }
}
