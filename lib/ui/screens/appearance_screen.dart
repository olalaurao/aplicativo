import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';
import '../../providers/settings_provider.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  static const _presets = [
    Color(0xFFF97316), // Orange (default)
    Color(0xFFFFB000), // Amber
    Color(0xFF3B82F6), // Blue
    Color(0xFF22C55E), // Green
    Color(0xFFF59E0B), // Yellow
    Color(0xFFEF4444), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFF0EA5E9), // Sky
    Color(0xFF14B8A6), // Teal
  ];

  String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final padded = clean.length == 6 ? 'FF$clean' : clean;
      return Color(int.parse(padded, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentHex = settings.accentColor.toUpperCase();

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
          // ── Theme mode ──
          Container(
            decoration: AppTheme.cardDecoration(context),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Modo de tema'),
              subtitle: Text(
                isDark ? 'Sistema escolheu modo escuro' : 'Sistema escolheu modo claro',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),

          // ── Accent Color ──
          Container(
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text(
                    'Cor de destaque',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _parseColor(currentHex),
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentHex,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'monospace'),
                  ),
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: _presets.map((color) {
                  final hex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                  final isSelected = currentHex == hex;
                  return GestureDetector(
                    onTap: () => notifier.updateAccentColor(hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 2)]
                            : [],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                          : null,
                    ),
                  );
                }).toList()),
                const SizedBox(height: 16),
                Text(
                  'A cor de destaque é aplicada em botões, ícones ativos e chips. Reinicie o app para ver a mudança completa.',
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
}

