import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
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
                onPressed: () => _showEditDialog(context, notifier, sig),
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
              onPressed: () {
                notifier.updateTypeSignature(
                  sig.objectType,
                  TypeSignature(
                    objectType: sig.objectType,
                    markerType: selectedMarker,
                    markerValue: valueController.text,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }
}
