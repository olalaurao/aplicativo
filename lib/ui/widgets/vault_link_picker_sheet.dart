import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/content_object.dart';
import '../../models/note_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../../services/collection_row_service.dart';
import '../theme.dart';
import 'empty_state.dart';

class VaultLinkPickerSheet extends ConsumerStatefulWidget {
  final String promptTitle;
  final bool allowMultiple;

  const VaultLinkPickerSheet({
    super.key,
    required this.promptTitle,
    this.allowMultiple = true,
  });

  @override
  ConsumerState<VaultLinkPickerSheet> createState() =>
      _VaultLinkPickerSheetState();
}

class _VaultLinkPickerSheetState extends ConsumerState<VaultLinkPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedKeys = {};
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() {});
    });
  }

  String _keyForObject(ContentObject o) => 'obj:${o.id}';
  String _keyForRow(CollectionRow r) => 'row:${r.noteSlug}:${r.lineIndex}';

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final notes = allObjects.whereType<Note>().where((n) => n.subtype == NoteSubtype.collection).toList();
    final objects = ref.watch(allObjectsProvider).valueOrNull ?? [];

    final collectionRows = <CollectionRow>[];
    for (final note in notes) {
      collectionRows.addAll(CollectionRowService.parseRows(note));
    }

    final filteredRows = query.isEmpty
        ? collectionRows
        : collectionRows.where((r) {
            return r.displayTitle.toLowerCase().contains(query) ||
                (r.subtitle?.toLowerCase().contains(query) ?? false);
          }).toList();

    final filteredObjects = query.isEmpty
        ? objects
        : objects.where((o) => o.title.toLowerCase().contains(query)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  widget.promptTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Buscar no vault...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  children: [
                    if (filteredRows.isNotEmpty) ...[
                      _sectionHeader('Collection rows'),
                      ...filteredRows.map((row) {
                        final note = notes.firstWhere(
                          (n) => n.slug == row.noteSlug,
                          orElse: () => notes.first,
                        );
                        return _buildRowTile(row, note);
                      }),
                    ],
                    if (filteredObjects.isNotEmpty) ...[
                      _sectionHeader('Vault objects'),
                      ...filteredObjects.map(_buildObjectTile),
                    ],
                    if (filteredRows.isEmpty &&
                        filteredObjects.isEmpty &&
                        query.isNotEmpty)
                      const EmptyState(
                        icon: Icons.search_off_rounded,
                        headline: 'No results',
                        subtext: 'Try another search term.',
                      ),
                    if (filteredRows.isEmpty &&
                        filteredObjects.isEmpty &&
                        query.isEmpty)
                      const EmptyState(
                        icon: Icons.collections_bookmark_outlined,
                        headline: 'Nothing to link',
                        subtext:
                            'Create a Collection Note to link its rows.',
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text('Pular'),
                      ),
                      const Spacer(),
                      if (widget.allowMultiple)
                        FilledButton(
                          onPressed: _selectedKeys.isEmpty
                              ? null
                              : () => _confirmSelection(
                                    notes,
                                    filteredObjects,
                                    collectionRows,
                                  ),
                          child: Text('Confirmar (${_selectedKeys.length})'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildRowTile(CollectionRow row, Note note) {
    final key = _keyForRow(row);
    final selected = _selectedKeys.contains(key);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        row.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        row.subtitle ?? 'Linha · ${note.title}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: widget.allowMultiple
          ? Checkbox(
              value: selected,
              onChanged: (_) => _toggleKey(key),
            )
          : null,
      onTap: () {
        if (widget.allowMultiple) {
          _toggleKey(key);
        } else {
          _confirmSingleRow(row, note);
        }
      },
    );
  }

  Widget _buildObjectTile(ContentObject object) {
    final key = _keyForObject(object);
    final selected = _selectedKeys.contains(key);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconForType(object.type), size: 20),
      title: Text(
        object.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(object.type),
      trailing: widget.allowMultiple
          ? Checkbox(value: selected, onChanged: (_) => _toggleKey(key))
          : null,
      onTap: () {
        if (widget.allowMultiple) {
          _toggleKey(key);
        } else {
          Navigator.pop(context, [
            VaultLinkRef(
              objectSlug: object.slug,
              objectType: object.type,
              displayTitle: object.title,
            ),
          ]);
        }
      },
    );
  }

  void _toggleKey(String key) {
    if (mounted) setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  Future<void> _confirmSingleRow(CollectionRow row, Note note) async {
    final blockId =
        await CollectionRowService.ensureBlockId(ref, note, row);
    if (!mounted) return;
    Navigator.pop(context, [
      VaultLinkRef(
        noteSlug: row.noteSlug,
        blockId: blockId,
        displayTitle: row.displayTitle,
      ),
    ]);
  }

  Future<void> _confirmSelection(
    List<Note> notes,
    List<ContentObject> objects,
    List<CollectionRow> allRows,
  ) async {
    final refs = <VaultLinkRef>[];
    for (final key in _selectedKeys) {
      if (key.startsWith('obj:')) {
        final id = key.substring(4);
        final object = objects.cast<ContentObject?>().firstWhere(
              (o) => o?.id == id,
              orElse: () => null,
            );
        if (object != null) {
          refs.add(VaultLinkRef(
            objectSlug: object.slug,
            objectType: object.type,
            displayTitle: object.title,
          ));
        }
      } else if (key.startsWith('row:')) {
        final parts = key.split(':');
        if (parts.length >= 3) {
          final lineIndex = int.tryParse(parts[2]) ?? -1;
          final row = allRows.firstWhere(
            (r) => r.noteSlug == parts[1] && r.lineIndex == lineIndex,
            orElse: () => allRows.firstOrNull ?? allRows.first,
          );
          final note = notes.firstWhere(
            (n) => n.slug == row.noteSlug,
            orElse: () => notes.first,
          );
          final blockId =
              await CollectionRowService.ensureBlockId(ref, note, row);
          refs.add(VaultLinkRef(
            noteSlug: row.noteSlug,
            blockId: blockId,
            displayTitle: row.displayTitle,
          ));
        }
      }
    }
    if (!mounted) return;
    Navigator.pop(context, refs);
  }

  IconData _iconForType(String type) => switch (type) {
        'task' => Icons.check_box_outline_blank_rounded,
        'goal' => Icons.flag_outlined,
        'habit' => Icons.loop_rounded,
        'note' => Icons.note_outlined,
        'project' => Icons.folder_outlined,
        _ => Icons.article_outlined,
      };
}
