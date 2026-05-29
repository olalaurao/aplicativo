import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../models/shared_types.dart';
import '../theme.dart';

class TypeSignaturesScreen extends ConsumerWidget {
  const TypeSignaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final sortedTypes = settings.typeSignatures.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Object Identification',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sortedTypes.length,
        itemBuilder: (context, index) {
          final type = sortedTypes[index];
          final sig = settings.typeSignatures[type]!;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: AppTheme.cardDecoration(context),
            child: ListTile(
              title: Text(
                _translateType(type),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${_translateMarker(sig.markerType)}: ${sig.markerValue}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                onPressed: () => _showEditDialog(context, ref, notifier, sig),
              ),
            ),
          );
        },
      ),
    );
  }

  String _translateType(String type) {
    switch (type) {
      case 'task':
        return 'Task';
      case 'habit':
        return 'Habit';
      case 'project':
        return 'Projeto';
      case 'goal':
        return 'Meta';
      case 'calendar_session':
        return 'Calendar Event';
      case 'note':
        return 'Note';
      case 'resource':
        return 'Resource';
      case 'person':
        return 'Person';
      case 'area':
        return 'Área';
      case 'activity':
        return 'Atividade';
      case 'place':
        return 'Lugar';
      case 'label':
        return 'Marcador';
      case 'organizer':
        return 'Organizador';
      default:
        return type;
    }
  }

  String _translateMarker(MarkerType type) {
    switch (type) {
      case MarkerType.tag:
        return 'Tag';
      case MarkerType.property:
        return 'Propriedade';
      case MarkerType.folder:
        return 'Pasta';
    }
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    SettingsNotifier notifier,
    TypeSignature sig,
  ) {
    final valueController = TextEditingController(text: sig.markerValue);
    MarkerType selectedMarker = sig.markerType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${_translateType(sig.objectType)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<MarkerType>(
                initialValue: selectedMarker,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Identificador',
                ),
                items: MarkerType.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(_translateMarker(m)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedMarker = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valueController,
                decoration: InputDecoration(
                  labelText: 'Valor do Identificador',
                  hintText: selectedMarker == MarkerType.tag
                      ? '#exemplo'
                      : selectedMarker == MarkerType.folder
                      ? 'folder/'
                      : 'chave: valor',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () async {
                final newValue = valueController.text.trim();
                final updatedSignature = TypeSignature(
                  objectType: sig.objectType,
                  markerType: selectedMarker,
                  markerValue: newValue,
                );
                if (selectedMarker == MarkerType.folder &&
                    newValue.isNotEmpty &&
                    newValue != sig.markerValue) {
                  final confirmed = await _confirmAndMoveFolder(
                    context,
                    ref,
                    sig,
                    newValue,
                  );
                  if (!confirmed) return;
                }
                await notifier.updateTypeSignature(
                  sig.objectType,
                  updatedSignature,
                );
                ref.invalidate(allObjectsProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmAndMoveFolder(
    BuildContext context,
    WidgetRef ref,
    TypeSignature oldSignature,
    String newFolder,
  ) async {
    final obsidian = ref.read(obsidianServiceProvider);
    final normalizedNewFolder = _normalizeFolder(newFolder);
    final normalizedOldFolder = _normalizeFolder(oldSignature.markerValue);
    final fullNewFolder = Directory(
      '${obsidian.vaultPath}/$normalizedNewFolder',
    );
    final exists = fullNewFolder.existsSync();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(exists ? 'Mover arquivos?' : 'Criar pasta e mover?'),
        content: Text(
          exists
              ? 'Mover os arquivos de "$normalizedOldFolder" para "$normalizedNewFolder"?'
              : 'A pasta "$normalizedNewFolder" não existe. Criar e mover os arquivos existentes para ela?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    if (!exists) await fullNewFolder.create(recursive: true);
    if (normalizedOldFolder.isEmpty ||
        normalizedOldFolder == normalizedNewFolder) {
      return true;
    }

    final files = await obsidian.getFilesInFolder(normalizedOldFolder);
    for (final file in files) {
      if (!file.path.endsWith('.md')) continue;
      final relativePath = obsidian.getRelativePath(file.path);
      final fileName = relativePath.split('/').last;
      final content = await file.readAsString();
      await obsidian.writeFile('$normalizedNewFolder/$fileName', content);
      await obsidian.deleteFile(relativePath);
    }
    return true;
  }

  String _normalizeFolder(String value) =>
      value.trim().replaceAll('\\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
}
