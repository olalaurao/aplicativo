// lib/ui/utils/object_icons.dart
// V5 F2.2 — Universal type icons (default icons per object type)
import '../../models/shared_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

class ObjectIcons {
  /// Returns the configured emoji icon for a given object type from settings.
  /// Falls back to default if not configured.
  static String emojiForType(String type, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final sig = settings.typeSignatures[type];
    if (sig != null && sig.emoji.isNotEmpty) {
      return sig.emoji;
    }
    return defaultIconForType(type);
  }

  /// Returns the default emoji icon for a given object type.
  /// Based on guidelines.md Part 1.5 Universal Type Icons table.
  static String defaultIconForType(String type) {
    return switch (type) {
      ObjectTypes.entry => '📓',
      ObjectTypes.habit => '🔁',
      ObjectTypes.tracker => '📊',
      ObjectTypes.goal => '🧭',
      ObjectTypes.note => '📝',
      ObjectTypes.event => '📅',
      ObjectTypes.reminder => '🔔',
      ObjectTypes.system => '⚙️',
      ObjectTypes.socialPost => '🔗',
      ObjectTypes.idea => '💡',
      ObjectTypes.inbox => '📥',
      ObjectTypes.shoppingList => '🛒',
      ObjectTypes.template => '🧩',
      ObjectTypes.area => '🏔',
      ObjectTypes.project => '🎯',
      ObjectTypes.activity => '🔄',
      ObjectTypes.label => '🏷',
      ObjectTypes.person => '👤',
      ObjectTypes.task => '✅',
      ObjectTypes.dailyNote => '📓',
      ObjectTypes.analysis => '📊',
      ObjectTypes.moodDef => '😐',
      _ => '📄',
    };
  }

  /// Returns the default emoji icon for a note subtype.
  static String defaultIconForNoteSubtype(String subtype) {
    return switch (subtype) {
      'text' => '📝',
      'outline' => '🗂',
      'collection' => '🗃',
      _ => '📝',
    };
  }

  /// Returns the default emoji icon for a habit mode.
  static String defaultIconForHabitMode(String mode) {
    return switch (mode) {
      'pact' => '🧪',
      'habit' => '🔁',
      _ => '🔁',
    };
  }

  /// Returns the default emoji icon for an entry type.
  static String defaultIconForEntryType(String entryType) {
    return switch (entryType) {
      'standard' => '📓',
      'field_note' => '⚡',
      'pmn' => '📋',
      _ => '📓',
    };
  }
}
