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
  final baseTheme = presets.firstWhere(
    (theme) => theme.id == settings.activeThemeId,
    orElse: () {
      final accentHex = settings.accentColor.toUpperCase();
      return presets.firstWhere(
        (theme) => theme.accentHex == accentHex,
        orElse: () => presets.first,
      );
    },
  );

  // Apply custom accent color from settings
  final customAccentColor = AppThemeConfig.colorFromHex(settings.accentColor);

  // Apply custom light background color if set
  Color? customBgColor;
  if (settings.backgroundColor != null) {
    customBgColor = AppThemeConfig.colorFromHex(settings.backgroundColor!);
  }

  // Apply custom dark background color if set
  Color? customDarkBgColor;
  if (settings.darkBackgroundColor != null) {
    customDarkBgColor = AppThemeConfig.colorFromHex(settings.darkBackgroundColor!);
  }

  return AppThemeConfig(
    id: baseTheme.id,
    label: baseTheme.label,
    accentColor: customAccentColor,
    backgroundColor: customBgColor ?? baseTheme.backgroundColor,
    darkBackgroundColor: customDarkBgColor ?? baseTheme.darkBackgroundColor,
    icon: baseTheme.icon,
    description: baseTheme.description,
    fontFamily: settings.fontFamily ?? baseTheme.fontFamily,
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
    lightTheme: AppTheme.getLightTheme(
      config.accentColor,
      backgroundColor: config.backgroundColor,
      fontFamily: config.fontFamily,
    ),
    darkTheme: AppTheme.getDarkTheme(
      config.accentColor,
      backgroundColor: config.darkBackgroundColor,
      fontFamily: config.fontFamily,
    ),
  );
});
