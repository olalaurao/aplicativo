import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../theme.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../providers/vault_provider.dart';
import '../../import_vault_screen.dart';
import '../../social_bulk_import_screen.dart';

class VaultImportSection extends ConsumerStatefulWidget {
  const VaultImportSection({super.key});

  @override
  ConsumerState<VaultImportSection> createState() => _VaultImportSectionState();
}

class _VaultImportSectionState extends ConsumerState<VaultImportSection> {
  late TextEditingController _vaultNameController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _vaultNameController = TextEditingController(text: settings.vaultName);
  }

  @override
  void dispose() {
    _vaultNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Vault Folder (Local)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              settings.vaultPath.isEmpty
                  ? 'Default (Documents/Citrine)'
                  : settings.vaultPath,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Icon(
              Icons.folder_open_rounded,
              size: 20,
              color: AppTheme.accentColor(context),
            ),
            onTap: () async {
              String? result = await FilePicker.platform.getDirectoryPath();
              if (result != null) {
                final validationError = await _validateVaultPath(result);
                if (validationError != null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(validationError)),
                  );
                  return;
                }
                await notifier.updateVaultPath(result);
                await ref.read(obsidianServiceProvider).initVault(
                  settings.vaultName,
                  customPath: result,
                );
              }
            },
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Vault Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              settings.vaultName,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.edit_note_rounded, size: 20),
            onTap: () => _showVaultDialog(context, notifier),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Import Existing Vault',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Point to an existing folder and index its compatible files.',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Icon(
              Icons.drive_folder_upload_rounded,
              size: 20,
              color: AppTheme.accentColor(context),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ImportVaultScreen(),
              ),
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Import URL List',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Import social posts from a list of links.',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Icon(
              Icons.playlist_add_rounded,
              size: 20,
              color: AppTheme.accentColor(context),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SocialBulkImportScreen(),
              ),
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Native TikTok Player',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              settings.tiktokResolverEndpoint.isEmpty
                  ? 'Configure an API to extract the direct video URL'
                  : settings.tiktokResolverEndpoint,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(
              Icons.video_settings_rounded,
              size: 20,
              color: AppTheme.accentColor(context),
            ),
            onTap: () => _showTikTokResolverDialog(context, settings, notifier),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: Icon(
              Icons.today_rounded,
              color: AppTheme.accentColor(context),
            ),
            title: const Text(
              'Daily Note Format',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '${_dailyIdentifierLabel(settings.dailyNoteIdentifier)} · ${settings.dailyNoteFolder}/${_dailyPreview(settings.dailyNoteDateFormat)}',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showDailyNoteDialog(context, settings, notifier),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text('Sync Hidden Files', style: TextStyle(fontSize: 13)),
            trailing: Switch.adaptive(
              value: false,
              onChanged: (v) {},
              activeThumbColor: AppTheme.accentColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _validateVaultPath(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return 'The selected folder does not exist.';
      }
      final probe = File(
        '${dir.path}${Platform.pathSeparator}.citrine_write_test',
      );
      await probe.writeAsString('ok');
      if (await probe.exists()) {
        await probe.delete();
      }
      return null;
    } catch (e) {
      return 'No write permission for this folder: $e';
    }
  }

  void _showVaultDialog(BuildContext context, SettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vault Name'),
        content: TextField(
          controller: _vaultNameController,
          decoration: const InputDecoration(
            hintText: 'Enter your Obsidian Vault name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              notifier.updateVaultName(_vaultNameController.text);
              Navigator.pop(ctx);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showTikTokResolverDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    final endpointController = TextEditingController(
      text: settings.tiktokResolverEndpoint,
    );
    final apiKeyController = TextEditingController(
      text: settings.tiktokResolverApiKey,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Native TikTok Player'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Configure an API that returns a direct video URL. '
                'Use {url} in the endpoint to insert the TikTok link; without {url}, the app sends ?url=...',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endpointController,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  hintText: 'https://api.exemplo.com/download?url={url}',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Optional API key',
                  hintText: 'Sent in x-api-key header',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final endpoint = endpointController.text;
              final apiKey = apiKeyController.text;
              Navigator.pop(ctx);
              await notifier.updateTikTokResolverSettings(
                endpoint: endpoint,
                apiKey: apiKey,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDailyNoteDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    var identifier = settings.dailyNoteIdentifier;
    var dateFormat = settings.dailyNoteDateFormat;
    final folderController = TextEditingController(
      text: settings.dailyNoteFolder,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Daily Note Format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: identifier,
                decoration: const InputDecoration(labelText: 'Identifier'),
                items: const [
                  DropdownMenuItem(
                    value: 'filename_format',
                    child: Text('Filename'),
                  ),
                  DropdownMenuItem(value: 'folder', child: Text('Folder')),
                  DropdownMenuItem(
                    value: 'frontmatter_type',
                    child: Text('Frontmatter type: daily_note'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => identifier = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: dateFormat,
                decoration: const InputDecoration(labelText: 'Formato da data'),
                items: const [
                  DropdownMenuItem(
                    value: 'yyyy-MM-dd',
                    child: Text('YYYY-MM-DD'),
                  ),
                  DropdownMenuItem(value: 'yy-MM-dd', child: Text('YY-MM-DD')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => dateFormat = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: folderController,
                decoration: const InputDecoration(labelText: 'Pasta'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Preview: ${folderController.text.trim().isEmpty ? 'daily' : folderController.text.trim()}/${_dailyPreview(dateFormat)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final id = identifier;
                final dateFmt = dateFormat;
                final folder = folderController.text.trim().isEmpty
                    ? 'daily'
                    : folderController.text.trim();
                Navigator.pop(ctx);
                await notifier.updateDailyNoteSettings(
                  identifier: id,
                  dateFormat: dateFmt,
                  folder: folder,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _dailyIdentifierLabel(String value) {
    return switch (value) {
      'folder' => 'Folder',
      'frontmatter_type' => 'Frontmatter type',
      _ => 'Filename',
    };
  }

  String _dailyPreview(String format) {
    return format == 'yy-MM-dd' ? '26-05-27.md' : '2026-05-27.md';
  }
}
