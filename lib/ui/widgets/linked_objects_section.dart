import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import 'universal_search_picker.dart';
import '../screens/universal_detail_view.dart';

class LinkedObjectsSection extends ConsumerWidget {
  final ContentObject owner;
  final List<String> links;
  final Future<void> Function(ContentObject selected) onAdd;
  final Future<void> Function(String slug) onRemove;
  final String? addButtonLabel;

  const LinkedObjectsSection({
    super.key,
    required this.owner,
    required this.links,
    required this.onAdd,
    required this.onRemove,
    this.addButtonLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final linked = _resolve(allObjects, links);
    final grouped = <String, List<ContentObject>>{};
    for (final obj in linked) {
      grouped.putIfAbsent(obj.type, () => []).add(obj);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 12, top: 24, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 20, color: AppTheme.accentColor(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Objetos vinculados',
                  style: AppTheme.sectionHeaderStyle(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => _pickObject(context),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: Text(addButtonLabel ?? 'Link'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        linked.isEmpty
            ? const Text('Nenhum objeto vinculado',
                style: TextStyle(color: AppColors.textMuted))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: grouped.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key.toUpperCase(),
                        style: const TextStyle(color: AppColors.textMuted,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8,
                        children: entry.value.map((obj) => InputChip(
                          label: Text(obj.title, maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                          onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                              UniversalDetailView(object: obj))),
                          onDeleted: () => onRemove('[[${obj.slug}]]'),
                        )).toList(),
                      ),
                    ],
                  ),
                )).toList(),
              ),
      ],
    );
  }

  List<ContentObject> _resolve(List<ContentObject> all, List<String> refs) {
    final slugs = refs.map((r) =>
      r.replaceAll('[[', '').replaceAll(']]', '').trim()).toSet();
    return all.where((o) => slugs.contains(o.slug)).toList();
  }

  void _pickObject(BuildContext context) async {
    final selected = await showModalBottomSheet<ContentObject>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UniversalSearchPickerSheet(
        title: 'Vincular objeto',
        onSelected: (obj) => Navigator.pop(context, obj),
        showClear: false,
      ),
    );
    if (selected != null) await onAdd(selected);
  }
}
