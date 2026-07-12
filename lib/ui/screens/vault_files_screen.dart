import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/vault_provider.dart';
import '../theme.dart';

class VaultFilesScreen extends ConsumerStatefulWidget {
  const VaultFilesScreen({super.key});

  @override
  ConsumerState<VaultFilesScreen> createState() => _VaultFilesScreenState();
}

class _VaultFilesScreenState extends ConsumerState<VaultFilesScreen> {
  late Future<List<File>> _filesFuture;

  @override
  void initState() {
    super.initState();
    final service = ref.read(obsidianServiceProvider);
    _filesFuture = service.getAllMarkdownFiles();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(obsidianServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Vault Files')),
      body: FutureBuilder<List<File>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          final files = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (files.isEmpty) {
            return const Center(
              child: Text(
                'No markdown files found.',
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
                  leading: Icon(
                    Icons.description_outlined,
                    color: AppTheme.accentColor(context),
                  ),
                  title: Text(
                    relativePath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${file.lengthSync()} bytes'),
                  onTap: () => _showFilePreview(context, file, relativePath),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showFilePreview(
    BuildContext context,
    File file,
    String title,
  ) async {
    final content = await file.readAsString();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SelectableText(content),
          ],
        ),
      ),
    );
  }
}
