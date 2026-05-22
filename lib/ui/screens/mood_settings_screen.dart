// lib/ui/screens/mood_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/mood_model.dart';
import '../theme.dart';

class MoodSettingsScreen extends ConsumerWidget {
  const MoodSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(moodsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Definições de humor')),
      body: moods.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mood_rounded,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum humor cadastrado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crie opções como Feliz, Neutro ou Cansado para usar no diário.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _editMood(context, ref, null),
                      style: AppTheme.primaryButtonStyle,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar humor'),
                    ),
                  ],
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: moods.length,
              onReorder: (oldIdx, newIdx) async {
                if (oldIdx < newIdx) {
                  newIdx -= 1;
                }
                final list = List<MoodDefinition>.from(moods);
                final item = list.removeAt(oldIdx);
                list.insert(newIdx, item);

                for (int i = 0; i < list.length; i++) {
                  final updated = list[i].copyWith(order: i);
                  await ref.read(moodsProvider.notifier).updateMood(updated);
                }
              },
              itemBuilder: (context, index) {
                final mood = moods[index];
                return Container(
                  key: ValueKey(mood.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: AppTheme.cardDecoration(context),
                  child: ListTile(
                    leading: Text(
                      mood.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      mood.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Valor: ${mood.numericValue}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.drag_handle_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => _editMood(context, ref, mood),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editMood(context, ref, null),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _editMood(BuildContext context, WidgetRef ref, MoodDefinition? mood) {
    final isNew = mood == null;
    final titleController = TextEditingController(text: mood?.title ?? '');
    final emojiController = TextEditingController(text: mood?.emoji ?? '');
    final valueController = TextEditingController(
      text: mood?.numericValue.toString() ?? '3',
    );
    final colorController = TextEditingController(
      text: mood?.color ?? '#9E9E9E',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNew ? 'Novo humor' : 'Editar humor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Nome'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emojiController,
                decoration: const InputDecoration(labelText: 'Emoji (ex: 😐)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(
                  labelText: 'Valor numérico (1-5)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Cor hex (ex: #9E9E9E)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!isNew)
            TextButton(
              onPressed: () async {
                await ref.read(moodsProvider.notifier).deleteMood(mood);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Excluir'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              final id = mood?.id ?? _uniqueMoodId(ref, title);
              final updatedMood = MoodDefinition(
                id: id,
                title: title,
                label: title,
                emoji: emojiController.text.trim().isEmpty
                    ? '😐'
                    : emojiController.text.trim(),
                numericValue: int.tryParse(valueController.text.trim()) ?? 3,
                color: _normalizeHexColor(colorController.text),
                order: mood?.order ?? ref.read(moodsProvider).length,
                obsidianPath: mood?.obsidianPath ?? '',
              );

              try {
                if (isNew) {
                  await ref.read(moodsProvider.notifier).addMood(updatedMood);
                } else {
                  await ref
                      .read(moodsProvider.notifier)
                      .updateMood(updatedMood);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao salvar humor: $e')),
                );
              }
            },
            style: AppTheme.primaryButtonStyle,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  String _slugFromTitle(String title) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    var slug = title.toLowerCase().trim();
    accents.forEach((from, to) => slug = slug.replaceAll(from, to));
    slug = slug
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')
        .replaceAll(RegExp(r'-+'), '-');
    return slug.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : slug;
  }

  String _uniqueMoodId(WidgetRef ref, String title) {
    final existing = ref.read(moodsProvider).map((m) => m.id).toSet();
    final base = _slugFromTitle(title);
    if (!existing.contains(base)) return base;
    var index = 2;
    while (existing.contains('$base-$index')) {
      index++;
    }
    return '$base-$index';
  }

  String _normalizeHexColor(String value) {
    final trimmed = value.trim();
    final withHash = trimmed.startsWith('#') ? trimmed : '#$trimmed';
    return RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(withHash)
        ? withHash.toUpperCase()
        : '#9E9E9E';
  }
}
