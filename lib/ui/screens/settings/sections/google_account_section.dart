import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../providers/vault_provider.dart';
import '../../../../providers/google_calendar_provider.dart' as calendar_auth;
import '../../../../services/google_drive_sync_service.dart';
import '../../../../services/google_auth_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleAccountSection extends ConsumerStatefulWidget {
  const GoogleAccountSection({super.key});

  @override
  ConsumerState<GoogleAccountSection> createState() => _GoogleAccountSectionState();
}

class _GoogleAccountSectionState extends ConsumerState<GoogleAccountSection> {
  late TextEditingController _driveFolderController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _driveFolderController = TextEditingController(
      text: settings.driveSyncFolder,
    );
  }

  @override
  void dispose() {
    _driveFolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      children: [
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
      ],
    );
  }

  Widget _buildGoogleAccountSignInRow() {
    final authService = ref.watch(googleAuthServiceProvider);
    final isSignedIn = authService.isSignedIn;

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
          isSignedIn ? 'Signed in as ${authService.currentUser?.email ?? 'Unknown'}' : 'Sign in to Google',
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
                onPressed: () => authService.signOut(),
                child: const Text(
                  'Sign out',
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                ),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          if (isSignedIn) {
            await authService.signOut();
          } else {
            await authService.signIn();
          }
        },
      ),
    );
  }

  Widget _buildGoogleCalendarTile() {
    final authService = ref.watch(googleAuthServiceProvider);
    final isSignedIn = authService.isSignedIn;
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
              isSignedIn
                  ? 'Connected as ${authService.currentUser?.email ?? 'Unknown'}'
                  : 'Not connected',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: isSignedIn
                ? TextButton(
                    onPressed: () => authService.signOut(),
                    child: const Text(
                      'DISCONNECT',
                      style: TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                  )
                : TextButton(
                    onPressed: () => authService.signIn(),
                    child: Text(
                      'CONNECT',
                      style: TextStyle(fontSize: 11, color: AppTheme.accentColor(context)),
                    ),
                  ),
          ),
          if (isSignedIn)
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
                      return ListTile(
                        title: Text(title),
                        subtitle: calendar.primary == true
                            ? const Text('Primary calendar')
                            : Text(id),
                        trailing: Switch.adaptive(
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
                          activeThumbColor: AppTheme.accentColor(context),
                        ),
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

  Future<void> _showDriveFolderPicker(
    BuildContext context,
    SettingsNotifier notifier,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = ref.read(googleAuthServiceProvider);
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
