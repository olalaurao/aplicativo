import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/google_auth_service.dart' as auth;

class PersistedSyncConflict {
  final String relativePath;
  final String localPath;
  final String remotePath;
  final DateTime detectedAt;

  const PersistedSyncConflict({
    required this.relativePath,
    required this.localPath,
    required this.remotePath,
    required this.detectedAt,
  });

  factory PersistedSyncConflict.fromMap(Map<String, dynamic> map) {
    return PersistedSyncConflict(
      relativePath: map['relativePath'] as String? ?? '',
      localPath: map['localPath'] as String? ?? '',
      remotePath: map['remotePath'] as String? ?? '',
      detectedAt: DateTime.fromMillisecondsSinceEpoch(
        map['detectedAt'] as int? ?? 0,
      ),
    );
  }
}

final persistedSyncConflictsProvider =
    FutureProvider.autoDispose<List<PersistedSyncConflict>>((ref) async {
      final rows = await ref.read(syncQueueServiceProvider).getConflicts();
      return rows.map(PersistedSyncConflict.fromMap).toList();
    });

class SyncConflictsScreen extends ConsumerStatefulWidget {
  const SyncConflictsScreen({super.key});

  @override
  ConsumerState<SyncConflictsScreen> createState() => _SyncConflictsScreenState();
}

class _SyncConflictsScreenState extends ConsumerState<SyncConflictsScreen> {
  bool _isResolvingAll = false;

