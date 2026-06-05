// lib/ui/screens/mood_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mood_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/app_color_picker.dart';
import 'universal_detail_view.dart';

class MoodSettingsScreen extends ConsumerWidget {
  const MoodSettingsScreen({super.key});

  static const int _maxMoods = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(moodsProvider);
    final sortedMoods = List<MoodDefinition>.from(moods)
      ..sort((a, b) {
        final byOrder = (a.order ?? a.numericValue).compareTo(
          b.order ?? b.numericValue,
        );
        if (byOrder != 0) return byOrder;
        return a.numericValue.compareTo(b.numericValue);
      });
    final canAdd = moods.length < _maxMoods;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Definições de humor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: canAdd
                  ? () => _editMood(context, ref, null)
                  : () => _showMaxMoodsMessage(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Adicionar'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: moods.isEmpty
            ? _MoodEmptyState(onAdd: () => _editMood(context, ref, null))
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: sortedMoods.length,
                header: _MoodHeader(
                  configured: moods.length,
                  max: _maxMoods,
                  missingValues: _missingValues(moods),
                ),
                onReorder: (oldIdx, newIdx) async {
                  if (oldIdx < newIdx) newIdx -= 1;
                  final list = List<MoodDefinition>.from(sortedMoods);
                  final item = list.removeAt(oldIdx);
                  list.insert(newIdx, item);

                  for (int i = 0; i < list.length; i++) {
                    final updated = list[i].copyWith(order: i);
                    await ref.read(moodsProvider.notifier).updateMood(updated);
                  }
                },
                itemBuilder: (context, index) {
                  final mood = sortedMoods[index];
                  return _MoodTile(
                    key: ValueKey(mood.id),
                    mood: mood,
                    onOpen: () => _openMood(context, mood),
                    onEdit: () => _editMood(context, ref, mood),
                    onDelete: () => _confirmDeleteMood(context, ref, mood),
                  );
                },
              ),
      ),
      floatingActionButton: moods.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: canAdd
                  ? () => _editMood(context, ref, null)
                  : () => _showMaxMoodsMessage(context),
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  void _openMood(BuildContext context, MoodDefinition mood) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UniversalDetailView(object: mood)),
    );
  }

  void _editMood(BuildContext context, WidgetRef ref, MoodDefinition? mood) {
    final currentMoods = ref.read(moodsProvider);
    if (mood == null && currentMoods.length >= _maxMoods) {
      _showMaxMoodsMessage(context);
      return;
    }

    final isNew = mood == null;
    final defaultValue = _nextAvailableValue(currentMoods);
    final titleController = TextEditingController(text: mood?.title ?? '');
    final emojiController = TextEditingController(text: mood?.emoji ?? '');
    final valueController = TextEditingController(
      text: (mood?.numericValue ?? defaultValue).toString(),
    );
    String selectedColor = AppColorPicker.normalizeHex(
      mood?.color ?? _defaultColorForValue(defaultValue),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Novo humor' : 'Editar humor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColorPicker.parseHex(
                      selectedColor,
                    ).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(
                        emojiController.text.trim().isEmpty
                            ? '😐'
                            : emojiController.text.trim(),
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          titleController.text.trim().isEmpty
                              ? 'Preview do humor'
                              : titleController.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColorPicker.parseHex(selectedColor),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emojiController,
                  decoration: const InputDecoration(labelText: 'Emoji'),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  decoration: const InputDecoration(
                    labelText: 'Valor numérico (1-15)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                AppColorPicker(
                  value: selectedColor,
                  onChanged: (color) =>
                      setDialogState(() => selectedColor = color),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                final numericValue =
                    ((int.tryParse(valueController.text.trim()) ?? defaultValue)
                            .clamp(1, _maxMoods))
                        .toInt();
                if (_hasDuplicateValue(
                  ref.read(moodsProvider),
                  numericValue,
                  mood?.id,
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('O valor $numericValue já está em uso.'),
                    ),
                  );
                  return;
                }

                final id = mood?.id ?? _uniqueMoodId(ref, title);
                final updatedMood = MoodDefinition(
                  id: id,
                  title: title,
                  label: title,
                  emoji: emojiController.text.trim().isEmpty
                      ? '😐'
                      : emojiController.text.trim(),
                  numericValue: numericValue,
                  color: selectedColor,
                  order: mood?.order ?? numericValue - 1,
                  obsidianPath: mood?.obsidianPath ?? 'moods/$id.md',
                );

                try {
                  if (isNew) {
                    await ref.read(moodsProvider.notifier).addMood(updatedMood);
                  } else {
                    await ref
                        .read(moodsProvider.notifier)
                        .updateMood(updatedMood);
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
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
      ),
    ).whenComplete(() {
      titleController.dispose();
      emojiController.dispose();
      valueController.dispose();
    });
  }

  Future<void> _confirmDeleteMood(
    BuildContext context,
    WidgetRef ref,
    MoodDefinition mood,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir humor?'),
        content: Text(
          '${mood.emoji} ${mood.title} será movido para a lixeira por 30 dias.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final originalPath = mood.obsidianPath.isNotEmpty
        ? mood.obsidianPath
        : 'moods/${mood.slug}.md';
    await ref.read(moodsProvider.notifier).deleteMood(mood);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${mood.title} excluído'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Desfazer',
          textColor: AppColors.accent,
          onPressed: () {
            ref.read(vaultProvider.notifier).restoreObject(mood, originalPath);
          },
        ),
      ),
    );
  }

  void _showMaxMoodsMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Você já configurou 15 humores.')),
    );
  }

  List<int> _missingValues(List<MoodDefinition> moods) {
    final used = moods.map((mood) => mood.numericValue).toSet();
    return [
      for (int value = 1; value <= _maxMoods; value++)
        if (!used.contains(value)) value,
    ];
  }

  int _nextAvailableValue(List<MoodDefinition> moods) {
    final missing = _missingValues(moods);
    return missing.isEmpty ? _maxMoods : missing.first;
  }

  bool _hasDuplicateValue(
    List<MoodDefinition> moods,
    int value,
    String? currentId,
  ) {
    return moods.any(
      (mood) => mood.numericValue == value && mood.id != currentId,
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
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
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

  String _defaultColorForValue(int value) {
    if (value <= 3) return '#EF4444';
    if (value <= 6) return '#F59E0B';
    if (value <= 9) return '#6B7280';
    if (value <= 12) return '#22C55E';
    return '#3B82F6';
  }
}

class _MoodHeader extends StatelessWidget {
  final int configured;
  final int max;
  final List<int> missingValues;

  const _MoodHeader({
    required this.configured,
    required this.max,
    required this.missingValues,
  });

  @override
  Widget build(BuildContext context) {
    final progress = configured / max;
    final missingText = missingValues.isEmpty
        ? 'Escala completa'
        : 'Faltam: ${missingValues.join(', ')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$configured/$max humores configurados',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkDivider
                  : AppColors.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.info),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            missingText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  final MoodDefinition mood;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MoodTile({
    super.key,
    required this.mood,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final moodColor = _colorFromHex(mood.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(
        context,
      ).copyWith(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: moodColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  mood.numericValue.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: moodColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(mood.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mood.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: moodColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Valor ${mood.numericValue}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Excluir',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFromHex(String value) {
    final hex = value.replaceAll('#', '').trim();
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return AppColors.textMuted;
    }
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class _MoodEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _MoodEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crie uma escala de até 15 humores para usar no diário.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              style: AppTheme.primaryButtonStyle,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar humor'),
            ),
          ],
        ),
      ),
    );
  }
}
