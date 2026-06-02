// lib/ui/screens/day_theme_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/day_theme_model.dart';
import '../../providers/day_theme_provider.dart';
import '../theme.dart';

class DayThemeScreen extends ConsumerWidget {
  const DayThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(dayThemesProvider);
    final blocks = [...ref.watch(timeBlocksProvider)]
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Temas de Dia'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_rounded),
            onSelected: (value) {
              if (value == 'block') _showBlockDialog(context, ref);
              if (value == 'theme') _showThemeDialog(context, ref);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'block', child: Text('Novo bloco')),
              PopupMenuItem(value: 'theme', child: Text('Novo tema')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Blocos de Tempo'),
          const SizedBox(height: 12),
          blocks.isEmpty
              ? _buildEmptyCard('Nenhum bloco definido')
              : ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final reordered = [...blocks];
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    for (int i = 0; i < reordered.length; i++) {
                      ref
                          .read(timeBlocksProvider.notifier)
                          .updateTimeBlock(reordered[i]..order = i);
                    }
                  },
                  children: blocks
                      .map(
                        (b) => Container(
                          key: ValueKey(b.id),
                          child: _buildBlockTile(context, ref, b),
                        ),
                      )
                      .toList(),
                ),
          const SizedBox(height: 32),
          _section('Temas do Dia'),
          const SizedBox(height: 12),
          themes.isEmpty
              ? _buildEmptyCard('Nenhum tema definido')
              : Column(
                  children: themes
                      .map((t) => _buildThemeTile(context, ref, t, blocks))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
      ),
    );
  }

  Widget _buildBlockTile(BuildContext context, WidgetRef ref, TimeBlock block) {
    final rangeText = block.timeRanges.isEmpty
        ? 'Sem horário definido'
        : block.timeRanges
              .map(
                (range) =>
                    '${_formatRangeTime(range.startHour, range.startMinute)}-${_formatRangeTime(range.endHour, range.endMinute)}',
              )
              .join(' | ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        onTap: () => _showBlockDialog(context, ref, block: block),
        title: Text(block.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(rangeText, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') _showBlockDialog(context, ref, block: block);
            if (value == 'delete') {
              final confirmed = await _confirmDelete(context, 'Excluir bloco?');
              if (confirmed) {
                await ref
                    .read(timeBlocksProvider.notifier)
                    .deleteTimeBlock(block);
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    WidgetRef ref,
    DayTheme theme,
    List<TimeBlock> blocks,
  ) {
    final blockTitles = blocks
        .where((block) => theme.blockIds.contains(block.id))
        .map((block) => block.title)
        .join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        onTap: () => _showThemeDialog(context, ref, theme: theme),
        title: Text(theme.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (theme.daysOfWeek.isNotEmpty) theme.daysOfWeek.join(', '),
            if (blockTitles.isNotEmpty) blockTitles,
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') _showThemeDialog(context, ref, theme: theme);
            if (value == 'delete') {
              final confirmed = await _confirmDelete(context, 'Excluir tema?');
              if (confirmed) {
                await ref
                    .read(dayThemesProvider.notifier)
                    .deleteDayTheme(theme);
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(
    BuildContext context,
    WidgetRef ref, {
    TimeBlock? block,
  }) {
    final nameController = TextEditingController(text: block?.title ?? '');
    final colorController = TextEditingController(text: block?.color ?? '');
    final ranges =
        block?.timeRanges
            .map(
              (range) => TimeRange(
                startHour: range.startHour,
                startMinute: range.startMinute,
                endHour: range.endHour,
                endMinute: range.endMinute,
              ),
            )
            .toList() ??
        [TimeRange(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0)];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(block == null ? 'Novo bloco' : 'Editar bloco'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Cor',
                  hintText: '#FF8A00',
                ),
              ),
              const SizedBox(height: 16),
              ...ranges.asMap().entries.map((entry) {
                final index = entry.key;
                final range = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: range.startHour.clamp(0, 23),
                                minute: range.startMinute.clamp(0, 59),
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                ranges[index] = TimeRange(
                                  startHour: picked.hour,
                                  startMinute: picked.minute,
                                  endHour: range.endHour,
                                  endMinute: range.endMinute,
                                );
                              });
                            }
                          },
                          child: Text(
                            'Início ${_formatRangeTime(range.startHour, range.startMinute)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: range.endHour.clamp(0, 23),
                                minute: range.endMinute.clamp(0, 59),
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                ranges[index] = TimeRange(
                                  startHour: range.startHour,
                                  startMinute: range.startMinute,
                                  endHour: picked.hour,
                                  endMinute: picked.minute,
                                );
                              });
                            }
                          },
                          child: Text(
                            'Fim ${_formatRangeTime(range.endHour, range.endMinute)}',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover intervalo',
                        onPressed: ranges.length == 1
                            ? null
                            : () =>
                                  setDialogState(() => ranges.removeAt(index)),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setDialogState(
                    () => ranges.add(
                      TimeRange(
                        startHour: 9,
                        startMinute: 0,
                        endHour: 10,
                        endMinute: 0,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar intervalo'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final normalizedRanges = ranges
                    .where(
                      (range) =>
                          _rangeEndMinutes(range) > _rangeStartMinutes(range),
                    )
                    .toList();
                if (normalizedRanges.isEmpty) return;
                final updated = TimeBlock(
                  id: block?.id,
                  title: name,
                  color: colorController.text.trim().isEmpty
                      ? null
                      : colorController.text.trim(),
                  timeRanges: normalizedRanges,
                  order: block?.order ?? ref.read(timeBlocksProvider).length,
                );
                if (block != null) updated.obsidianPath = block.obsidianPath;
                if (block == null) {
                  await ref
                      .read(timeBlocksProvider.notifier)
                      .addTimeBlock(updated);
                } else {
                  await ref
                      .read(timeBlocksProvider.notifier)
                      .updateTimeBlock(updated);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref, {
    DayTheme? theme,
  }) {
    final nameController = TextEditingController(text: theme?.title ?? '');
    final colorController = TextEditingController(text: theme?.color ?? '');
    final selectedDays = {...?theme?.daysOfWeek};
    final blocks = ref.read(timeBlocksProvider);
    final selectedBlocks = {...?theme?.blockIds};
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(theme == null ? 'Novo tema' : 'Editar tema'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colorController,
                  decoration: const InputDecoration(
                    labelText: 'Cor',
                    hintText: '#FF8A00',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dias',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Wrap(
                  spacing: 8,
                  children: days
                      .map(
                        (day) => FilterChip(
                          label: Text(day),
                          selected: selectedDays.contains(day),
                          onSelected: (selected) => setDialogState(() {
                            if (selected) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                if (blocks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Blocos',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  ...blocks.map(
                    (block) => CheckboxListTile(
                      value: selectedBlocks.contains(block.id),
                      title: Text(block.title),
                      onChanged: (selected) => setDialogState(() {
                        if (selected == true) {
                          selectedBlocks.add(block.id);
                        } else {
                          selectedBlocks.remove(block.id);
                        }
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final updated = DayTheme(
                  id: theme?.id,
                  title: name,
                  color: colorController.text.trim().isEmpty
                      ? null
                      : colorController.text.trim(),
                  daysOfWeek: selectedDays.toList(),
                  blockIds: selectedBlocks.toList(),
                );
                if (theme != null) updated.obsidianPath = theme.obsidianPath;
                if (theme == null) {
                  await ref
                      .read(dayThemesProvider.notifier)
                      .addDayTheme(updated);
                } else {
                  await ref
                      .read(dayThemesProvider.notifier)
                      .updateDayTheme(updated);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Esta ação pode ser desfeita pela lixeira do vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _formatRangeTime(int hour, int minute) {
    return '${hour.clamp(0, 23).toString().padLeft(2, '0')}:${minute.clamp(0, 59).toString().padLeft(2, '0')}';
  }

  int _rangeStartMinutes(TimeRange range) {
    return (range.startHour.clamp(0, 23) * 60) + range.startMinute.clamp(0, 59);
  }

  int _rangeEndMinutes(TimeRange range) {
    return (range.endHour.clamp(0, 24) * 60) + range.endMinute.clamp(0, 59);
  }
}
