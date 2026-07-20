import 'package:flutter/material.dart';

/// Represents a single color in a custom palette
class PaletteColor {
  final String id;
  final String hex;
  final String? name;
  final DateTime createdAt;

  PaletteColor({
    required this.id,
    required this.hex,
    this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Normalizes hex color to #RRGGBB format
  static String normalizeHex(String hex) {
    var val = hex.trim().replaceAll('#', '');
    if (val.length == 3) {
      val = val.split('').map((c) => '$c$c').join();
    }
    if (val.length != 6) {
      return '#9CA3AF'; // fallback gray
    }
    return '#${val.toUpperCase()}';
  }

  /// Converts hex to Flutter Color
  static Color parseHex(String hex, {Color fallback = const Color(0xFF9CA3AF)}) {
    final clean = hex.trim().replaceAll('#', '');
    if (clean.length != 6) return fallback;
    try {
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return fallback;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hex': hex,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PaletteColor.fromMap(Map<String, dynamic> map) {
    return PaletteColor(
      id: map['id'] as String,
      hex: map['hex'] as String,
      name: map['name'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
    );
  }

  PaletteColor copyWith({
    String? id,
    String? hex,
    String? name,
    DateTime? createdAt,
  }) {
    return PaletteColor(
      id: id ?? this.id,
      hex: hex ?? this.hex,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Represents a user's custom color palette
/// Supports up to 15 colors for light mode and optionally 15 for dark mode
class ColorPalette {
  final String id;
  final String name;
  final List<PaletteColor> lightColors;
  final List<PaletteColor> darkColors;
  final bool useSeparateDarkPalette;
  final DateTime updatedAt;

  ColorPalette({
    required this.id,
    required this.name,
    List<PaletteColor>? lightColors,
    List<PaletteColor>? darkColors,
    this.useSeparateDarkPalette = false,
    DateTime? updatedAt,
  })  : lightColors = lightColors ?? [],
        darkColors = darkColors ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  /// Maximum number of colors per palette
  static const int maxColorsPerPalette = 15;

  /// Maximum number of colors for background palette
  static const int maxBackgroundColors = 5;

  /// Get hex codes for light mode
  List<String> get lightHexes => lightColors.map((c) => c.hex).toList();

  /// Get hex codes for dark mode
  /// If useSeparateDarkPalette is false, returns light colors
  List<String> get darkHexes =>
      useSeparateDarkPalette ? darkColors.map((c) => c.hex).toList() : lightHexes;

  /// Check if light palette is full
  bool get isLightPaletteFull => lightColors.length >= maxColorsPerPalette;

  /// Check if dark palette is full
  bool get isDarkPaletteFull => darkColors.length >= maxColorsPerPalette;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lightColors': lightColors.map((c) => c.toMap()).toList(),
      'darkColors': darkColors.map((c) => c.toMap()).toList(),
      'useSeparateDarkPalette': useSeparateDarkPalette,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ColorPalette.fromMap(Map<String, dynamic> map) {
    return ColorPalette(
      id: map['id'] as String,
      name: map['name'] as String,
      lightColors: (map['lightColors'] as List<dynamic>?)
              ?.map((m) => PaletteColor.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      darkColors: (map['darkColors'] as List<dynamic>?)
              ?.map((m) => PaletteColor.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      useSeparateDarkPalette: map['useSeparateDarkPalette'] as bool? ?? false,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  /// Create a copy with updated fields
  ColorPalette copyWith({
    String? id,
    String? name,
    List<PaletteColor>? lightColors,
    List<PaletteColor>? darkColors,
    bool? useSeparateDarkPalette,
    DateTime? updatedAt,
  }) {
    return ColorPalette(
      id: id ?? this.id,
      name: name ?? this.name,
      lightColors: lightColors ?? this.lightColors,
      darkColors: darkColors ?? this.darkColors,
      useSeparateDarkPalette: useSeparateDarkPalette ?? this.useSeparateDarkPalette,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Default palette with standard colors
  static ColorPalette get defaultPalette {
    return ColorPalette(
      id: 'default',
      name: 'Default',
      lightColors: [
        PaletteColor(id: 'c1', hex: '#DC2626', name: 'Red'),
        PaletteColor(id: 'c2', hex: '#F97316', name: 'Orange'),
        PaletteColor(id: 'c3', hex: '#F59E0B', name: 'Amber'),
        PaletteColor(id: 'c4', hex: '#84CC16', name: 'Lime'),
        PaletteColor(id: 'c5', hex: '#10B981', name: 'Green'),
        PaletteColor(id: 'c6', hex: '#06B6D4', name: 'Cyan'),
        PaletteColor(id: 'c7', hex: '#3B82F6', name: 'Blue'),
        PaletteColor(id: 'c8', hex: '#8B5CF6', name: 'Purple'),
        PaletteColor(id: 'c9', hex: '#EC4899', name: 'Pink'),
        PaletteColor(id: 'c10', hex: '#6B7280', name: 'Gray'),
      ],
    );
  }
}

/// Represents background color palette for app theming
/// Supports up to 5 colors for light and dark modes
class BackgroundColorPalette {
  final List<String> lightBackgrounds;
  final List<String> darkBackgrounds;
  final DateTime updatedAt;

  BackgroundColorPalette({
    List<String>? lightBackgrounds,
    List<String>? darkBackgrounds,
    DateTime? updatedAt,
  })  : lightBackgrounds = lightBackgrounds ?? [],
        darkBackgrounds = darkBackgrounds ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  /// Maximum number of background colors per mode
  static const int maxBackgroundColors = 5;

  /// Check if light palette is full
  bool get isLightPaletteFull => lightBackgrounds.length >= maxBackgroundColors;

  /// Check if dark palette is full
  bool get isDarkPaletteFull => darkBackgrounds.length >= maxBackgroundColors;

  Map<String, dynamic> toMap() {
    return {
      'lightBackgrounds': lightBackgrounds,
      'darkBackgrounds': darkBackgrounds,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BackgroundColorPalette.fromMap(Map<String, dynamic> map) {
    return BackgroundColorPalette(
      lightBackgrounds:
          (map['lightBackgrounds'] as List<dynamic>?)?.cast<String>() ?? [],
      darkBackgrounds:
          (map['darkBackgrounds'] as List<dynamic>?)?.cast<String>() ?? [],
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  BackgroundColorPalette copyWith({
    List<String>? lightBackgrounds,
    List<String>? darkBackgrounds,
    DateTime? updatedAt,
  }) {
    return BackgroundColorPalette(
      lightBackgrounds: lightBackgrounds ?? this.lightBackgrounds,
      darkBackgrounds: darkBackgrounds ?? this.darkBackgrounds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
