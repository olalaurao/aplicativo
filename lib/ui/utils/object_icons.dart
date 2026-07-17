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

  // ── Color helpers ──────────────────────────────────────────────────────────

  /// Returns the configured color for [type] from settings, or a default.
  static Color colorForType(String type, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return colorForTypeWithSignatures(type, settings.typeSignatures);
  }

  /// Returns the configured color for [type] from [typeSignatures], or the
  /// hardcoded default for that type.
  static Color colorForTypeWithSignatures(
    String type,
    Map<String, TypeSignature> typeSignatures,
  ) {
    final sig = typeSignatures[type];
    if (sig != null && sig.colorHex != null && sig.colorHex!.isNotEmpty) {
      return _parseHex(sig.colorHex!);
    }
    return defaultColorForType(type);
  }

  /// Parses a '#RRGGBB' hex string to a [Color]. Falls back to gray.
  static Color _parseHex(String hex) {
    final clean = hex.trim().replaceAll('#', '');
    if (clean.length == 6) {
      try {
        return Color(int.parse('0xFF$clean'));
      } catch (_) {}
    } else if (clean.length == 8) {
      try {
        return Color(int.parse('0x$clean'));
      } catch (_) {}
    }
    return const Color(0xFF9CA3AF); // fallback gray
  }

  /// Default semantic color per object type — used when no custom color is set.
  static Color defaultColorForType(String type) {
    return switch (type) {
      ObjectTypes.task     => const Color(0xFF3B82F6), // blue
      ObjectTypes.habit    => const Color(0xFF10B981), // green
      ObjectTypes.goal     => const Color(0xFFF59E0B), // amber
      ObjectTypes.event    => const Color(0xFF8B5CF6), // purple
      ObjectTypes.reminder => const Color(0xFFF97316), // orange
      ObjectTypes.entry    => const Color(0xFF6B7280), // muted gray
      ObjectTypes.note     => const Color(0xFF6B7280),
      ObjectTypes.idea     => const Color(0xFFF59E0B), // amber
      ObjectTypes.project  => const Color(0xFF3B82F6), // blue
      ObjectTypes.area     => const Color(0xFF06B6D4), // cyan
      ObjectTypes.person   => const Color(0xFFEC4899), // pink
      ObjectTypes.tracker  => const Color(0xFF8B5CF6), // purple
      ObjectTypes.timeBlock => const Color(0xFF06B6D4), // cyan/info
      _ => const Color(0xFF9CA3AF), // neutral gray
    };
  }
}
