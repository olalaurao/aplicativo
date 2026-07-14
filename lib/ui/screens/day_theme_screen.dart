// lib/ui/screens/day_theme_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/organizer_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/app_color_picker.dart';
import '../forms/create_organizer_form.dart';

class DayThemeScreen extends ConsumerWidget {
  const DayThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final themes = allObjects.whereType<Organizer>().where((o) => o.organizerType == OrganizerType.dayTheme).toList();
    final blocks = [...allObjects.whereType<Organizer>().where((o) => o.organizerType == OrganizerType.timeBlock).toList()]
      ..sort((Organizer a, Organizer b) {
        final aStart = a.timeRanges.isEmpty ? 24 * 60 : a.timeRanges.first.startHour * 60 + a.timeRanges.first.startMinute;
        final bStart = b.timeRanges.isEmpty ? 24 * 60 : b.timeRanges.first.startHour * 60 + b.timeRanges.first.startMinute;
        return aStart.compareTo(bStart);
      });

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Day Themes & Blocks'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.add_rounded),
              onSelected: (value) {
                if (value == 'block') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => CreateOrganizerForm(
                      initialType: OrganizerType.timeBlock,
                    ),
                  ));
                }
                if (value == 'theme') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => CreateOrganizerForm(
                      initialType: OrganizerType.dayTheme,
                    ),
                  ));
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'block', child: Text('New Block')),
                PopupMenuItem(value: 'theme', child: Text('New Theme')),
              ],
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.accentColor(context),
            labelColor: AppTheme.accentColor(context),
            tabs: const [
              Tab(text: 'Themes'),
              Tab(text: 'Blocks'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Themes
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                themes.isEmpty
                    ? _buildEmptyCard('No themes defined')
                    : Column(
                        children: themes
                            .map((t) => _buildThemeTile(context, ref, t, blocks))
                            .toList(),
                      ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New Day Theme'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.accentColor(context).withValues(alpha: 0.4)),
                      foregroundColor: AppTheme.accentColor(context),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => CreateOrganizerForm(
                          initialType: OrganizerType.dayTheme,
                        ),
                      ));
                    },
                  ),
                ),
              ],
            ),
            // Tab 2: Blocks
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                blocks.isEmpty
                    ? _buildEmptyCard('No blocks defined')
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
                          for (final block in reordered) {
                            ref
                                .read(timeBlocksProvider.notifier)
                                .updateTimeBlock(block);
                          }
                        },
                        children: blocks
                            .asMap()
                            .entries
                            .map(
                              (entry) => Container(
                                key: ValueKey(entry.value.id),
                                child: _buildBlockTile(context, ref, entry.value, entry.key),
                              ),
                            )
                            .toList(),
                      ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New Time Block'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.accentColor(context).withValues(alpha: 0.4)),
                      foregroundColor: AppTheme.accentColor(context),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => CreateOrganizerForm(
                          initialType: OrganizerType.timeBlock,
                        ),
                      ));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildBlockTile(BuildContext context, WidgetRef ref, Organizer block, int reorderIndex) {
    final color = AppColorPicker.parseHex(
      block.color ?? '#FFB000',
      fallback: AppTheme.accentColor(context),
    );
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
        contentPadding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
        leading: Container(width: 4, height: 48,
          decoration: BoxDecoration(color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)))),
        title: Text(block.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(rangeText,
          style: TextStyle(fontSize: AppTextSize.xs, color: AppTheme.textMutedColor(context))),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _buildTimeBar(block, color),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CreateOrganizerForm(
                    initialType: OrganizerType.timeBlock,
                    organizer: block,
                  ),
                ));
              }
              if (value == 'delete') {
                final confirmed = await _confirmDelete(context, 'Delete block?');
                if (confirmed) {
                  await ref
                      .read(timeBlocksProvider.notifier)
                      .deleteTimeBlock(block);
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          const SizedBox(width: 4),
          ReorderableDragStartListener(index: reorderIndex,
            child: const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted)),
        ]),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => CreateOrganizerForm(
              initialType: OrganizerType.timeBlock,
              organizer: block,
            ),
          ));
        }
      ),
    );
  }

  Widget _buildTimeBar(Organizer block, Color color) {
    if (block.timeRanges.isEmpty) return const SizedBox();
    
    final range = block.timeRanges.first;
    final s = range.startHour * 60 + range.startMinute;
    final e = range.endHour * 60 + range.endMinute;
    
    final total = (e > s ? e - s : (24 * 60 - s) + e).clamp(0, 24 * 60);
    final flex = (total / (24 * 60) * 60).clamp(4.0, 60.0);
    return Container(width: 60, height: 6,
      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(3)),
      child: Stack(children: [
        Positioned(
          left: (s / (24 * 60) * 60).clamp(0.0, 56.0),
          child: Container(width: flex, height: 6,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))))
      ]));
  }

  Widget _buildThemeTile(
    BuildContext context,
    WidgetRef ref,
    Organizer theme,
    List<Organizer> blocks,
  ) {
    final themeColor = AppColorPicker.parseHex(
      theme.color ?? '#FFB000',
      fallback: AppTheme.accentColor(context),
    );
    final blockTitles = blocks
        .where((block) => theme.organizers.any((ref) =>
            ref.slug == block.id || ref.slug == block.slug))
        .map((block) => block.title)
        .join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => CreateOrganizerForm(
              initialType: OrganizerType.dayTheme,
              organizer: theme,
            ),
          ));
        },
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: themeColor.withValues(alpha: 0.16),
          child: Icon(Icons.palette_rounded, color: themeColor, size: 18),
        ),
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
            if (value == 'edit') {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CreateOrganizerForm(
                  initialType: OrganizerType.dayTheme,
                  organizer: theme,
                ),
              ));
            }
            if (value == 'delete') {
              final confirmed = await _confirmDelete(context, 'Delete theme?');
              if (confirmed) {
                await ref
                    .read(dayThemesProvider.notifier)
                    .deleteDayTheme(theme);
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
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
          'This action can be undone via the vault trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _formatRangeTime(int hour, int minute) {
    return '${hour.clamp(0, 23).toString().padLeft(2, '0')}:${minute.clamp(0, 59).toString().padLeft(2, '0')}';
  }
}
