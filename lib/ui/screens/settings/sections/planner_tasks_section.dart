import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../ui/widgets/app_switch_tile.dart';

class PlannerTasksSection extends ConsumerWidget {
  const PlannerTasksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Color Scheme',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              _plannerColorModeLabel(settings.plannerColorMode),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Icon(
              Icons.palette_outlined,
              size: 20,
              color: AppTheme.accentColor(context),
            ),
            onTap: () => _showColorModeDialog(
              context,
              notifier,
              settings.plannerColorMode,
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Start of Week',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              settings.startOfWeek == 1 ? 'Monday' : 'Sunday',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(
              Icons.calendar_view_week_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
            onTap: () => _showStartOfWeekDialog(
              context,
              notifier,
              settings.startOfWeek,
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Natural Language Task Parsing',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Detect dates, times, and priorities as you type tasks',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Switch.adaptive(
              value: settings.nlpTaskParsingEnabled,
              onChanged: (v) => notifier.updateNlpTaskParsingEnabled(v),
              activeThumbColor: AppTheme.accentColor(context),
            ),
          ),
          const Divider(height: 1, indent: 16),
          AppSwitchTile(
            title: 'Show Overdue Section',
            subtitle: 'Show overdue tasks, goals, and projects',
            value: settings.showOverdueSection,
            onChanged: (val) => notifier.updateShowOverdueSection(val),
          ),
        ],
      ),
    );
  }

  void _showColorModeDialog(
    BuildContext context,
    SettingsNotifier notifier,
    String currentMode,
  ) {
    final options = [
      ('category', 'Category Colors'),
      ('type', 'Type Colors'),
      ('default', 'Default Colors'),
    ];
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Color Scheme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final value = opt.$1;
            final label = opt.$2;
            return ListTile(
              leading: Icon(
                currentMode == value
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: currentMode == value
                    ? AppTheme.accentColor(context)
                    : AppColors.textMuted,
              ),
              title: Text(label),
              onTap: () {
                notifier.updatePlannerColorMode(value);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _plannerColorModeLabel(String mode) {
    switch (mode) {
      case 'category':
        return 'Category Colors';
      case 'type':
        return 'Type Colors';
      case 'default':
        return 'Default Colors';
      default:
        return 'Category Colors';
    }
  }

  void _showStartOfWeekDialog(
    BuildContext context,
    SettingsNotifier notifier,
    int current,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start of Week'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                current == 1
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: current == 1 ? AppTheme.accentColor(context) : AppColors.textMuted,
              ),
              title: const Text('Monday'),
              onTap: () {
                notifier.updatePlannerSettings(startOfWeek: 1);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                current == 7
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: current == 7 ? AppTheme.accentColor(context) : AppColors.textMuted,
              ),
              title: const Text('Sunday'),
              onTap: () {
                notifier.updatePlannerSettings(startOfWeek: 7);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
