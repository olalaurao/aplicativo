import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/people_model.dart';
import '../../models/content_object.dart';
import '../../models/project_model.dart';
import '../../models/shared_types.dart';
import '../../models/task_model.dart';
import '../../providers/google_calendar_provider.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/universal_search_picker.dart';

class GoogleEventDetailScreen extends ConsumerStatefulWidget {
  final google_calendar.Event event;

  const GoogleEventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<GoogleEventDetailScreen> createState() =>
      _GoogleEventDetailScreenState();
}

class _GoogleEventDetailScreenState
    extends ConsumerState<GoogleEventDetailScreen> {
  late google_calendar.Event _event;
  final Set<String> _selectedPeopleIds = {};

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider);
    final start = _event.start?.dateTime ?? _event.start?.date;
    final end = _event.end?.dateTime ?? _event.end?.date;
    final isAllDay = _event.start?.date != null;

    final startTime = start?.toLocal();
    final endTime = end?.toLocal();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Evento do Google'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => _openInGoogleCalendar(context),
            tooltip: 'Abrir no Google Agenda',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _event.summary ?? '(Untitled)',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Importado do Google Calendar',
                        style: TextStyle(
                          color: AppTheme.textMutedColor(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              context,
              icon: Icons.access_time_rounded,
              title: 'Quando',
              content: isAllDay
                  ? '${DateFormat('EEEE, d MMMM').format(startTime!)} (Dia inteiro)'
                  : '${DateFormat('EEEE, d MMMM').format(startTime!)}\n'
                        '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime!)}',
            ),
            if (_event.location != null && _event.location!.isNotEmpty)
              _buildSection(
                context,
                icon: Icons.location_on_outlined,
                title: 'Local',
                content: _event.location!,
              ),
            if (_event.description != null && _event.description!.isNotEmpty)
              _buildSection(
                context,
                icon: Icons.notes_rounded,
                title: 'Description',
                content: _event.description!,
                isMarkdown: true,
              ),
            if (people.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildPeopleSection(context, people),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link_rounded),
                label: const Text('Associar a...'),
                onPressed: () => _showLinkObjectPicker(context),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openInGoogleCalendar(context),
                icon: const Icon(Icons.calendar_today_rounded),
                label: const Text('Ver no Google Agenda'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.info,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkObjectPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UniversalSearchPickerSheet(
        title: 'Associar evento a...',
        initialFilter: 'all',
        showClear: false,
        onSelected: (object) async {
          Navigator.pop(context);
          await _linkEventToObject(object);
        },
      ),
    );
  }

  Future<void> _linkEventToObject(ContentObject object) async {
    if (object is! Task && object is! Project) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma tarefa ou projeto.'),
        ),
      );
      return;
    }

    final start = (_event.start?.dateTime ?? _event.start?.date)?.toLocal();
    final eventDate = start?.toIso8601String();
    final title = _event.summary ?? 'Evento Google';

    if (object is Task) {
      await ref
          .read(vaultProvider.notifier)
          .updateObject(
            object.copyWith(
              linkedGoogleEventId: _event.id,
              linkedGoogleEventTitle: title,
              linkedGoogleEventDate: eventDate,
              linkedGoogleEventUrl: _event.htmlLink,
            ),
          );
    } else if (object is Project) {
      object
        ..linkedGoogleEventId = _event.id
        ..linkedGoogleEventTitle = title
        ..linkedGoogleEventDate = eventDate
        ..linkedGoogleEventUrl = _event.htmlLink;
      await ref.read(vaultProvider.notifier).updateObject(object);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Evento associado a "${object.title}".')),
    );
  }

  Widget _buildPeopleSection(BuildContext context, List<Person> people) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PESSOAS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.info,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: people.map((person) {
            final selected = _selectedPeopleIds.contains(person.id);
            return FilterChip(
              selected: selected,
              label: Text(
                person.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              avatar: Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: selected ? Colors.white : AppColors.info,
              ),
              selectedColor: AppColors.info,
              checkmarkColor: Colors.white,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedPeopleIds.add(person.id);
                  } else {
                    _selectedPeopleIds.remove(person.id);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Marcar pessoas vistas e atualizar contato'),
            onPressed: _selectedPeopleIds.isEmpty
                ? null
                : () => _markPeopleSeen(people),
          ),
        ),
      ],
    );
  }

  Future<void> _markPeopleSeen(List<Person> people) async {
    final selected = people
        .where((person) => _selectedPeopleIds.contains(person.id))
        .toList();
    if (selected.isEmpty) return;

    final names = selected.map((person) => '[[${person.slug}]]').join(', ');
    final marker = 'people:: $names';
    final currentDescription = _event.description ?? '';
    _event.description = currentDescription.contains(marker)
        ? currentDescription
        : [
            if (currentDescription.trim().isNotEmpty) currentDescription.trim(),
            marker,
          ].join('\n');

    try {
      final service = ref.read(googleCalendarServiceProvider);
      final updatedEvent = await service.updateEvent(_event);
      setState(() => _event = updatedEvent);

      final seenAt =
          (_event.start?.dateTime ?? _event.start?.date)?.toLocal() ??
          DateTime.now();
      for (final person in selected) {
        final updatedPerson = person.copyWith(lastContactDate: seenAt);
        await ref.read(vaultProvider.notifier).updateObject(updatedPerson);
        await _upsertNextContactTask(updatedPerson);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} pessoa(s) atualizadas.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar o evento: $e')),
      );
    }
  }

  Future<void> _upsertNextContactTask(Person person) async {
    final frequency = person.contactFrequency;
    if (frequency == null) return;
    final dueDate = (person.lastContactDate ?? DateTime.now()).add(frequency);
    final title = 'Entrar em contato com ${person.title}';
    final allObjects = ref.read(allObjectsProvider).value ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    final existing = tasks
        .where(
          (task) =>
              task.title == title ||
              task.organizers.any((org) => org.slug == person.slug),
        )
        .firstOrNull;
    final organizer = OrganizerReference(
      type: 'person',
      slug: person.slug,
      title: person.title,
    );

    if (existing != null) {
      await ref
          .read(vaultProvider.notifier)
          .updateObject(
            existing.copyWith(
              endDate: dueDate,
              stage: TaskStage.todo,
              organizers: [
                ...existing.organizers.where((org) => org.slug != person.slug),
                organizer,
              ],
            ),
          );
      return;
    }

    await ref
        .read(vaultProvider.notifier)
        .createObject(
          Task(
            title: title,
            endDate: dueDate,
            stage: TaskStage.todo,
            priority: person.contactPriority,
            organizers: [organizer],
            notes: [
              'Criada automaticamente a partir de um evento do Google Calendar.',
            ],
          ),
        );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    bool isMarkdown = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.info),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.info,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInGoogleCalendar(BuildContext context) async {
    final htmlLink = _event.htmlLink;
    if (htmlLink != null) {
      final uri = Uri.parse(htmlLink);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the Google Calendar link.'),
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This event does not have an associated link.'),
          ),
        );
      }
    }
  }
}
