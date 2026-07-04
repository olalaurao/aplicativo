import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/reminder_model.dart';
import '../../models/reminder_config.dart';
import '../../models/scheduler.dart';
import '../../models/shared_types.dart';
import '../../models/template_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import 'scheduler_picker.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_picker_modal.dart';

class CreateReminderForm extends ConsumerStatefulWidget {
  const CreateReminderForm({super.key});

  @override
  ConsumerState<CreateReminderForm> createState() => _CreateReminderFormState();
}

class _CreateReminderFormState extends ConsumerState<CreateReminderForm> {
  late final TextEditingController _titleController;
  final List<TextEditingController> _checkboxControllers = [];
  DateTime _date = DateTime.now();
  TimeOfDay? _time;
  Scheduler? _scheduler;
  String? _timeBlock;
  bool _completable = true;
  final List<String> _checkboxes = [];
  final List<OrganizerReference> _organizers = [];

  NotificationType _type = NotificationType.push;
  bool _ringOnSilent = false;
  int _snoozeMinutes = 10;

  @override
  void initState() {
    super.initState();
    _titleController = WikiLinkTextController(context: context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var c in _checkboxControllers) {
      c.dispose();
    }
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
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_all_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: 'Usar Template',
                    onPressed: _showTemplatePicker,
                  ),
                  const Spacer(),
                  const Text(
                    'New Reminder',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: hasTitle ? _saveReminder : null,
                    child: Text(
                      'Add',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: hasTitle
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Remind me to...',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _metadataChip(
                          icon: Icons.event_outlined,
                          label: DateFormat('MMM d').format(_date),
                          onTap: _pickDate,
                        ),
                        const SizedBox(width: 8),
                        _metadataChip(
                          icon: Icons.access_time_rounded,
                          label: _time?.format(context) ?? 'Time',
                          onTap: _pickTime,
                          isActive: _time != null,
                        ),
                        const SizedBox(width: 8),
                        _metadataChip(
                          icon: Icons.repeat_rounded,
                          label: _scheduler != null ? 'Recurring' : 'Repeat',
                          onTap: _pickRepeat,
                          isActive: _scheduler != null,
                        ),
                        const SizedBox(width: 8),
                        _metadataChip(
                          icon: Icons.layers_outlined,
                          label: _organizers.isEmpty
                              ? 'Organizers'
                              : '${_organizers.length} organizers',
                          onTap: _pickOrganizers,
                          isActive: _organizers.isNotEmpty,
                        ),
                        const SizedBox(width: 8),
                        _metadataChip(
                          icon: Icons.view_timeline_outlined,
                          label: _timeBlock ?? 'Time block',
                          onTap: _pickTimeBlock,
                          isActive: _timeBlock != null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Notification Settings
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tipo de Notificação',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildTypeChip(
                              NotificationType.push,
                              'Push',
                              Icons.notifications_active_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildTypeChip(
                              NotificationType.popup,
                              'Popup',
                              Icons.picture_in_picture_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildTypeChip(
                              NotificationType.alarm,
                              'Alarme',
                              Icons.alarm_rounded,
                            ),
                          ],
                        ),
                        if (_type == NotificationType.alarm) ...[
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text(
                              'Tocar no silencioso',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: _ringOnSilent,
                            onChanged: (val) => setState(() => _ringOnSilent = val),
                            contentPadding: EdgeInsets.zero,
                          ),
                          Row(
                            children: [
                              const Text('Soneca (min):', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 16),
                              DropdownButton<int>(
                                value: _snoozeMinutes,
                                items: [5, 10, 15, 30]
                                    .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _snoozeMinutes = val ?? 10),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Completable',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _completable,
                              onChanged: (v) =>
                                  setState(() => _completable = v),
                              activeThumbColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Checklist',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._checkboxes.asMap().entries.map((entry) {
                          if (_checkboxControllers.length <= entry.key) {
                            _checkboxControllers.add(
                              WikiLinkTextController(
                                context: context,
                                text: entry.value,
                              ),
                            );
                          }
                          final controller = _checkboxControllers[entry.key];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_box_outline_blank,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    onChanged: (v) =>
                                        _checkboxes[entry.key] = v,
                                    style: const TextStyle(fontSize: 15),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _checkboxes.removeAt(entry.key);
                                      _checkboxControllers
                                          .removeAt(entry.key)
                                          .dispose();
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: _addCheckbox,
                          child: const Text(
                            'Add item',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildTypeChip(NotificationType type, String label, IconData icon) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveReminder() {
    final time = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time?.hour ?? 0,
      _time?.minute ?? 0,
    );
    
    final reminder = Reminder(
      title: _titleController.text.trim(),
      time: time,
      isCompleted: false,
      isCompletable: _completable,
      notes: _checkboxes.isNotEmpty ? _checkboxes.join('\n') : null,
      scheduler: _scheduler,
      timeBlock: _timeBlock,
      organizers: _organizers,
      reminders: [
        ReminderConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          triggerTime: time,
          type: _type,
          ringOnSilent: _ringOnSilent,
          snoozeMinutes: _snoozeMinutes,
        ),
      ],
    );
    
    ref.read(remindersProvider.notifier).addReminder(reminder);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminder "${reminder.title}" set!')),
    );
  }

  void _showTemplatePicker() async {
    final templates = ref
        .read(templatesProvider)
        .where((t) => t.templateType == 'reminder')
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
                      extra: {'initialType': 'reminder'},
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
      if (template.frontmatterDefaults.containsKey('completable')) {
        _completable = template.frontmatterDefaults['completable'] as bool? ?? true;
      }
      if (template.body.isNotEmpty) {
        final lines = template.body.split('\n');
        _checkboxes.clear();
        _checkboxControllers.clear();
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            _checkboxes.add(line.trim());
            _checkboxControllers.add(TextEditingController(text: line.trim()));
          }
        }
      }
    });
  }

  Widget _metadataChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _date = d);
  }

  void _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _time = t);
  }

  void _pickRepeat() async {
    final s = await showModalBottomSheet<Scheduler>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SchedulerPicker(),
    );
    if (s != null) setState(() => _scheduler = s);
  }

  Future<void> _pickOrganizers() async {
    final res = await showOrganizerPickerModal(context, ref, _organizers);
    if (res != null && mounted) {
      setState(() {
        _organizers.clear();
        _organizers.addAll(res);
      });
    }
  }

  Future<void> _pickTimeBlock() async {
    final blocks = ref.read(timeBlocksProvider);
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Time block',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('No time block'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            ...blocks.map(
              (block) => ListTile(
                leading: const Icon(Icons.view_timeline_outlined),
                title: Text(block.title),
                subtitle: Text(_formatTimeBlock(block)),
                selected: _timeBlock == block.id,
                onTap: () => Navigator.pop(ctx, block.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _timeBlock = selected.isEmpty ? null : selected);
    }
  }

  void _addCheckbox() {
    setState(() {
      _checkboxes.add('New item');
    });
  }

  String _formatTimeBlock(dynamic block) {
    if (block.timeRanges.isEmpty) return 'No fixed hours';
    final range = block.timeRanges.first;
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(range.startHour)}:${twoDigits(range.startMinute)} - ${twoDigits(range.endHour)}:${twoDigits(range.endMinute)}';
  }
}
