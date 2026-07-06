// lib/ui/forms/create_project_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/shared_types.dart';
import '../../models/template_model.dart';
import '../../models/kpi_model.dart' as kpi_model;
import '../../models/scheduler.dart';
import '../../models/habit_model.dart';
import '../../models/tracker_model.dart';
import '../../providers/vault_provider.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';
import '../../services/collection_row_service.dart';
import '../theme.dart';
import 'scheduler_picker.dart';

class CreateProjectForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final Project? existingProject;
  final List<OrganizerReference>? initialOrganizers;
  const CreateProjectForm({super.key, this.initialTitle, this.existingProject, this.initialOrganizers});

  @override
  ConsumerState<CreateProjectForm> createState() => _CreateProjectFormState();
}

class _CreateProjectFormState extends ConsumerState<CreateProjectForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  ProjectState _state = ProjectState.active;
  TaskPriority _priority = TaskPriority.none;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedColor = '#3B82F6';
  List<OrganizerReference> _organizers = [];
  bool _useRotation = false;
  DateTime? _rotationStartDate;
  String? _methodLabel;
  List<RotationGroup> _rotationGroups = [];
  final _methodLabelController = TextEditingController();
  List<kpi_model.KPI> _kpis = [];
  Scheduler? _scheduler;

  static const _colorSwatches = [
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#DC2626',
    '#F97316',
    '#F59E0B',
    '#10B981',
    '#14B8A6',
    '#6B7280',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = WikiLinkTextController(
      context: context,
      text: widget.existingProject?.title ?? widget.initialTitle,
    );
    _descController = WikiLinkTextController(
      context: context,
      text: widget.existingProject?.description ?? '',
    );

    if (widget.existingProject != null) {
      final project = widget.existingProject!;
      _state = project.projectState;
      _priority = project.projectPriority;
      _startDate = project.startDate;
      _endDate = project.endDate;
      _selectedColor = project.color ?? '#3B82F6';
      _organizers = List.from(project.organizers);
      _useRotation = project.hasRotation;
      _rotationStartDate = project.rotationStartDate;
      _methodLabel = project.methodLabel;
      _methodLabelController.text = project.methodLabel ?? '';
      _rotationGroups = List.from(project.rotationGroups);
      _kpis = List.from(project.kpis);
      _scheduler = project.scheduler;
    } else {
      if (widget.initialOrganizers != null) {
        _organizers = List.from(widget.initialOrganizers!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _methodLabelController.dispose();
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
            content: const Text('Você possui alterações não salvas. Deseja sair mesmo assim?'),
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
      child:  Scaffold(
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
              'New Project',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            actions: [
              if (widget.existingProject == null)
                IconButton(
                  icon: const Icon(
                    Icons.copy_all_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Usar Template',
                  onPressed: _showTemplatePicker,
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // âÂ”Â€âÂ”Â€âÂ”Â€ Title âÂ”Â€âÂ”Â€âÂ”Â€
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Project title',
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

                  // âÂ”Â€âÂ”Â€âÂ”Â€ Color Swatches âÂ”Â€âÂ”Â€âÂ”Â€
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colorSwatches.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final hex = _colorSwatches[index];
                        final color = _parseColor(hex);
                        final selected = _selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: selected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // âÂ”Â€âÂ”Â€âÂ”Â€ State & Priority âÂ”Â€âÂ”Â€âÂ”Â€
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDropdownRow<ProjectState>(
                          'State',
                          _state,
                          ProjectState.values,
                          (val) => setState(() => _state = val!),
                        ),
                        const Divider(height: 24),
                        _buildDropdownRow<TaskPriority>(
                          'Priority',
                          _priority,
                          TaskPriority.values,
                          (val) => setState(() => _priority = val!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // âÂ”Â€âÂ”Â€âÂ”Â€ Dates âÂ”Â€âÂ”Â€âÂ”Â€
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _dateRow(
                          'Start Date',
                          _startDate,
                          (d) => setState(() => _startDate = d),
                        ),
                        const Divider(height: 24),
                        _dateRow(
                          'Due Date',
                          _endDate,
                          (d) => setState(() => _endDate = d),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // âÂ”Â€âÂ”Â€âÂ”Â€ Description âÂ”Â€âÂ”Â€âÂ”Â€
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descController,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Project goals and details...',
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // KPIs
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'KPIs',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addKpi,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add KPI'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_kpis.isEmpty)
                          const Text(
                            'No KPIs configured',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          )
                        else
                          ..._kpis.asMap().entries.map((e) {
                            final kpi = e.value;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(kpi.title),
                              subtitle: Text(
                                '${kpi.currentValue.toStringAsFixed(0)} / ${kpi.targetValue.toStringAsFixed(0)}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(() => _kpis.removeAt(e.key)),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Scheduler
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Scheduler',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (_scheduler != null)
                              TextButton.icon(
                                onPressed: () => setState(() => _scheduler = null),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: const Text('Remove'),
                              )
                            else
                              TextButton.icon(
                                onPressed: _addScheduler,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add Scheduler'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_scheduler != null)
                          Text(
                            'Scheduler configured',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Organizers
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: OrganizerSelectorField(
                      selectedOrganizers: _organizers,
                      onChanged: (val) => setState(() => _organizers = val),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Este projeto usa rotação de zonas'),
                          value: _useRotation,
                          onChanged: (v) => setState(() => _useRotation = v),
                        ),
                        if (_useRotation) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Início da rotação'),
                            subtitle: Text(
                              _rotationStartDate != null
                                  ? DateFormat('d MMM yyyy')
                                      .format(_rotationStartDate!)
                                  : 'Selecionar data',
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _rotationStartDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _rotationStartDate = picked);
                              }
                            },
                          ),
                          TextField(
                            controller: _methodLabelController,
                            decoration: const InputDecoration(
                              labelText: 'Rótulo do método (opcional)',
                              hintText: 'Método FlyLady',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._rotationGroups.asMap().entries.map((e) {
                            final g = e.value;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${g.emoji ?? ''} ${g.name}'.trim()),
                              subtitle: Text('${g.periodDays} dias'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(
                                  () => _rotationGroups.removeAt(e.key),
                                ),
                              ),
                            );
                          }),
                          TextButton.icon(
                            onPressed: _addRotationGroup,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Adicionar zona'),
                          ),
                        ],
                      ],
                    ),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: hasTitle ? _saveProject : null,
              style: FilledButton.styleFrom(
                backgroundColor: _parseColor(_selectedColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Create Project',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildDropdownRow<T extends Enum>(
    String label,
    T value,
    List<T> values,
    ValueChanged<T?> onChanged,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        DropdownButton<T>(
          value: value,
          underline: const SizedBox(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          onChanged: onChanged,
          items: values
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.name.toUpperCase()),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _dateRow(
    String label,
    DateTime? date,
    ValueChanged<DateTime?> onPicked,
  ) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onPicked(d);
      },
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            date != null ? DateFormat('MMM d, yyyy').format(date) : 'Set date',
            style: TextStyle(
              fontSize: 14,
              color: date != null ? AppColors.primary : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  void _addKpi() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _KpiBuilderSheet(
        onSave: (kpi) {
          setState(() => _kpis.add(kpi));
        },
      ),
    );
  }

  void _addScheduler() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SchedulerPicker(
        initialScheduler: _scheduler,
      ),
    ).then((scheduler) {
      if (scheduler != null) {
        setState(() => _scheduler = scheduler);
      }
    });
  }

  void _addRotationGroup() {
    final nameController = TextEditingController();
    final daysController = TextEditingController(text: '7');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova zona'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duração (dias)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              setState(() {
                _rotationGroups.add(RotationGroup(
                  id: slugify(name),
                  name: name,
                  periodDays: int.tryParse(daysController.text) ?? 7,
                  order: _rotationGroups.length,
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showTemplatePicker() async {
    final templates = ref
        .read(templatesProvider)
        .where((t) => t.templateType == 'project')
        .toList();

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Templates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/create/template',
                      extra: {'initialType': 'project'},
                    );
                  },
                  child: const Text('Criar novo'),
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
                  Navigator.pop(context);
                  _applyTemplate(t);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyTemplate(TemplateDefinition template) {
    setState(() {
      if (template.frontmatterDefaults.containsKey('title')) {
        _titleController.text = template.frontmatterDefaults['title'] as String;
      }
      if (template.frontmatterDefaults.containsKey('description')) {
        _descController.text = template.frontmatterDefaults['description'] as String;
      }
      if (template.frontmatterDefaults.containsKey('color')) {
        _selectedColor = template.frontmatterDefaults['color'] as String;
      }
      if (template.frontmatterDefaults.containsKey('priority')) {
        final priorityStr = template.frontmatterDefaults['priority'] as String;
        _priority = TaskPriority.values.firstWhere(
          (e) => e.name == priorityStr,
          orElse: () => TaskPriority.none,
        );
      }
      if (template.body.isNotEmpty) {
        _descController.text = template.body;
      }
    });
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _saveProject() {
    var project = Project(
      id:
          widget.existingProject?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: widget.existingProject?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      state: _state,
      priority: _priority,
      startDate: _startDate,
      endDate: _endDate,
      color: _selectedColor,
      organizers: _organizers,
      kpis: _kpis,
      scheduler: _scheduler,
    );

    project = project.copyProjectWith(
      rotationGroups: _useRotation ? _rotationGroups : [],
      rotationStartDate: _useRotation ? _rotationStartDate : null,
      methodLabel: _useRotation && _methodLabelController.text.trim().isNotEmpty
          ? _methodLabelController.text.trim()
          : null,
    );

    if (widget.existingProject != null) {
      ref.read(vaultProvider.notifier).updateObject(project);
    } else {
      ref.read(vaultProvider.notifier).createObject(project);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Project "${project.title}" ${widget.existingProject != null ? 'updated' : 'created'}!',
        ),
        backgroundColor: _parseColor(_selectedColor),
      ),
    );
  }
}

class _KpiBuilderSheet extends ConsumerStatefulWidget {
  final Function(kpi_model.KPI) onSave;
  const _KpiBuilderSheet({required this.onSave});

  @override
  ConsumerState<_KpiBuilderSheet> createState() => _KpiBuilderSheetState();
}

class _KpiBuilderSheetState extends ConsumerState<_KpiBuilderSheet> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  kpi_model.KPISourceType _sourceType = kpi_model.KPISourceType.manualQuantity;
  String? _sourceId;
  String? _fieldId;

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(objectsByTypeProvider('habit')).whereType<Habit>().toList();
    final trackers = ref.watch(objectsByTypeProvider('tracker')).whereType<TrackerDefinition>().toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add KPI',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'KPI Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<kpi_model.KPISourceType>(
            initialValue: _sourceType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de Fonte',
              border: OutlineInputBorder(),
            ),
            items: kpi_model.KPISourceType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(
                      t.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                _sourceType = v!;
                _sourceId = null;
                _fieldId = null;
              });
            },
          ),
          const SizedBox(height: 12),

          if (_sourceType.name.startsWith('habit'))
            DropdownButtonFormField<String>(
              initialValue: _sourceId,
              decoration: const InputDecoration(
                labelText: 'Selecionar Habit',
                border: OutlineInputBorder(),
              ),
              items: habits
                  .map<DropdownMenuItem<String>>(
                    (h) => DropdownMenuItem(
                      value: h.id,
                      child: Text(h.displayTitle),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _sourceId = v),
            ),

          if (_sourceType.name.startsWith('tracker')) ...[
            DropdownButtonFormField<String>(
              initialValue: _sourceId,
              decoration: const InputDecoration(
                labelText: 'Selecionar Rastreador',
                border: OutlineInputBorder(),
              ),
              items: trackers
                  .map<DropdownMenuItem<String>>(
                    (t) => DropdownMenuItem(value: t.id, child: Text(t.title)),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _sourceId = v;
                _fieldId = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_sourceId != null) ...[
              Builder(
                builder: (context) {
                  final tracker = trackers.firstWhere(
                    (t) => t.id == _sourceId,
                    orElse: () => trackers.first,
                  );
                  final allFields = tracker.sections
                      .expand((s) => s.inputFields)
                      .toList();
                  return DropdownButtonFormField<String>(
                    initialValue: _fieldId,
                    decoration: const InputDecoration(
                      labelText: 'Selecionar Campo',
                      border: OutlineInputBorder(),
                    ),
                    items: allFields
                        .map(
                          (f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(f.title),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _fieldId = v),
                  );
                },
              ),
            ],
          ],

          if (_sourceType.name.startsWith('habit') ||
              _sourceType.name.startsWith('tracker'))
            const SizedBox(height: 12),

          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Valor Meta',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_titleController.text.isEmpty ||
                    _targetController.text.isEmpty) {
                  return;
                }
                final newKpi = kpi_model.KPI(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleController.text,
                  sourceType: _sourceType,
                  sourceId: _sourceId,
                  fieldId: _fieldId,
                  targetValue: double.tryParse(_targetController.text) ?? 100,
                  autoComplete: false,
                );
                widget.onSave(newKpi);
                Navigator.pop(context);
              },
              child: const Text('Save KPI'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
