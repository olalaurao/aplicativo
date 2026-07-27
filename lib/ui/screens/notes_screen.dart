import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/create_menu_sheet.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/saved_filter.dart';
import '../../models/note_model.dart';
import '../../services/markdown_parser.dart';
import '../widgets/rich_text_editor.dart';
import '../widgets/outline_editor.dart';
import '../widgets/collection_editor.dart';
import '../widgets/filter_sort_sheet.dart';
import '../widgets/filterable_list_header.dart';
import '../utils/filter_sort_utils.dart';
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

  // Bulk selection
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(
        () => _savedFilters = ref.read(settingsProvider).filtersFor('note'),
      );
    });
  }

  List<T> _applyFilterAndSort<T>(List<T> all) {
    return FilterSortUtils.applyFilterAndSort(all, _searchQuery, _activeFilter);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  List<String> _effectiveVisibleNoteFields() {
    final fields = _activeFilter?.visibleProperties.isNotEmpty == true
        ? _activeFilter!.visibleProperties.toSet()
        : <String>{'noteType'};
    if (_activeFilter?.includeSortProperty != false) {
      final sortField = _propertyKeyForSort(
        _activeFilter?.sortBy ?? SortField.modified,
      );
      if (sortField != null) fields.add(sortField);
    }
    fields.remove('title');
    return fields.toList();
  }

  String? _propertyKeyForSort(SortField sort) {
    return switch (sort) {
      SortField.title => 'title',
      SortField.created => 'created',
      SortField.modified => 'modified',
      _ => null,
    };
  }

  List<Widget> _buildNoteProperties(Note note, Color typeColor) {
    return [
      for (final field in _effectiveVisibleNoteFields())
        if (_notePropertyValue(note, field).isNotEmpty)
          _notePropertyChip(
            _notePropertyLabel(field),
            _notePropertyValue(note, field),
            field == 'noteType' ? typeColor : AppColors.textMuted,
          ),
    ];
  }

  String _notePropertyValue(Note note, String field) {
    return switch (field) {
      'noteType' => note.noteType,
      'created' => _formatDate(note.createdAt),
      'modified' => _formatDate(note.updatedAt),
      'tags' => note.tags.join(', '),
      'organizers' =>
        note.organizers
            .map((organizer) => organizer.title)
            .where((title) => title.trim().isNotEmpty)
            .join(', '),
      'pinned' => note.pinned ? 'yes' : 'no',
      'archived' => note.archived ? 'yes' : 'no',
      _ => '',
    };
  }

  String _notePropertyLabel(String field) {
    for (final property in NoteFilterProperties.all) {
      if (property.key == field) return property.label;
    }
    return field;
  }

  Widget _notePropertyChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color == AppColors.textMuted
              ? AppTheme.textMutedColor(context)
              : color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final settings = ref.watch(settingsProvider);
    final noteSignature = settings.typeSignatures['note'];

    final allNotes = allObjects.whereType<Note>().where((note) {
      // Filter by Object Identification signature for notes
      if (noteSignature != null) {
        final frontmatter = note.toBaseMap();
        final body = note.body;
        final path = note.obsidianPath;
        if (!MarkdownParser.matchesSignature(
          frontmatter,
          body,
          path,
          noteSignature,
        )) {
          return false;
        }
      }
      return true;
    }).toList();
    final filteredNotes = _applyFilterAndSort(allNotes);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} selecionados')
            : const Text('Notes'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              onPressed: () {
                final allObjects = ref.read(allObjectsProvider).value ?? [];
                final allNotes = allObjects.whereType<Note>().toList();
                final filteredNotes = _applyFilterAndSort(allNotes);
                setState(() {
                  _selectedIds.clear();
                  _selectedIds.addAll(filteredNotes.map((n) => n.id));
                });
              },
              tooltip: 'Selecionar todos',
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              }),
              tooltip: 'Cancelar seleção',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded),
              onPressed: () => setState(() => _isSelectionMode = true),
              tooltip: 'Seleção múltipla',
            ),
          ],
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ─── Header ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: FilterableListHeader(
                targetType: 'note',
                searchQuery: _searchQuery,
                activeFilter: _activeFilter,
                savedFilters: _savedFilters,
                viewMode: _viewMode == NoteViewMode.grid ? ViewMode.grid : ViewMode.list,
                availableProperties: NoteFilterProperties.all,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onFilterChanged: (f) => setState(() {
                  _activeFilter = f;
                  _savedFilters = ref.read(settingsProvider).filtersFor('note');
                }),
                onViewModeChanged: (v) => setState(() {
                  if (v == ViewMode.grid) {
                    _viewMode = NoteViewMode.grid;
                  } else {
                    _viewMode = NoteViewMode.list;
                  }
                }),
                onAddPressed: () => showCreateMenu(context),
              ),
            ),
          ),

          // ─── Notes List ───
          if (filteredNotes.isEmpty)
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
                      color: AppTheme.accentColor(
                        context,
                      ).withValues(alpha: 0.3),
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
            )
          else
            _viewMode == NoteViewMode.grid
                ? SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.05,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildGridCard(
                          ctx,
                          filteredNotes[i],
                          key: ValueKey(filteredNotes[i].id),
                        ),
                        childCount: filteredNotes.length,
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildNoteItem(
                            context,
                            filteredNotes[index],
                            key: ValueKey(filteredNotes[index].id),
                          ),
                        ),
                        childCount: filteredNotes.length,
                      ),
                    ),
                  ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }



  Widget _buildGridCard(BuildContext context, Note note, {Key? key}) {
    final (_, color, _) = _noteTypeAssets(note);
    final isSelected = _selectedIds.contains(note.id);

    return GestureDetector(
      key: key,
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(note.id);
                } else {
                  _selectedIds.add(note.id);
                }
              });
            }
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UniversalDetailView(object: note),
              ),
            ),
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedIds.add(note.id);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentColor(context).withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: AppTheme.accentColor(context), width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Builder(
                  builder: (context) {
                    final iconData = _noteIconData(note);
                    if (iconData != null) {
                      return Icon(
                        iconData,
                        size: 20,
                        color: AppTheme.accentColor(context),
                      );
                    }
                    return Text(
                      _noteEmoji(note),
                      style: const TextStyle(fontSize: 20),
                    );
                  },
                ),
                if (_isSelectionMode)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected
                            ? AppTheme.accentColor(context)
                            : Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _buildNoteProperties(note, color),
            ),
          ],
        ),
      ),
    );
  }

  IconData? _noteIconData(Note note) {
    final iconData = ObjectIcons.iconDataForType('note', ref);
    if (note.noteType == 'outline') {
      return ObjectIcons.defaultIconDataForNoteSubtype('outline');
    }
    if (note.noteType == 'collection') {
      return ObjectIcons.defaultIconDataForNoteSubtype('collection');
    }
    return iconData;
  }

  String _noteEmoji(Note note) {
    final emoji = ObjectIcons.emojiForType('note', ref);
    if (note.noteType == 'outline') {
      return ObjectIcons.defaultIconForNoteSubtype('outline');
    }
    if (note.noteType == 'collection') {
      return ObjectIcons.defaultIconForNoteSubtype('collection');
    }
    return emoji;
  }

  (IconData, Color, String) _noteTypeAssets(Note note) =>
      switch (note.noteType) {
        'outline' => (
          Icons.account_tree_outlined,
          AppColors.habitGreen,
          'Outline',
        ),
        'collection' => (
          Icons.grid_view_rounded,
          AppColors.habitPurple,
          'Collection',
        ),
        _ => (Icons.description_outlined, AppColors.info, 'Text'),
      };

  Widget _buildNoteItem(BuildContext context, Note note, {Key? key}) {
    final isExpanded = _expandedNoteId == note.id;
    final (icon, color, _) = _noteTypeAssets(note);
    final isSelected = _selectedIds.contains(note.id);

    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.accentColor(context).withValues(alpha: 0.1)
            : null,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: AppTheme.accentColor(context), width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            InkWell(
              onTap: _isSelectionMode
                  ? () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(note.id);
                        } else {
                          _selectedIds.add(note.id);
                        }
                      });
                    }
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UniversalDetailView(object: note),
                      ),
                    ),
              onLongPress: () {
                setState(() {
                  _isSelectionMode = true;
                  _selectedIds.add(note.id);
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
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
                        if (_isSelectionMode)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? AppTheme.accentColor(context)
                                    : Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                      ],
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _buildNoteProperties(note, color),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
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
                    color: Theme.of(
                      context,
                    ).scaffoldBackgroundColor.withValues(alpha: 0.5),
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
    );
  }

  Widget _buildExpandedEditor(Note note) {
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
