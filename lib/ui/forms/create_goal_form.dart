// lib/ui/forms/create_goal_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/goal_model.dart';
import '../../models/habit_model.dart';
import '../../models/kpi_model.dart';
import '../../models/note_model.dart';
import '../../models/organizer_model.dart';
import '../../models/shared_types.dart';
import '../../models/template_model.dart';
import '../../providers/vault_provider.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';
import '../theme.dart';
import '../widgets/date_picker_field.dart';

class CreateGoalForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final Goal? existingGoal;
  final List<OrganizerReference>? initialOrganizers;
  const CreateGoalForm({super.key, this.initialTitle, this.existingGoal, this.initialOrganizers});

  @override
  ConsumerState<CreateGoalForm> createState() => _CreateGoalFormState();
}

class _CreateGoalFormState extends ConsumerState<CreateGoalForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  GoalType _goalType = GoalType.oneTime;
  DateTime? _deadline;
  String _selectedColor = '#10B981';
  bool _ignoreDirty = false;

  static const _colorSwatches = [
    '#DC2626',
    '#F97316',
    '#F59E0B',
    '#10B981',
    '#14B8A6',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#6B7280',
  ];

  GoalStatus _state = GoalStatus.active;
  List<KPI> _kpis = [];
  List<OrganizerReference> _organizers = [];

  @override
  void initState() {
    super.initState();
    _titleController = WikiLinkTextController(
      context: context,
      text: widget.existingGoal?.title ?? widget.initialTitle,
    );
    _descController = WikiLinkTextController(
      context: context,
      text: widget.existingGoal?.description ?? '',
    );

    if (widget.existingGoal != null) {
      final goal = widget.existingGoal!;
      _titleController.text = goal.title;
      _selectedColor = goal.color ?? '#10B981';
      _goalType = goal.goalType;
      _deadline = goal.deadline;
      _state = goal.state;
      _kpis = List.from(goal.kpis);
      _organizers = List.from(goal.organizers);
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
    super.dispose();
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
    final hasTitle = _titleController.text.trim().isNotEmpty;

    final isDirty = !_ignoreDirty && _titleController.text.trim().isNotEmpty;

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
          setState(() => _ignoreDirty = true);
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
                'Novo Goal',
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
                        hintText: 'Goal title',
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

                    // âÂ”Â€âÂ”Â€âÂ”Â€ Status âÂ”Â€âÂ”Â€âÂ”Â€
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          DropdownButton<GoalStatus>(
                            value: _state,
                            underline: const SizedBox(),
                            items: GoalStatus.values
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _state = v);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // âÂ”Â€âÂ”Â€âÂ”Â€ Goal Type Card âÂ”Â€âÂ”Â€âÂ”Â€
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tipo de Goal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _typeButton(
                                GoalType.oneTime,
                                'One time',
                                Icons.flag_rounded,
                              ),
                              const SizedBox(width: 12),
                              _typeButton(
                                GoalType.repeating,
                                'Recorrente',
                                Icons.cached_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // âÂ”Â€âÂ”Â€âÂ”Â€ Deadline Card âÂ”Â€âÂ”Â€âÂ”Â€
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        decoration: AppTheme.cardDecoration(context),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              'Prazo',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _deadline != null
                                  ? DateFormat('d MMM, yyyy').format(_deadline!)
                                  : 'Definir prazo',
                              style: TextStyle(
                                fontSize: 14,
                                color: _deadline != null
                                    ? AppTheme.accentColor(context)
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w500,
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
                      ),
                    ),

                    const SizedBox(height: 12),

                    // âÂ”Â€âÂ”Â€âÂ”Â€ KPIs âÂ”Â€âÂ”Â€âÂ”Â€
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Indicadores de Desempenho (KPIs)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._kpis.asMap().entries.map((e) {
                            final isPrimary = e.key == 0;
                            final kpi = e.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  if (isPrimary)
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: AppColors.warning,
                                    ),
                                  if (isPrimary) const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          kpi.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Meta: ${kpi.targetValue} (${kpi.sourceType.label})',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () =>
                                        setState(() => _kpis.removeAt(e.key)),
                                  ),
                                ],
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: _addKpi,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.accentColor(context).withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                '+ Add KPI',
                                style: TextStyle(
                                  color: AppTheme.accentColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // âÂ”Â€âÂ”Â€âÂ”Â€ Organizers âÂ”Â€âÂ”Â€âÂ”Â€
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: OrganizerSelectorField(
                        selectedOrganizers: _organizers,
                        onChanged: (val) => setState(() => _organizers = val),
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
                              hintText: 'What do you want to achieve?',
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
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

        // âÂ”Â€âÂ”Â€âÂ”Â€ Save Button âÂ”Â€âÂ”Â€âÂ”Â€
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: hasTitle ? _saveGoal : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _parseColor(_selectedColor),
                  disabledBackgroundColor: AppColors.textMuted.withValues(
                    alpha: 0.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Criar Goal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeButton(GoalType type, String label, IconData icon) {
    final selected = _goalType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _goalType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentColor(context) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(
                    color: AppTheme.accentColor(context).withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _deadline = date);
  }

  void _saveGoal() {
    final goal = Goal(
      id:
          widget.existingGoal?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: widget.existingGoal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      goalType: _goalType,
      state: _state,
      deadline: _deadline,
      color: _selectedColor,
      kpis: _kpis,
      organizers: _organizers,
      obsidianPath: widget.existingGoal?.obsidianPath ?? '',
    );

    if (widget.existingGoal != null) {
      ref.read(vaultProvider.notifier).updateObject(goal);
    } else {
      ref.read(goalsProvider.notifier).addGoal(goal);
    }
  }

  void _showTemplatePicker() async {
    final templates = ref
        .read(templatesProvider)
        .where((t) => t.templateType == 'goal')
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
                      extra: {'initialType': 'goal'},
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
      if (template.frontmatterDefaults.containsKey('goal_type')) {
        final typeStr = template.frontmatterDefaults['goal_type'] as String;
        _goalType = GoalType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => GoalType.oneTime,
        );
      }
      if (template.body.isNotEmpty) {
        _descController.text = template.body;
      }
    });
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
}

class _KpiBuilderSheet extends ConsumerStatefulWidget {
  final Function(KPI) onSave;
  const _KpiBuilderSheet({required this.onSave});

  @override
  ConsumerState<_KpiBuilderSheet> createState() => _KpiBuilderSheetState();
}

class _KpiBuilderSheetState extends ConsumerState<_KpiBuilderSheet> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  KPISourceType _sourceType = KPISourceType.manualQuantity;
  String? _sourceId;
  String? _fieldId;
  String? _calculationMode;
  String? _selectedOtherMode;
  KPIDisplayType _displayType = KPIDisplayType.progressBar;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _autoComplete = false;
  ActionDef? _autoCompleteAction;

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppTheme.accentColor(context);
    }
  }

  List<_CalculationModeOption> _getCalculationModeOptions(KPISourceType sourceType) {
    switch (sourceType) {
      case KPISourceType.habit:
        return const [
          _CalculationModeOption(label: 'Total de conclusões', value: null),
          _CalculationModeOption(label: 'Sequência atual (streak)', value: 'streak'),
          _CalculationModeOption(label: 'Taxa de sucesso (%)', value: 'success_rate'),
        ];
      case KPISourceType.trackerField:
        return const [
          _CalculationModeOption(label: 'Soma', value: null),
          _CalculationModeOption(label: 'Média', value: 'average'),
          _CalculationModeOption(label: 'Máximo', value: 'max'),
          _CalculationModeOption(label: 'Mínimo', value: 'min'),
          _CalculationModeOption(label: 'Valor mais recente', value: 'latest'),
        ];
      case KPISourceType.subtasks:
        return const [
          _CalculationModeOption(label: 'Contagem de tarefas concluídas', value: null),
          _CalculationModeOption(label: 'Porcentagem de conclusão', value: 'goal_percentage'),
        ];
      case KPISourceType.entry:
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

  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final habits = allObjects.whereType<Habit>().toList();
    final trackers = ref.watch(trackersProvider);

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
          DropdownButtonFormField<KPISourceType>(
            initialValue: _sourceType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de Fonte',
              border: OutlineInputBorder(),
            ),
            items: KPISourceType.values
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
            selectedItemBuilder: (context) => KPISourceType.values
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
                  .map(
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
          if (_sourceType == KPISourceType.subtasks) ...[
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

          if (_sourceType == KPISourceType.collection) ...[
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

          if (_sourceType == KPISourceType.entry ||
              _sourceType == KPISourceType.timeSpent) ...[
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
          if (_sourceType == KPISourceType.others) ...[
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
          if (_sourceType == KPISourceType.habit ||
              _sourceType == KPISourceType.trackerField ||
              _sourceType == KPISourceType.subtasks ||
              _sourceType == KPISourceType.entry) ...[
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
          DropdownButtonFormField<KPIDisplayType>(
            value: _displayType,
            decoration: const InputDecoration(
              labelText: 'Como exibir',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: KPIDisplayType.number,
                child: Text('Número'),
              ),
              DropdownMenuItem(
                value: KPIDisplayType.percentage,
                child: Text('Porcentagem'),
              ),
              DropdownMenuItem(
                value: KPIDisplayType.progressBar,
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
                final kpi = KPI(
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
                widget.onSave(kpi);
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
