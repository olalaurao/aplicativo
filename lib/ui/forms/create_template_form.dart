import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/template_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/rich_text_editor.dart';

class CreateTemplateForm extends ConsumerStatefulWidget {
  final TemplateDefinition? existingTemplate;
  final String? initialType;
  final String? initialBody;

  const CreateTemplateForm({
    super.key,
    this.existingTemplate,
    this.initialType,
    this.initialBody,
  });

  @override
  ConsumerState<CreateTemplateForm> createState() => _CreateTemplateFormState();
}

class _CreateTemplateFormState extends ConsumerState<CreateTemplateForm> {
  late TextEditingController _titleController;
  late String _selectedType;
  late String _body;
  late Map<String, dynamic> _frontmatterDefaults;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingTemplate?.title ?? '',
    );
    _selectedType = widget.existingTemplate?.templateType ?? 
                    widget.initialType ?? 
                    'note';
    _body = widget.existingTemplate?.body ?? widget.initialBody ?? '';
    _frontmatterDefaults = Map<String, dynamic>.from(widget.existingTemplate?.frontmatterDefaults ?? {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira um título.')),
      );
      return;
    }

    if (widget.existingTemplate != null) {
      final updated = widget.existingTemplate!.copyWith(
        title: title,
        templateType: _selectedType,
        body: _body,
        frontmatterDefaults: _frontmatterDefaults,
      );
      await ref.read(templatesProvider.notifier).updateTemplate(updated);
    } else {
      final newTemplate = TemplateDefinition.create(
        title: title,
        templateType: _selectedType,
        body: _body,
        frontmatterDefaults: _frontmatterDefaults,
      );
      await ref.read(templatesProvider.notifier).addTemplate(newTemplate);
    }

    if (mounted) {
      context.pop();
    }
  }

  void _showAddPropertyDialog() {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    String propertyType = 'custom';
    String selectedPriority = 'medium';
    int durationMinutes = 30;
    bool isPinned = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Nova Propriedade Padrão'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: propertyType,
                      decoration: const InputDecoration(labelText: 'Tipo de Propriedade'),
                      items: [
                        const DropdownMenuItem(value: 'custom', child: Text('Personalizada')),
                        if (_selectedType == 'task') ...[
                          const DropdownMenuItem(value: 'priority', child: Text('Prioridade (priority)')),
                          const DropdownMenuItem(value: 'duration', child: Text('Duração em min (duration)')),
                        ],
                        if (_selectedType == 'note')
                          const DropdownMenuItem(value: 'pinned', child: Text('Fixado (pinned)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            propertyType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (propertyType == 'custom') ...[
                      TextField(
                        controller: keyController,
                        decoration: const InputDecoration(labelText: 'Chave (ex: tags, autor)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: valueController,
                        decoration: const InputDecoration(labelText: 'Valor'),
                      ),
                    ] else if (propertyType == 'priority') ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedPriority,
                        decoration: const InputDecoration(labelText: 'Prioridade'),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('Nenhuma')),
                          DropdownMenuItem(value: 'low', child: Text('Baixa')),
                          DropdownMenuItem(value: 'medium', child: Text('Média')),
                          DropdownMenuItem(value: 'high', child: Text('Alta')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedPriority = val;
                            });
                          }
                        },
                      ),
                    ] else if (propertyType == 'duration') ...[
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Minutos'),
                        onChanged: (val) {
                          durationMinutes = int.tryParse(val) ?? 30;
                        },
                      ),
                    ] else if (propertyType == 'pinned') ...[
                      Row(
                        children: [
                          const Text('Fixar por padrão?'),
                          const Spacer(),
                          Switch(
                            value: isPinned,
                            onChanged: (val) {
                              setDialogState(() {
                                isPinned = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCELAR'),
                ),
                TextButton(
                  onPressed: () {
                    String finalKey = '';
                    dynamic finalValue;

                    if (propertyType == 'custom') {
                      finalKey = keyController.text.trim();
                      finalValue = valueController.text.trim();
                    } else if (propertyType == 'priority') {
                      finalKey = 'priority';
                      finalValue = selectedPriority;
                    } else if (propertyType == 'duration') {
                      finalKey = 'duration';
                      finalValue = durationMinutes;
                    } else if (propertyType == 'pinned') {
                      finalKey = 'pinned';
                      finalValue = isPinned;
                    }

                    if (finalKey.isNotEmpty) {
                      setState(() {
                        _frontmatterDefaults[finalKey] = finalValue;
                      });
                    }
                    Navigator.pop(ctx);
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  child: const Text('ADICIONAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFrontmatterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Metadados Padrão (Frontmatter)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 20),
              onPressed: _showAddPropertyDialog,
              tooltip: 'Adicionar propriedade',
            ),
          ],
        ),
        if (_frontmatterDefaults.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Nenhum metadado padrão definido.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _frontmatterDefaults.entries.map((entry) {
                return InputChip(
                  label: Text('${entry.key}: ${entry.value}'),
                  onDeleted: () {
                    setState(() {
                      _frontmatterDefaults.remove(entry.key);
                    });
                  },
                  deleteIconColor: AppColors.error,
                  backgroundColor: AppColors.surfaceVariant,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTemplate == null ? 'Novo Template' : 'Editar Template'),
        actions: [
          TextButton(
            onPressed: _saveTemplate,
            child: const Text(
              'Salvar',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'Título do Template',
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tipo de Objeto', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'note', child: Text('Nota')),
                      DropdownMenuItem(value: 'task', child: Text('Tarefa')),
                      DropdownMenuItem(value: 'entry', child: Text('Journal Entry')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedType = val;
                          // Filter out properties that don't match the new type
                          if (_selectedType == 'task') {
                            _frontmatterDefaults.remove('pinned');
                          } else if (_selectedType == 'note') {
                            _frontmatterDefaults.remove('priority');
                            _frontmatterDefaults.remove('duration');
                          } else {
                            _frontmatterDefaults.remove('pinned');
                            _frontmatterDefaults.remove('priority');
                            _frontmatterDefaults.remove('duration');
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFrontmatterSection(),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: RichTextEditor(
                  content: _body,
                  onChanged: (val) => _body = val,
                  placeholder: 'Conteúdo do template... Use {{date}}, {{time}}, {{title}} para variáveis.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
