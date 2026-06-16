// lib/ui/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/content_object.dart';
import '../../services/search_service.dart';
import '../theme.dart';
import 'pomodoro_screen.dart';
import 'archive_screen.dart';
import 'settings_screen.dart';
import 'inbox_screen.dart';
import '../forms/create_task_form.dart';
import '../widgets/object_action_wrapper.dart';
import '../../models/organizer_model.dart';
import '../../models/social_post.dart';

class SearchAction {
  final String label;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context) onExecute;
  SearchAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onExecute,
  });
}

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialType;

  const SearchScreen({super.key, this.initialType});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _searchService = SearchService();
  List<ContentObject> _results = [];
  List<SearchAction> _actionResults = [];
  String? _selectedType;
  String? _socialPlatformFilter;
  String? _socialCreatorFilter;

  final Map<String, String> _typeLabels = {
    'task': 'Tasks',
    'habit': 'Habits',
    'journal_entry': 'Journal',
    'note': 'Notes',
    'idea': 'Ideias',
    'goal': 'Goals',
    'project': 'Projects',
    'person': 'People',
    'resource': 'Media',
    'social_post': 'Posts sociais',
  };

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  List<SearchAction> _getAllActions() {
    return [
      SearchAction(
        label: 'New Task',
        icon: Icons.add_task_rounded,
        color: AppColors.primary,
        onExecute: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const CreateTaskForm()),
        ),
      ),
      SearchAction(
        label: 'Start Pomodoro',
        icon: Icons.timer_rounded,
        color: AppColors.error,
        onExecute: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const PomodoroScreen()),
        ),
      ),
      SearchAction(
        label: 'View Archive',
        icon: Icons.archive_rounded,
        color: AppColors.textMuted,
        onExecute: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const ArchiveScreen()),
        ),
      ),
      SearchAction(
        label: 'Open Settings',
        icon: Icons.settings_rounded,
        color: AppColors.info,
        onExecute: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      SearchAction(
        label: 'Inbox',
        icon: Icons.inbox_rounded,
        color: AppColors.warning,
        onExecute: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const InboxScreen()),
        ),
      ),
    ];
  }

  void _onSearchChanged(String query, List<ContentObject> allObjects) {
    final normalized = query.toLowerCase().trim();
    setState(() {
      var results = _searchService.search(
        allObjects,
        query,
        typeFilter: _selectedType,
      );

      if (_selectedType == 'social_post') {
        results = results.whereType<SocialPost>().where((post) {
          if (_socialPlatformFilter != null &&
              post.platform.name != _socialPlatformFilter) {
            return false;
          }
          if (_socialCreatorFilter != null &&
              post.authorHandle != _socialCreatorFilter &&
              post.authorName != _socialCreatorFilter) {
            return false;
          }
          return true;
        }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }

      _results = results;
      _actionResults = _getAllActions()
          .where((a) => a.label.toLowerCase().contains(normalized))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allObjectsAsync = ref.watch(allObjectsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (query) {
            allObjectsAsync.whenData(
              (objects) => _onSearchChanged(query, objects),
            );
          },
          decoration: const InputDecoration(
            hintText: 'Search...',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() => _results = []);
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedType == null,
                  onSelected: (val) {
                    setState(() => _selectedType = null);
                    allObjectsAsync.whenData(
                      (objects) =>
                          _onSearchChanged(_searchController.text, objects),
                    );
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _selectedType == null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _selectedType == null
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                ..._typeLabels.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: _selectedType == entry.key,
                      onSelected: (val) {
                        setState(() => _selectedType = val ? entry.key : null);
                        allObjectsAsync.whenData(
                          (objects) =>
                              _onSearchChanged(_searchController.text, objects),
                        );
                      },
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedType == entry.key
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedType == entry.key
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_selectedType == 'social_post')
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Platform: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...[
                    'X',
                    'LinkedIn',
                    'Threads',
                    'Instagram',
                    'YouTube',
                    'TikTok',
                  ].map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(p),
                        selected: _socialPlatformFilter == p.toLowerCase(),
                        onSelected: (val) {
                          setState(
                            () => _socialPlatformFilter = val
                                ? p.toLowerCase()
                                : null,
                          );
                          allObjectsAsync.whenData(
                            (objects) => _onSearchChanged(
                              _searchController.text,
                              objects,
                            ),
                          );
                        },
                        labelStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Creator: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('My Posts'),
                    selected: _socialCreatorFilter == 'me',
                    onSelected: (val) {
                      setState(() => _socialCreatorFilter = val ? 'me' : null);
                      allObjectsAsync.whenData(
                        (objects) =>
                            _onSearchChanged(_searchController.text, objects),
                      );
                    },
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          Expanded(
            child: (_results.isEmpty && _actionResults.isEmpty)
                ? (_searchController.text.isEmpty
                      ? _buildSearchHome()
                      : _buildEmptyState())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_searchController.text.isNotEmpty &&
                          _selectedType != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _typeLabels[_selectedType] ??
                                          _selectedType!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedType = null);
                                        final objects =
                                            ref
                                                .read(allObjectsProvider)
                                                .valueOrNull ??
                                            [];
                                        _onSearchChanged(
                                          _searchController.text,
                                          objects,
                                        );
                                      },
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      if (_actionResults.isNotEmpty) ...[
                        const Text(
                          'ACTIONS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._actionResults.map(
                          (a) => _buildActionTile(context, a),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_results.isNotEmpty) ...[
                        const Text(
                          'RESULTADOS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._results.map(
                          (obj) => _buildResultTile(context, obj),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, SearchAction action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(action.icon, size: 18, color: action.color),
        ),
        title: Text(
          action.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: AppColors.textMuted,
        ),
        onTap: () => action.onExecute(context),
      ),
    );
  }

  Widget _buildSearchHome() {
    final recentSearches = ref.watch(
      settingsProvider.select((s) => s.recentSearches),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Buscas Recentes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(settingsProvider.notifier).clearRecentSearches(),
                  child: const Text('Limpar', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...recentSearches.map((s) => _buildRecentItem(s)),
            const SizedBox(height: 32),
          ],
          const Text(
            'Explore por Tipo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildExploreGrid(),
        ],
      ),
    );
  }

  Widget _buildRecentItem(String text) {
    return ListTile(
      leading: const Icon(
        Icons.history_rounded,
        color: AppColors.textMuted,
        size: 20,
      ),
      title: Text(text, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(
        Icons.north_west_rounded,
        size: 16,
        color: AppColors.textMuted,
      ),
      onTap: () {
        _searchController.text = text;
        final allObjectsAsync = ref.read(allObjectsProvider);
        allObjectsAsync.whenData((objects) => _onSearchChanged(text, objects));
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildExploreGrid() {
    final types = [
      {
        'label': 'Projects',
        'icon': Icons.folder_copy_rounded,
        'color': AppColors.primary,
      },
      {
        'label': 'People',
        'icon': Icons.people_rounded,
        'color': AppColors.info,
      },
      {
        'label': 'Media',
        'icon': Icons.local_library_rounded,
        'color': AppColors.warning,
      },
      {
        'label': 'Habits',
        'icon': Icons.loop_rounded,
        'color': AppColors.habitGreen,
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: types
          .map(
            (t) => InkWell(
              onTap: () {
                _searchController.text = (t['label'] as String);
                final allObjectsAsync = ref.read(allObjectsProvider);
                allObjectsAsync.whenData(
                  (objects) =>
                      _onSearchChanged(_searchController.text, objects),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: AppTheme.cardDecoration(context),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      t['icon'] as IconData,
                      size: 20,
                      color: t['color'] as Color,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t['label'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildResultTile(BuildContext context, ContentObject obj) {
    final query = _searchController.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ObjectActionWrapper(
        object: obj,
        child: InkWell(
          onTap: () {
            if (query.isNotEmpty) {
              ref.read(settingsProvider.notifier).addRecentSearch(query);
            }
            context.push(
              '/detail/${Uri.encodeComponent(obj.id)}',
              extra: {'searchQuery': query, 'searchSnippet': obj.snippet},
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _typeColor(obj.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _typeIcon(obj.type),
                    size: 20,
                    color: _typeColor(obj.type),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obj.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (obj.snippet != null && obj.snippet!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            obj.snippet!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Text(
                        _getTypeLabel(obj).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline;
      case 'habit':
        return Icons.loop_rounded;
      case 'goal':
        return Icons.flag_rounded;
      case 'project':
        return Icons.folder_copy_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'resource':
        return Icons.local_library_rounded;
      case 'journal_entry':
        return Icons.auto_stories_rounded;
      case 'note':
        return Icons.sticky_note_2_rounded;
      case 'idea':
        return Icons.lightbulb_outline_rounded;
      default:
        return Icons.article_outlined;
    }
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
      case 'person':
        return 'Pessoa';
      default:
        return obj.type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'task':
        return AppColors.info;
      case 'habit':
        return AppColors.habitGreen;
      case 'goal':
        return AppColors.habitOrange;
      case 'project':
        return AppColors.primary;
      case 'idea':
        return AppColors.warning;
      case 'person':
        return AppColors.info;
      case 'resource':
        return AppColors.warning;
      case 'journal_entry':
        return AppColors.habitPurple;
      case 'note':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(color: AppColors.textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
