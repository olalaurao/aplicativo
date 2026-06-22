// lib/ui/screens/object_conflicts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';

class ObjectConflictsScreen extends ConsumerWidget {
  const ObjectConflictsScreen({super.key});

  String _getDefaultFolderForType(String type) {
    return switch (type) {
      'mood_definition'   => 'moods',
      'combined_analysis' => 'analyses',
      _ => 'app',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(typeConflictedObjectsProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Conflitos de Tipo'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              ref.invalidate(allObjectsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Atualizando vault...')),
              );
            },
            tooltip: 'Recarregar do disco',
          ),
        ],
      ),
      body: SafeArea(
        child: conflicts.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.habitGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: AppColors.habitGreen,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Nenhum conflito de tipo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Todos os objetos no vault estão alinhados com suas assinaturas de arquivo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: conflicts.length,
                itemBuilder: (context, index) {
                  final obj = conflicts[index];
                  final literalType = obj.literalType ?? 'N/A';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    color: Theme.of(context).cardColor,
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
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
                                      obj.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      obj.obsidianPath,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              obj.conflictReason ?? 'Conflito de tipo desconhecido.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    try {
                                      await ref.read(vaultProvider.notifier).updateObject(obj);
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Frontmatter atualizado com sucesso!'),
                                        ),
                                      );
                                    } catch (e) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Erro ao atualizar frontmatter: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                                  label: const Text(
                                    'Fix Frontmatter',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    final defaultFolder = settings.folderPaths[literalType] ??
                                        _getDefaultFolderForType(literalType);
                                    final newPath = '$defaultFolder/${obj.obsidianFileName}.md';

                                    try {
                                      final service = ref.read(obsidianServiceProvider);
                                      await service.moveFile(obj.obsidianPath, newPath);
                                      ref.invalidate(allObjectsProvider);

                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Arquivo movido para $defaultFolder/',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Erro ao mover arquivo: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                                  label: const Text(
                                    'Mover Arquivo',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
