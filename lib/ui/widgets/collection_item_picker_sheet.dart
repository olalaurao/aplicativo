import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/note_model.dart';
import '../../models/shared_types.dart';
import '../../models/tracker_model.dart';
import '../../providers/vault_provider.dart';

class CollectionItemPickerSheet extends ConsumerStatefulWidget {
  final String collectionNoteSlug;

  const CollectionItemPickerSheet({
    super.key,
    required this.collectionNoteSlug,
  });

  @override
  ConsumerState<CollectionItemPickerSheet> createState() =>
      _CollectionItemPickerSheetState();

  static Future<VaultLinkRef?> show(
    BuildContext context, {
    required String collectionNoteSlug,
  }) {
    return showModalBottomSheet<VaultLinkRef>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CollectionItemPickerSheet(
        collectionNoteSlug: collectionNoteSlug,
      ),
    );
  }
}

class _CollectionItemPickerSheetState
    extends ConsumerState<CollectionItemPickerSheet> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _items = [];
  List<InputField> _schema = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    final allObjects = await ref.read(allObjectsProvider.future);
    final note = allObjects.where((o) => o is Note && o.slug == widget.collectionNoteSlug).firstOrNull as Note?;

    if (note == null || note.subtype != NoteSubtype.collection) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = jsonDecode(note.body);
      final schemaData = data is Map ? data['schema'] : null;
      final itemData = data is Map ? data['items'] : null;

      if (schemaData is List) {
        _schema = schemaData
            .whereType<Map>()
            .map((e) => InputField.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (itemData is List) {
        _items = itemData
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('CollectionItemPickerSheet parse error: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getItemTitle(Map<String, dynamic> item) {
    for (final prop in _schema) {
      if (prop.type != InputFieldType.text && prop.type != InputFieldType.selection) {
        continue;
      }
      final value = item[prop.id];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return 'Untitled';
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final query = _searchQuery.toLowerCase();
    return _items.where((item) {
      final title = _getItemTitle(item).toLowerCase();
      return title.contains(query);
    }).toList();
  }

  Future<void> _addNewItem() async {
    // Find first text-type property
    final textProp = _schema.firstWhere(
      (p) => p.type == InputFieldType.text,
      orElse: () => _schema.first,
    );

    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add new item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: textProp.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty) return;

    final newItem = <String, dynamic>{'id': DateTime.now().millisecondsSinceEpoch.toString()};
    newItem[textProp.id] = title;

    setState(() {
      _items.add(newItem);
    });

    await _saveCollection();

    final ref = VaultLinkRef(
      noteSlug: widget.collectionNoteSlug,
      blockId: newItem['id'],
      displayTitle: title,
    );

    if (mounted) Navigator.pop(context, ref);
  }

  Future<void> _saveCollection() async {
    final allObjects = await ref.read(allObjectsProvider.future);
    final note = allObjects.where((o) => o is Note && o.slug == widget.collectionNoteSlug).firstOrNull as Note?;

    if (note == null) return;

    final data = {
      'schema': _schema.map((e) => e.toMap()).toList(),
      'items': _items,
    };

    final updated = note.copyWith(body: jsonEncode(data));
    await ref.read(notesProvider.notifier).updateNote(updated);
  }

  void _selectItem(Map<String, dynamic> item) {
    final ref = VaultLinkRef(
      noteSlug: widget.collectionNoteSlug,
      blockId: item['id']?.toString(),
      displayTitle: _getItemTitle(item),
    );
    Navigator.pop(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      height: 500,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search items...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredItems.length + 1,
              itemBuilder: (context, index) {
                if (index == _filteredItems.length) {
                  // Add new item row
                  return ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add new item'),
                    onTap: _addNewItem,
                  );
                }

                final item = _filteredItems[index];
                final title = _getItemTitle(item);
                return ListTile(
                  title: Text(title),
                  onTap: () => _selectItem(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
