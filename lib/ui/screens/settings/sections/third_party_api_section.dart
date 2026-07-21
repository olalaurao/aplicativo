import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../../providers/settings_provider.dart';

class ThirdPartyApiSection extends ConsumerWidget {
  const ThirdPartyApiSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      children: [
        Container(
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            title: const Text(
              'Google Books API Key',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              settings.googleBooksApiKey.isEmpty
                  ? 'Required to search and save books from posts'
                  : 'Configured',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Icon(
              Icons.key_rounded,
              size: 20,
              color: AppTheme.accentColor(context),
            ),
            onTap: () => _showGoogleBooksApiKeyDialog(
              context,
              settings,
              notifier,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            title: const Text(
              'OMDb API Key (IMDb)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              settings.omdbApiKey.isEmpty
                  ? 'Needed for IMDb title/poster (free at omdbapi.com)'
                  : 'Configured ✓',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Icon(
              Icons.movie_outlined,
              size: 20,
              color: settings.omdbApiKey.isEmpty ? AppColors.warning : AppTheme.accentColor(context),
            ),
            onTap: () => _showOmdbApiKeyDialog(context, settings, notifier),
          ),
        ),
      ],
    );
  }

  void _showGoogleBooksApiKeyDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    final controller = TextEditingController(text: settings.googleBooksApiKey);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Google Books API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'AIza...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = controller.text.trim();
              Navigator.pop(context);
              await notifier.updateGoogleBooksApiKey(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showOmdbApiKeyDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    final controller = TextEditingController(text: settings.omdbApiKey);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('OMDb API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'e.g. 1a2b3c4d',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = controller.text.trim();
              Navigator.pop(context);
              await notifier.updateOmdbApiKey(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
