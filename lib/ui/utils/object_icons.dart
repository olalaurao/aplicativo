// lib/ui/utils/object_icons.dart
// V5 F2.2 — Universal type icons (default icons per object type)
import '../../models/shared_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import 'material_icon_set.dart';

class ObjectIcons {
  /// Returns the configured emoji icon for a given object type from settings.
  /// Falls back to default if not configured.
  static String emojiForType(String type, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return emojiForTypeWithSignatures(type, settings.typeSignatures);
  }

  /// Returns the configured emoji icon for a given object type from a signatures map.
  /// Falls back to default if not configured.
  static String emojiForTypeWithSignatures(String type, Map<String, TypeSignature> typeSignatures) {
    final sig = typeSignatures[type];
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
      ObjectTypes.value => '💎',
      ObjectTypes.pillar => '🏛️',
      ObjectTypes.action => '🔋',
      ObjectTypes.dayTheme => '☀️',
      ObjectTypes.timeBlock => '⏰',
      ObjectTypes.routine => '🔄',
      ObjectTypes.wellbeingIndicator => '❤️',
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

  /// Returns the configured IconData for a given object type from settings.
  /// Falls back to default if not configured.
  static IconData? iconDataForType(String type, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return iconDataForTypeWithSignatures(type, settings.typeSignatures);
  }

  /// Returns the configured IconData for a given object type from a signatures map.
  /// Falls back to default if not configured.
  static IconData? iconDataForTypeWithSignatures(String type, Map<String, TypeSignature> typeSignatures) {
    final sig = typeSignatures[type];
    if (sig != null && sig.iconName != null) {
      return MaterialIconSet.getIcon(sig.iconName!);
    }
    return defaultIconDataForType(type);
  }

  /// Returns the default IconData for a given object type.
  static IconData defaultIconDataForType(String type) {
    return switch (type) {
      ObjectTypes.task => Icons.check_circle_outline,
      ObjectTypes.habit => Icons.refresh,
      ObjectTypes.tracker => Icons.bar_chart,
      ObjectTypes.goal => Icons.flag,
      ObjectTypes.note => Icons.description,
      ObjectTypes.event => Icons.calendar_today,
      ObjectTypes.reminder => Icons.notifications,
      ObjectTypes.idea => Icons.lightbulb,
      ObjectTypes.person => Icons.person,
      ObjectTypes.project => Icons.folder,
      ObjectTypes.area => Icons.layers,
      ObjectTypes.activity => Icons.sports,
      ObjectTypes.label => Icons.label,
      ObjectTypes.pillar => Icons.account_balance,
      ObjectTypes.value => Icons.diamond,
      ObjectTypes.action => Icons.bolt,
      ObjectTypes.entry => Icons.menu_book,
      ObjectTypes.shoppingList => Icons.shopping_cart,
      ObjectTypes.template => Icons.dashboard,
      ObjectTypes.inbox => Icons.inbox,
      ObjectTypes.moodDef => Icons.sentiment_satisfied,
      ObjectTypes.system => Icons.settings,
      ObjectTypes.socialPost => Icons.share,
      ObjectTypes.analysis => Icons.analytics,
      ObjectTypes.dayTheme => Icons.wb_sunny,
      ObjectTypes.timeBlock => Icons.access_time,
      ObjectTypes.routine => Icons.repeat,
      ObjectTypes.wellbeingIndicator => Icons.favorite,
      _ => Icons.description,
    };
  }

  /// Returns the default IconData for a note subtype.
  static IconData defaultIconDataForNoteSubtype(String subtype) {
    return switch (subtype) {
      'text' => Icons.description,
      'outline' => Icons.view_list,
      'collection' => Icons.folder,
      _ => Icons.description,
    };
  }
}
