import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/system_model.dart';
import '../../models/shared_types.dart';
import '../../providers/systems_provider.dart';
import '../theme.dart';
import '../widgets/organizer_selector_field.dart';
import 'package:uuid/uuid.dart';
import '../../models/scheduler.dart';
import 'scheduler_picker.dart';

class CreateSystemForm extends ConsumerStatefulWidget {
  final SystemDefinition? existingSystem;
  const CreateSystemForm({super.key, this.existingSystem});

  @override
  ConsumerState<CreateSystemForm> createState() => _CreateSystemFormState();
}

class _CreateSystemFormState extends ConsumerState<CreateSystemForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _triggerController;
  late final TextEditingController _descriptionController;
  int _estimatedMinutes = 0;
  List<SystemStep> _steps = [];
  List<OrganizerReference> _organizers = [];
  Scheduler? _scheduler;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSystem;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _triggerController = TextEditingController(text: existing?.trigger ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _estimatedMinutes = existing?.estimatedMinutes ?? 0;
    _steps = existing != null ? List.from(existing.steps) : [];
    _organizers = existing != null ? List.from(existing.organizers) : [];
    _scheduler = existing?.scheduler;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _triggerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _hasTitle => _titleController.text.trim().isNotEmpty;

  void _addStep() {
    setState(() {
      _steps.add(SystemStep(title: ''));
    });
    // Focus on the new step after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  void _updateStepTitle(int index, String title) {
    final updated = List<SystemStep>.from(_steps);
    updated[index] = updated[index].copyWith(title: title);
    setState(() {
      _steps = updated;
    });
  }

  Future<void> _pickDuration() async {
    int? selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int temp = _estimatedMinutes;
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(ctx),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  'Tempo estimado (minutos)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [5, 10, 15, 20, 30, 45, 60, 90, 120].map((m) {
                    final sel = temp == m;
                    return GestureDetector(
                      onTap: () => setModalState(() => temp = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.accentColor(context) : AppTheme.surfaceVariantColor(ctx),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? AppTheme.accentColor(context) : AppTheme.dividerColor(ctx),
                          ),
                        ),
                        child: Text(
                          '$m min',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppTheme.textSecondaryColor(ctx),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => Navigator.pop(ctx, temp),
                    child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    if (selected != null) {
      setState(() => _estimatedMinutes = selected);
    }
  }

  void _pickScheduler() async {
    final result = await showModalBottomSheet<Scheduler>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: SchedulerPicker(initialScheduler: _scheduler),
      ),
    );
    if (result != null) setState(() => _scheduler = result);
  }

  String _getScheduleSummary(Scheduler s) {
    if (s.rules.isEmpty) return 'Sem regras';
    final r = s.rules.first;
    switch (r.repeatType) {
      case RepeatType.numberOfDays:
        return 'A cada ${r.interval} dias';
      case RepeatType.daysOfWeek:
        return r.daysOfWeek?.join(', ') ?? 'Dias da semana';
      case RepeatType.numberOfWeeks:
        return 'A cada ${r.interval} semanas';
      case RepeatType.numberOfMonths:
        return 'A cada ${r.interval} meses';
      default:
        return 'Personalizado';
    }
  }

  Future<void> _save() async {
    if (!_hasTitle) return;

    final system = SystemDefinition(
      id: widget.existingSystem?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      trigger: _triggerController.text.trim(),
      estimatedMinutes: _estimatedMinutes,
      steps: _steps.where((s) => s.title.trim().isNotEmpty).toList(),
      description: _descriptionController.text.trim(),
      runCount: widget.existingSystem?.runCount ?? 0,
      lastRun: widget.existingSystem?.lastRun,
      averageMinutes: widget.existingSystem?.averageMinutes ?? 0,
      scheduler: _scheduler,
      createdAt: widget.existingSystem?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      obsidianPath: widget.existingSystem?.obsidianPath ?? '',
    )..organizers = _organizers;

    if (widget.existingSystem != null) {
      await ref.read(systemsProvider.notifier).updateSystem(system);
    } else {
      await ref.read(systemsProvider.notifier).addSystem(system);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir System?'),
        content: const Text('Esta ação pode ser desfeita por 30 dias.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(systemsProvider.notifier).deleteSystem(widget.existingSystem!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSystem != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              isEditing ? 'Editar System' : 'Novo System',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            actions: [
              if (isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: _delete,
                ),
              TextButton(
                onPressed: _hasTitle ? _save : null,
                child: Text(
                  'Salvar',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _hasTitle ? AppTheme.accentColor(context) : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Title ───
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Nome do System',
                      hintStyle: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Metadata Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Trigger manual / texto
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Gatilho manual',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _triggerController,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.accentColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ex: "Quando acordar"',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMutedColor(context),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        // Automático / Scheduler
                        GestureDetector(
                          onTap: _pickScheduler,
                          child: Row(
                            children: [
                              const Text(
                                'Agendamento (Automático)',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Text(
                                _scheduler != null ? _getScheduleSummary(_scheduler!) : 'Nenhum',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _scheduler != null ? AppTheme.accentColor(context) : AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_scheduler != null)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                                  onPressed: () => setState(() => _scheduler = null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              else ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                        // Estimated duration
                        GestureDetector(
                          onTap: _pickDuration,
                          child: Row(
                            children: [
                              const Text(
                                'Tempo estimado',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Text(
                                _estimatedMinutes > 0 ? '$_estimatedMinutes min' : 'Não estimado',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _estimatedMinutes > 0 ? AppTheme.accentColor(context) : AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Steps Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Steps',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.add_rounded, color: AppTheme.accentColor(context)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _addStep,
                            ),
                          ],
                        ),
                        if (_steps.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Nenhum step ainda. Adicione o passo-a-passo do seu System.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMutedColor(context),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex--;
                                final step = _steps.removeAt(oldIndex);
                                _steps.insert(newIndex, step);
                              });
                            },
                            itemCount: _steps.length,
                            itemBuilder: (ctx, index) {
                              final step = _steps[index];
                              return _StepRow(
                                key: ValueKey(step.id),
                                index: index,
                                step: step,
                                onChanged: (title) => _updateStepTitle(index, title),
                                onRemove: () => _removeStep(index),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Description Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Descrição / Notas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descriptionController,
                          maxLines: null,
                          minLines: 3,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimaryColor(context),
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Contexto, propósito ou regras do System...',
                            hintStyle: TextStyle(
                              color: AppTheme.textMutedColor(context),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Connections Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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

      // ─── CTA Save Button ───
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasTitle ? AppTheme.accentColor(context) : AppColors.textMuted,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: _hasTitle ? _save : null,
              child: const Text(
                'Salvar System',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatefulWidget {
  final int index;
  final SystemStep step;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  const _StepRow({
    super.key,
    required this.index,
    required this.step,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.step.title);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textMuted, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '${widget.index + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryColor(context),
              ),
              decoration: InputDecoration(
                hintText: 'Descreva o step...',
                hintStyle: TextStyle(color: AppTheme.textMutedColor(context), fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
