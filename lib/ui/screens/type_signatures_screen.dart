import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../models/shared_types.dart';
import '../theme.dart';
import '../widgets/icon_picker.dart';
import '../utils/material_icon_set.dart';

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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sig.iconName != null)
                    Icon(
                      MaterialIconSet.getIcon(sig.iconName!),
                      size: 20,
                      color: AppTheme.accentColor(context),
                    )
                  else
                    Text(
                      sig.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.edit_rounded,
                      size: 20,
                      color: AppTheme.accentColor(context),
                    ),
                    onPressed: () => _showEditDialog(context, ref, notifier, sig),
                  ),
                ],
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
      case 'idea':
        return 'Idea';
      case 'habit':
        return 'Habit';
      case 'project':
        return 'Project';
      case 'goal':
        return 'Goal';
      case 'event':
        return 'Event';
      case 'note':
        return 'Note';
      case 'resource':
        return 'Resource';
      case 'person':
        return 'Person';
      case 'system':
        return 'System';
      case 'tracker':
        return 'Tracker';
      case 'entry':
        return 'Journal Entry';
      case 'reminder':
        return 'Reminder';
      case 'social_post':
        return 'Social Post';
      case 'mood_definition':
        return 'Mood Definition';
      case 'area':
        return 'Area';
      case 'activity':
        return 'Activity';
      case 'label':
        return 'Label';
      case 'organizer':
        return 'Organizer';
      case 'pillar':
        return 'Pillar';
      case 'value':
        return 'Value';
      case 'action':
        return 'Action';
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
    String? selectedIconName = sig.iconName;
    MarkerType selectedMarker = sig.markerType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${_translateType(sig.objectType)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => IconPicker(
                      selectedIconName: selectedIconName,
                      onIconSelected: (icon) {
                        Navigator.pop(context, icon);
                      },
                    ),
                  );
                  if (result != null) {
                    setState(() => selectedIconName = result);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedIconName != null ? MaterialIconSet.getIcon(selectedIconName!) : Icons.help_outline,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(selectedIconName ?? 'Select icon'),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                  emoji: '',
                  iconName: selectedIconName,
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
