import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../widgets/date_picker_field.dart';
import '../../models/note_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../widgets/outline_editor.dart';
import '../widgets/rich_text_editor.dart';
import '../widgets/collection_editor.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/metadata_strip.dart';
import '../widgets/organizer_picker_modal.dart';
import 'package:go_router/go_router.dart';

enum NoteType { text, outline, collection }

class CreateNoteForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final Note? existingNote;
  final List<String>? initialTags;
  final String? initialFolder;
  final NoteType? initialType;
  final List<OrganizerReference>? initialOrganizers;
  const CreateNoteForm({
    super.key,
    this.initialTitle,
    this.existingNote,
    this.initialTags,
    this.initialFolder,
    this.initialType,
    this.initialOrganizers,
  });

  @override
  ConsumerState<CreateNoteForm> createState() => _CreateNoteFormState();
}

class _CreateNoteFormState extends ConsumerState<CreateNoteForm> {
  late final TextEditingController _titleController;
  String _richContent = '';
  NoteType _noteType = NoteType.text;
  List<OrganizerReference> _organizers = [];
  List<String> _tags = [];
  bool _pinned = false;
  bool _isChecklist = false;
  bool _showInPlanner = false;
  DateTime _createdAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _titleController = WikiLinkTextController(
      context: context,
      text: widget.existingNote?.title ?? widget.initialTitle ?? '',
    );

    if (widget.initialTags != null) {
      _tags.addAll(widget.initialTags!);
    }

