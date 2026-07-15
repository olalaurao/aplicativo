import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/create_menu_sheet.dart';
import '../widgets/object_action_wrapper.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/saved_filter.dart';
import '../../models/note_model.dart';
import '../widgets/rich_text_editor.dart';
import '../widgets/outline_editor.dart';
import '../widgets/collection_editor.dart';
import '../widgets/filter_sort_sheet.dart';
import '../utils/object_icons.dart';
import 'universal_detail_view.dart';

enum NoteViewMode { grid, grouped, list }

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _searchQuery = '';
  
  SavedFilter? _activeFilter;
  List<SavedFilter> _savedFilters = [];
  NoteViewMode _viewMode = NoteViewMode.grid;
  String? _expandedNoteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _savedFilters = ref.read(settingsProvider).filtersFor('note'));
    });
  }

  List<T> _applyFilterAndSort<T>(List<T> all) {
    var result = (_activeFilter?.apply(all) ?? all).where((item) =>
      _searchQuery.isEmpty ||
      (item as dynamic).title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final sort = _activeFilter?.sortBy ?? SortField.modified;
    final asc  = _activeFilter?.sortAscending ?? false;
    result.sort((a, b) {
      final cmp = switch (sort) {
        SortField.title    => (a as dynamic).title.compareTo((b as dynamic).title),
        SortField.created  => ((a as dynamic).createdAt ?? DateTime(0))
                                .compareTo((b as dynamic).createdAt ?? DateTime(0)),
        SortField.modified => ((a as dynamic).updatedAt ?? DateTime(0))
                                .compareTo((b as dynamic).updatedAt ?? DateTime(0)),
        SortField.manual   => ((a as dynamic).order ?? 0).compareTo((b as dynamic).order ?? 0),
        SortField.priority => ((a as dynamic).priority?.index ?? 0)
                                .compareTo((b as dynamic).priority?.index ?? 0),
        SortField.rating   => ((a as dynamic).rating ?? 0).compareTo((b as dynamic).rating ?? 0),
        _ => 0,
      };
      return asc ? cmp : -cmp;
    });
    return result;
  }

  void _openFilterSheet() => FilterSortSheet.show(
    context: context, ref: ref,
    targetType: 'note',
    currentFilter: _activeFilter,
    availableProperties: NoteFilterProperties.all,
    onApply: (f) => setState(() {
      _activeFilter = f;
      _savedFilters = ref.read(settingsProvider).filtersFor('note');
      if (f != null) {
        if (f.viewMode == ViewMode.grid) {
          _viewMode = NoteViewMode.grid;
        } else if (f.viewMode == ViewMode.grouped) {
          _viewMode = NoteViewMode.grouped;
        } else {
          _viewMode = NoteViewMode.list;
        }
      }
    }));

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
    }
    return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final allNotes = allObjects.whereType<Note>().toList();
    final filteredNotes = _applyFilterAndSort(allNotes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          // ─── Header ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            _viewMode == NoteViewMode.grid ? Icons.grid_view_rounded : Icons.view_list_rounded,
                            size: 22, color: AppColors.textSecondary),
                          onPressed: () => setState(() {
                            _viewMode = _viewMode == NoteViewMode.grid ? NoteViewMode.list : NoteViewMode.grid;
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, size: 22, color: AppColors.textSecondary),
                          onPressed: _openFilterSheet,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: AppTheme.accentColor(context),
                            ),
                          ),
                          onPressed: () => showCreateMenu(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Search bar
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search notes...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceVariantColor(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFilterChips(),
                  ],
                ),
              ),
            ),

          // ─── Notes List ───
          if (filteredNotes.isNotEmpty)
            if (_viewMode == NoteViewMode.grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10,
                    mainAxisSpacing: 10, childAspectRatio: 1.05),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildGridCard(ctx, filteredNotes[i]),
                    childCount: filteredNotes.length)))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverReorderableList(
                  itemBuilder: (context, index) => Padding(
                    key: ValueKey((filteredNotes[index] as dynamic).id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildNoteItem(context, filteredNotes[index]),
                  ),
                  itemCount: filteredNotes.length,
                  onReorder: (oldIndex, newIndex) {
                    if (_activeFilter?.sortBy != SortField.manual) return;
                    _onReorder(filteredNotes, oldIndex, newIndex);
                  },
                ),
              )
          else
            // ─── Empty State ───
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 56,
                      color: AppTheme.accentColor(context).withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No notes yet'
                          : 'No results found',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_searchQuery.isEmpty)
                      Text(
                        'Create text notes, outlines or collections',
                        style: TextStyle(
                          color: AppTheme.textMutedColor(context),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _onReorder(List<dynamic> list, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      // Update order field for all items in the list to persist
      for (int i = 0; i < list.length; i++) {
        final current = list[i];
        if (current.order != i) {
          final updated = current.copyWith(order: i);
          ref.read(vaultProvider.notifier).updateObject(updated);
        }
      }
    });
  }

  Widget _buildFilterChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [
      _chip('Todos', _activeFilter == null, () => setState(() => _activeFilter = null)),
      ..._savedFilters.map((f) => _chip(f.name, _activeFilter?.id == f.id,
        () => setState(() => _activeFilter = f))),
      GestureDetector(
        onTap: _openFilterSheet,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20)),
          child: const Text('+ filtro', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.info)))),
    ]));

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accentColor(context) : AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: selected ? Colors.black : AppTheme.textSecondaryColor(context)))));

  Widget _buildGridCard(BuildContext context, dynamic note) {
    final (_, color, label) = _noteTypeAssets(note);
    return ObjectActionWrapper(object: note,
      child: InkWell(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => UniversalDetailView(object: note))),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.cardDecoration(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Builder(
              builder: (context) {
                final iconData = _noteIconData(note);
                if (iconData != null)
                  return Icon(iconData, size: 20, color: AppTheme.accentColor(context));
                return Text(_noteEmoji(note), style: const TextStyle(fontSize: 20));
              },
            ),
            const SizedBox(height: 8),
            Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            Row(children: [
              _typeBadge(label, color),
              const Spacer(),
              Text(_formatDate(note.updatedAt ?? note.createdAt),
                style: TextStyle(fontSize: 9, color: AppTheme.textMutedColor(context))),
            ]),
          ]))));
  }

  IconData? _noteIconData(dynamic note) {
    final iconData = ObjectIcons.iconDataForType('note', ref);
    if (note.noteType == 'outline') return ObjectIcons.defaultIconDataForNoteSubtype('outline');
    if (note.noteType == 'collection') return ObjectIcons.defaultIconDataForNoteSubtype('collection');
    return iconData;
  }

  String _noteEmoji(dynamic note) {
    final emoji = ObjectIcons.emojiForType('note', ref);
    if (note.noteType == 'outline') return ObjectIcons.defaultIconForNoteSubtype('outline');
    if (note.noteType == 'collection') return ObjectIcons.defaultIconForNoteSubtype('collection');
    return emoji;
  }

  (IconData, Color, String) _noteTypeAssets(dynamic note) => switch (note.noteType) {
    'outline'    => (Icons.account_tree_outlined, AppColors.habitGreen, 'Outline'),
    'collection' => (Icons.grid_view_rounded, AppColors.habitPurple, 'Collection'),
    _            => (Icons.description_outlined, AppColors.info, 'Text'),
  };

  Widget _typeBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(
      fontSize: 9, fontWeight: FontWeight.w700, color: color)));

  Widget _buildNoteItem(BuildContext context, dynamic note) {
    final isExpanded = _expandedNoteId == note.id;
    final (icon, color, typeLabel) = _noteTypeAssets(note);

    return ObjectActionWrapper(
      object: note,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: AppTheme.cardDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UniversalDetailView(object: note)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 20, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: AppTheme.badgeDecoration(color),
                                  child: Text(
                                    typeLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Modified ${_formatDate(note.updatedAt ?? note.createdAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMutedColor(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 20,
                          color: AppTheme.textMutedColor(context),
                        ),
                        onPressed: () => setState(() {
                          _expandedNoteId = isExpanded ? null : note.id;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    height: note.noteType == 'text' ? 200 : null,
                    constraints: note.noteType == 'text'
                        ? null
                        : const BoxConstraints(maxHeight: 400),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .scaffoldBackgroundColor
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.5),
                      ),
                    ),
                    child: _buildExpandedEditor(note),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedEditor(dynamic note) {
    if (note.noteType == 'outline') {
      return OutlineEditor(
        initialContent: note.body,
        onChanged: (content) {
          final updatedNote = note.copyWith(
            body: content,
            updatedAt: DateTime.now(),
          );
          ref.read(vaultProvider.notifier).updateObject(updatedNote);
        },
      );
    } else if (note.noteType == 'collection') {
      return CollectionEditor(
        initialContent: note.body,
        onChanged: (content) {
          final updatedNote = note.copyWith(
            body: content,
            updatedAt: DateTime.now(),
          );
          ref.read(vaultProvider.notifier).updateObject(updatedNote);
        },
      );
    } else {
      return RichTextEditor(
        content: note.body,
        expands: true,
        onChanged: (newContent) {
          final updatedNote = note.copyWith(
            body: newContent,
            updatedAt: DateTime.now(),
          );
          ref.read(vaultProvider.notifier).updateObject(updatedNote);
        },
      );
    }
  }
}
