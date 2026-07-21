import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/app_switch_tile.dart';
import '../../providers/navigation_provider.dart';
import '../../models/navigation_item.dart';
import '../../models/task_model.dart';
import 'widgets_management_screen.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/google_calendar_provider.dart' as calendar_auth;
import 'mood_settings_screen.dart';
import 'scheduler_management_screen.dart';
import 'notification_settings_screen.dart';
import 'day_theme_screen.dart';
import 'theme_screen.dart';
import 'import_vault_screen.dart';
import 'social_bulk_import_screen.dart';
import 'color_palette_screen.dart';
import 'background_color_screen.dart';
import '../../providers/color_palette_provider.dart';
import '../../models/color_palette_model.dart';

import 'package:file_picker/file_picker.dart';
import '../../services/google_drive_sync_service.dart';
import '../../services/google_auth_service.dart' as drive_auth;
import '../../services/pomodoro_bg_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'category_management_screen.dart';
import 'type_signatures_screen.dart';
import 'diagnostic_reports_screen.dart';
import '../../models/template_model.dart';
import '../../services/permission_service.dart';
import '../../services/dataview_generator.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _vaultNameController;
  late TextEditingController _driveFolderController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _vaultNameController = TextEditingController(text: settings.vaultName);
    _driveFolderController = TextEditingController(
      text: settings.driveSyncFolder,
    );
  }

  @override
  void dispose() {
    _vaultNameController.dispose();
    _driveFolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            title: Text(
              'Settings',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            floating: true,
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _section('Profile'),
                const SizedBox(height: 12),
                Container(
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
                ),

                _section('Vault & Import'),
                const SizedBox(height: 12),
                Container(
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
                          String? result = await FilePicker.platform
                              .getDirectoryPath();
                          if (result != null) {
                            final validationError = await _validateVaultPath(
                              result,
                            );
                            if (validationError != null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(validationError)),
                              );
                              return;
                            }
                            await notifier.updateVaultPath(result);
                            await ref
                                .read(obsidianServiceProvider)
                                .initVault(
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
                        onTap: () => _showTikTokResolverDialog(
                          context,
                          settings,
                          notifier,
                        ),
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
                        onTap: () =>
                            _showDailyNoteDialog(context, settings, notifier),
                      ),
                      const Divider(height: 1, indent: 16),
                      _switchTileSimple('Sync Hidden Files', false, (v) {}),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _section('Appearance'),
                const SizedBox(height: 12),
                Container(
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
                ),
                const SizedBox(height: 24),
                _section('Google Account'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'One account powers both Calendar sync and Drive backup — signing out disables both.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                _buildGoogleAccountSignInRow(),
                const SizedBox(height: 12),
                _buildGoogleCalendarTile(),
                const SizedBox(height: 12),
                Container(
                  decoration: AppTheme.cardDecoration(context),
                  child: ListTile(
                    title: const Text(
                      'Google Drive Folder',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      settings.driveSyncFolderPath.isNotEmpty
                          ? settings.driveSyncFolderPath
                          : settings.driveSyncFolder,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.cloud_sync_rounded,
                      size: 20,
                      color: AppColors.info,
                    ),
                    onTap: () => _showDriveFolderPicker(context, notifier),
                  ),
                ),
                const SizedBox(height: 24),
                _section('Mood & Schedules'),
                const SizedBox(height: 12),
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
                const SizedBox(height: 24),
                _section('Interface Customization'),
                const SizedBox(height: 12),
                _buildBottomBarEditor(),

                const SizedBox(height: 24),
                _section('Third-Party & API Keys'),
                const SizedBox(height: 12),
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
                const SizedBox(height: 24),
                _section('Sync & Backup'),
                const SizedBox(height: 12),
                _switchTile('Auto-Sync in Background', settings.autoSync, (
                  value,
                ) async {
                  await notifier.updateAutoSync(value);
                  await PomodoroBackgroundService.setAutoSyncEnabled(value);
                }),
                _switchTile(
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
                    onTap: () async {
                      try {
                        final backupService = ref.read(
                          backupServiceProvider,
                        );
                        final driveSync = ref.read(
                          googleDriveSyncServiceProvider,
                        );
                        final auth = ref.read(
                          drive_auth.googleAuthServiceProvider,
                        );
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
                    },
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
                const SizedBox(height: 24),
                _section('Notifications'),
                const SizedBox(height: 12),
                _switchTile(
                  'Habit Reminders',
                  settings.habitReminders,
                  notifier.updateHabitReminders,
                ),
                _switchTile(
                  'Pomodoro Sounds',
                  settings.pomodoroSounds,
                  notifier.updatePomodoroSounds,
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: AppTheme.cardDecoration(context),
                  child: ListTile(
                    title: const Text(
                      'Notification Appearance',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Customize colors and buttons for popups & alarms',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                  ),
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: AppTheme.cardDecoration(context),
                    child: Column(
                      children: [
                        FutureBuilder<bool>(
                          future: PermissionService.canScheduleExactAlarms(),
                          builder: (context, snap) {
                            final granted = snap.data ?? true;
                            return ListTile(
                              leading: Icon(
                                granted
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                color: granted
                                    ? AppColors.success
                                    : AppColors.warning,
                                size: 20,
                              ),
                              title: const Text(
                                'Exact Alarm Permission',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                granted
                                    ? 'Granted — alarms fire at exact time'
                                    : 'Not granted — alarms may be delayed',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: granted
                                  ? null
                                  : TextButton(
                                      onPressed: () async {
                                        await PermissionService.showExactAlarmPermissionDialog(
                                          context,
                                        );
                                        if (mounted) setState(() {}); // Refresh status
                                      },
                                      child: const Text(
                                        'Grant',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16),
                        FutureBuilder<bool>(
                          future: PermissionService.checkFullScreenIntent(),
                          builder: (context, snap) {
                            final granted = snap.data ?? true;
                            return ListTile(
                              leading: Icon(
                                granted
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                color: granted
                                    ? AppColors.success
                                    : AppColors.warning,
                                size: 20,
                              ),
                              title: const Text(
                                'Full-Screen Notification',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                granted
                                    ? 'Granted — popups appear over lock screen'
                                    : 'Not granted — popups may not appear on lock screen',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: granted
                                  ? null
                                  : TextButton(
                                      onPressed: () async {
                                        await PermissionService.requestFullScreenIntent();
                                        if (mounted) setState(() {}); // Refresh status
                                      },
                                      child: const Text(
                                        'Grant',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _section('Planner & Tasks'),
                const SizedBox(height: 12),
                Container(
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
                          settings.plannerColorMode == 'category'
                              ? 'By Category'
                              : 'By Priority',
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
                          onChanged: (v) =>
                              notifier.updateNlpTaskParsingEnabled(v),
                          activeThumbColor: AppTheme.accentColor(context),
                        ),
                      ),
                      const Divider(height: 1, indent: 16),
                      AppSwitchTile(
                        title: 'Show Overdue Section',
                        subtitle: 'Show overdue tasks, goals, and projects',
                        value: settings.showOverdueSection,
                        onChanged: (val) =>
                            notifier.updateShowOverdueSection(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _section('Object Structure'),
                const SizedBox(height: 12),
                Container(
                  decoration: AppTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Object Identification',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Configure how tasks, habits and projects are recognized in your Vault.',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TypeSignaturesScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16),
                      _buildDailyReviewTemplateTile(),
                      const Divider(height: 1, indent: 16),
                      ListTile(
                        title: const Text(
                          'Ideas',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Configure capture strategy',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showIdeaSettingsDialog(
                          context,
                          settings,
                          notifier,
                        ),
                      ),
                      const Divider(height: 1, indent: 16),
                      ListTile(
                        title: const Text(
                          'Manage Categories',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategoryManagementScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16),
                      ListTile(
                        title: const Text(
                          'Categorization Rules',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${settings.autoCategoryRules.length} active rules',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 20,
                          color: AppColors.info,
                        ),
                        onTap: () => _showAutoCategoryRulesDialog(
                          context,
                          settings,
                          notifier,
                        ),
                      ),
                      const Divider(height: 1, indent: 16),
                      ListTile(
                        title: const Text(
                          'Category Colors',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${settings.categoryColors.length} custom colors',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.color_lens_outlined,
                          size: 20,
                          color: AppColors.warning,
                        ),
                        onTap: () => _showCategoryColorsDialog(
                          context,
                          settings,
                          notifier,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _section('Obsidian Tools'),
                const SizedBox(height: 12),
                Container(
                  decoration: AppTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.auto_fix_high_rounded,
                          color: AppTheme.accentColor(context),
                        ),
                        title: const Text(
                          'Regenerate Dataview Queries',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Generates index.md with Dataview queries in each vault folder',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _regenerateDataview(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _section('Diagnostics & Maintenance'),
                const SizedBox(height: 12),
                Container(
                  decoration: AppTheme.cardDecoration(context),
                  child: ListTile(
                    leading: Icon(
                      Icons.assessment_rounded,
                      color: AppTheme.accentColor(context),
                    ),
                    title: const Text(
                      'Diagnostic Reports',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'View system health and performance metrics',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DiagnosticReportsScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: AppTheme.cardDecoration(context),
                  child: ListTile(
                    leading: Icon(
                      Icons.widgets_rounded,
                      color: AppTheme.accentColor(context),
                    ),
                    title: const Text(
                      'Widgets',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Manage home screen widgets',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WidgetsManagementScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _section('About'),
                const SizedBox(height: 12),
                Container(
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
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
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

  Future<void> _regenerateDataview(BuildContext context) async {
    final obsidian = ref.read(obsidianServiceProvider);
    final gen = DataviewGenerator(obsidian);
    final projects = ref.read(projectsProvider);
    final allObjects = ref.read(allObjectsProvider).value ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    try {
      await gen.regenerateAll(projects: projects, tasks: tasks);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dataview queries regenerated successfully!'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error regenerating: $e')));
    }
  }

  Widget _buildBottomBarEditor() {
    final navItemsAsync = ref.watch(navigationProvider);
    final navItems = navItemsAsync.valueOrNull ?? [];
    final notifier = ref.read(navigationProvider.notifier);

    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 8),
                Text(
                  'Bottom Bar Tabs',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Drag to reorder. Select up to 5 tabs.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: navItems.length,
            onReorder: notifier.reorder,
            itemBuilder: (context, index) {
              final item = navItems[index];
              final isPinned =
                  item.section == NavSection.home ||
                  item.section == NavSection.more;

              return ListTile(
                key: ValueKey(
                  item.isCustom ? item.id ?? item.route : item.section.name,
                ),
                leading: Icon(
                  item.icon,
                  color: item.inBottomBar
                      ? AppTheme.accentColor(context)
                      : AppColors.textMuted,
                ),
                title: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: item.inBottomBar
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPinned)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      Switch.adaptive(
                        value: item.inBottomBar,
                        onChanged: (_) => notifier.toggleInBottomBar(
                          item.isCustom ? item.id : item.section,
                        ),
                        activeThumbColor: AppTheme.accentColor(context),
                      ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
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

  Widget _switchTileSimple(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 13)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.accentColor(context),
      ),
    );
  }

  Widget _buildDailyReviewTemplateTile() {
    final settings = ref.watch(settingsProvider);
    final templates = ref.watch(templatesProvider);
    final entryTemplates = templates
        .where((t) => t.templateType == 'entry')
        .toList();

    final selectedTemplate = entryTemplates
        .cast<TemplateDefinition?>()
        .firstWhere(
          (t) => t?.id == settings.reviewDailyTemplateId,
          orElse: () => null,
        );

    return ListTile(
      title: const Text(
        'Template de Daily Review',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        selectedTemplate != null
            ? 'Ativo: ${selectedTemplate.title}'
            : 'Nenhum template selecionado',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Icon(
        Icons.rate_review_outlined,
        size: 20,
        color: AppTheme.accentColor(context),
      ),
      onTap: () => _showDailyReviewTemplatePicker(
        context,
        entryTemplates,
        settings.reviewDailyTemplateId,
      ),
    );
  }

  void _showDailyReviewTemplatePicker(
    BuildContext context,
    List<TemplateDefinition> entryTemplates,
    String currentId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Select Daily Review Template',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: entryTemplates.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              'Nenhum template de Entry encontrado.\nCrie um template em Templates primeiro.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: entryTemplates.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              final isSelected = currentId.isEmpty;
                              return ListTile(
                                title: const Text(
                                  'Nenhum',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: AppTheme.accentColor(context),
                                      )
                                    : null,
                                onTap: () {
                                  ref
                                      .read(settingsProvider.notifier)
                                      .updateReviewDailyTemplateId('');
                                  Navigator.pop(ctx);
                                },
                              );
                            }
                            final template = entryTemplates[index - 1];
                            final isSelected = template.id == currentId;
                            return ListTile(
                              title: Text(
                                template.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: const Text(
                                'Daily review prompt',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: AppTheme.accentColor(context),
                                    )
                                  : null,
                              onTap: () {
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateReviewDailyTemplateId(template.id);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
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

  void _showIdeaSettingsDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    String currentStrategy = settings.ideaStrategy;
    final tagController = TextEditingController(text: settings.ideaTag);
    final folderController = TextEditingController(text: settings.ideaFolder);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Idea Configuration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How should the system recognize an idea?'),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: currentStrategy,
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => currentStrategy = v);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RadioListTile<String>(
                        title: Text('By Tag'),
                        value: 'tag',
                      ),
                      if (currentStrategy == 'tag')
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 32,
                            right: 16,
                            bottom: 8,
                          ),
                          child: TextField(
                            controller: tagController,
                            decoration: const InputDecoration(
                              labelText: 'Tag (without #)',
                            ),
                          ),
                        ),
                      const RadioListTile<String>(
                        title: Text('By Folder'),
                        value: 'folder',
                      ),
                      if (currentStrategy == 'folder')
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 32,
                            right: 16,
                            bottom: 8,
                          ),
                          child: TextField(
                            controller: folderController,
                            decoration: const InputDecoration(
                              labelText: 'Folder Path',
                            ),
                          ),
                        ),
                      const RadioListTile<String>(
                        title: Text('Any Note'),
                        value: 'any_note',
                      ),
                    ],
                  ),
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
                final strategy = currentStrategy;
                final tag = tagController.text.trim();
                final folder = folderController.text.trim();
                Navigator.pop(ctx);
                await notifier.setIdeaStrategy(
                  strategy: strategy,
                  tag: tag,
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

  void _showManualDriveFolderDialog(
    BuildContext context,
    SettingsNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create/use folder by name'),
        content: TextField(
          controller: _driveFolderController,
          decoration: const InputDecoration(hintText: 'Sync folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              notifier.updateDriveSyncFolder(_driveFolderController.text);
              Navigator.pop(ctx);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
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
              ref.read(googleBooksApiKeyProvider.notifier).state = value;
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


  Future<void> _showDriveFolderPicker(
    BuildContext context,
    SettingsNotifier notifier,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = ref.read(drive_auth.googleAuthServiceProvider);
      final client = auth.authClient ?? await auth.signIn();
      if (client == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Connect Google Drive first.')),
        );
        return;
      }

      final driveSync = ref.read(googleDriveSyncServiceProvider);
      driveSync.init(client);

      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => _DriveFolderPickerDialog(
          driveSync: driveSync,
          onManualName: () {
            Navigator.pop(dialogContext);
            _showManualDriveFolderDialog(context, notifier);
          },
          onSelected: (folder, path) async {
            final id = folder.id;
            final name = folder.name;
            if (id == null || name == null) return;
            await notifier.updateDriveSyncFolderSelection(
              id: id,
              name: name,
              path: path,
            );
            await driveSync.useExistingVaultFolder(id);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Drive folder selected: $path')),
              );
            }
          },
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error listing Drive folders: $e')),
      );
    }
  }

  void _showColorModeDialog(
    BuildContext context,
    SettingsNotifier notifier,
    String currentMode,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Color Scheme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                currentMode == 'category'
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: currentMode == 'category'
                    ? AppTheme.accentColor(context)
                    : AppColors.textMuted,
              ),
              title: const Text('By Category'),
              onTap: () {
                notifier.updatePlannerColorMode('category');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                currentMode == 'priority'
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: currentMode == 'priority'
                    ? AppTheme.accentColor(context)
                    : AppColors.textMuted,
              ),
              title: const Text('By Priority'),
              onTap: () {
                notifier.updatePlannerColorMode('priority');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
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

  void _showAutoCategoryRulesDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    final patternController = TextEditingController();
    final categoryController = TextEditingController();
    String targetType = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            children: [
              const Text(
                'Auto-Categorization Rules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: settings.autoCategoryRules.isEmpty
                    ? const Center(
                        child: Text(
                          'No rules created.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: settings.autoCategoryRules.length,
                        itemBuilder: (c, i) {
                          final rule = settings.autoCategoryRules[i];
                          return ListTile(
                            title: Text(rule.pattern),
                            subtitle: Text(
                              '${rule.targetType} -> ${rule.category}',
                            ),
                          );
                        },
                      ),
              ),
              const Divider(),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Pattern',
                  hintText: 'Example: #work or project',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: '[[work]]',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: targetType,
                decoration: const InputDecoration(labelText: 'Target type'),
                items:
                    const [
                          'all',
                          'task',
                          'habit',
                          'note',
                          'entry',
                          'project',
                          'resource',
                        ]
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                onChanged: (value) =>
                    setModalState(() => targetType = value ?? 'all'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final pattern = patternController.text.trim();
                    final category = categoryController.text.trim();
                    if (pattern.isEmpty || category.isEmpty) return;
                    await notifier.addAutoCategoryRule(
                      AutoCategoryRule(
                        pattern: pattern,
                        category: category,
                        targetType: targetType,
                      ),
                    );
                    patternController.clear();
                    categoryController.clear();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('ADD RULE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryColorsDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    final categoryController = TextEditingController();
    String selectedColor = '#8B5CF6';
    const swatches = [
      '#EF4444',
      '#F97316',
      '#F59E0B',
      '#10B981',
      '#06B6D4',
      '#3B82F6',
      '#8B5CF6',
      '#EC4899',
      '#6B7280',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Category Colors',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (settings.categoryColors.isNotEmpty)
                ...settings.categoryColors.entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Color(
                        int.parse(entry.value.replaceAll('#', '0xFF')),
                      ),
                    ),
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                  ),
                ),
              const Divider(),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: '[[work]]',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: swatches.map((hex) {
                  final selected = selectedColor == hex;
                  final color = Color(int.parse(hex.replaceAll('#', '0xFF')));
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final category = categoryController.text.trim();
                    if (category.isEmpty) return;
                    await notifier.updateCategoryColor(category, selectedColor);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('SAVE COLOR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleAccountSignInRow() {
    final authAccount = ref.watch(calendar_auth.googleAuthServiceProvider);
    final authNotifier = ref.read(calendar_auth.googleAuthServiceProvider.notifier);
    final isSignedIn = authAccount != null;

    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isSignedIn
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded,
            size: 18,
            color: AppColors.info,
          ),
        ),
        title: Text(
          isSignedIn ? 'Signed in as ${authAccount!.email}' : 'Sign in to Google',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          isSignedIn ? 'Connected to Calendar and Drive' : 'Tap to connect',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isSignedIn
            ? TextButton(
                onPressed: () => authNotifier.signOut(),
                child: const Text(
                  'Sign out',
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                ),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          if (isSignedIn) {
            await authNotifier.signOut();
          } else {
            await authNotifier.signIn();
          }
        },
      ),
    );
  }

  Widget _buildGoogleCalendarTile() {
    final googleUser = ref.watch(calendar_auth.googleAuthServiceProvider);
    final authNotifier = ref.read(
      calendar_auth.googleAuthServiceProvider.notifier,
    );
    final calendarsAsync = ref.watch(calendar_auth.googleCalendarListProvider);
    final visibilityAsync = ref.watch(
      calendar_auth.googleCalendarVisibilityProvider,
    );

    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.calendar_month_rounded,
              color: AppTheme.accentColor(context),
            ),
            title: const Text(
              'Google Calendar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              googleUser != null
                  ? 'Connected as ${googleUser.email}'
                  : 'Not connected',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: googleUser != null
                ? TextButton(
                    onPressed: () => authNotifier.signOut(),
                    child: const Text(
                      'DISCONNECT',
                      style: TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                  )
                : TextButton(
                    onPressed: () => authNotifier.signIn(),
                    child: Text(
                      'CONNECT',
                      style: TextStyle(fontSize: 11, color: AppTheme.accentColor(context)),
                    ),
                  ),
          ),
          if (googleUser != null)
            calendarsAsync.when(
              data: (calendars) {
                final defaultEnabled = calendars
                    .where((entry) => entry.selected != false)
                    .map((entry) => entry.id)
                    .whereType<String>()
                    .toSet();
                final configured = visibilityAsync.valueOrNull;
                final enabled = configured ?? defaultEnabled;

                if (calendars.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No calendars found.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: calendars.map((calendar) {
                      final id = calendar.id;
                      if (id == null) return const SizedBox.shrink();
                      final title = calendar.summary ?? id;
                      return AppSwitchTile(
                        title: title,
                        subtitle: calendar.primary == true
                            ? 'Primary calendar'
                            : id,
                        value: enabled.contains(id),
                        onChanged: (_) => ref
                            .read(
                              calendar_auth
                                  .googleCalendarVisibilityProvider
                                  .notifier,
                            )
                            .toggleCalendar(
                              id,
                              defaultEnabledIds: defaultEnabled,
                            ),
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Failed to load calendars: $error',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
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
}

class _DriveFolderPickerDialog extends StatefulWidget {
  final GoogleDriveSyncService driveSync;
  final VoidCallback onManualName;
  final Future<void> Function(drive.File folder, String path) onSelected;

  const _DriveFolderPickerDialog({
    required this.driveSync,
    required this.onManualName,
    required this.onSelected,
  });

  @override
  State<_DriveFolderPickerDialog> createState() =>
      _DriveFolderPickerDialogState();
}

class _DriveFolderPickerDialogState extends State<_DriveFolderPickerDialog> {
  final List<({String id, String name})> _trail = [];
  late Future<List<drive.File>> _foldersFuture = _loadFolders();

  String get _currentPath {
    if (_trail.isEmpty) return 'Google Drive';
    return _trail.map((item) => item.name).join('/');
  }

  Future<List<drive.File>> _loadFolders() async {
    final parentId = _trail.isEmpty ? null : _trail.last.id;
    final folders = await widget.driveSync.listFolders(parentId: parentId);
    if (_trail.isEmpty) {
      final shared = await widget.driveSync.listSharedFolders();
      final byId = <String, drive.File>{};
      for (final folder in [...folders, ...shared]) {
        final id = folder.id;
        if (id != null) byId[id] = folder;
      }
      return byId.values.toList()
        ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    }
    return folders;
  }

  void _openFolder(drive.File folder) {
    final id = folder.id;
    final name = folder.name;
    if (id == null || name == null) return;
    setState(() {
      _trail.add((id: id, name: name));
      _foldersFuture = _loadFolders();
    });
  }

  void _goBack() {
    if (_trail.isEmpty) return;
    setState(() {
      _trail.removeLast();
      _foldersFuture = _loadFolders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Drive folder'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: _trail.isEmpty ? null : _goBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    _currentPath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<drive.File>>(
                future: _foldersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final folders = snapshot.data ?? [];
                  if (folders.isEmpty) {
                    return const Center(child: Text('No subfolders found.'));
                  }
                  return ListView.separated(
                    itemCount: folders.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      final name = folder.name ?? 'Unnamed folder';
                      return ListTile(
                        leading: const Icon(Icons.folder_rounded),
                        title: Text(name),
                        subtitle: folder.parents == null
                            ? const Text('Shared with me')
                            : null,
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Open folder',
                              icon: const Icon(Icons.chevron_right_rounded),
                              onPressed: () => _openFolder(folder),
                            ),
                            IconButton(
                              tooltip: 'Use this folder',
                              icon: const Icon(Icons.check_rounded),
                              onPressed: () {
                                final selectedPath = _trail.isEmpty
                                    ? name
                                    : '${_trail.map((item) => item.name).join('/')}/$name';
                                widget.onSelected(folder, selectedPath);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onManualName,
          child: const Text('TYPE NAME'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}
