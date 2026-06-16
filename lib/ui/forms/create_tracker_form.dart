// lib/ui/forms/create_tracker_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tracker_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../widgets/organizer_selector_field.dart';
import '../theme.dart';

class CreateTrackerForm extends ConsumerStatefulWidget {
  final TrackerDefinition? tracker;
  const CreateTrackerForm({super.key, this.tracker});

  @override
  ConsumerState<CreateTrackerForm> createState() => _CreateTrackerFormState();
}

class _CreateTrackerFormState extends ConsumerState<CreateTrackerForm> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedColor = '#EF4444';
  final List<TrackerSection> _sections = [];
  List<OrganizerReference> _organizers = [];
  bool _isHealthTracker = false;

  static const _colorSwatches = [
    '#EF4444',
    '#F97316',
    '#F59E0B',
    '#10B981',
    '#06B6D4',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#6B7280',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.tracker != null) {
      _titleController.text = widget.tracker!.title;
      _descController.text = widget.tracker!.description ?? '';
      _selectedColor = widget.tracker!.color;
      _sections.addAll(widget.tracker!.sections);
      _organizers = List.from(widget.tracker!.organizers);
      _isHealthTracker = widget.tracker!.isHealthTracker;
    } else {
      _sections.add(TrackerSection(title: 'Default Section', inputFields: []));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _canSave;

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
              title: Text(
                widget.tracker == null ? 'Novo Tracker' : 'Edit Tracker',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
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
                        hintText: 'Tracker Title',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Color Selector
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colorSwatches.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final hex = _colorSwatches[index];
                          final color = Color(
                            int.parse(hex.replaceAll('#', '0xFF')),
                          );
                          final selected = _selectedColor == hex;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = hex),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description and organizers
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Descrição',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descController,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'O que você quer rastrear?',
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const Divider(height: 24),
                          OrganizerSelectorField(
                            selectedOrganizers: _organizers,
                            onChanged: (val) =>
                                setState(() => _organizers = val),
                          ),
                          const Divider(height: 24),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _isHealthTracker,
                            onChanged: (value) =>
                                setState(() => _isHealthTracker = value),
                            title: const Text(
                              'Tracker de saúde',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: const Text(
                              'Permite alertas automáticos por campo.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ..._sections.asMap().entries.map(
                      (entry) => _buildSectionEditor(entry.key, entry.value),
                    ),

                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Section'),
                      style: AppTheme.secondaryButtonStyle,
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: canSave ? _saveTracker : null,
                style: AppTheme.primaryButtonStyle,
                child: Text(
                  widget.tracker == null ? 'Create Tracker' : 'Save Changes',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSave {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasField = _sections.any(
      (section) =>
          section.inputFields.any((field) => field.title.trim().isNotEmpty),
    );
    return hasTitle && hasField;
  }

  Widget _buildSectionEditor(int sIndex, TrackerSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: section.title),
                  onChanged: (v) => section.title = v,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Section Name',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
                onPressed: () => setState(() => _sections.removeAt(sIndex)),
              ),
            ],
          ),
          const Divider(),
          ...section.inputFields.asMap().entries.map(
            (entry) => _buildFieldEditor(sIndex, entry.key, entry.value),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _addField(sIndex),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Add Campo'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldEditor(int sIndex, int fIndex, InputField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: TextEditingController(text: field.title),
                  onChanged: (v) => field.title = v,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Label',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
                Text(
                  field.type.name,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: field.type.name,
            items: InputFieldType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t.name,
                    child: Text(t.name, style: const TextStyle(fontSize: 12)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(
              () => field.type = InputFieldType.values.firstWhere(
                (e) => e.name == v,
              ),
            ),
            underline: const SizedBox(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 16),
            onPressed: () => _editFieldConfig(sIndex, fIndex, field),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () =>
                setState(() => _sections[sIndex].inputFields.removeAt(fIndex)),
          ),
        ],
      ),
    );
  }

  void _editFieldConfig(int sIndex, int fIndex, InputField field) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Config: ${field.title}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              if (field.type == InputFieldType.quantity ||
                  field.type == InputFieldType.range ||
                  field.type == InputFieldType.duration)
                TextField(
                  controller: TextEditingController(text: field.unit),
                  onChanged: (v) => field.unit = v,
                  decoration: const InputDecoration(
                    labelText: 'Unidade (ex: km, kg, horas)',
                  ),
                ),
              if (field.type == InputFieldType.range) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: field.min?.toString(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => field.min = double.tryParse(v),
                        decoration: const InputDecoration(labelText: 'Min'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: field.max?.toString(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => field.max = double.tryParse(v),
                        decoration: const InputDecoration(labelText: 'Max'),
                      ),
                    ),
                  ],
                ),
              ],
              if (field.type == InputFieldType.selection ||
                  field.type == InputFieldType.checklist)
                TextField(
                  controller: TextEditingController(
                    text: field.options?.join(', '),
                  ),
                  onChanged: (v) => field.options = v
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Options (comma-separated)',
                  ),
                ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: field.alwaysAlert,
                onChanged: (value) => setState(() => field.alwaysAlert = value),
                title: const Text(
                  'Sempre alertar quando registrado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownButtonFormField<FieldAlertLevel>(
                initialValue: field.alertLevel,
                decoration: const InputDecoration(labelText: 'Nível do alerta'),
                items: FieldAlertLevel.values
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text(_alertLevelLabel(level)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => field.alertLevel = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(
                  text: field.alertThreshold?.toString() ?? '',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) =>
                    field.alertThreshold = double.tryParse(value),
                decoration: const InputDecoration(
                  labelText: 'Threshold inferior',
                  helperText: 'Alerta quando o valor for menor ou igual.',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: field.alertNote ?? ''),
                onChanged: (value) => field.alertNote = value.trim().isEmpty
                    ? null
                    : value.trim(),
                decoration: const InputDecoration(
                  labelText: 'Nota do alerta',
                  hintText: 'Ex: depende dos remédios',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<FieldDataSource>(
                initialValue: field.dataSource,
                decoration: const InputDecoration(labelText: 'Fonte dos dados'),
                items: FieldDataSource.values
                    .map(
                      (source) => DropdownMenuItem(
                        value: source,
                        child: Text(_dataSourceLabel(source)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => field.dataSource = value);
                },
              ),
              if (field.dataSource == FieldDataSource.habit) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(
                    text: field.linkedHabitId ?? '',
                  ),
                  onChanged: (value) => field.linkedHabitId =
                      value.trim().isEmpty ? null : value.trim(),
                  decoration: const InputDecoration(
                    labelText: 'ID do hábito vinculado',
                  ),
                ),
              ],
              if (field.dataSource == FieldDataSource.recurringTask) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(
                    text: field.linkedTaskTitle ?? '',
                  ),
                  onChanged: (value) => field.linkedTaskTitle =
                      value.trim().isEmpty ? null : value.trim(),
                  decoration: const InputDecoration(
                    labelText: 'Texto da tarefa recorrente',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                  Navigator.pop(ctx);
                },
                child: const Text('OK'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _addSection() {
    setState(() {
      _sections.add(TrackerSection(title: 'New Section', inputFields: []));
    });
  }

  void _addField(int sIndex) {
    setState(() {
      _sections[sIndex].inputFields.add(
        InputField(
          id: 'field_${_sections[sIndex].inputFields.length + 1}',
          title: 'Novo Campo',
          type: InputFieldType.text,
        ),
      );
    });
  }

  void _saveTracker() {
    final tracker = TrackerDefinition(
      id: widget.tracker?.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      color: _selectedColor,
      sections: _sections,
      isHealthTracker: _isHealthTracker,
      organizers: _organizers,
    );

    if (widget.tracker != null) {
      ref.read(vaultProvider.notifier).updateObject(tracker);
    } else {
      ref.read(trackersProvider.notifier).addTracker(tracker);
    }
    Navigator.pop(context);
  }

  String _alertLevelLabel(FieldAlertLevel level) {
    return switch (level) {
      FieldAlertLevel.none => 'Sem alerta',
      FieldAlertLevel.info => 'Informativo',
      FieldAlertLevel.warning => 'Atenção',
      FieldAlertLevel.critical => 'Crítico',
    };
  }

  String _dataSourceLabel(FieldDataSource source) {
    return switch (source) {
      FieldDataSource.tracker => 'Registro do tracker',
      FieldDataSource.habit => 'Hábito vinculado',
      FieldDataSource.recurringTask => 'Tarefa recorrente',
    };
  }
}
