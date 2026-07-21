import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../mood_settings_screen.dart';
import '../../scheduler_management_screen.dart';
import '../../day_theme_screen.dart';

class MoodSchedulesSection extends StatelessWidget {
  const MoodSchedulesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            title: const Text(
              'Mood Definitions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MoodSettingsScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            title: const Text(
              'Schedules Management',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SchedulerManagementScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            title: const Text(
              'Day Themes & Time Blocks',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DayThemeScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
