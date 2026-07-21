import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../providers/vault_provider.dart';
import '../../../../services/pomodoro_bg_service.dart';
import '../../../../services/google_drive_sync_service.dart';
import '../../../../services/google_auth_service.dart' as drive_auth;
import '../../../../services/backup_service.dart';

class SyncBackupSection extends ConsumerWidget {
  const SyncBackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      children: [
        _switchTile(context, 'Auto-Sync in Background', settings.autoSync, (value) async {
          await notifier.updateAutoSync(value);
          await PomodoroBackgroundService.setAutoSyncEnabled(value);
        }),
        _switchTile(
          context,
          'Conflicts: Keep Most Recent',
          settings.conflictKeepNewest,
          notifier.updateConflictResolution,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            leading: Icon(
              Icons.backup_rounded,
              color: AppTheme.accentColor(context),
            ),
            title: const Text(
              'Backup Now',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Creates a copy on Google Drive',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () => _performBackup(context, ref),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            leading: const Icon(
              Icons.delete_sweep_rounded,
              color: AppColors.error,
            ),
            title: const Text(
              'Clear Data Cache',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Reloads all Vault files',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              ref.invalidate(allObjectsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Cache cleared. Data will be reloaded.',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _switchTile(BuildContext context, String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.accentColor(context),
        ),
      ),
    );
  }

  Future<void> _performBackup(BuildContext context, WidgetRef ref) async {
    try {
      final backupService = ref.read(backupServiceProvider);
      final driveSync = ref.read(googleDriveSyncServiceProvider);
      final auth = ref.read(drive_auth.googleAuthServiceProvider);
      if (auth.authClient == null) {
        throw Exception('Google Drive not connected');
      }

      driveSync.init(auth.authClient!);
      final settings = ref.read(settingsProvider);

      // 1. Garantir que a pasta do vault existe no Drive
      if (settings.driveSyncFolderId.isNotEmpty) {
        await driveSync.useExistingVaultFolder(
          settings.driveSyncFolderId,
        );
      } else {
        await driveSync.setupVaultFolder(
          settings.driveSyncFolder,
        );
      }

      // 2. Criar backup local (ZIP completo com anexos)
      final zipFile = await backupService.createBackup();
      if (zipFile == null) {
        throw Exception('Failed to generate backup file');
      }

      // 3. Upload para o Drive
      await driveSync.createBackupFromFile(zipFile);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup sent to Google Drive!'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup error: $e')),
      );
    }
  }
}
