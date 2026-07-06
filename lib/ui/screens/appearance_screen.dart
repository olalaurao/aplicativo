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
    final currentHex = settings.accentColor.toUpperCase();
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
                const SizedBox(height: 8),
                Text(
                  switch (mode) {
                    ThemeMode.light => 'Fixed light theme',
                    ThemeMode.dark => 'Fixed dark theme',
                    ThemeMode.system => 'Follow system setting',
                  },
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedColor(context),
                  ),
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
          Container(
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Active theme',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: activeTheme.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentHex,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activeTheme.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedColor(context),
                    height: 1.4,
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
                const SizedBox(height: 4),
                Text(
                  'Selection is saved in app preferences and applied immediately.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedColor(context),
                    height: 1.4,
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
                      selected: activeTheme.fontFamily == 'Inter',
                      onTap: () => _updateFont(context, ref, 'Inter'),
                    ),
                    _fontChip(
                      context,
                      label: 'Roboto',
                      selected: activeTheme.fontFamily == 'Roboto',
                      onTap: () => _updateFont(context, ref, 'Roboto'),
                    ),
                    _fontChip(
                      context,
                      label: 'Open Sans',
                      selected: activeTheme.fontFamily == 'OpenSans',
                      onTap: () => _updateFont(context, ref, 'OpenSans'),
                    ),
                    _fontChip(
                      context,
                      label: 'Lato',
                      selected: activeTheme.fontFamily == 'Lato',
                      onTap: () => _updateFont(context, ref, 'Lato'),
                    ),
                    _fontChip(
                      context,
                      label: 'Poppins',
                      selected: activeTheme.fontFamily == 'Poppins',
                      onTap: () => _updateFont(context, ref, 'Poppins'),
                    ),
                  ],
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
                  'Background color',
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
                    _colorChip(
                      context,
                      color: const Color(0xFFF8F9FB),
                      selected: activeTheme.backgroundColor == const Color(0xFFF8F9FB),
                      onTap: () => _updateBackgroundColor(context, ref, const Color(0xFFF8F9FB)),
                    ),
                    _colorChip(
                      context,
                      color: const Color(0xFFFFFBF0),
                      selected: activeTheme.backgroundColor == const Color(0xFFFFFBF0),
                      onTap: () => _updateBackgroundColor(context, ref, const Color(0xFFFFFBF0)),
                    ),
                    _colorChip(
                      context,
                      color: const Color(0xFFF0F9FF),
                      selected: activeTheme.backgroundColor == const Color(0xFFF0F9FF),
                      onTap: () => _updateBackgroundColor(context, ref, const Color(0xFFF0F9FF)),
                    ),
                    _colorChip(
                      context,
                      color: const Color(0xFFF0FDF4),
                      selected: activeTheme.backgroundColor == const Color(0xFFF0FDF4),
                      onTap: () => _updateBackgroundColor(context, ref, const Color(0xFFF0FDF4)),
                    ),
                    _colorChip(
                      context,
                      color: const Color(0xFFFDF2F8),
                      selected: activeTheme.backgroundColor == const Color(0xFFFDF2F8),
                      onTap: () => _updateBackgroundColor(context, ref, const Color(0xFFFDF2F8)),
                    ),
                    _colorChip(
                      context,
                      color: const Color(0xFFF5F3FF),
                      selected: activeTheme.backgroundColor == const Color(0xFFF5F3FF),
                      onTap: () => _updateBackgroundColor(context, ref, const Color(0xFFF5F3FF)),
                    ),
                    _colorChip(
                      context,
                      color: Colors.white,
                      selected: activeTheme.backgroundColor == Colors.white,
                      onTap: () => _updateBackgroundColor(context, ref, Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : AppTheme.textSecondaryColor(context),
      ),
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.28)
            : Theme.of(context).dividerColor,
      ),
      backgroundColor: AppTheme.surfaceVariantColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      showCheckmark: false,
    );
  }

  Widget _fontChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : AppTheme.textSecondaryColor(context),
      ),
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.28)
            : Theme.of(context).dividerColor,
      ),
      backgroundColor: AppTheme.surfaceVariantColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      showCheckmark: false,
    );
  }

  Widget _colorChip(
    BuildContext context, {
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              )
            : null,
      ),
    );
  }

  void _updateFont(BuildContext context, WidgetRef ref, String fontFamily) {
    final settings = ref.read(settingsProvider);
    final activeTheme = ref.read(activeThemeConfigProvider);
    final updatedTheme = AppThemeConfig(
      id: activeTheme.id,
      label: activeTheme.label,
      accentColor: activeTheme.accentColor,
      backgroundColor: activeTheme.backgroundColor,
      icon: activeTheme.icon,
      description: activeTheme.description,
      fontFamily: fontFamily,
    );
    ref.read(settingsProvider.notifier).updateCustomTheme(updatedTheme);
  }

  void _updateBackgroundColor(BuildContext context, WidgetRef ref, Color backgroundColor) {
    final settings = ref.read(settingsProvider);
    final activeTheme = ref.read(activeThemeConfigProvider);
    final updatedTheme = AppThemeConfig(
      id: activeTheme.id,
      label: activeTheme.label,
      accentColor: activeTheme.accentColor,
      backgroundColor: backgroundColor,
      icon: activeTheme.icon,
      description: activeTheme.description,
      fontFamily: activeTheme.fontFamily,
    );
    ref.read(settingsProvider.notifier).updateCustomTheme(updatedTheme);
  }
}
