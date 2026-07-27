import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/idea_model.dart';
import '../../models/saved_filter.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme.dart';
import '../forms/create_idea_form.dart';
import '../utils/filter_sort_utils.dart';
import '../widgets/filterable_list_header.dart';
import '../widgets/overdue_section.dart';

class IdeasScreen extends ConsumerStatefulWidget {
  const IdeasScreen({super.key});

  @override
  ConsumerState<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends ConsumerState<IdeasScreen> {
  String _searchQuery = '';
  SavedFilter? _activeFilter;
  List<SavedFilter> _savedFilters = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(
        () => _savedFilters = ref.read(settingsProvider).filtersFor('idea'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawIdeas = ref.watch(ideasProvider);
    final filtered = FilterSortUtils.applyFilterAndSort(
      rawIdeas,
      _searchQuery,
      _activeFilter,
    ).cast<IdeaDefinition>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        key: const PageStorageKey('ideas-scroll'),
        slivers: [
          SliverAppBar(
            title: const Text('Ideias'),
            floating: true,
            pinned: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: FilterableListHeader(
                targetType: 'idea',
                searchQuery: _searchQuery,
                activeFilter: _activeFilter,
                savedFilters: _savedFilters,
                availableProperties: IdeaFilterProperties.all,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onFilterChanged: (f) => setState(() {
                  _activeFilter = f;
                  _savedFilters = ref.read(settingsProvider).filtersFor('idea');
                }),
                onAddPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateIdeaForm()),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: const OverdueSection(filterTypes: ['idea']),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 64,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma ideia capturada',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final idea = filtered[index];
                    return _buildIdeaTile(context, idea);
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdeaTile(BuildContext context, IdeaDefinition idea) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        title: Text(
          idea.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: idea.linkedTaskIds.isNotEmpty
            ? Text(
                '${idea.linkedTaskIds.length} tasks vinculadas',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              )
            : null,
        trailing: idea.isConverted
            ? const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.success,
                size: 20,
              )
            : const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateIdeaForm(existingIdea: idea),
            ),
          );
        },
        onLongPress: () => _showConvertMenu(context, idea),
      ),
    );
  }

  void _showConvertMenu(BuildContext context, IdeaDefinition idea) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Converter para...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentColor(context)),
              title: const Text('Tarefa'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversão requer contexto com ref')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.folder_outlined, color: AppTheme.accentColor(context)),
              title: const Text('Projeto'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversão requer contexto com ref')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.track_changes_rounded, color: AppTheme.accentColor(context)),
              title: const Text('Objetivo'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversão requer contexto com ref')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.article_outlined, color: AppTheme.accentColor(context)),
              title: const Text('Nota'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversão requer contexto com ref')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
