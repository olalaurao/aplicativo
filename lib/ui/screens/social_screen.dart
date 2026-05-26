// lib/ui/screens/social_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/shared_types.dart';
import '../../models/social_post.dart';
import '../../providers/vault_provider.dart';
import '../../services/oembed_service.dart';
import '../forms/create_organizer_form.dart';
import '../forms/create_social_post_form.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/organizer_picker_modal.dart';
import '../widgets/social_post_grid_card.dart';
import 'search_screen.dart';
import 'social_post_detail.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  SocialPlatform? _selectedPlatform;
  String _sortMode = 'saved_desc';
  bool _isGridMode = true;
  bool _showUnwatchedOnly = false;
  bool _isMultiSelectMode = false;
  String? _selectedOrganizerFilter;
  String? _selectedOrganizerLabel;
  final Set<String> _selectedIds = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _clipboardBannerShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboardUrl());
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(socialPostsProvider);
    final filtered = _filteredPosts(posts);
    final platforms = posts.map((post) => post.platform).toSet().toList()
      ..sort((a, b) => platformLabel(a).compareTo(platformLabel(b)));

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildCollectionsDrawer(posts),
      body: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey('social-scroll'),
          slivers: [
            SliverAppBar(
              title: Text(
                _isMultiSelectMode
                    ? '${_selectedIds.length} selecionados'
                    : 'Social',
              ),
              centerTitle: true,
              floating: true,
              pinned: true,
              leading: _isMultiSelectMode
                  ? TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Cancelar'),
                    )
                  : null,
              leadingWidth: _isMultiSelectMode ? 96 : null,
              actions: _isMultiSelectMode
                  ? [
                      IconButton(
                        tooltip: 'Adicionar a coleção',
                        icon: const Icon(Icons.collections_bookmark_outlined),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _addSelectedToCollection(posts),
                      ),
                      IconButton(
                        tooltip: 'Marcar como vistos',
                        icon: const Icon(Icons.visibility_rounded),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _markSelectedWatched(posts),
                      ),
                      IconButton(
                        tooltip: 'Deletar',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _deleteSelected(posts),
                      ),
                    ]
                  : [
                      IconButton(
                        tooltip: 'Coleções',
                        icon: const Icon(Icons.folder_outlined),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      ),
                      IconButton(
                        tooltip: 'Pesquisar',
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const SearchScreen(initialType: 'social_post'),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Filtros',
                        icon: const Icon(Icons.tune_rounded),
                        onPressed: _showSortSheet,
                      ),
                      IconButton(
                        tooltip: _isGridMode ? 'Ver lista' : 'Ver grade',
                        icon: Icon(
                          _isGridMode
                              ? Icons.view_list_rounded
                              : Icons.grid_view_rounded,
                        ),
                        onPressed: () =>
                            setState(() => _isGridMode = !_isGridMode),
                      ),
                      IconButton(
                        tooltip: 'Novo post',
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateSocialPostForm(),
                          ),
                        ),
                      ),
                    ],
            ),
            SliverToBoxAdapter(child: _buildPlatformChips(platforms)),
            if (_selectedOrganizerFilter != null)
              SliverToBoxAdapter(child: _buildOrganizerFilterChip()),
            if (posts.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else if (filtered.isEmpty)
              SliverFillRemaining(child: _buildFilteredEmptyState())
            else if (_isGridMode)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => SocialPostGridCard(
                      post: filtered[index],
                      isMultiSelectMode: _isMultiSelectMode,
                      isSelected: _selectedIds.contains(filtered[index].id),
                      onTap: () => _handlePostTap(filtered[index]),
                      onLongPress: () => _selectPost(filtered[index]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _SocialPostListTile(
                    post: filtered[index],
                    isMultiSelectMode: _isMultiSelectMode,
                    isSelected: _selectedIds.contains(filtered[index].id),
                    onTap: () => _handlePostTap(filtered[index]),
                    onLongPress: () => _selectPost(filtered[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<SocialPost> _filteredPosts(List<SocialPost> posts) {
    final filtered = posts.where((post) {
      if (_selectedPlatform != null && post.platform != _selectedPlatform) {
        return false;
      }
      if (_showUnwatchedOnly && post.watched) return false;
      if (_selectedOrganizerFilter == '_none' && post.organizers.isNotEmpty) {
        return false;
      }
      if (_selectedOrganizerFilter != null &&
          _selectedOrganizerFilter != '_none' &&
          !post.organizers.any(
            (organizer) => organizer.toWikiLink() == _selectedOrganizerFilter,
          )) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortMode) {
        'saved_asc' => a.createdAt.compareTo(b.createdAt),
        'posted_desc' => (b.postedAt ?? b.createdAt).compareTo(
          a.postedAt ?? a.createdAt,
        ),
        'unwatched' => _watchedRank(a).compareTo(_watchedRank(b)),
        _ => b.createdAt.compareTo(a.createdAt),
      };
    });
    return filtered;
  }

  int _watchedRank(SocialPost post) => post.watched ? 1 : 0;

  Widget _buildPlatformChips(List<SocialPlatform> platforms) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _chip(
            label: 'Todos',
            selected: _selectedPlatform == null,
            color: AppColors.primary,
            onTap: () => setState(() => _selectedPlatform = null),
          ),
          for (final platform in platforms)
            _chip(
              label: platformLabel(platform),
              selected: _selectedPlatform == platform,
              color: socialPlatformColor(platform),
              onTap: () => setState(() {
                _selectedPlatform = _selectedPlatform == platform
                    ? null
                    : platform;
              }),
            ),
          _chip(
            label: 'Não visto',
            selected: _showUnwatchedOnly,
            color: AppColors.info,
            onTap: () =>
                setState(() => _showUnwatchedOnly = !_showUnwatchedOnly),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: color.withValues(alpha: 0.15),
        backgroundColor: AppTheme.surfaceVariantColor(context),
        side: BorderSide(color: selected ? color : AppColors.divider),
        labelStyle: TextStyle(
          color: selected ? color : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.play_circle_outline_rounded,
      headline: 'Nenhum post salvo ainda',
      subtext:
          'Cole um link do TikTok, Instagram, Substack ou Pinterest para começar.',
      ctaLabel: 'Salvar primeiro post',
      onCta: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateSocialPostForm()),
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    final label = _selectedPlatform == null
        ? 'com esses filtros'
        : 'de ${platformLabel(_selectedPlatform!)}';
    return Center(
      child: Text(
        'Nenhum post $label',
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }

  void _showSortSheet() {
    var localSort = _sortMode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ordenar por',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _sortTile(
                    value: 'saved_desc',
                    groupValue: localSort,
                    label: 'Salvo (mais recente)',
                    onChanged: (value) =>
                        setSheetState(() => localSort = value),
                  ),
                  _sortTile(
                    value: 'saved_asc',
                    groupValue: localSort,
                    label: 'Salvo (mais antigo)',
                    onChanged: (value) =>
                        setSheetState(() => localSort = value),
                  ),
                  _sortTile(
                    value: 'posted_desc',
                    groupValue: localSort,
                    label: 'Data do post (mais recente)',
                    onChanged: (value) =>
                        setSheetState(() => localSort = value),
                  ),
                  _sortTile(
                    value: 'unwatched',
                    groupValue: localSort,
                    label: 'Não vistos primeiro',
                    onChanged: (value) =>
                        setSheetState(() => localSort = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            setState(() {
                              _sortMode = 'saved_desc';
                              _selectedPlatform = null;
                              _showUnwatchedOnly = false;
                              _selectedOrganizerFilter = null;
                              _selectedOrganizerLabel = null;
                            });
                          },
                          child: const Text('Limpar filtros'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            setState(() => _sortMode = localSort);
                          },
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sortTile({
    required String value,
    required String groupValue,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    final selected = value == groupValue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.primary : AppColors.textMuted,
      ),
      title: Text(label),
      onTap: () => onChanged(value),
    );
  }

  void _handlePostTap(SocialPost post) {
    if (_isMultiSelectMode) {
      _toggleSelected(post);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SocialPostDetail(post: post)),
    );
  }

  void _selectPost(SocialPost post) {
    setState(() {
      _isMultiSelectMode = true;
      _selectedIds.add(post.id);
    });
  }

  void _toggleSelected(SocialPost post) {
    setState(() {
      if (_selectedIds.contains(post.id)) {
        _selectedIds.remove(post.id);
      } else {
        _selectedIds.add(post.id);
      }
      if (_selectedIds.isEmpty) _isMultiSelectMode = false;
    });
  }

  void _clearSelection() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _addSelectedToCollection(List<SocialPost> posts) async {
    final currentSelection = _selectedPosts(posts);
    final selectedOrganizers = await showOrganizerPickerModal(
      context,
      ref,
      const [],
    );
    if (!mounted || selectedOrganizers == null || selectedOrganizers.isEmpty) {
      return;
    }

    for (final post in currentSelection) {
      final merged = <String, OrganizerReference>{
        for (final organizer in post.organizers)
          organizer.toWikiLink(): organizer,
        for (final organizer in selectedOrganizers)
          organizer.toWikiLink(): organizer,
      }.values.toList();
      await ref
          .read(socialPostsProvider.notifier)
          .updatePost(post.copyWith(organizers: merged));
    }
    _clearSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${currentSelection.length} posts adicionados a ${selectedOrganizers.first.title}',
          ),
        ),
      );
    }
  }

  Future<void> _markSelectedWatched(List<SocialPost> posts) async {
    final selected = _selectedPosts(posts);
    for (final post in selected.where((post) => !post.watched)) {
      await ref.read(socialPostsProvider.notifier).toggleWatched(post);
    }
    _clearSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.length} posts marcados como vistos'),
        ),
      );
    }
  }

  Future<void> _deleteSelected(List<SocialPost> posts) async {
    final selected = _selectedPosts(posts);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deletar ${selected.length} posts?'),
        content: const Text('Os arquivos serão movidos para a lixeira.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final post in selected) {
      await ref.read(socialPostsProvider.notifier).deletePost(post);
    }
    _clearSelection();
  }

  List<SocialPost> _selectedPosts(List<SocialPost> posts) {
    return posts.where((post) => _selectedIds.contains(post.id)).toList();
  }

  Widget _buildOrganizerFilterChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          label: Text(_selectedOrganizerLabel ?? 'Coleção'),
          avatar: const Icon(Icons.folder_outlined, size: 16),
          onDeleted: () => setState(() {
            _selectedOrganizerFilter = null;
            _selectedOrganizerLabel = null;
          }),
        ),
      ),
    );
  }

  Widget _buildCollectionsDrawer(List<SocialPost> posts) {
    final counts = <String, ({OrganizerReference organizer, int count})>{};
    var uncategorized = 0;
    for (final post in posts) {
      if (post.organizers.isEmpty) {
        uncategorized++;
        continue;
      }
      for (final organizer in post.organizers) {
        final key = organizer.toWikiLink();
        final current = counts[key];
        counts[key] = (organizer: organizer, count: (current?.count ?? 0) + 1);
      }
    }
    final entries = counts.entries.toList()
      ..sort(
        (a, b) => a.value.organizer.title.compareTo(b.value.organizer.title),
      );

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Coleções',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmarks_outlined),
              title: const Text('Todos os posts'),
              trailing: Text('${posts.length}'),
              selected: _selectedOrganizerFilter == null,
              onTap: () => _selectOrganizerFilter(null, null),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Sem coleção'),
              trailing: Text('$uncategorized'),
              selected: _selectedOrganizerFilter == '_none',
              onTap: () => _selectOrganizerFilter('_none', 'Sem coleção'),
            ),
            for (final entry in entries)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(
                  entry.value.organizer.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('${entry.value.count}'),
                selected: _selectedOrganizerFilter == entry.key,
                onTap: () => _selectOrganizerFilter(
                  entry.key,
                  entry.value.organizer.title,
                ),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Nova coleção'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateOrganizerForm(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectOrganizerFilter(String? key, String? label) {
    Navigator.pop(context);
    setState(() {
      _selectedOrganizerFilter = key;
      _selectedOrganizerLabel = label;
    });
  }

  Future<void> _checkClipboardUrl() async {
    if (_clipboardBannerShown || !mounted) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || !OEmbedService.isSupportedUrl(text)) return;
    _clipboardBannerShown = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text('Link social encontrado na área de transferência.'),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('Ignorar'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateSocialPostForm(initialUrl: text),
                ),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class _SocialPostListTile extends StatelessWidget {
  final SocialPost post;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SocialPostListTile({
    required this.post,
    required this.isMultiSelectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: AppTheme.cardDecoration(context),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: SocialPostThumbnail(post: post),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SocialPlatformBadge(platform: post.platform, fontSize: 9),
                      if (!post.watched) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.info,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.caption?.trim().isNotEmpty == true
                        ? post.caption!.trim()
                        : post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _OrganizerChips(post: post)),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(post.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isMultiSelectMode)
              Checkbox(value: isSelected, onChanged: (_) => onTap()),
          ],
        ),
      ),
    );
  }

  String get _handle {
    final value = post.authorHandle ?? post.authorName ?? 'Post';
    return value.startsWith('@') ? value : '@$value';
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return 'há ${diff.inDays} dias';
    if (diff.inHours >= 1) return 'há ${diff.inHours} h';
    if (diff.inMinutes >= 1) return 'há ${diff.inMinutes} min';
    return 'agora';
  }
}

class _OrganizerChips extends StatelessWidget {
  final SocialPost post;

  const _OrganizerChips({required this.post});

  @override
  Widget build(BuildContext context) {
    final visible = post.organizers.take(3).toList();
    final extra = post.organizers.length - visible.length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final organizer in visible)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: Text(
                  organizer.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 10),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          if (extra > 0)
            Text(
              '+$extra',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