  @override
  Widget build(BuildContext context) {
    final conflictsAsync = ref.watch(persistedSyncConflictsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conflitos de sincronização'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: conflictsAsync.when(
          data: (conflicts) {
            if (conflicts.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_done_rounded,
                        size: 48,
                        color: AppColors.success,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Nenhum conflito pendente',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                if (conflicts.isNotEmpty && !_isResolvingAll)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardFillColor(context),
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.dividerColor(context),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _resolveAll(context, conflicts, keepLocal: true),
                            icon: const Icon(Icons.phone_android, size: 18),
                            label: const Text(
                              'Manter todos local',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _resolveAll(context, conflicts, keepLocal: false),
                            icon: const Icon(Icons.cloud, size: 18),
                            label: const Text(
                              'Manter todos Drive',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isResolvingAll)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Resolvendo conflitos...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: conflicts.length,
                    itemBuilder: (context, index) {
                      return _ConflictCard(conflict: conflicts[index]);
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erro ao carregar conflitos: $error',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resolveAll(
    BuildContext context,
    List<PersistedSyncConflict> conflicts, {
    required bool keepLocal,
  }) async {
    setState(() {
      _isResolvingAll = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    int resolved = 0;
    int failed = 0;

    try {
      final obsidian = ref.read(obsidianServiceProvider);
      final queue = ref.read(syncQueueServiceProvider);
      final driveSync = ref.read(googleDriveSyncServiceProvider);
      final authService = ref.read(auth.googleAuthServiceProvider);
      final settings = ref.read(settingsProvider);
      final backupService = ref.read(backupServiceProvider);

      final client = await authService.ensureClient();
      if (client == null) {
        throw Exception('Google Drive não está conectado');
      }

      driveSync.init(client);
      if (settings.driveSyncFolderId.isNotEmpty) {
        await driveSync.useExistingVaultFolder(settings.driveSyncFolderId);
      } else {
        await driveSync.setupVaultFolder(settings.driveSyncFolder);
      }

      final zipFile = await backupService.createBackup();
      if (zipFile != null) {
        await driveSync.createBackupFromFile(zipFile);
      }

      for (final conflict in conflicts) {
        try {
          final sourcePath = keepLocal ? conflict.localPath : conflict.remotePath;
          final chosenContent = await obsidian.readFile(sourcePath);
          if (chosenContent == null) {
            failed++;
            debugPrint('Failed to resolve ${conflict.relativePath}: version not found');
            continue;
          }

          await obsidian.writeFile(conflict.relativePath, chosenContent);
          final hash = driveSync.calculateHash(chosenContent);
          final uploaded = await driveSync.syncFile(
            conflict.relativePath,
            chosenContent,
            hash,
          );
          if (!uploaded) {
            failed++;
            debugPrint('Failed to resolve ${conflict.relativePath}: upload failed');
            continue;
          }

          await queue.upsertFileSyncState(
            relativePath: conflict.relativePath,
            localHash: hash,
            remoteHash: hash,
            baseHash: hash,
          );
          await queue.removeConflict(conflict.relativePath);

          ref
              .read(syncConflictsProvider.notifier)
              .removeConflict(conflict.relativePath);
          resolved++;
        } catch (e) {
          failed++;
          debugPrint('Failed to resolve ${conflict.relativePath}: $e');
        }
      }

      ref.invalidate(persistedSyncConflictsProvider);
      ref.invalidate(allObjectsProvider);

      final remaining = await queue.getConflicts();
      ref
          .read(syncStatusProvider.notifier)
          .setStatus(
            remaining.isEmpty ? SyncStatus.synced : SyncStatus.conflict,
          );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            keepLocal
                ? 'Resolvidos: $resolved, Falharam: $failed (versão local)'
                : 'Resolvidos: $resolved, Falharam: $failed (versão Drive)',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to resolve all conflicts: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao resolver conflitos: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingAll = false;
        });
      }
    }
  }
}

class _ConflictCard extends ConsumerStatefulWidget {
  final PersistedSyncConflict conflict;

  const _ConflictCard({required this.conflict});

  @override
  ConsumerState<_ConflictCard> createState() => _ConflictCardState();
}

class _ConflictCardState extends ConsumerState<_ConflictCard> {
  bool _isResolving = false;

  @override
  Widget build(BuildContext context) {
    final obsidian = ref.watch(obsidianServiceProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.conflict.relativePath,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(widget.conflict.detectedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<String?>>(
            future: Future.wait([
              obsidian.readFile(widget.conflict.localPath),
              obsidian.readFile(widget.conflict.remotePath),
            ]),
            builder: (context, snapshot) {
              final local = snapshot.data?[0] ?? '';
              final remote = snapshot.data?[1] ?? '';

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PreviewBox(
                          title: 'Local',
                          content: local,
                          color: AppTheme.accentColor(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PreviewBox(
                          title: 'Drive',
                          content: remote,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isResolving)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                snapshot.connectionState == ConnectionState.done
                                ? () => _resolve(
                                    context,
                                    widget.conflict,
                                    keepLocal: true,
                                  )
                                : null,
                            child: const Text(
                              'Manter local',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                snapshot.connectionState == ConnectionState.done
                                ? () => _resolve(
                                    context,
                                    widget.conflict,
                                    keepLocal: false,
                                  )
                                : null,
                            child: const Text(
                              'Manter Drive',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    PersistedSyncConflict conflict, {
    required bool keepLocal,
  }) async {
    setState(() {
      _isResolving = true;
    });

    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final obsidian = ref.read(obsidianServiceProvider);
      final queue = ref.read(syncQueueServiceProvider);
      final driveSync = ref.read(googleDriveSyncServiceProvider);
      final authService = ref.read(auth.googleAuthServiceProvider);
      final settings = ref.read(settingsProvider);
      final backupService = ref.read(backupServiceProvider);

      final client = await authService.ensureClient();
      if (client == null) {
        throw Exception('Google Drive não está conectado');
      }

      final sourcePath = keepLocal ? conflict.localPath : conflict.remotePath;
      final chosenContent = await obsidian.readFile(sourcePath);
      if (chosenContent == null) {
        throw Exception('Versão escolhida não foi encontrada');
      }

      driveSync.init(client);
      if (settings.driveSyncFolderId.isNotEmpty) {
        await driveSync.useExistingVaultFolder(settings.driveSyncFolderId);
      } else {
        await driveSync.setupVaultFolder(settings.driveSyncFolder);
      }

      final zipFile = await backupService.createBackup();
      if (zipFile != null) {
        await driveSync.createBackupFromFile(zipFile);
      }

      await obsidian.writeFile(conflict.relativePath, chosenContent);
      final hash = driveSync.calculateHash(chosenContent);
      final uploaded = await driveSync.syncFile(
        conflict.relativePath,
        chosenContent,
        hash,
      );
      if (!uploaded) {
        throw Exception('Não foi possível atualizar o Drive');
      }

      await queue.upsertFileSyncState(
        relativePath: conflict.relativePath,
        localHash: hash,
        remoteHash: hash,
        baseHash: hash,
      );
      await queue.removeConflict(conflict.relativePath);

      ref
          .read(syncConflictsProvider.notifier)
          .removeConflict(conflict.relativePath);
      ref.invalidate(persistedSyncConflictsProvider);
      ref.invalidate(allObjectsProvider);

      final remaining = await queue.getConflicts();
      ref
          .read(syncStatusProvider.notifier)
          .setStatus(
            remaining.isEmpty ? SyncStatus.synced : SyncStatus.conflict,
          );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            keepLocal
                ? 'Versão local mantida e enviada ao Drive'
                : 'Versão do Drive aplicada ao vault',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to resolve sync conflict: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao resolver conflito: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _PreviewBox extends StatelessWidget {
  final String title;
  final String content;
  final Color color;

  const _PreviewBox({
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final preview = content.trim().isEmpty
        ? 'Conteúdo indisponível'
        : content.trim().replaceAll(RegExp(r'\s+'), ' ');

    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        color: color.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            preview,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
