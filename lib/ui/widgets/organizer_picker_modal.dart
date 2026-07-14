import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/shared_types.dart';
import '../../models/content_object.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/goal_model.dart';
import '../../models/note_model.dart';
import '../../models/organizer_model.dart';
import '../../models/people_model.dart';
import '../../models/resource_model.dart';
import '../../models/project_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/search_service.dart';
import '../theme.dart';
import 'app_chip.dart';

Future<List<OrganizerReference>?> showOrganizerPickerModal(
  BuildContext context,
  WidgetRef ref,
  List<OrganizerReference> initialSelected, {
  String initialFilter = 'all',
}) async {
  final allObjects = await ref.read(allObjectsProvider.future);
  final List<ContentObject> mutableObjects = List.from(
    allObjects.where((o) => o.title.isNotEmpty),
  );

  if (!context.mounted) return null;

  final SearchService searchService = SearchService();
  String searchQuery = '';
  String selectedFilter = initialFilter;
  List<OrganizerReference> selected = List.from(initialSelected);

  IconData getIconForType(String type) {
    switch (type) {
      case 'project':
        return Icons.rocket_launch_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'area':
        return Icons.category_rounded;
      case 'task':
        return Icons.check_circle_outline_rounded;
      case 'goal':
        return Icons.flag_rounded;
      case 'habit':
        return Icons.repeat_rounded;
      case 'tracker':
        return Icons.bar_chart_rounded;
      case 'resource':
        return Icons.menu_book_rounded;
      case 'social_post':
        return Icons.bookmarks_rounded;
      case 'note':
        return Icons.description_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  String getTypeLabel(ContentObject obj) {
    if (obj is Organizer) {
      switch (obj.organizerType) {
        case OrganizerType.area:
          return 'Area';
        case OrganizerType.project:
          return 'Project';
        case OrganizerType.activity:
          return 'Activity';
        case OrganizerType.label:
          return 'Label';
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
      }
    }
    switch (obj.type) {
      case 'task':
        return 'Tarefa';
      case 'habit':
        return 'Habit';
      case 'goal':
        return 'Goal';
      case 'note':
        return 'Nota';
      case 'resource':
        return 'Resource';
      case 'social_post':
        return 'Social post';
      case 'person':
        return 'Pessoa';
      default:
        return obj.type;
    }
  }

  Widget buildFilterChip(
    String filter,
    String label,
    String selectedFilter,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AppChip(
        label: label,
        selected: isSelected,
        onTap: () => onSelected(filter),
        variant: ChipVariant.choice,
        size: ChipSize.small,
      ),
    );
  }

  void showCreateInlineChoiceDialog(
    BuildContext context,
    WidgetRef ref,
    String title,
    ValueChanged<ContentObject> onCreated,
  ) {
    final types = [
      {
        'type': 'task',
        'label': 'Task',
        'icon': Icons.check_circle_outline_rounded,
      },
      {'type': 'habit', 'label': 'Habit', 'icon': Icons.loop_rounded},
      {
        'type': 'goal',
        'label': 'Goal',
        'icon': Icons.track_changes_rounded,
      },
      {'type': 'note', 'label': 'Nota', 'icon': Icons.article_outlined},
      {'type': 'project', 'label': 'Project', 'icon': Icons.folder_outlined},
      {
        'type': 'area',
        'label': 'Area (Organizer)',
        'icon': Icons.layers_outlined,
      },
      {
        'type': 'person',
        'label': 'Person',
        'icon': Icons.person_outline_rounded,
      },
      {
        'type': 'resource',
        'label': 'Resource',
        'icon': Icons.menu_book_outlined,
      },
      {
        'type': 'label',
        'label': 'Label (Label)',
        'icon': Icons.label_outlined,
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
            Text(
              'Criar "$title" como:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                      Navigator.pop(sheetContext); // Close type sheet
                      final String id = const Uuid().v4();
                      ContentObject newObj;

                      if (t['type'] == 'task') {
                        newObj = Task(
                          id: id,
                          title: title,
                          stage: TaskStage.todo,
                          createdAt: DateTime.now(),
                        );
                      } else if (t['type'] == 'habit') {
                        newObj = Habit(
                          id: id,
                          title: title,
                          color: '#10B981',
                          createdAt: DateTime.now(),
                          slots: [],
                        );
                      } else if (t['type'] == 'goal') {
                        newObj = Goal(
                          id: id,
                          title: title,
                          state: GoalStatus.active,
                          createdAt: DateTime.now(),
                        );
                      } else if (t['type'] == 'note') {
                        newObj = Note(
                          id: id,
                          title: title,
                          subtype: NoteSubtype.text,
                          body: '',
                          createdAt: DateTime.now(),
                        );
                      } else if (t['type'] == 'project') {
                        newObj = Project(
                          id: id,
                          title: title,
                          state: ProjectState.active,
                          createdAt: DateTime.now(),
                        );
                      } else if (t['type'] == 'area') {
                        newObj = Organizer(
                          id: id,
                          title: title,
                          organizerType: OrganizerType.area,
                          createdAt: DateTime.now(),
                        );
                      } else if (t['type'] == 'label') {
                        newObj = Organizer(
                          id: id,
                          title: title,
                          organizerType: OrganizerType.label,
                          createdAt: DateTime.now(),
                        );
                      } else if (t['type'] == 'person') {
                        newObj = Person(
                          id: id,
                          title: title,
                          createdAt: DateTime.now(),
                        );
                      } else if (t['type'] == 'resource') {
                        newObj = Resource(
                          id: id,
                          title: title,
                          mediaType: 'Book',
                          status: ResourceStatus.toConsume,
                          createdAt: DateTime.now(),
                        );
                      } else {
                        newObj = Note(
                          id: id,
                          title: title,
                          subtype: NoteSubtype.text,
                          body: '',
                          createdAt: DateTime.now(),
                        );
                      }

                      try {
                        await ref
                            .read(vaultProvider.notifier)
                            .createObject(newObj);
                        onCreated(newObj);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro ao criar objeto: $e')),
                          );
                        }
                      }
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

  return showModalBottomSheet<List<OrganizerReference>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          // Apply filter
          var displayObjects = mutableObjects.where((obj) {
            if (selectedFilter != 'all') {
              if (selectedFilter == 'area') {
                if (obj is! Organizer ||
                    (obj).organizerType != OrganizerType.area) {
                  return false;
                }
              } else if (selectedFilter == 'label') {
                if (obj is! Organizer ||
                    (obj).organizerType != OrganizerType.label) {
                  return false;
                }
              } else if (selectedFilter == 'project') {
                if (obj.type != 'project' &&
                    (obj is! Organizer ||
                        (obj).organizerType != OrganizerType.project)) {
                  return false;
                }
              } else {
                if (obj.type != selectedFilter) return false;
              }
            }
            return true;
          }).toList();

          // Apply search query
          if (searchQuery.trim().isNotEmpty) {
            displayObjects = searchService.search(
              displayObjects,
              searchQuery.trim(),
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Organizers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context, selected),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Bar
                TextField(
                  onChanged: (val) {
                    setModalState(() {
                      searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Pesquisar...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      buildFilterChip('all', 'All', selectedFilter, (val) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('task', 'Tasks', selectedFilter, (val) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('habit', 'Habits', selectedFilter, (
                        val,
                      ) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('goal', 'Objetivos', selectedFilter, (
                        val,
                      ) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('project', 'Projetos', selectedFilter, (
                        val,
                      ) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('area', 'Areas', selectedFilter, (val) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('note', 'Notes', selectedFilter, (val) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('label', 'Labels', selectedFilter, (val) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('resource', 'Resources', selectedFilter, (
                        val,
                      ) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('social_post', 'Posts', selectedFilter, (
                        val,
                      ) {
                        setModalState(() => selectedFilter = val);
                      }),
                      buildFilterChip('person', 'People', selectedFilter, (
                        val,
                      ) {
                        setModalState(() => selectedFilter = val);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: displayObjects.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Nenhum objeto encontrado',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: displayObjects.length,
                          itemBuilder: (context, index) {
                            final obj = displayObjects[index];
                            final isSelected = selected.any(
                              (o) => o.slug == obj.id || o.slug == obj.slug,
                            );
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.accentColor(context).withValues(
                                  alpha: 0.1,
                                ),
                                child: Icon(
                                  getIconForType(obj.type),
                                  size: 18,
                                  color: AppTheme.accentColor(context),
                                ),
                              ),
                              title: Text(
                                obj.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                getTypeLabel(obj).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                  letterSpacing: 1,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: AppTheme.accentColor(context),
                                    )
                                  : null,
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    selected.removeWhere(
                                      (o) =>
                                          o.slug == obj.id ||
                                          o.slug == obj.slug,
                                    );
                                  } else {
                                    selected.add(
                                      OrganizerReference(
                                        type: obj.type,
                                        slug: obj.slug,
                                        title: obj.title,
                                      ),
                                    );
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                // Criar Novo Objeto Button
                if (searchQuery.trim().isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showCreateInlineChoiceDialog(
                          context,
                          ref,
                          searchQuery.trim(),
                          (newObj) {
                            setModalState(() {
                              mutableObjects.add(newObj);
                              selected.add(
                                OrganizerReference(
                                  type: newObj.type,
                                  slug: newObj.id,
                                  title: newObj.title,
                                ),
                              );
                            });
                          },
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Criar "${searchQuery.trim()}" como...'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}


