import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/content_object.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/goal_model.dart';
import '../../models/note_model.dart';
import '../../models/organizer_model.dart';
import '../../models/people_model.dart';
import '../../models/resource_model.dart';
import '../../models/project_model.dart';
import '../../models/social_post.dart';
import '../../providers/vault_provider.dart';
import '../../services/search_service.dart';
import '../theme.dart';

class UniversalSearchPickerSheet extends ConsumerStatefulWidget {
  final String title;
  final ValueChanged<ContentObject> onSelected;
  final VoidCallback? onClear;
  final bool showClear;
  final String initialFilter; // 'all', 'task', etc.

  const UniversalSearchPickerSheet({
    super.key,
    required this.title,
    required this.onSelected,
    this.onClear,
    this.showClear = true,
    this.initialFilter = 'all',
  });

  @override
  ConsumerState<UniversalSearchPickerSheet> createState() =>
      _UniversalSearchPickerSheetState();
}

class _UniversalSearchPickerSheetState
    extends ConsumerState<UniversalSearchPickerSheet> {
  late TextEditingController _searchController;
  final SearchService _searchService = SearchService();
  late String _selectedFilter;
  SocialPlatform? _socialPlatformFilter;
  String? _socialCreatorFilter;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedFilter = widget.initialFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allObjectsAsync = ref.watch(allObjectsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: AppTheme.sheetDecoration(context),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Pesquisar...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'Tudo'),
                _filterChip('task', 'Tarefas'),
                _filterChip('habit', 'Hábitos'),
                _filterChip('goal', 'Objetivos'),
                _filterChip('project', 'Projetos'),
                _filterChip('area', 'Áreas'),
                _filterChip('note', 'Notas'),
                _filterChip('idea', 'Ideias'),
                _filterChip('resource', 'Recursos'),
                _filterChip('social_post', 'Posts'),
                _filterChip('person', 'Pessoas'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Results
          Expanded(
            child: allObjectsAsync.when(
              data: (objects) {
                // Apply filters
                var filtered = objects.where((obj) {
                  if (_selectedFilter != 'all') {
                    if (_selectedFilter == 'area') {
                      if (obj is! Organizer ||
                          (obj).organizerType != OrganizerType.area) {
                        return false;
                      }
                    } else if (_selectedFilter == 'project') {
                      // Allow both Project objects and Organizer objects of type project
                      if (obj.type != 'project' &&
                          (obj is! Organizer ||
                              (obj).organizerType != OrganizerType.project)) {
                        return false;
                      }
                    } else {
                      if (obj.type != _selectedFilter) return false;
                    }
                  }
                  return true;
                }).toList();

                if (_selectedFilter == 'social_post') {
                  filtered = filtered.where((obj) {
                    if (obj is! SocialPost) return false;
                    final matchesPlatform =
                        _socialPlatformFilter == null ||
                        obj.platform == _socialPlatformFilter;
                    final creator = _creatorLabel(obj).toLowerCase();
                    final matchesCreator =
                        _socialCreatorFilter == null ||
                        creator == _socialCreatorFilter!.toLowerCase();
                    return matchesPlatform && matchesCreator;
                  }).toList();
                }

                // Apply query search
                final query = _searchController.text.trim();
                if (query.isNotEmpty) {
                  filtered = _searchService.search(filtered, query);
                }

                if (filtered.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final obj = filtered[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _getIconForType(obj),
                      title: Text(
                        obj.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _getTypeLabel(obj).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      onTap: () {
                        widget.onSelected(obj);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
          if (_selectedFilter == 'social_post')
            _buildSocialFilters(
              allObjectsAsync.valueOrNull?.whereType<SocialPost>().toList() ??
                  const [],
            ),
          const SizedBox(height: 16),

          // Bottom Action: Criar Novo Objeto
          if (_searchController.text.trim().isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateTypeChoiceDialog(
                  context,
                  _searchController.text.trim(),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Criar "${_searchController.text.trim()}" como...',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

          if (widget.showClear && widget.onClear != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  widget.onClear!();
                },
                child: const Text(
                  'Limpar Seleção',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary.withValues(alpha: 0.1),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        side: isSelected
            ? const BorderSide(color: AppColors.primary)
            : BorderSide(color: AppColors.textMuted.withValues(alpha: 0.3)),
        onSelected: (val) {
          if (!val) return;
          setState(() {
            _selectedFilter = filter;
            if (filter != 'social_post') {
              _socialPlatformFilter = null;
              _socialCreatorFilter = null;
            }
          });
        },
      ),
    );
  }

  Widget _buildSocialFilters(List<SocialPost> posts) {
    final creators =
        posts
            .map(_creatorLabel)
            .where((creator) => creator.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _socialPlatformChip(null, 'Todas'),
              ...SocialPlatform.values.map(
                (platform) => _socialPlatformChip(platform, platform.name),
              ),
            ],
          ),
        ),
        if (creators.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _socialCreatorChip(null, 'Todos criadores'),
                ...creators
                    .take(12)
                    .map((creator) => _socialCreatorChip(creator, creator)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _socialPlatformChip(SocialPlatform? platform, String label) {
    final selected = _socialPlatformFilter == platform;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => setState(() => _socialPlatformFilter = platform),
      ),
    );
  }

  Widget _socialCreatorChip(String? creator, String label) {
    final selected = _socialCreatorFilter == creator;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => setState(() => _socialCreatorFilter = creator),
      ),
    );
  }

  String _creatorLabel(SocialPost post) {
    return post.authorHandle?.trim().isNotEmpty == true
        ? post.authorHandle!.trim()
        : (post.authorName ?? '').trim();
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Nenhum objeto encontrado',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Experimente mudar o filtro ou criar um novo.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _getIconForType(ContentObject obj) {
    IconData icon;
    Color color;
    if (obj is Organizer) {
      switch (obj.organizerType) {
        case OrganizerType.area:
          icon = Icons.layers_outlined;
          color = AppColors.primary;
          break;
        case OrganizerType.project:
          icon = Icons.folder_outlined;
          color = AppColors.primary;
          break;
        default:
          icon = Icons.radio_button_unchecked_rounded;
          color = AppColors.textMuted;
      }
    } else {
      switch (obj.type) {
        case 'task':
          icon = Icons.check_circle_outline_rounded;
          color = AppColors.info;
          break;
        case 'goal':
          icon = Icons.track_changes_rounded;
          color = AppColors.habitOrange;
          break;
        case 'habit':
          icon = Icons.loop_rounded;
          color = AppColors.habitGreen;
          break;
        case 'project':
          icon = Icons.folder_outlined;
          color = AppColors.habitPurple;
          break;
        case 'note':
          icon = Icons.article_outlined;
          color = AppColors.primary;
          break;
        case 'idea':
          icon = Icons.lightbulb_outline_rounded;
          color = AppColors.warning;
          break;
        case 'resource':
          icon = Icons.menu_book_outlined;
          color = AppColors.primary;
          break;
        case 'social_post':
          icon = Icons.bookmarks_outlined;
          color = AppColors.primary;
          break;
        case 'person':
          icon = Icons.person_outline_rounded;
          color = AppColors.primary;
          break;
        default:
          icon = Icons.radio_button_unchecked_rounded;
          color = AppColors.textMuted;
      }
    }
    return Icon(icon, color: color);
  }

  String _getTypeLabel(ContentObject obj) {
    if (obj is Organizer) {
      switch (obj.organizerType) {
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
        case OrganizerType.task:
          return 'Tarefa';
        case OrganizerType.goal:
          return 'Objetivo';
        case OrganizerType.habit:
          return 'Hábito';
        case OrganizerType.tracker:
          return 'Rastreador';
      }
    }
    switch (obj.type) {
      case 'task':
        return 'Tarefa';
      case 'habit':
        return 'Hábito';
      case 'goal':
        return 'Objetivo';
      case 'note':
        return 'Nota';
      case 'idea':
        return 'Ideia';
      case 'resource':
        return 'Recurso';
      case 'social_post':
        return 'Post social';
      case 'person':
        return 'Pessoa';
      default:
        return obj.type;
    }
  }

  void _showCreateTypeChoiceDialog(BuildContext context, String newTitle) {
    final types = [
      {
        'type': 'task',
        'label': 'Tarefa',
        'icon': Icons.check_circle_outline_rounded,
      },
      {'type': 'habit', 'label': 'Hábito', 'icon': Icons.loop_rounded},
      {
        'type': 'goal',
        'label': 'Objetivo',
        'icon': Icons.track_changes_rounded,
      },
      {'type': 'note', 'label': 'Nota', 'icon': Icons.article_outlined},
      {'type': 'project', 'label': 'Projeto', 'icon': Icons.folder_outlined},
      {
        'type': 'area',
        'label': 'Área (Organizador)',
        'icon': Icons.layers_outlined,
      },
      {
        'type': 'person',
        'label': 'Pessoa',
        'icon': Icons.person_outline_rounded,
      },
      {
        'type': 'resource',
        'label': 'Recurso',
        'icon': Icons.menu_book_outlined,
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
              'Criar "$newTitle" como:',
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
                      color: AppColors.primary,
                    ),
                    title: Text(t['label'] as String),
                    onTap: () async {
                      Navigator.pop(sheetContext); // Close type sheet
                      // Don't close the search picker sheet here, let _createNewObject do it
                      await _createNewObject(t['type'] as String, newTitle);
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

  Future<void> _createNewObject(String type, String title) async {
    final String id = const Uuid().v4();
    ContentObject newObj;

    if (type == 'task') {
      newObj = Task(
        id: id,
        title: title,
        stage: TaskStage.todo,
        createdAt: DateTime.now(),
      );
    } else if (type == 'habit') {
      newObj = Habit(
        id: id,
        title: title,
        color: '#10B981',
        createdAt: DateTime.now(),
        slots: [],
      );
    } else if (type == 'goal') {
      newObj = Goal(
        id: id,
        title: title,
        state: GoalStatus.active,
        createdAt: DateTime.now(),
      );
    } else if (type == 'note') {
      newObj = Note(
        id: id,
        title: title,
        subtype: NoteSubtype.text,
        body: '',
        createdAt: DateTime.now(),
      );
    } else if (type == 'project') {
      newObj = Project(
        id: id,
        title: title,
        state: ProjectState.active,
        createdAt: DateTime.now(),
      );
    } else if (type == 'area') {
      newObj = Organizer(
        id: id,
        title: title,
        organizerType: OrganizerType.area,
        createdAt: DateTime.now(),
      );
    } else if (type == 'person') {
      newObj = Person(id: id, title: title, createdAt: DateTime.now());
    } else if (type == 'resource') {
      newObj = Resource(
        id: id,
        title: title,
        resourceType: 'Book',
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
      await ref.read(vaultProvider.notifier).createObject(newObj);
      widget.onSelected(newObj);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao criar objeto: $e')));
      }
    }
  }
}
