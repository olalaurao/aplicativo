import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../theme_screen.dart';

class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        title: const Text(
          'Appearance',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text(
          'Theme, colors, and font',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ThemeScreen(),
          ),
        ),
      ),
    );
  }
}
