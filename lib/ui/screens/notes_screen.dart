// lib/ui/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/create_menu_sheet.dart';
import '../widgets/object_action_wrapper.dart';
import '../../providers/vault_provider.dart';
import '../widgets/rich_text_editor.dart';
import 'universal_detail_view.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  int _filterIndex = 0;
  String _searchQuery = '';
  String _sortBy = 'manual'; // manual, modified, created, title
  String? _expandedNoteId;

  @override
  Widget build(BuildContext context) {
    final allNotes = ref.watch(notesProvider);
    
    // Filtering
    List<dynamic> filteredNotes = allNotes.where((n) {
      final matchesSearch = n.title.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      if (_filterIndex == 0) return matchesSearch;
      if (_filterIndex == 1) return matchesSearch && n.noteType == 'text';
      if (_filterIndex == 2) return matchesSearch && n.noteType == 'outline';
      if (_filterIndex == 3) return matchesSearch && n.noteType == 'collection';
      return matchesSearch;
    }).toList();

    // Sorting
    filteredNotes.sort((a, b) {
      switch (_sortBy) {
        case 'manual':
          return (a.order ?? 0).compareTo(b.order ?? 0);
        case 'title':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'created':
          final aTime = a.createdAt ?? DateTime(0);
          final bTime = b.createdAt ?? DateTime(0);
          return bTime.compareTo(aTime);
        case 'modified':
        default:
          final aTime = a.updatedAt ?? a.createdAt ?? DateTime(0);
          final bTime = b.updatedAt ?? b.createdAt ?? DateTime(0);
          return bTime.compareTo(aTime);
      }
    });

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
                        _buildSortButton(),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: AppColors.primary,
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverReorderableList(
                itemBuilder: (context, index) => Padding(
                  key: ValueKey(filteredNotes[index].id),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildNoteItem(context, filteredNotes[index]),
                ),
                itemCount: filteredNotes.length,
                onReorder: (oldIndex, newIndex) {
                  if (_sortBy != 'manual') return;
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
                      color: AppColors.primary.withValues(alpha: 0.3),
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

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort_rounded, size: 22, color: AppColors.textSecondary),
      onSelected: (val) => setState(() => _sortBy = val),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'manual', child: Text('Sort Manually')),
        const PopupMenuItem(value: 'modified', child: Text('Sort by Modified')),
        const PopupMenuItem(value: 'created', child: Text('Sort by Created')),
        const PopupMenuItem(value: 'title', child: Text('Sort by Title')),
      ],
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

  Widget _buildFilterChips() {
    final labels = ['All', 'Text', 'Outline', 'Collection'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _filterIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filterIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppTheme.surfaceVariantColor(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNoteItem(BuildContext context, dynamic note) {
    final isExpanded = _expandedNoteId == note.id;
    IconData icon = Icons.description_outlined;
    Color color = AppColors.info;
    String typeLabel = 'Text';

    if (note.noteType == 'outline') {
      icon = Icons.account_tree_outlined;
      color = AppColors.habitGreen;
      typeLabel = 'Outline';
    } else if (note.noteType == 'collection') {
      icon = Icons.grid_view_rounded;
      color = AppColors.habitPurple;
      typeLabel = 'Collection';
    }

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
                                    'Modified ${_formatDate(note.updatedAt)}',
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
              if (isExpanded && note.noteType == 'text')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                    ),
                    child: RichTextEditor(
                      content: note.body,
                      expands: true,
                      onChanged: (newContent) {
                        final updatedNote = note.copyWith(
                          body: newContent,
                          updatedAt: DateTime.now(),
                        );
                        ref.read(vaultProvider.notifier).updateObject(updatedNote);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }
}

