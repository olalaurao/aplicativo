import 'package:flutter/material.dart';
import '../../../theme.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        leading: Icon(
          Icons.info_outline_rounded,
          color: AppTheme.accentColor(context),
        ),
        title: const Text(
          'About Citrine',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text(
          'Version 1.0.0',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showAboutDialog(
          context: context,
          applicationName: 'Citrine',
          applicationVersion: '1.0.0',
          applicationIcon: Icon(
            Icons.auto_awesome_rounded,
            color: AppTheme.accentColor(context),
            size: 48,
          ),
          children: [const Text('Your personal vault and productivity assistant.')],
        ),
      ),
    );
  }
}
