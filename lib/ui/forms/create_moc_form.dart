// lib/ui/forms/create_moc_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/moc_model.dart';
import '../../models/content_object.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../widgets/wiki_link_picker.dart';
import '../theme.dart';

class CreateMocForm extends ConsumerStatefulWidget {
  final MocDefinition? existingMoc;
  const CreateMocForm({super.key, this.existingMoc});

  @override
  ConsumerState<CreateMocForm> createState() => _CreateMocFormState();
}

class _CreateMocFormState extends ConsumerState<CreateMocForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<String> _children = [];

  @override
  void initState() {
    super.initState();
    final moc = widget.existingMoc;
    if (moc != null) {
      _titleController.text = moc.title;
      _descriptionController.text = moc.description;
      _children = List.from(moc.children);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];

    // Helper to resolve wikilink to title
    String _resolveWikiLinkTitle(String link) {
      final slug = link.replaceAll('[[', '').replaceAll(']]', '').trim();
      final obj = allObjects.firstWhere(
        (o) => o.slug == slug || o.title.toLowerCase() == slug.toLowerCase(),
        orElse: () => NewPagePlaceholder(title: slug),
      );
      return obj.title;
    }

    String _resolveWikiLinkType(String link) {
      final slug = link.replaceAll('[[', '').replaceAll(']]', '').trim();
      final obj = allObjects.firstWhere(
        (o) => o.slug == slug || o.title.toLowerCase() == slug.toLowerCase(),
        orElse: () => NewPagePlaceholder(title: slug),
      );
      return obj is NewPagePlaceholder ? 'note' : obj.type;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.existingMoc == null ? 'Novo MOC' : 'Editar MOC',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: hasTitle ? _saveMoc : null,
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: hasTitle ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'MOC Title',
                      hintStyle: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'MOC Description...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Itens Conectados (Children)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      IconButton(
                        onPressed: _addChild,
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                        tooltip: 'Adicionar Item',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_children.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.link_rounded, size: 32, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          const Text(
                            'Nenhum item conectado a este MOC',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _addChild,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Conectar Item'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 400,
                      child: ReorderableListView.builder(
                        itemCount: _children.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = _children.removeAt(oldIndex);
                            _children.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final link = _children[index];
                          final title = _resolveWikiLinkTitle(link);
                          final type = _resolveWikiLinkType(link);

                          return Card(
                            key: ValueKey(link),
                            margin: const EdgeInsets.only(bottom: 8),
                            color: AppColors.surfaceVariant,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            child: ListTile(
                              leading: _buildTypeIcon(type),
                              title: Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                link,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                    onPressed: () {
                                      setState(() {
                                        _children.removeAt(index);
                                      });
                                    },
                                  ),
                                  const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addChild() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WikiLinkPicker(
        onSelected: (obj) {
          Navigator.pop(context);
          final link = '[[${obj.slug}]]';
          if (!_children.contains(link)) {
            setState(() {
              _children.add(link);
            });
          }
        },
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'task':
        icon = Icons.check_circle_outline_rounded;
        color = AppColors.info;
        break;
      case 'habit':
        icon = Icons.repeat_rounded;
        color = AppColors.habitOrange;
        break;
      case 'project':
        icon = Icons.folder_open_rounded;
        color = AppColors.habitPurple;
        break;
      case 'person':
        icon = Icons.person_outline_rounded;
        color = AppColors.habitGreen;
        break;
      case 'resource':
        icon = Icons.bookmark_outline_rounded;
        color = AppColors.error;
        break;
      default:
        icon = Icons.description_outlined;
        color = AppColors.textMuted;
    }
    return Icon(icon, color: color, size: 20);
  }

  void _saveMoc() async {
    final existing = widget.existingMoc;
    final moc = MocDefinition(
      id: existing?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      children: _children,
      createdAt: existing?.createdAt,
      obsidianPath: existing?.obsidianPath ?? '',
    );

    if (existing == null) {
      await ref.read(mocsProvider.notifier).addMoc(moc);
    } else {
      await ref.read(mocsProvider.notifier).updateMoc(moc);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('MOC "${moc.title}" salvo com sucesso!'),
        ),
      );
    }
  }
}
