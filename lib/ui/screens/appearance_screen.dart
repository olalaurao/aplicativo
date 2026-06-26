import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        title: const Text('Aparência'),
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
                        'Modo de tema',
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
                    ThemeMode.light => 'Tema claro fixo',
                    ThemeMode.dark => 'Tema escuro fixo',
                    ThemeMode.system => 'Segue a configuração do sistema',
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
                      label: 'Sistema',
                      selected: mode == ThemeMode.system,
                      onTap: () => notifier.updateThemeMode('system'),
                    ),
                    _modeChip(
                      context,
                      label: 'Claro',
                      selected: mode == ThemeMode.light,
                      onTap: () => notifier.updateThemeMode('light'),
                    ),
                    _modeChip(
                      context,
                      label: 'Escuro',
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
                      'Tema ativo',
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
                  'A seleção é salva nas preferências do app e aplicada imediatamente.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedColor(context),
                    height: 1.4,
                  ),
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
}
