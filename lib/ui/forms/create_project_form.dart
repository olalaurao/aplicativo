// lib/ui/forms/create_project_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/shared_types.dart';
import '../../models/template_model.dart';
import '../../models/kpi_model.dart' as kpi_model;
import '../../models/scheduler.dart';
import '../../models/habit_model.dart';
import '../../models/tracker_model.dart';
import '../../models/note_model.dart';
import '../../models/organizer_model.dart';
import '../../models/checklist_step.dart';
import '../../providers/vault_provider.dart';
import '../../providers/color_palette_provider.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';
import '../widgets/app_switch_tile.dart';
import '../widgets/date_picker_field.dart';
import '../widgets/checklist_step_editor.dart';
import '../../services/collection_row_service.dart';
import '../theme.dart';
import 'scheduler_picker.dart';
import '../../models/color_palette_model.dart';

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
  bool _rotationResetRequested = false;
  Scheduler? _scheduler;
  List<ChecklistStep> _steps = [];

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
      _steps = List.from(project.steps);
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
                  icon: Icon(
                    Icons.copy_all_rounded,
                    color: AppTheme.accentColor(context),
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
                    onChanged: (_) { if (mounted) setState(() {}); },
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

                  // ─── Color Swatches ───
                  SizedBox(
                    height: 44,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final palette = ref.watch(colorPaletteProvider);
                        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                        
                        // Use custom palette colors, or fall back to default
                        final colorHexes = isDarkMode && palette.useSeparateDarkPalette
                            ? palette.darkHexes
                            : palette.lightHexes;
                        
                        final colorsToUse = colorHexes.isNotEmpty
                            ? colorHexes
                            : _colorSwatches;
                        
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: colorsToUse.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final hex = colorsToUse[index];
                            final color = PaletteColor.parseHex(hex);
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

                  // Checklist Steps
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
                              'Checklist',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addChecklistStep,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Step'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_steps.isEmpty)
                          const Text(
                            'No checklist steps',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          )
                        else
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _steps.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final step = _steps.removeAt(oldIndex);
                                _steps.insert(newIndex, step);
                              });
                            },
                            itemBuilder: (context, index) {
                              return ChecklistStepEditor(
                                key: ValueKey(_steps[index].id),
                                step: _steps[index],
                                index: index,
                                onChanged: (title) {
                                  setState(() {
                                    _steps[index] = _steps[index].copyWith(title: title);
                                  });
                                },
                                onRemove: () {
                                  setState(() => _steps.removeAt(index));
                                },
                                onStepChanged: (updatedStep) {
                                  setState(() {
                                    _steps[index] = updatedStep;
                                  });
                                },
                              );
                            },
                          ),
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
                              color: AppTheme.accentColor(context),
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
                        AppSwitchTile(
                          title: 'This project uses zone rotation',
                          value: _useRotation,
                          onChanged: (v) => setState(() => _useRotation = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_useRotation) ...[
                          if (widget.existingProject?.rotationCurrentGroupId == null) ...[
                            // Show editable start date only if rotation hasn't started yet
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Rotation start date'),
                              subtitle: Text(
                                _rotationStartDate != null
                                    ? DateFormat('d MMM yyyy')
                                        .format(_rotationStartDate!)
                                    : 'Select date',
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
                          ] else ...[
                            // Rotation has started - show read-only label and reset action
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Started on'),
                              subtitle: Text(
                                widget.existingProject?.rotationCurrentPeriodStart != null
                                    ? DateFormat('d MMM yyyy').format(
                                        widget.existingProject!.rotationCurrentPeriodStart!)
                                    : 'Unknown',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Restart rotation?'),
                                    content: const Text(
                                      'This resets which zone is active and all rotation history. Continue?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Restart'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  setState(() {
                                    _rotationStartDate = DateTime.now();
                                    _rotationResetRequested = true;
                                  });
                                }
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Restart rotation from today'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.priorityHigh,
                              ),
                            ),
                          ],
                          TextField(
                            controller: _methodLabelController,
                            decoration: const InputDecoration(
                              labelText: 'Method label (optional)',
                              hintText: 'FlyLady method',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _rotationGroups.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex--;
                                final item = _rotationGroups.removeAt(oldIndex);
                                _rotationGroups.insert(newIndex, item);
                                // Update order fields to match new positions
                                for (int i = 0; i < _rotationGroups.length; i++) {
                                  _rotationGroups[i] = RotationGroup(
                                    id: _rotationGroups[i].id,
                                    name: _rotationGroups[i].name,
                                    emoji: _rotationGroups[i].emoji,
                                    colorHex: _rotationGroups[i].colorHex,
                                    periodDays: _rotationGroups[i].periodDays,
                                    order: i,
                                  );
                                }
                              });
                            },
                            itemBuilder: (context, index) {
                              final g = _rotationGroups[index];
                              return Card(
                                key: ValueKey('zone-${g.id}-$index'),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  leading: const Icon(Icons.drag_handle_rounded,
                                      color: AppColors.textMuted, size: 20),
                                  title: Text('${g.emoji ?? ''} ${g.name}'.trim()),
                                  subtitle: Text('${g.periodDays} days'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => setState(
                                      () => _rotationGroups.removeAt(index),
                                    ),
                                  ),
                                  onTap: () => _addRotationGroup(existingGroup: g),
                                ),
                              );
                            },
                          ),
                          TextButton.icon(
                            onPressed: () => _addRotationGroup(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add zone'),
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.accentColor(context),
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
              color: date != null ? AppTheme.accentColor(context) : AppColors.textMuted,
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

  void _addChecklistStep() {
    setState(() {
      _steps.add(ChecklistStep(
        title: 'New step',
        kind: 'plain',
      ));
    });
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

  void _addRotationGroup({RotationGroup? existingGroup}) {
    final nameController = TextEditingController(text: existingGroup?.name ?? '');
    final daysController = TextEditingController(text: existingGroup?.periodDays.toString() ?? '7');
    String? selectedEmoji = existingGroup?.emoji;
    String? selectedColor = existingGroup?.colorHex;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existingGroup == null ? 'New zone' : 'Edit zone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (days)'),
              ),
              const SizedBox(height: 12),
              // Emoji picker
              Row(
                children: [
                  const Text('Emoji: ', style: TextStyle(fontSize: 14)),
                  GestureDetector(
                    onTap: () async {
                      const emojis = ['🏠', '💼', '🏋️', '📚', '🎨', '🍳', '🧹', '🌿', '💰', '🚗', '✈️', '🎮'];
                      final picked = await showModalBottomSheet<String>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: GridView.builder(
                            shrinkWrap: true,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                            ),
                            itemCount: emojis.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.all(8),
                              child: GestureDetector(
                                onTap: () => Navigator.pop(ctx, emojis[i]),
                                child: Text(
                                  emojis[i],
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedEmoji = picked);
                      }
                    },
                    child: Text(
                      selectedEmoji ?? 'Select',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Color picker
              Row(
                children: [
                  const Text('Color: ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8,
                        children: _colorSwatches.map((color) {
                          final isSelected = selectedColor == color;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedColor = color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(int.parse(color.replaceAll('#', '0xFF'))),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.black : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                setState(() {
                  if (existingGroup == null) {
                    // Add new zone
                    _rotationGroups.add(RotationGroup(
                      id: slugify(name),
                      name: name,
                      emoji: selectedEmoji,
                      colorHex: selectedColor,
                      periodDays: int.tryParse(daysController.text) ?? 7,
                      order: _rotationGroups.length,
                    ));
                  } else {
                    // Edit existing zone - keep the same id
                    final index = _rotationGroups.indexWhere((g) => g.id == existingGroup.id);
                    if (index >= 0) {
                      _rotationGroups[index] = RotationGroup(
                        id: existingGroup.id,
                        name: name,
                        emoji: selectedEmoji,
                        colorHex: selectedColor,
                        periodDays: int.tryParse(daysController.text) ?? 7,
                        order: existingGroup.order,
                      );
                    }
                  }
                });
                Navigator.pop(ctx);
              },
              child: Text(existingGroup == null ? 'Add' : 'Save'),
            ),
          ],
        ),
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
      return AppTheme.accentColor(context);
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
      steps: _steps,
    );

    project = project.copyProjectWith(
      rotationGroups: _useRotation ? _rotationGroups : [],
      rotationStartDate: _useRotation ? _rotationStartDate : null,
      methodLabel: _useRotation && _methodLabelController.text.trim().isNotEmpty
          ? _methodLabelController.text.trim()
          : null,
      // Reset rotation state if user requested a restart
      rotationCurrentGroupId: _rotationResetRequested ? null : widget.existingProject?.rotationCurrentGroupId,
      rotationCurrentPeriodStart: _rotationResetRequested ? null : widget.existingProject?.rotationCurrentPeriodStart,
      rotationCycleNumber: _rotationResetRequested ? 1 : widget.existingProject?.rotationCycleNumber,
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
  String? _calculationMode;
  String? _selectedOtherMode;
  kpi_model.KPIDisplayType _displayType = kpi_model.KPIDisplayType.progressBar;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _autoComplete = false;
  ActionDef? _autoCompleteAction;

  List<_CalculationModeOption> _getCalculationModeOptions(kpi_model.KPISourceType sourceType) {
    switch (sourceType) {
      case kpi_model.KPISourceType.habit:
        return const [
          _CalculationModeOption(label: 'Total de conclusões', value: null),
          _CalculationModeOption(label: 'Sequência atual (streak)', value: 'streak'),
          _CalculationModeOption(label: 'Taxa de sucesso (%)', value: 'success_rate'),
        ];
      case kpi_model.KPISourceType.trackerField:
        return const [
          _CalculationModeOption(label: 'Soma', value: null),
          _CalculationModeOption(label: 'Média', value: 'average'),
          _CalculationModeOption(label: 'Máximo', value: 'max'),
          _CalculationModeOption(label: 'Mínimo', value: 'min'),
          _CalculationModeOption(label: 'Valor mais recente', value: 'latest'),
        ];
      case kpi_model.KPISourceType.subtasks:
        return const [
          _CalculationModeOption(label: 'Contagem de tarefas concluídas', value: null),
          _CalculationModeOption(label: 'Porcentagem de conclusão', value: 'goal_percentage'),
        ];
      case kpi_model.KPISourceType.entry:
        return const [
          _CalculationModeOption(label: 'Contagem de entradas', value: null),
          _CalculationModeOption(label: 'Contagem de palavras', value: 'word_count'),
        ];
      default:
        return const [];
    }
  }

  List<_ScopeOption> _getProjectAndGoalOptions() {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final projects = allObjects.where((o) => o.type == 'project').toList();
    final goals = allObjects.where((o) => o.type == 'goal').toList();
    
    return [
      ...projects.map((p) => _ScopeOption(label: p.displayTitle, value: p.slug)),
      ...goals.map((g) => _ScopeOption(label: g.displayTitle, value: g.slug)),
    ];
  }

  List<_ScopeOption> _getCollectionOptions() {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final collections = allObjects.whereType<Note>()
        .where((n) => n.subtype == NoteSubtype.collection)
        .toList();
    
    return collections.map((c) => _ScopeOption(label: c.displayTitle, value: c.id)).toList();
  }

  List<_ScopeOption> _getOrganizerOptions() {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final organizers = allObjects.whereType<Organizer>().toList();
    
    return [
      const _ScopeOption(label: 'Todos', value: null),
      ...organizers.map((o) => _ScopeOption(label: o.displayTitle, value: o.slug)),
    ];
  }

  void _showKpiActionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecionar Ação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Adicionar Entrada de Journal'),
              onTap: () {
                setState(() {
                  _autoCompleteAction = ActionDef(
                    type: 'add_entry',
                    trigger: 'kpi_reached',
                  );
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Criar Tarefa'),
              onTap: () {
                setState(() {
                  _autoCompleteAction = ActionDef(
                    type: 'create_task',
                    trigger: 'kpi_reached',
                  );
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Adicionar Nota de Texto'),
              onTap: () {
                setState(() {
                  _autoCompleteAction = ActionDef(
                    type: 'add_text_note',
                    trigger: 'kpi_reached',
                  );
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Abrir URL'),
              onTap: () {
                setState(() {
                  _autoCompleteAction = ActionDef(
                    type: 'launch_url',
                    trigger: 'kpi_reached',
                  );
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppTheme.accentColor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final habits = allObjects.whereType<Habit>().toList();
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
            selectedItemBuilder: (context) => kpi_model.KPISourceType.values
                .map(
                  (t) => Text(
                    t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                _sourceType = v!;
                _sourceId = null;
                _fieldId = null;
                _calculationMode = null;
                _selectedOtherMode = null;
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

          // Scope pickers for subtasks, collection, entry, timeSpent
          if (_sourceType == kpi_model.KPISourceType.subtasks) ...[
            DropdownButtonFormField<String>(
              value: _sourceId,
              decoration: const InputDecoration(
                labelText: 'Selecionar Projeto ou Meta',
                border: OutlineInputBorder(),
              ),
              items: _getProjectAndGoalOptions().map((option) {
                return DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
                );
              }).toList(),
              onChanged: (v) => setState(() => _sourceId = v),
            ),
            const SizedBox(height: 12),
          ],

          if (_sourceType == kpi_model.KPISourceType.collection) ...[
            DropdownButtonFormField<String>(
              value: _sourceId,
              decoration: const InputDecoration(
                labelText: 'Selecionar Coleção',
                border: OutlineInputBorder(),
              ),
              items: _getCollectionOptions().map((option) {
                return DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
                );
              }).toList(),
              onChanged: (v) => setState(() => _sourceId = v),
            ),
            const SizedBox(height: 12),
          ],

          if (_sourceType == kpi_model.KPISourceType.entry ||
              _sourceType == kpi_model.KPISourceType.timeSpent) ...[
            DropdownButtonFormField<String>(
              value: _sourceId,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Organizador (opcional)',
                border: OutlineInputBorder(),
              ),
              items: _getOrganizerOptions().map((option) {
                return DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
                );
              }).toList(),
              onChanged: (v) => setState(() => _sourceId = v),
            ),
            const SizedBox(height: 12),
          ],

          // Others source type - second dropdown for specific modes
          if (_sourceType == kpi_model.KPISourceType.others) ...[
            DropdownButtonFormField<String>(
              value: _selectedOtherMode,
              decoration: const InputDecoration(
                labelText: 'Tipo de Indicador',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'mood_average',
                  child: Text('Humor Médio'),
                ),
                DropdownMenuItem(
                  value: 'mood_trend',
                  child: Text('Tendência de Humor'),
                ),
                DropdownMenuItem(
                  value: 'photo_count',
                  child: Text('Contagem de Fotos'),
                ),
                DropdownMenuItem(
                  value: 'comment_count',
                  child: Text('Contagem de Comentários'),
                ),
                DropdownMenuItem(
                  value: 'reflection_length',
                  child: Text('Tamanho das Reflexões'),
                ),
                DropdownMenuItem(
                  value: 'planner_task_count',
                  child: Text('Contagem de Tarefas'),
                ),
                DropdownMenuItem(
                  value: 'planner_overdue_count',
                  child: Text('Tarefas Atrasadas'),
                ),
                DropdownMenuItem(
                  value: 'organizer_association_count',
                  child: Text('Associações do Organizador'),
                ),
              ],
              onChanged: (v) => setState(() {
                _selectedOtherMode = v;
                _calculationMode = v;
              }),
            ),
            const SizedBox(height: 12),
            // Mood axis toggle for mood_average
            if (_selectedOtherMode == 'mood_average') ...[
              SegmentedButton<String?>(
                segments: const [
                  ButtonSegment(
                    value: null,
                    label: Text('Prazer (padrão)'),
                  ),
                  ButtonSegment(
                    value: 'energy',
                    label: Text('Energia'),
                  ),
                ],
                selected: {_fieldId},
                onSelectionChanged: (Set<String?> newSelection) {
                  setState(() {
                    _fieldId = newSelection.firstOrNull;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            // Organizer scope picker for task-based modes
            if (_selectedOtherMode == 'planner_task_count' ||
                _selectedOtherMode == 'planner_overdue_count' ||
                _selectedOtherMode == 'organizer_association_count') ...[
              DropdownButtonFormField<String>(
                value: _sourceId,
                decoration: const InputDecoration(
                  labelText: 'Filtrar por Organizador',
                  border: OutlineInputBorder(),
                ),
                items: _getOrganizerOptions().map((option) {
                  return DropdownMenuItem<String>(
                    value: option.value,
                    child: Text(option.label),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _sourceId = v),
              ),
              const SizedBox(height: 12),
            ],
          ],

          // Calculation Mode Picker
          if (_sourceType == kpi_model.KPISourceType.habit ||
              _sourceType == kpi_model.KPISourceType.trackerField ||
              _sourceType == kpi_model.KPISourceType.subtasks ||
              _sourceType == kpi_model.KPISourceType.entry) ...[
            DropdownButtonFormField<String>(
              value: _calculationMode,
              decoration: const InputDecoration(
                labelText: 'Modo de Cálculo',
                border: OutlineInputBorder(),
              ),
              items: _getCalculationModeOptions(_sourceType).map((option) {
                return DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
                );
              }).toList(),
              onChanged: (v) => setState(() => _calculationMode = v),
            ),
            const SizedBox(height: 12),
          ],

          // Display Type Picker
          DropdownButtonFormField<kpi_model.KPIDisplayType>(
            value: _displayType,
            decoration: const InputDecoration(
              labelText: 'Como exibir',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: kpi_model.KPIDisplayType.number,
                child: Text('Número'),
              ),
              DropdownMenuItem(
                value: kpi_model.KPIDisplayType.percentage,
                child: Text('Porcentagem'),
              ),
              DropdownMenuItem(
                value: kpi_model.KPIDisplayType.progressBar,
                child: Text('Barra de progresso'),
              ),
            ],
            onChanged: (v) => setState(() => _displayType = v!),
          ),
          const SizedBox(height: 12),

          // Date Range Pickers
          DatePickerField(
            label: 'Data de início (opcional)',
            selectedDate: _startDate,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateChanged: (picked) {
              if (picked != null) {
                setState(() => _startDate = picked);
              }
            },
          ),
          const SizedBox(height: 12),
          DatePickerField(
            label: 'Data de término (opcional)',
            selectedDate: _endDate,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateChanged: (picked) {
              if (picked != null) {
                setState(() => _endDate = picked);
              }
            },
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Valor Meta',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Auto-complete toggle
          CheckboxListTile(
            title: const Text('Auto-completar ao atingir meta'),
            subtitle: const Text('Executar ação automaticamente quando o KPI atingir o valor alvo'),
            value: _autoComplete,
            onChanged: (v) => setState(() => _autoComplete = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (_autoComplete) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showKpiActionPicker(),
              icon: Icon(_autoCompleteAction != null ? Icons.check : Icons.add),
              label: Text(_autoCompleteAction != null 
                  ? 'Ação: ${_autoCompleteAction!.type}' 
                  : 'Selecionar Ação'),
            ),
          ],
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
                  calculationMode: _calculationMode,
                  targetValue: double.tryParse(_targetController.text) ?? 100,
                  displayType: _displayType,
                  startDate: _startDate,
                  endDate: _endDate,
                  autoComplete: _autoComplete,
                  autoCompleteAction: _autoCompleteAction?.toJson(),
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

class _CalculationModeOption {
  final String label;
  final String? value;
  const _CalculationModeOption({required this.label, this.value});
}

class _ScopeOption {
  final String label;
  final String? value;
  const _ScopeOption({required this.label, this.value});
}
