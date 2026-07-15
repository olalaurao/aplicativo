import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'triple_check_sheet.dart';
import 'universal_search_picker.dart';

class ObjectActionWrapper extends ConsumerWidget {
  final ContentObject object;
  final Widget child;
  final VoidCallback? onTap;

  const ObjectActionWrapper({
    super.key,
    required this.object,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
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
              leading: Icon(
                Icons.edit_outlined,
                color: AppTheme.accentColor(context),
              ),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editObject(context, object);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.swap_horiz_rounded,
                color: AppTheme.accentColor(context),
              ),
              title: const Text('Alterar Tipo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showChangeTypeSheet(context, ref, object);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.call_merge_rounded,
                color: AppTheme.accentColor(context),
              ),
              title: const Text('Mesclar com outra nota'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showMergeTargetPicker(context, ref, object);
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
            // Triple Check — visible only for non-finalized Tasks
            if (object is Task && object.stage != TaskStage.finalized)
              ListTile(
                leading: const Icon(
                  Icons.troubleshoot_rounded,
                  color: AppColors.warning,
                ),
                title: const Text('Por que estou evitando isso?'),
                subtitle: const Text('Triple Check'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showTripleCheckSheet(context, ref, object);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showMergeTargetPicker(
  BuildContext context,
  WidgetRef ref,
  ContentObject source,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (pickerContext) => UniversalSearchPickerSheet(
      title: 'Escolher nota correta',
      initialFilter: 'note',
      showClear: false,
      onSelected: (target) async {
        Navigator.pop(pickerContext);
        if (target.id == source.id ||
            target.obsidianPath == source.obsidianPath) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escolha uma nota diferente.')),
          );
          return;
        }
        await _confirmMergeIntoTarget(context, ref, source, target);
      },
    ),
  );
}

Future<void> _confirmMergeIntoTarget(
  BuildContext context,
  WidgetRef ref,
  ContentObject source,
  ContentObject target,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Mesclar notas?'),
      content: Text(
        'Todas as conexões de "${source.title}" serão redirecionadas para '
        '"${target.title}". O conteúdo será anexado à nota correta e a nota '
        'errada será movida para a lixeira.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor(context)),
          child: const Text('Mesclar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await ref
        .read(vaultProvider.notifier)
        .redirectAndDeleteObject(source: source, target: target);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${source.title}" mesclada em "${target.title}".'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao mesclar notas: $e')));
    }
  }
}

void _showChangeTypeSheet(
  BuildContext context,
  WidgetRef ref,
  ContentObject object,
) {
  final types = [
    {
      'type': 'task',
      'label': 'Task',
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
                    color: AppTheme.accentColor(context),
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
          style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor(context)),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    String newType = targetType;
    Map<String, dynamic> extraFields = {};

    if (const ['area', 'activity', 'label'].contains(targetType)) {
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
  // Fallback to form-based navigation for other types
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
    ref.read(vaultProvider.notifier).deleteObject(object);
  } else if (object is Task) {
    ref.read(vaultProvider.notifier).deleteObject(object);
  } else if (object is Project) {
    ref.read(vaultProvider.notifier).deleteObject(object);
  } else if (object is Person) {
    ref.read(vaultProvider.notifier).deleteObject(object);
  } else if (object is TrackerDefinition) {
    ref.read(vaultProvider.notifier).deleteObject(object);
  } else if (object is Goal) {
    ref.read(vaultProvider.notifier).deleteObject(object);
  } else if (object is Note) {
    ref.read(vaultProvider.notifier).deleteObject(object);
  } else if (object is JournalEntry) {
    await ref.read(vaultProvider.notifier).deleteObject(object);
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
  if (object is Task) return 'Task';
  if (object is Habit) return 'Habit';
  if (object is Goal) return 'Goal';
  if (object is Note) return 'Note';
  if (object is JournalEntry) return 'Journal';
  if (object is Project) return 'Project';
  if (object is Person) return 'Person';
  if (object is Resource) return 'Resource';
  if (object is TrackerDefinition) return 'Tracker';
  if (object is Organizer) {
    switch (object.organizerType) {
      case OrganizerType.area:
        return 'Area';
      case OrganizerType.project:
        return 'Project';
      case OrganizerType.activity:
        return 'Activity';
      case OrganizerType.label:
        return 'Tag';
      case OrganizerType.person:
        return 'Person';
      case OrganizerType.task:
        return 'Task';
      case OrganizerType.goal:
        return 'Goal';
      case OrganizerType.habit:
        return 'Habit';
      case OrganizerType.tracker:
        return 'Tracker';
      case OrganizerType.dayTheme:
        return 'Day Theme';
      case OrganizerType.timeBlock:
        return 'Time Block';
      case OrganizerType.routine:
        return 'Routine';
      case OrganizerType.value:
        return 'Value';
    }
  }
  if (object is Reminder) return 'Reminder';
  if (object is TrackingRecord) return 'Record';
  return object.type;
}
