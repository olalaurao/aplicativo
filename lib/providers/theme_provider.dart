import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_theme_config.dart';
import '../ui/theme.dart';
import 'settings_provider.dart';

class AppThemeBundle {
  final AppThemeConfig config;
  final ThemeMode themeMode;
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  const AppThemeBundle({
    required this.config,
    required this.themeMode,
    required this.lightTheme,
    required this.darkTheme,
  });
}

final availableThemesProvider = Provider<List<AppThemeConfig>>((ref) {
  return AppThemeConfig.presets;
});

final activeThemeConfigProvider = Provider<AppThemeConfig>((ref) {
  final settings = ref.watch(settingsProvider);
  final presets = ref.watch(availableThemesProvider);
  return presets.firstWhere(
    (theme) => theme.id == settings.activeThemeId,
    orElse: () {
      final accentHex = settings.accentColor.toUpperCase();
      return presets.firstWhere(
        (theme) => theme.accentHex == accentHex,
        orElse: () => presets.first,
      );
    },
  );
});

final themeProvider = Provider<AppThemeBundle>((ref) {
  final settings = ref.watch(settingsProvider);
  final config = ref.watch(activeThemeConfigProvider);
  final themeMode = switch (settings.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  return AppThemeBundle(
    config: config,
    themeMode: themeMode,
    lightTheme: AppTheme.getLightTheme(config.accentColor),
    darkTheme: AppTheme.getDarkTheme(config.accentColor),
  );
});
