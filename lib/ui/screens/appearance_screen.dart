import 'package:flutter/material.dart';

import '../theme.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: AppTheme.cardDecoration(context),
            child: ListTile(
              leading: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              ),
              title: const Text('Theme mode'),
              subtitle: Text(
                isDark
                    ? 'System selected dark mode'
                    : 'System selected light mode',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accent Colors',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _Swatch(AppColors.primary),
                    _Swatch(AppColors.info),
                    _Swatch(AppColors.habitGreen),
                    _Swatch(AppColors.warning),
                    _Swatch(AppColors.error),
                    _Swatch(AppColors.habitPink),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;

  const _Swatch(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
