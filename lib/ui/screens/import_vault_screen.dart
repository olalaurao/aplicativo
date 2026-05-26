import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/markdown_parser.dart';
import '../theme.dart';

class ImportVaultScreen extends ConsumerStatefulWidget {
  const ImportVaultScreen({super.key});

  @override
  ConsumerState<ImportVaultScreen> createState() => _ImportVaultScreenState();
}

class _ImportVaultScreenState extends ConsumerState<ImportVaultScreen> {
  String? _selectedPath;
  int _typedFiles = 0;
  int _plainNotes = 0;
  bool _scanning = false;
  bool _importing = false;

  Future<void> _pickVault() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecionar pasta do vault Obsidian',
    );
    if (path == null || !mounted) return;

    setState(() {
      _selectedPath = path;
      _typedFiles = 0;
      _plainNotes = 0;
      _scanning = true;
    });

    try {
      final validationError = await _validateVaultPath(path);
      if (validationError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
        return;
      }
      final files = Directory(path)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.md'));

      var typed = 0;
      var plain = 0;
      for (final file in files) {
        final content = await file.readAsString();
        final frontmatter = MarkdownParser.parseFrontmatter(content);
        if ((frontmatter['type']?.toString() ?? '').isNotEmpty) {
          typed++;
        } else {
          plain++;
        }
      }

      if (!mounted) return;
      setState(() {
        _typedFiles = typed;
        _plainNotes = plain;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao ler o vault: $e')));
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _importVault() async {
    final path = _selectedPath;
    if (path == null || _importing) return;

    setState(() => _importing = true);
    try {
      final settings = ref.read(settingsProvider);
      await ref.read(settingsProvider.notifier).updateVaultPath(path);
      await ref
          .read(obsidianServiceProvider)
          .initVault(settings.vaultName, customPath: path);
      ref.invalidate(allObjectsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vault importado e indexado com sucesso.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao importar vault: $e')));
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<String?> _validateVaultPath(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return 'A pasta selecionada não existe.';
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
      return 'Sem permissão de escrita nesta pasta: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedPath != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar vault Obsidian')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pasta do vault',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedPath ?? 'Nenhuma pasta selecionada',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _scanning ? null : _pickVault,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: Text(
                        _scanning ? 'Lendo arquivos...' : 'Selecionar pasta',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (hasSelection)
              Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prévia da indexação',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      label: 'Arquivos com frontmatter type:',
                      value: _typedFiles.toString(),
                    ),
                    const SizedBox(height: 8),
                    _StatRow(
                      label: 'Arquivos sem type: como Text Note',
                      value: _plainNotes.toString(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: hasSelection && !_scanning && !_importing
                ? _importVault
                : null,
            child: Text(_importing ? 'Importando...' : 'Importar vault'),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
