import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/content_object.dart';
import '../../models/goal_model.dart';
import '../../models/habit_model.dart';
import '../../models/journal_entry.dart';
import '../../models/note_model.dart';
import '../../models/organizer_model.dart';
import '../../models/people_model.dart';
import '../../models/project_model.dart';
import '../../models/reminder_model.dart';
import '../../models/resource_model.dart';
import '../../models/task_model.dart';
import '../../models/tracker_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/undo_service.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_goal_form.dart';
import '../forms/create_habit_form.dart';
import '../forms/create_note_form.dart';
import '../forms/create_organizer_form.dart';
import '../forms/create_person_form.dart';
import '../forms/create_project_form.dart';
import '../forms/create_resource_form.dart';
import '../forms/create_task_form.dart';
import '../forms/create_tracker_form.dart';
import '../theme.dart';

class ObjectActionWrapper extends ConsumerWidget {
  final ContentObject object;
  final Widget child;

  const ObjectActionWrapper({
    super.key,
    required this.object,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () => showObjectActionSheet(context, ref, object),
      child: child,
    );
  }
}

Future<void> showObjectActionSheet(
  BuildContext context,
  WidgetRef ref,
  ContentObject object,
) async {
  HapticFeedback.mediumImpact();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(
                object.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_typeLabel(object)),
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editObject(context, object);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Alterar Tipo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showChangeTypeSheet(context, ref, object);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.open_in_new_rounded,
                color: AppColors.info,
              ),
              title: const Text('Abrir no Obsidian'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openInObsidian(context, ref, object);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text('Excluir'),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(context, ref, object);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _showChangeTypeSheet(
  BuildContext context,
  WidgetRef ref,
  ContentObject object,
) {
  final types = [
    {
      'type': 'task',
      'label': 'Tarefa',
      'icon': Icons.check_circle_outline_rounded,
    },
    {'type': 'habit', 'label': 'Hábito', 'icon': Icons.loop_rounded},
    {'type': 'goal', 'label': 'Objetivo', 'icon': Icons.track_changes_rounded},
    {'type': 'note', 'label': 'Nota', 'icon': Icons.article_outlined},
    {'type': 'project', 'label': 'Projeto', 'icon': Icons.folder_outlined},
    {'type': 'area', 'label': 'Área', 'icon': Icons.layers_outlined},
    {'type': 'activity', 'label': 'Atividade', 'icon': Icons.sports_outlined},
    {'type': 'label', 'label': 'Etiqueta', 'icon': Icons.label_outline_rounded},
    {'type': 'person', 'label': 'Pessoa', 'icon': Icons.person_outline_rounded},
    {'type': 'place', 'label': 'Lugar', 'icon': Icons.place_outlined},
    {'type': 'resource', 'label': 'Recurso', 'icon': Icons.menu_book_outlined},
    {
      'type': 'tracker_definition',
      'label': 'Rastreador',
      'icon': Icons.analytics_outlined,
    },
  ];

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Alterar Tipo de Objeto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Converter "${object.title}" para:',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: types.length,
              itemBuilder: (context, index) {
                final t = types[index];
                return ListTile(
                  leading: Icon(
                    t['icon'] as IconData,
                    color: AppColors.primary,
                  ),
                  title: Text(t['label'] as String),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _confirmAndChangeType(
                      context,
                      ref,
                      object,
                      t['type'] as String,
                      t['label'] as String,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirmAndChangeType(
  BuildContext context,
  WidgetRef ref,
  ContentObject object,
  String targetType,
  String targetLabel,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Alterar para $targetLabel?'),
      content: Text(
        'Tem certeza que deseja converter "${object.title}" em $targetLabel? Os dados compatíveis serão migrados.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    String newType = targetType;
    Map<String, dynamic> extraFields = {};

    if (const ['area', 'activity', 'label', 'place'].contains(targetType)) {
      newType = 'organizer';
      extraFields['organizerType'] = targetType;
    }

    await ref
        .read(vaultProvider.notifier)
        .changeObjectType(object, newType, extraFields: extraFields);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${object.title}" convertido para $targetLabel com sucesso!',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao converter tipo: $e')));
    }
  }
}

void _editObject(BuildContext context, ContentObject object) {
  final formPage = _formPageFor(object);
  if (formPage == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Editing for ${_typeLabel(object).toLowerCase()} not yet available.',
        ),
      ),
    );
    return;
  }

  Navigator.push(context, MaterialPageRoute(builder: (_) => formPage));
}

Widget? _formPageFor(ContentObject object) {
  if (object is Task) return CreateTaskForm(existingTask: object);
  if (object is Habit) return CreateHabitForm(existingHabit: object);
  if (object is Goal) return CreateGoalForm(existingGoal: object);
  if (object is Note) return CreateNoteForm(existingNote: object);
  if (object is JournalEntry) return CreateEntryForm(existingEntry: object);
  if (object is Project) return CreateProjectForm(existingProject: object);
  if (object is Person) return CreatePersonForm(existingPerson: object);
  if (object is Resource) return CreateResourceForm(existingResource: object);
  if (object is TrackerDefinition) return CreateTrackerForm(tracker: object);
  if (object is Organizer) return CreateOrganizerForm(organizer: object);
  return null;
}

Future<void> _openInObsidian(
  BuildContext context,
  WidgetRef ref,
  ContentObject object,
) async {
  final path = object.obsidianPath;
  if (path.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This item does not have a file in the vault yet.'),
      ),
    );
    return;
  }

  final settings = ref.read(settingsProvider);
  final cleanPath = path.endsWith('.md')
      ? path.substring(0, path.length - 3)
      : path;
  final uri = Uri.parse(
    'obsidian://open?vault=${Uri.encodeComponent(settings.vaultName)}&file=${Uri.encodeComponent(cleanPath)}',
  );
  debugPrint('Opening Obsidian: $uri');

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open in Obsidian.')),
      );
    }
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  ContentObject object,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete item?'),
      content: Text(
        '“${object.title}” will be moved to _deleted in the vault.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final originalPath = object.obsidianPath;

  // Eagerly update state for instantaneous UI feedback
  if (object is Habit) {
    ref.read(habitsProvider.notifier).deleteHabit(object);
  } else if (object is Task) {
    ref.read(tasksProvider.notifier).deleteTask(object);
  } else if (object is Project) {
    ref.read(projectsProvider.notifier).deleteProject(object);
  } else if (object is Person) {
    ref.read(peopleProvider.notifier).deletePerson(object);
  } else if (object is TrackerDefinition) {
    ref.read(trackersProvider.notifier).deleteTracker(object);
  } else if (object is Goal) {
    ref.read(goalsProvider.notifier).deleteGoal(object);
  } else if (object is Note) {
    ref.read(notesProvider.notifier).deleteNote(object);
  } else if (object is JournalEntry) {
    await ref.read(todayJournalProvider.notifier).deleteEntry(object);
  } else {
    await ref.read(vaultProvider.notifier).deleteObject(object);
  }

  if (!context.mounted) return;
  UndoService.showUndoSnackbar(
    context: context,
    message: '${object.title} deleted.',
    onUndo: () =>
        ref.read(vaultProvider.notifier).restoreObject(object, originalPath),
  );
}

String _typeLabel(ContentObject object) {
  if (object is Task) return 'Tarefa';
  if (object is Habit) return 'Hábito';
  if (object is Goal) return 'Objetivo';
  if (object is Note) return 'Nota';
  if (object is JournalEntry) return 'Diário';
  if (object is Project) return 'Projeto';
  if (object is Person) return 'Pessoa';
  if (object is Resource) return 'Recurso';
  if (object is TrackerDefinition) return 'Rastreador';
  if (object is Organizer) {
    switch (object.organizerType) {
      case OrganizerType.area:
        return 'Área';
      case OrganizerType.project:
        return 'Projeto';
      case OrganizerType.activity:
        return 'Atividade';
      case OrganizerType.label:
        return 'Etiqueta';
      case OrganizerType.person:
        return 'Pessoa';
      case OrganizerType.place:
        return 'Lugar';
    }
  }
  if (object is Reminder) return 'Lembrete';
  if (object is TrackingRecord) return 'Registro';
  return object.type;
}
