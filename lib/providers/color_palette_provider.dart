import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/color_palette_model.dart';
import 'settings_provider.dart';

/// Provider for user's custom color palette
final colorPaletteProvider =
    StateNotifierProvider<ColorPaletteNotifier, ColorPalette>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ColorPaletteNotifier(prefs);
});

/// Notifier for managing color palette state
class ColorPaletteNotifier extends StateNotifier<ColorPalette> {
  final SharedPreferences _prefs;
  static const String _paletteKey = 'user_color_palette';

  ColorPaletteNotifier(this._prefs) : super(ColorPalette.defaultPalette) {
    _loadPalette();
  }

  /// Load palette from SharedPreferences
  void _loadPalette() {
    final paletteJson = _prefs.getString(_paletteKey);
    if (paletteJson != null) {
      try {
        final map = json.decode(paletteJson) as Map<String, dynamic>;
        state = ColorPalette.fromMap(map);
      } catch (e) {
        // If loading fails, use default palette
        state = ColorPalette.defaultPalette;
      }
    }
  }

  /// Save palette to SharedPreferences
  void _savePalette() {
    final paletteJson = json.encode(state.toMap());
    _prefs.setString(_paletteKey, paletteJson);
  }

  /// Add a color to light mode palette
  void addLightColor(String hex, {String? name}) {
    if (state.isLightPaletteFull) return;
    
    final newColor = PaletteColor(
      id: 'light_${DateTime.now().millisecondsSinceEpoch}',
      hex: PaletteColor.normalizeHex(hex),
      name: name,
    );
    
    state = state.copyWith(
      lightColors: [...state.lightColors, newColor],
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Add a color to dark mode palette
  void addDarkColor(String hex, {String? name}) {
    if (state.isDarkPaletteFull) return;
    
    final newColor = PaletteColor(
      id: 'dark_${DateTime.now().millisecondsSinceEpoch}',
      hex: PaletteColor.normalizeHex(hex),
      name: name,
    );
    
    state = state.copyWith(
      darkColors: [...state.darkColors, newColor],
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Update a light mode color
  void updateLightColor(String id, String hex, {String? name}) {
    final updatedColors = state.lightColors.map((c) {
      if (c.id == id) {
        return c.copyWith(
          hex: PaletteColor.normalizeHex(hex),
          name: name ?? c.name,
        );
      }
      return c;
    }).toList();
    
    state = state.copyWith(
      lightColors: updatedColors,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Update a dark mode color
  void updateDarkColor(String id, String hex, {String? name}) {
    final updatedColors = state.darkColors.map((c) {
      if (c.id == id) {
        return c.copyWith(
          hex: PaletteColor.normalizeHex(hex),
          name: name ?? c.name,
        );
      }
      return c;
    }).toList();
    
    state = state.copyWith(
      darkColors: updatedColors,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Remove a light mode color
  void removeLightColor(String id) {
    final updatedColors = state.lightColors.where((c) => c.id != id).toList();
    state = state.copyWith(
      lightColors: updatedColors,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Remove a dark mode color
  void removeDarkColor(String id) {
    final updatedColors = state.darkColors.where((c) => c.id != id).toList();
    state = state.copyWith(
      darkColors: updatedColors,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Toggle separate dark palette mode
  void toggleSeparateDarkPalette(bool enabled) {
    state = state.copyWith(
      useSeparateDarkPalette: enabled,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Reset to default palette
  void resetToDefault() {
    state = ColorPalette.defaultPalette;
    _savePalette();
  }

  /// Clear all colors from light palette
  void clearLightPalette() {
    state = state.copyWith(
      lightColors: [],
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Clear all colors from dark palette
  void clearDarkPalette() {
    state = state.copyWith(
      darkColors: [],
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Reorder light colors
  void reorderLightColors(int oldIndex, int newIndex) {
    final colors = List<PaletteColor>.from(state.lightColors);
    final item = colors.removeAt(oldIndex);
    colors.insert(newIndex, item);
    state = state.copyWith(
      lightColors: colors,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Reorder dark colors
  void reorderDarkColors(int oldIndex, int newIndex) {
    final colors = List<PaletteColor>.from(state.darkColors);
    final item = colors.removeAt(oldIndex);
    colors.insert(newIndex, item);
    state = state.copyWith(
      darkColors: colors,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }
}

/// Provider for background color palette
final backgroundColorPaletteProvider =
    StateNotifierProvider<BackgroundColorPaletteNotifier, BackgroundColorPalette>(
        (ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BackgroundColorPaletteNotifier(prefs);
});

/// Notifier for managing background color palette state
class BackgroundColorPaletteNotifier extends StateNotifier<BackgroundColorPalette> {
  final SharedPreferences _prefs;
  static const String _bgPaletteKey = 'background_color_palette';

  BackgroundColorPaletteNotifier(this._prefs)
      : super(BackgroundColorPalette()) {
    _loadPalette();
  }

  /// Load palette from SharedPreferences
  void _loadPalette() {
    final paletteJson = _prefs.getString(_bgPaletteKey);
    if (paletteJson != null) {
      try {
        final map = json.decode(paletteJson) as Map<String, dynamic>;
        state = BackgroundColorPalette.fromMap(map);
      } catch (e) {
        // If loading fails, use empty palette
        state = BackgroundColorPalette();
      }
    }
  }

  /// Save palette to SharedPreferences
  void _savePalette() {
    final paletteJson = json.encode(state.toMap());
    _prefs.setString(_bgPaletteKey, paletteJson);
  }

  /// Add a light background color
  void addLightBackground(String hex) {
    if (state.isLightPaletteFull) return;
    
    final normalized = PaletteColor.normalizeHex(hex);
    state = state.copyWith(
      lightBackgrounds: [...state.lightBackgrounds, normalized],
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Add a dark background color
  void addDarkBackground(String hex) {
    if (state.isDarkPaletteFull) return;
    
    final normalized = PaletteColor.normalizeHex(hex);
    state = state.copyWith(
      darkBackgrounds: [...state.darkBackgrounds, normalized],
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Update a light background color
  void updateLightBackground(int index, String hex) {
    if (index < 0 || index >= state.lightBackgrounds.length) return;
    
    final backgrounds = List<String>.from(state.lightBackgrounds);
    backgrounds[index] = PaletteColor.normalizeHex(hex);
    state = state.copyWith(
      lightBackgrounds: backgrounds,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Update a dark background color
  void updateDarkBackground(int index, String hex) {
    if (index < 0 || index >= state.darkBackgrounds.length) return;
    
    final backgrounds = List<String>.from(state.darkBackgrounds);
    backgrounds[index] = PaletteColor.normalizeHex(hex);
    state = state.copyWith(
      darkBackgrounds: backgrounds,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Remove a light background color
  void removeLightBackground(int index) {
    if (index < 0 || index >= state.lightBackgrounds.length) return;
    
    final backgrounds = List<String>.from(state.lightBackgrounds);
    backgrounds.removeAt(index);
    state = state.copyWith(
      lightBackgrounds: backgrounds,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Remove a dark background color
  void removeDarkBackground(int index) {
    if (index < 0 || index >= state.darkBackgrounds.length) return;
    
    final backgrounds = List<String>.from(state.darkBackgrounds);
    backgrounds.removeAt(index);
    state = state.copyWith(
      darkBackgrounds: backgrounds,
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Clear all light backgrounds
  void clearLightBackgrounds() {
    state = state.copyWith(
      lightBackgrounds: [],
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Clear all dark backgrounds
  void clearDarkBackgrounds() {
    state = state.copyWith(
      darkBackgrounds: [],
      updatedAt: DateTime.now(),
    );
    _savePalette();
  }

  /// Reset to empty palette
  void resetToEmpty() {
    state = BackgroundColorPalette();
    _savePalette();
  }
}
