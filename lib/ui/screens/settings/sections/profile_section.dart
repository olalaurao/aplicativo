import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../../providers/settings_provider.dart';

class ProfileSection extends ConsumerWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Container(
      decoration: AppTheme.cardDecoration(context),
      margin: const EdgeInsets.only(bottom: 24),
      child: ListTile(
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.accentColor(context).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: AppTheme.accentColor(context),
          ),
        ),
        title: const Text(
          'Your name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          settings.userName?.isNotEmpty == true
              ? settings.userName!
              : 'What should I call you?',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(
          Icons.edit_rounded,
          size: 16,
          color: AppColors.textMuted,
        ),
        onTap: () => _editUserName(context, settings, notifier),
      ),
    );
  }

  Future<void> _editUserName(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) async {
    final ctrl = TextEditingController(text: settings.userName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'What should I call you?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentColor(context)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) await notifier.setUserName(result);
  }
}
