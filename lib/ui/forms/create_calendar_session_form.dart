import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/calendar_session.dart';
import '../../models/task_model.dart';
import '../../models/goal_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';
import '../widgets/universal_search_picker.dart';
import '../widgets/app_color_picker.dart';

class CreateCalendarSessionForm extends ConsumerStatefulWidget {
  final CalendarSession? existingSession;
  final String? initialTitle;
  final DateTime? initialDate;

  const CreateCalendarSessionForm({
    super.key,
    this.existingSession,
    this.initialTitle,
    this.initialDate,
  });

  @override
  ConsumerState<CreateCalendarSessionForm> createState() => _CreateCalendarSessionFormState();
}

class _CreateCalendarSessionFormState extends ConsumerState<CreateCalendarSessionForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _durationController;
  late final TextEditingController _noteController;

  DateTime _date = DateTime.now();
  TimeOfDay? _timeOfDay;
  CalendarSessionState _state = CalendarSessionState.scheduled;
  Task? _linkedTask;
  Goal? _linkedGoal;
  String? _color;
  List<OrganizerReference> _organizers = [];
  bool _multiDay = false;

  @override
  void initState() {
    super.initState();
    _titleController = WikiLinkTextController(
      context: context,
      text: widget.existingSession?.title ?? widget.initialTitle,
    );
    _durationController = TextEditingController(
      text: (widget.existingSession?.duration ?? 60).toString(),
    );
    _noteController = TextEditingController(
      text: widget.existingSession?.note ?? '',
    );

    if (widget.existingSession != null) {
      final session = widget.existingSession!;
      _date = session.date;
      _state = session.state;
      _multiDay = session.multiDay;
      _color = session.color;
      _organizers = List.from(session.organizers);

      if (session.timeOfDay != null && session.timeOfDay!.contains(':')) {
        final parts = session.timeOfDay!.split(':');
        if (parts.length == 2) {
          _timeOfDay = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    } else if (widget.initialDate != null) {
      _date = widget.initialDate!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existingSession != null) {
      final session = widget.existingSession!;
      final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];

      if (session.linkedTaskId != null && _linkedTask == null) {
        final task = allObjects.firstWhere(
          (o) => o is Task && o.slug == session.linkedTaskId,
          orElse: () => Task(
            id: session.linkedTaskId!,
            title: session.linkedTaskId!,
            stage: TaskStage.todo,
            createdAt: DateTime.now(),
          ),
        );
        _linkedTask = task as Task;
      }

      if (session.linkedGoalId != null && _linkedGoal == null) {
        final goal = allObjects.firstWhere(
          (o) => o is Goal && o.slug == session.linkedGoalId,
          orElse: () => Goal(
            id: session.linkedGoalId!,
            title: session.linkedGoalId!,
            state: GoalStatus.active,
            createdAt: DateTime.now(),
          ),
        );
        _linkedGoal = goal as Goal;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _stateLabel(CalendarSessionState state) {
    return switch (state) {
      CalendarSessionState.scheduled => 'Agendado',
      CalendarSessionState.inProgress => 'Em Progresso',
      CalendarSessionState.completed => 'Concluído',
      CalendarSessionState.backlog => 'Backlog',
      CalendarSessionState.cancelled => 'Cancelado',
    };
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDay ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _timeOfDay = picked);
    }
  }

  void _saveSession() async {
    if (_titleController.text.trim().isEmpty) return;

    final duration = int.tryParse(_durationController.text.trim()) ?? 60;
    final timeStr = _timeOfDay != null
        ? '${_timeOfDay!.hour.toString().padLeft(2, '0')}:${_timeOfDay!.minute.toString().padLeft(2, '0')}'
        : null;

    final session = CalendarSession(
      id: widget.existingSession?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      date: DateTime(_date.year, _date.month, _date.day),
      state: _state,
      timeOfDay: timeStr,
      duration: duration,
      multiDay: _multiDay,
      linkedTaskId: _linkedTask?.slug,
      linkedGoalId: _linkedGoal?.slug,
      note: _noteController.text.trim(),
      color: _color,
      organizers: _organizers,
      createdAt: widget.existingSession?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.existingSession != null) {
        await ref.read(vaultProvider.notifier).updateObject(session);
      } else {
        await ref.read(vaultProvider.notifier).createObject(session);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao salvar sessão de calendário: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar sessão: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final isDirty = hasTitle || _noteController.text.trim().isNotEmpty;

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
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            widget.existingSession != null ? 'Editar Sessão' : 'Nova Sessão',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: hasTitle ? _saveSession : null,
              child: Text(
                'Salvar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: hasTitle ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  hintText: 'Título da sessão',
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

              // ─── Status/State Segmented ───
              Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: CalendarSessionState.values.map((state) {
                          final selected = _state == state;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _state = state),
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  _stateLabel(state),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ─── Date & Time & Duration Card ───
              Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Date picker
                    GestureDetector(
                      onTap: _pickDate,
                      child: Row(
                        children: [
                          const Text(
                            'Data',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_date),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                    const Divider(height: 24),

                    // TimeOfDay picker
                    GestureDetector(
                      onTap: _pickTime,
                      child: Row(
                        children: [
                          const Text(
                            'Horário',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text(
                            _timeOfDay != null ? _timeOfDay!.format(context) : 'Selecionar',
                            style: TextStyle(
                              fontSize: 14,
                              color: _timeOfDay != null ? AppColors.primary : AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                    const Divider(height: 24),

                    // Duration field
                    Row(
                      children: [
                        const Text(
                          'Duração',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              suffixText: ' min',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Multi-day toggle
                    Row(
                      children: [
                        const Text(
                          'Múltiplos Dias',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Switch.adaptive(
                          value: _multiDay,
                          onChanged: (v) => setState(() => _multiDay = v),
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ─── Connections (Linked Task & Goal) Card ───
              Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Linked Task Picker
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => UniversalSearchPickerSheet(
                            title: 'Vincular Tarefa',
                            initialFilter: 'task',
                            onSelected: (obj) {
                              if (obj is Task) {
                                setState(() => _linkedTask = obj);
                              }
                              Navigator.pop(context);
                            },
                            showClear: true,
                            onClear: () {
                              setState(() => _linkedTask = null);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          const Text(
                            'Tarefa Vinculada',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Expanded(
                            child: Text(
                              _linkedTask?.title ?? 'Nenhuma',
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: _linkedTask != null ? AppColors.primary : AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                    const Divider(height: 24),

                    // Linked Goal Picker
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => UniversalSearchPickerSheet(
                            title: 'Vincular Objetivo',
                            initialFilter: 'goal',
                            onSelected: (obj) {
                              if (obj is Goal) {
                                setState(() => _linkedGoal = obj);
                              }
                              Navigator.pop(context);
                            },
                            showClear: true,
                            onClear: () {
                              setState(() => _linkedGoal = null);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          const Text(
                            'Objetivo Vinculado',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Expanded(
                            child: Text(
                              _linkedGoal?.title ?? 'Nenhum',
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: _linkedGoal != null ? AppColors.primary : AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
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

              // ─── Organizers Field Card ───
              Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OrganizerSelectorField(
                  selectedOrganizers: _organizers,
                  onChanged: (val) => setState(() => _organizers = val),
                ),
              ),
              const SizedBox(height: 12),

              // ─── AppColorPicker Card ───
              Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.all(16),
                child: AppColorPicker(
                  value: _color ?? '#FFB000',
                  onChanged: (hex) => setState(() => _color = hex),
                ),
              ),
              const SizedBox(height: 12),

              // ─── Note Card ───
              Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notas / Observações',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 6,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Adicionar observações para esta sessão...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
