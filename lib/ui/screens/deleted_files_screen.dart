import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/vault_provider.dart';
import '../theme.dart';

class DeletedFilesScreen extends ConsumerStatefulWidget {
  const DeletedFilesScreen({super.key});

  @override
  ConsumerState<DeletedFilesScreen> createState() => _DeletedFilesScreenState();
}

class _DeletedFilesScreenState extends ConsumerState<DeletedFilesScreen> {
  late Future<List<File>> _filesFuture;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _refreshFiles();
  }

  void _refreshFiles() {
    final service = ref.read(obsidianServiceProvider);
    _filesFuture = service.getFilesInFolder('_deleted');
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(obsidianServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Trash')),
      body: FutureBuilder<List<File>>(
        key: ValueKey(_refreshKey),
        future: _filesFuture,
        builder: (context, snapshot) {
          final files = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (files.isEmpty) {
            return const Center(
              child: Text(
                'Trash is empty.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final relativePath = service.getRelativePath(file.path);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: AppTheme.cardDecoration(context),
                child: ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    relativePath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Modified ${file.statSync().modified}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref
                          .read(vaultProvider.notifier)
                          .restoreDeletedFile(relativePath);
                      if (mounted) {
                        setState(() {
                          _refreshKey++;
                        });
                        _refreshFiles();
                      }
                    },
                    child: const Text('Restore'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
