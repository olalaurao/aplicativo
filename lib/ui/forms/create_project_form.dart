// lib/ui/forms/create_project_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';
import '../theme.dart';

class CreateProjectForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final Project? existingProject;
  const CreateProjectForm({super.key, this.initialTitle, this.existingProject});

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
      _state = project.state;
      _priority = project.priority;
      _startDate = project.startDate;
      _endDate = project.endDate;
      _selectedColor = project.color ?? '#3B82F6';
      _organizers = List.from(project.organizers);
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
    final hasTitle = _titleController.text.trim().isNotEmpty;

    final isDirty = _titleController.text.trim().isNotEmpty;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alteraÃ§Ãµes?'),
            content: const Text('VocÃª possui alteraÃ§Ãµes nÃ£o salvas. Deseja sair mesmo assim?'),
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
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€ Title Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€
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

                  // Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€ Color Swatches Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€
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

                  // Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€ State & Priority Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€
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

                  // Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€ Dates Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€
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

                  // Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€ Description Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€
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

                  // Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€ Organizers Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: OrganizerSelectorField(
                      selectedOrganizers: _organizers,
                      onChanged: (val) => setState(() => _organizers = val),
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

  void _saveProject() {
    final project = Project(
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
    );

    if (widget.existingProject != null) {
      ref.read(vaultProvider.notifier).updateObject(project);
    } else {
      ref.read(projectsProvider.notifier).addProject(project);
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

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
