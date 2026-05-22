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
    final blocks = ref.watch(timeBlocksProvider);

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
              PopupMenuItem(value: 'block', child: Text('New Time Block')),
              PopupMenuItem(value: 'theme', child: Text('New Day Theme')),
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
                    final item = blocks.removeAt(oldIndex);
                    blocks.insert(newIndex, item);
                    for (int i = 0; i < blocks.length; i++) {
                      blocks[i].order = i;
                      ref.read(timeBlocksProvider.notifier).updateTimeBlock(blocks[i]);
                    }
                  },
                  children: blocks
                      .map((b) => Container(
                            key: ValueKey(b.id),
                            child: _buildBlockTile(context, b),
                          ))
                      .toList(),
                ),
          const SizedBox(height: 32),
          _section('Temas do Dia'),
          const SizedBox(height: 12),
          themes.isEmpty
              ? _buildEmptyCard('Nenhum tema definido')
              : Column(
                  children: themes
                      .map((t) => _buildThemeTile(context, t))
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

  Widget _buildBlockTile(BuildContext context, dynamic block) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        title: Text(block.title),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, dynamic theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        title: Text(theme.title),
        subtitle: Text(theme.daysOfWeek.join(', ')),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  void _showBlockDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Time Block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: start,
                        );
                        if (picked != null) {
                          setDialogState(() => start = picked);
                        }
                      },
                      child: Text('Start ${start.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: end,
                        );
                        if (picked != null) setDialogState(() => end = picked);
                      },
                      child: Text('End ${end.format(context)}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final id = DateTime.now().millisecondsSinceEpoch.toString();
                await ref
                    .read(timeBlocksProvider.notifier)
                    .addTimeBlock(
                      TimeBlock(
                        id: id,
                        title: name,
                        timeRanges: [
                          TimeRange(
                            startHour: start.hour,
                            startMinute: start.minute,
                            endHour: end.hour,
                            endMinute: end.minute,
                          ),
                        ],
                        order: ref.read(timeBlocksProvider).length,
                      ),
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final selectedDays = <String>{};
    final blocks = ref.read(timeBlocksProvider);
    final selectedBlocks = <String>{};
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Day Theme'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Days',
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
                    'Blocks',
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref
                    .read(dayThemesProvider.notifier)
                    .addDayTheme(
                      DayTheme(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: name,
                        daysOfWeek: selectedDays.toList(),
                        blockIds: selectedBlocks.toList(),
                      ),
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