    if (widget.existingNote != null) {
      final note = widget.existingNote!;
      _richContent = note.body;
      _organizers = List.of(note.organizers);
      _tags = List.of(note.tags);
      _pinned = note.pinned;
      _isChecklist = note.isChecklist;
      _showInPlanner = note.showInPlanner;
      _createdAt = note.createdAt;
      switch (note.subtype) {
        case NoteSubtype.text:
          _noteType = NoteType.text;
          break;
        case NoteSubtype.outline:
          _noteType = NoteType.outline;
          break;
        case NoteSubtype.collection:
          _noteType = NoteType.collection;
          break;
      }
    } else {
      if (widget.initialType != null) {
        _noteType = widget.initialType!;
      }
      if (widget.initialOrganizers != null) {
        _organizers = List.from(widget.initialOrganizers!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = _titleController.text.trim().isNotEmpty;

    final isDirty = _titleController.text.trim().isNotEmpty;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text(
              'Você possui alterações não salvas. Deseja sair mesmo assim?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if ((discard ?? false) && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'New Note',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.copy_all_rounded,
                    color: AppTheme.accentColor(context),
                  ),
                  tooltip: 'Usar Template',
                  onPressed: _showTemplatePicker,
                ),
                TextButton(
                  onPressed: hasTitle ? _saveNote : null,
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: hasTitle ? AppTheme.accentColor(context) : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    // Type selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _typeSelector(
                            NoteType.text,
                            'Text',
                            Icons.description_outlined,
                          ),
                          _typeSelector(
                            NoteType.outline,
                            'Outline',
                            Icons.account_tree_outlined,
                          ),
                          _typeSelector(
                            NoteType.collection,
                            'Collection',
                            Icons.grid_view_rounded,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    TextField(
                      controller: _titleController,
                      onChanged: (_) { if (mounted) setState(() {}); },
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // âÂ”Â€âÂ”Â€âÂ”Â€ Metadata Strip âÂ”Â€âÂ”Â€âÂ”Â€
                    MetadataStrip(
                      chips: [
                        MetadataChip(
                          icon: Icons.layers_outlined,
                          label: _organizers.isEmpty
                              ? 'Organizers'
                              : '${_organizers.length} organizers',
                          onTap: _pickOrganizer,
                        ),
                        MetadataChip(
                          icon: Icons.tag_rounded,
                          label: _tags.isEmpty ? 'Tags' : _tags.join(', '),
                          onTap: _editTags,
                        ),
                        MetadataChip(
                          icon: _pinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          label: _pinned ? 'Pinned' : 'Pin',
                          onTap: () => setState(() => _pinned = !_pinned),
                        ),
                        MetadataChip(
                          icon: _isChecklist
                              ? Icons.checklist_rtl_rounded
                              : Icons.check_box_outline_blank_rounded,
                          label: 'Checklist',
                          onTap: () =>
                              setState(() => _isChecklist = !_isChecklist),
                        ),
                        if (_noteType == NoteType.text)
                          MetadataChip(
                            icon: _showInPlanner
                                ? Icons.event_available_rounded
                                : Icons.event_note_outlined,
                            label: _showInPlanner ? 'No Planner' : 'Ocultar',
                            onTap: () => setState(
                              () => _showInPlanner = !_showInPlanner,
                            ),
                          ),
                        MetadataChip(
                          icon: Icons.calendar_today_outlined,
                          label:
                              '${_createdAt.year}-${_createdAt.month.toString().padLeft(2, '0')}-${_createdAt.day.toString().padLeft(2, '0')}',
                          onTap: _pickDate,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Content
                    _noteType == NoteType.outline
                        ? OutlineEditor(
                            initialContent: _richContent,
                            onChanged: (v) => _richContent = v,
                          )
                        : _noteType == NoteType.collection
                        ? CollectionEditor(
                            initialContent: _richContent,
                            onChanged: (v) => _richContent = v,
                          )
                        : SizedBox(
                            height: 500,
                            child: RichTextEditor(
                              content: _richContent,
                              placeholder: _hintForType(),
                              onChanged: (v) => _richContent = v,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeSelector(NoteType type, String label, IconData icon) {
    final selected = _noteType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _noteType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkCardFill
                      : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppTheme.accentColor(context) : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hintForType() {
    switch (_noteType) {
      case NoteType.text:
        return 'Start writing...';
      case NoteType.outline:
        return 'Use bullets for your outline...';
      case NoteType.collection:
        return 'Add items to your collection...';
    }
  }

  void _saveNote() {
    final defaultPath = widget.initialFolder != null
        ? '${widget.initialFolder}/'
        : '';

    final note = Note(
      id:
          widget.existingNote?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: _createdAt,
      obsidianPath: widget.existingNote?.obsidianPath ?? defaultPath,
      updatedAt: DateTime.now(),
      title: _titleController.text.trim(),
      subtype: _mapNoteTypeToSubtype(_noteType),
      body: _richContent.trim(),
      organizers: _organizers,
      tags: _tags,
      pinned: _pinned,
      isChecklist: _isChecklist,
      showInPlanner: _noteType == NoteType.text && _showInPlanner,
      schedulerSlug: widget.existingNote?.schedulerSlug,
    );

    if (widget.existingNote != null) {
      ref.read(vaultProvider.notifier).updateObject(note);
    } else {
      ref.read(vaultProvider.notifier).createObject(note);
    }

    Navigator.pop(context, true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Note "${note.title}" ${widget.existingNote != null ? 'updated' : 'saved'}',
        ),
      ),
    );
  }

  NoteSubtype _mapNoteTypeToSubtype(NoteType type) {
    switch (type) {
      case NoteType.text:
        return NoteSubtype.text;
      case NoteType.outline:
        return NoteSubtype.outline;
      case NoteType.collection:
        return NoteSubtype.collection;
    }
  }

  Future<void> _pickOrganizer() async {
    final res = await showOrganizerPickerModal(context, ref, _organizers);
    if (res != null && mounted) {
      setState(() {
        _organizers.clear();
        _organizers.addAll(res);
      });
    }
  }

  Future<void> _editTags() async {
    final controller = TextEditingController(text: _tags.join(', '));
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tags'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'work, ideas, reference'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final tags = controller.text
                  .split(',')
                  .map((tag) => tag.trim().replaceFirst(RegExp(r'^#'), ''))
                  .where((tag) => tag.isNotEmpty)
                  .toSet()
                  .toList();
              Navigator.pop(context, tags);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) setState(() => _tags = result);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _createdAt = picked);
  }

  void _showTemplatePicker() async {
    final templates = ref
        .read(templatesProvider)
        .where((t) => t.templateType == 'note')
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Templates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/create/template',
                      extra: {'initialType': 'note'},
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (templates.isEmpty)
              const Text(
                'Nenhum template encontrado.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ...templates.map(
              (t) => ListTile(
                title: Text(t.title),
                onTap: () {
                  String body = t.body;
                  body = body.replaceAll(
                    '{{date}}',
                    DateFormat('dd/MM/yyyy').format(_createdAt),
                  );
                  body = body.replaceAll(
                    '{{time}}',
                    DateFormat('HH:mm').format(_createdAt),
                  );
                  body = body.replaceAll(
                    '{{weekday}}',
                    DateFormat('EEEE').format(_createdAt),
                  );
                  body = body.replaceAll(
                    '{{title}}',
                    _titleController.text.isNotEmpty
                        ? _titleController.text
                        : 'Nova Nota',
                  );

                  setState(() {
                    if (_richContent.isEmpty) {
                      _richContent = body;
                    } else {
                      _richContent += '\n$body';
                    }

                    if (t.frontmatterDefaults.containsKey('pinned')) {
                      _pinned = t.frontmatterDefaults['pinned'] == true;
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
