import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_theme_config.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../theme.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeBundle = ref.watch(themeProvider);
    final themes = ref.watch(availableThemesProvider);
    final activeTheme = ref.watch(activeThemeConfigProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final mode = themeBundle.themeMode;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Appearance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: AppTheme.cardDecoration(context),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(switch (mode) {
                      ThemeMode.light => Icons.light_mode_rounded,
                      ThemeMode.dark => Icons.dark_mode_rounded,
                      ThemeMode.system => Icons.brightness_auto_rounded,
                    }, color: themeBundle.config.accentColor),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Theme mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _modeChip(
                      context,
                      label: 'System',
                      selected: mode == ThemeMode.system,
                      onTap: () => notifier.updateThemeMode('system'),
                    ),
                    _modeChip(
                      context,
                      label: 'Light',
                      selected: mode == ThemeMode.light,
                      onTap: () => notifier.updateThemeMode('light'),
                    ),
                    _modeChip(
                      context,
                      label: 'Dark',
                      selected: mode == ThemeMode.dark,
                      onTap: () => notifier.updateThemeMode('dark'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (mode == ThemeMode.dark || (mode == ThemeMode.system && Theme.of(context).brightness == Brightness.dark)) ...[
            Container(
              decoration: AppTheme.cardDecoration(context),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dark Mode Background',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _backgroundSwatch(
                        context,
                        label: 'Default',
                        colorHex: AppColors.darkBackground.value.toRadixString(16).padLeft(8, '0').toUpperCase(),
                        currentColor: settings.darkBackgroundColor,
                        onTap: () => notifier.updateDarkBackgroundColor('#1A1A2E'),
                      ),
                      _backgroundSwatch(
                        context,
                        label: 'Pure Black',
                        colorHex: 'FF000000',
                        currentColor: settings.darkBackgroundColor,
                        onTap: () => notifier.updateDarkBackgroundColor('#000000'),
                      ),
                      _backgroundSwatch(
                        context,
                        label: 'Navy',
                        colorHex: 'FF0B1021',
                        currentColor: settings.darkBackgroundColor,
                        onTap: () => notifier.updateDarkBackgroundColor('#0B1021'),
                      ),
                      _backgroundSwatch(
                        context,
                        label: 'Plum',
                        colorHex: 'FF1A0B1C',
                        currentColor: settings.darkBackgroundColor,
                        onTap: () => notifier.updateDarkBackgroundColor('#1A0B1C'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (mode == ThemeMode.light || (mode == ThemeMode.system && Theme.of(context).brightness == Brightness.light)) ...[
            Container(
              decoration: AppTheme.cardDecoration(context),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Light Mode Background',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _backgroundSwatch(
                        context,
                        label: 'Default',
                        colorHex: AppColors.background.value.toRadixString(16).padLeft(8, '0').toUpperCase(),
                        currentColor: settings.backgroundColor,
                        onTap: () => notifier.updateLightBackgroundColor('#F8F8F8'),
                      ),
                      _backgroundSwatch(
                        context,
                        label: 'Pure White',
                        colorHex: 'FFFFFFFF',
                        currentColor: settings.backgroundColor,
                        onTap: () => notifier.updateLightBackgroundColor('#FFFFFF'),
                      ),
                      _backgroundSwatch(
                        context,
                        label: 'Warm',
                        colorHex: 'FFFFFDF8',
                        currentColor: settings.backgroundColor,
                        onTap: () => notifier.updateLightBackgroundColor('#FFFFDF8'),
                      ),
                      _backgroundSwatch(
                        context,
                        label: 'Cool',
                        colorHex: 'FFF5F7FA',
                        currentColor: settings.backgroundColor,
                        onTap: () => notifier.updateLightBackgroundColor('#F5F7FA'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          Container(
            decoration: AppTheme.cardDecoration(context),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active theme',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                ...themes.map(
                  (theme) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => notifier.updateActiveTheme(
                        themeId: theme.id,
                        accentColor: theme.accentHex,
                      ),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariantColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: activeTheme.id == theme.id
                                ? theme.accentColor
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: theme.accentColor.withValues(
                                  alpha: 0.14,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(theme.icon, color: theme.accentColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    theme.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    theme.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMutedColor(context),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (activeTheme.id == theme.id)
                              Icon(
                                Icons.check_circle_rounded,
                                color: theme.accentColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Font',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _fontChip(
                      context,
                      label: 'Inter',
                      selected: settings.fontFamily == 'Inter' || (settings.fontFamily?.isEmpty ?? true),
                      onTap: () => notifier.updateFontFamily('Inter'),
                    ),
                    _fontChip(
                      context,
                      label: 'Roboto',
                      selected: settings.fontFamily == 'Roboto',
                      onTap: () => notifier.updateFontFamily('Roboto'),
                    ),
                    _fontChip(
                      context,
                      label: 'Outfit',
                      selected: settings.fontFamily == 'Outfit',
                      onTap: () => notifier.updateFontFamily('Outfit'),
                    ),
                    _fontChip(
                      context,
                      label: 'Lora',
                      selected: settings.fontFamily == 'Lora',
                      onTap: () => notifier.updateFontFamily('Lora'),
                    ),
                    _fontChip(
                      context,
                      label: 'JetBrains Mono',
                      selected: settings.fontFamily == 'JetBrains Mono',
                      onTap: () => notifier.updateFontFamily('JetBrains Mono'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _modeChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentColor(context).withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppTheme.accentColor(context)
                : AppTheme.dividerColor(context),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppTheme.accentColor(context)
                : AppTheme.textSecondaryColor(context),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _fontChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentColor(context).withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppTheme.accentColor(context)
                : AppTheme.dividerColor(context),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppTheme.accentColor(context)
                : AppTheme.textSecondaryColor(context),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _backgroundSwatch(
    BuildContext context, {
    required String label,
    required String colorHex,
    required String? currentColor,
    required VoidCallback onTap,
  }) {
    final color = Color(int.parse(colorHex, radix: 16));
    final isSelected = (currentColor?.toUpperCase() ?? '') == colorHex.toUpperCase() ||
                       (currentColor == null && colorHex == AppColors.background.value.toRadixString(16).padLeft(8, '0').toUpperCase()) ||
                       (currentColor == null && colorHex == AppColors.darkBackground.value.toRadixString(16).padLeft(8, '0').toUpperCase());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.accentColor(context) : AppTheme.dividerColor(context),
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.accentColor(context) : AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
