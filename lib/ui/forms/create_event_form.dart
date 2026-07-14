import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/people_model.dart';
import '../../models/event_model.dart';
import '../../models/shared_types.dart';
import '../../models/task_model.dart';
import '../../models/template_model.dart';
import '../../providers/google_calendar_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/google_auth_service.dart' as auth;
import '../theme.dart';
import '../widgets/date_picker_field.dart';

class CreateEventForm extends ConsumerStatefulWidget {
  final Task? existingEvent;
  final String? initialTitle;

  const CreateEventForm({super.key, this.existingEvent, this.initialTitle});

  @override
  ConsumerState<CreateEventForm> createState() => _CreateEventFormState();
}

class _CreateEventFormState extends ConsumerState<CreateEventForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay(
    hour: (TimeOfDay.now().hour + 1).clamp(0, 23),
    minute: TimeOfDay.now().minute,
  );
  final Set<String> _selectedPersonIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.existingEvent;
    _titleController = TextEditingController(
      text: event?.title ?? widget.initialTitle ?? '',
    );
    _locationController = TextEditingController();
    _descriptionController = TextEditingController(
      text: event?.notes.join('\n') ?? '',
    );
    if (event?.startDate != null) _date = event!.startDate!;
    if (event?.scheduledTime != null) {
      final parts = event!.scheduledTime!.split(':');
      _startTime = TimeOfDay(
        hour: int.tryParse(parts.first) ?? _startTime.hour,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      );
      final end = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _startTime.hour,
        _startTime.minute,
      ).add(Duration(minutes: event.duration));
      _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
    }
    if (event != null) {
      _selectedPersonIds.addAll(
        event.participants.map((participant) => participant.slug),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider);
    final canSave = _titleController.text.trim().isNotEmpty && !_saving;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.existingEvent == null ? 'Criar Evento' : 'Editar Evento',
        ),
        actions: [
          if (widget.existingEvent == null)
            IconButton(
              icon: Icon(
                Icons.copy_all_rounded,
                color: AppTheme.accentColor(context),
              ),
              tooltip: 'Usar Template',
              onPressed: _showTemplatePicker,
            ),
          TextButton(
            onPressed: canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('SALVAR'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Título *'),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: Text(
                      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStartTime,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_startTime.format(context)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEndTime,
                    icon: const Icon(Icons.timer_outlined),
                    label: Text(_endTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Local'),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição'),
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 20),
            Text(
              'Participantes',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            if (people.isEmpty)
              Text(
                'Nenhuma pessoa com email cadastrada.',
                style: TextStyle(color: AppTheme.textMutedColor(context)),
              )
            else
              ...people.map((person) {
                final selected =
                    _selectedPersonIds.contains(person.id) ||
                    _selectedPersonIds.contains(person.slug);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected,
                  onChanged: (_) => setState(() {
                    if (selected) {
                      _selectedPersonIds
                        ..remove(person.id)
                        ..remove(person.slug);
                    } else {
                      _selectedPersonIds.add(person.id);
                    }
                  }),
                  title: Text(
                    person.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    person.email ?? 'Sem email',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  void _showTemplatePicker() async {
    final templates = ref
        .read(templatesProvider)
        .where((t) => t.templateType == 'event')
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
                      extra: {'initialType': 'event'},
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
      if (template.frontmatterDefaults.containsKey('location')) {
        _locationController.text = template.frontmatterDefaults['location'] as String;
      }
      if (template.frontmatterDefaults.containsKey('description')) {
        _descriptionController.text = template.frontmatterDefaults['description'] as String;
      }
      if (template.body.isNotEmpty) {
        _descriptionController.text = template.body;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final people = allObjects.whereType<Person>().toList();
    final participants = people
        .where(
          (person) =>
              _selectedPersonIds.contains(person.id) ||
              _selectedPersonIds.contains(person.slug),
        )
        .toList();
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    );
    var end = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
    final duration = end.difference(start).inMinutes;

    final participantRefs = participants
        .map(
          (person) => OrganizerReference(
            type: 'person',
            slug: person.slug,
            title: person.title,
          ),
        )
        .toList();
    final participantSlugs = participants.map((person) => person.slug).toList();

    final task = (widget.existingEvent ?? Task(title: _titleController.text.trim()))
        .copyWith(
      title: _titleController.text.trim(),
      startDate: start,
      endDate: end,
      scheduledTime:
          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      duration: duration,
      notes: [
        if (_locationController.text.trim().isNotEmpty)
          'Local: ${_locationController.text.trim()}',
        _descriptionController.text.trim(),
      ].where((line) => line.isNotEmpty).toList(),
      participants: participantRefs,
      categories: const ['[[events]]'],
    );

    Event eventObject({String? googleEventId, String? googleEventUrl}) {
      return Event(
        title: _titleController.text.trim(),
        startDatetime: start,
        endDatetime: end,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        participants: participantSlugs,
        googleEventId: googleEventId,
        googleEventUrl: googleEventUrl,
        organizers: participantRefs,
        categories: const ['[[events]]'],
      );
    }

    try {
      final authClient = await ref
          .read(auth.googleAuthServiceProvider)
          .ensureClient();
      if (authClient != null) {
        final calendarService = ref.read(googleCalendarServiceProvider)
          ..init(authClient);
        final event = await calendarService.saveEvent(
          googleEventId: widget.existingEvent?.exportedCalendarId,
          title: task.title,
          start: start,
          end: end,
          location: _locationController.text.trim(),
          description: _descriptionController.text.trim(),
          participants: participants,
        );
        final savedTask = task.copyWith(
          exportedCalendarId: event.id,
          linkedGoogleEventId: event.id,
          linkedGoogleEventTitle: event.summary,
          linkedGoogleEventDate: start.toIso8601String(),
          linkedGoogleEventUrl: event.htmlLink,
        );
        if (widget.existingEvent == null) {
          await ref.read(vaultProvider.notifier).createObject(
                eventObject(googleEventId: event.id, googleEventUrl: event.htmlLink),
              );
        } else {
          await ref.read(vaultProvider.notifier).updateObject(savedTask);
        }
      } else {
        if (widget.existingEvent == null) {
          await ref.read(vaultProvider.notifier).createObject(eventObject());
        } else {
          await ref.read(vaultProvider.notifier).updateObject(task);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao criar evento: $e')));
        setState(() => _saving = false);
      }
    }
  }
}
