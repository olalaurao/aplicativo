import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/idea_model.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/rich_text_editor.dart';

class CreateIdeaForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final IdeaDefinition? existingIdea;

  const CreateIdeaForm({super.key, this.initialTitle, this.existingIdea});

  @override
  ConsumerState<CreateIdeaForm> createState() => _CreateIdeaFormState();
}

class _CreateIdeaFormState extends ConsumerState<CreateIdeaForm> {
  late final TextEditingController _titleController;
  String _richContent = '';
  List<String> _linkedTaskIds = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingIdea?.title ?? widget.initialTitle ?? '',
    );
    if (widget.existingIdea != null) {
      _richContent = widget.existingIdea!.body;
      _linkedTaskIds = List.from(widget.existingIdea!.linkedTaskIds);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveIdea() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final existing = widget.existingIdea;
    if (existing != null) {
      final idea = existing.copyWith(
        title: title,
        body: _richContent,
        linkedTaskIds: _linkedTaskIds,
        updatedAt: DateTime.now(),
      );
      await ref.read(ideasProvider.notifier).updateIdea(idea);
    } else {
      final idea = IdeaDefinition(
        id: const Uuid().v4(),
        title: title,
        body: _richContent,
        linkedTaskIds: _linkedTaskIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.read(ideasProvider.notifier).addIdea(idea);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _pickTasks() async {
    final allTasks =
        ref.read(allObjectsProvider).value?.whereType<Task>().toList() ?? [];

    // Simple bottom sheet to pick multiple tasks
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _TaskPickerSheet(
          allTasks: allTasks,
          initialSelectedIds: _linkedTaskIds,
        );
      },
    );

    if (result != null) {
      setState(() {
        _linkedTaskIds = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = _titleController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.existingIdea != null ? 'Editar Ideia' : 'Nova Ideia',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: hasTitle ? _saveIdea : null,
            child: Text(
              'Salvar',
              style: TextStyle(
                color: hasTitle ? AppColors.primary : AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              decoration: const InputDecoration(
                hintText: 'Título da Ideia',
                hintStyle: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: -0.5,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 20),

            // Linked Tasks
            GestureDetector(
              onTap: _pickTasks,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.task_alt_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _linkedTaskIds.isEmpty
                            ? 'Vincular Tasks...'
                            : '${_linkedTaskIds.length} tasks vinculadas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _linkedTaskIds.isEmpty
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            Expanded(
              child: RichTextEditor(
                content: _richContent,
                onChanged: (val) => _richContent = val,
                placeholder: 'Descreva sua ideia...',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskPickerSheet extends StatefulWidget {
  final List<Task> allTasks;
  final List<String> initialSelectedIds;

  const _TaskPickerSheet({
    required this.allTasks,
    required this.initialSelectedIds,
  });

  @override
  State<_TaskPickerSheet> createState() => _TaskPickerSheetState();
}

class _TaskPickerSheetState extends State<_TaskPickerSheet> {
  late Set<String> _selectedIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = widget.allTasks.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Tasks Vinculadas',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Buscar tasks...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppTheme.surfaceVariantColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filteredTasks.length,
              itemBuilder: (context, index) {
                final task = filteredTasks[index];
                final isSelected = _selectedIds.contains(task.id);
                return CheckboxListTile(
                  value: isSelected,
                  title: Text(task.title),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.add(task.id);
                      } else {
                        _selectedIds.remove(task.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.pop(context, _selectedIds.toList()),
              child: const Text(
                'Confirmar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
