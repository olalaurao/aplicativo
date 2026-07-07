// lib/ui/screens/social_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/shared_types.dart';
import '../../models/social_post.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/oembed_service.dart';
import '../forms/create_organizer_form.dart';
import '../forms/create_social_post_form.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/organizer_picker_modal.dart';
import '../widgets/social_embed_view.dart';
import '../widgets/social_post_grid_card.dart';
import '../widgets/universal_search_picker.dart';
import 'search_screen.dart';
import 'social_post_detail.dart';

enum SocialSortMode { savedDesc, savedAsc, postedDesc, unwatchedFirst }

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  SocialPlatform? _selectedPlatform;
  SocialSortMode _sortMode = SocialSortMode.savedDesc;
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
    final socialViewMode = ref.watch(
      settingsProvider.select((settings) => settings.socialViewMode),
    );
    final isGridMode = socialViewMode != 'timeline';
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
                        tooltip: 'Adicionar a label',
                        icon: const Icon(Icons.label_outlined),
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
                        tooltip: 'Labels',
                        icon: const Icon(Icons.label_outlined),
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
                        tooltip: isGridMode ? 'Ver timeline' : 'Ver grade',
                        icon: Icon(
                          isGridMode
                              ? Icons.view_agenda_rounded
                              : Icons.grid_view_rounded,
                        ),
                        onPressed: () {
                          ref
                              .read(settingsProvider.notifier)
                              .updateSocialViewMode(
                                isGridMode ? 'timeline' : 'grid',
                              );
                        },
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
            else if (isGridMode)
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
                  itemBuilder: (context, index) => _SocialTimelineCard(
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
        SocialSortMode.savedAsc => a.createdAt.compareTo(b.createdAt),
        SocialSortMode.postedDesc => (b.postedAt ?? b.createdAt).compareTo(
          a.postedAt ?? a.createdAt,
        ),
        SocialSortMode.unwatchedFirst => _watchedRank(a).compareTo(_watchedRank(b)),
        SocialSortMode.savedDesc => b.createdAt.compareTo(a.createdAt),
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
            color: AppTheme.accentColor(context),
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
                    value: SocialSortMode.savedDesc,
                    groupValue: localSort,
                    label: 'Salvo (mais recente)',
                    onChanged: (value) =>
                        setSheetState(() => localSort = value),
                  ),
                  _sortTile(
                    value: SocialSortMode.savedAsc,
                    groupValue: localSort,
                    label: 'Salvo (mais antigo)',
                    onChanged: (value) =>
                        setSheetState(() => localSort = value),
                  ),
                  _sortTile(
                    value: SocialSortMode.postedDesc,
                    groupValue: localSort,
                    label: 'Data do post (mais recente)',
                    onChanged: (value) =>
                        setSheetState(() => localSort = value),
                  ),
                  _sortTile(
                    value: SocialSortMode.unwatchedFirst,
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
                              _sortMode = SocialSortMode.savedDesc;
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
    required SocialSortMode value,
    required SocialSortMode groupValue,
    required String label,
    required ValueChanged<SocialSortMode> onChanged,
  }) {
    final selected = value == groupValue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppTheme.accentColor(context) : AppColors.textMuted,
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
      initialFilter: 'label',
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
          label: Text(_selectedOrganizerLabel ?? 'Label'),
          avatar: const Icon(Icons.label_outlined, size: 16),
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
      final labels = post.organizers.where((o) => o.type == 'label').toList();
      if (labels.isEmpty) {
        uncategorized++;
        continue;
      }
      for (final organizer in labels) {
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
                'Labels',
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
              leading: const Icon(Icons.label_off_outlined),
              title: const Text('Sem label'),
              trailing: Text('$uncategorized'),
              selected: _selectedOrganizerFilter == '_none',
              onTap: () => _selectOrganizerFilter('_none', 'Sem label'),
            ),
            for (final entry in entries)
              ListTile(
                leading: const Icon(Icons.label_outlined),
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
              title: const Text('Novo label'),
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

class _SocialTimelineCard extends ConsumerStatefulWidget {
  final SocialPost post;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SocialTimelineCard({
    required this.post,
    required this.isMultiSelectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  ConsumerState<_SocialTimelineCard> createState() =>
      _SocialTimelineCardState();
}

class _SocialTimelineCardState extends ConsumerState<_SocialTimelineCard> {
  late final TextEditingController _noteController;
  late final TextEditingController _tagController;
  Timer? _noteDebounce;
  ScrollPosition? _scrollPosition;
  bool _captionExpanded = false;
  bool _noteExpanded = false;
  bool _tagsExpanded = false;
  bool _wasMostlyVisible = false;
  bool _autoWatched = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.post.personalNote ?? '',
    );
    _tagController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _SocialTimelineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.personalNote != widget.post.personalNote &&
        !_noteController.selection.isValid) {
      _noteController.text = widget.post.personalNote ?? '';
    }
    if (oldWidget.post.id != widget.post.id) {
      _wasMostlyVisible = false;
      _autoWatched = widget.post.watched;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition == nextPosition) return;
    _scrollPosition?.removeListener(_checkVisibility);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_checkVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void dispose() {
    _noteDebounce?.cancel();
    _scrollPosition?.removeListener(_checkVisibility);
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: AppTheme.cardDecoration(context),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              onTap: widget.onTap,
              leading: CircleAvatar(
                backgroundColor: socialPlatformColor(
                  post.platform,
                ).withValues(alpha: 0.14),
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: socialPlatformColor(post.platform),
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      _handle(post),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (post.links.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.link_rounded, size: 14, color: AppColors.textMuted),
                  ],
                ],
              ),
              subtitle: Text(
                '${platformLabel(post.platform)} · ${_relativeTime(post.createdAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: widget.isMultiSelectMode
                  ? Checkbox(
                      value: widget.isSelected,
                      onChanged: (_) => widget.onTap(),
                    )
                  : IconButton(
                      tooltip: 'Abrir detalhes',
                      icon: const Icon(Icons.more_horiz_rounded),
                      onPressed: widget.onTap,
                    ),
            ),
            if (post.videoUrl?.isNotEmpty == true ||
                post.embedUrl?.isNotEmpty == true ||
                post.platform == SocialPlatform.pinterest ||
                (post.platform == SocialPlatform.tiktok &&
                    post.mediaType == SocialMediaType.video))
              SocialEmbedView(post: post)
            else
              GestureDetector(
                onTap: widget.onTap,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SocialPostThumbnail(post: post, iconSize: 56),
                ),
              ),
            if (post.caption?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.caption!.trim(),
                      maxLines: _captionExpanded ? null : 2,
                      overflow: _captionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _captionExpanded = !_captionExpanded),
                      child: Text(_captionExpanded ? 'ver menos' : 'ver mais'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Coleção',
                    icon: const Icon(Icons.folder_outlined),
                    onPressed: _pickOrganizers,
                  ),
                  IconButton(
                    tooltip: 'Nota',
                    icon: const Icon(Icons.note_alt_outlined),
                    onPressed: () =>
                        setState(() => _noteExpanded = !_noteExpanded),
                  ),
                  IconButton(
                    tooltip: 'Tags',
                    icon: const Icon(Icons.local_offer_outlined),
                    onPressed: () =>
                        setState(() => _tagsExpanded = !_tagsExpanded),
                  ),
                  IconButton(
                    tooltip: 'Associar a objeto',
                    icon: const Icon(Icons.link_rounded),
                    onPressed: _associateObject,
                  ),
                  const Spacer(),
                  if (!post.watched)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(socialPostsProvider.notifier)
                          .toggleWatched(post),
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('Visto'),
                    ),
                ],
              ),
            ),
            if (_noteExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: _scheduleNoteSave,
                  decoration: const InputDecoration(
                    hintText: 'Nota pessoal',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            if (_tagsExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final tag in post.tags)
                          InputChip(
                            label: Text(tag),
                            onDeleted: () => _removeTag(tag),
                          ),
                      ],
                    ),
                    TextField(
                      controller: _tagController,
                      onSubmitted: (_) => _addTag(),
                      decoration: const InputDecoration(
                        hintText: 'Adicionar tag',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOrganizers() async {
    final selected = await showOrganizerPickerModal(
      context,
      ref,
      widget.post.organizers,
    );
    if (selected == null || !mounted) return;
    await ref
        .read(socialPostsProvider.notifier)
        .updatePost(widget.post.copyWith(organizers: selected));
  }

  Future<void> _associateObject() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => UniversalSearchPickerSheet(
        title: 'Associar post a...',
        showClear: false,
        onSelected: (object) async {
          Navigator.pop(sheetContext);
          final refLink = _objectWikiLink(object);
          final refs = <String>{...widget.post.links, refLink}.toList();
          await ref
              .read(socialPostsProvider.notifier)
              .updatePost(widget.post.copyWith(links: refs));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Associado a ${object.title}')),
          );
        },
      ),
    );
  }

  String _objectWikiLink(dynamic object) {
    final target = object.obsidianFileName?.toString().trim() ?? '';
    final slug = object.slug?.toString().trim() ?? '';
    final chosen = target.isNotEmpty ? target : slug;
    if (chosen.isNotEmpty) {
      return '[[$chosen]]';
    }
    return '[[${slug.isNotEmpty ? slug : object.id}]]';
  }

  void _checkVisibility() {
    if (!mounted || widget.post.watched || _autoWatched) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + renderObject.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final visibleTop = topLeft.dy.clamp(0.0, viewportHeight);
    final visibleBottom = bottom.clamp(0.0, viewportHeight);
    final visibleHeight = (visibleBottom - visibleTop).clamp(
      0.0,
      renderObject.size.height,
    );
    final visibleFraction = renderObject.size.height == 0
        ? 0.0
        : visibleHeight / renderObject.size.height;

    if (visibleFraction >= 0.8) {
      _wasMostlyVisible = true;
      return;
    }

    if (_wasMostlyVisible && visibleFraction <= 0.2) {
      _autoWatched = true;
      ref
          .read(socialPostsProvider.notifier)
          .updatePost(widget.post.copyWith(watched: true));
    }
  }

  void _scheduleNoteSave(String value) {
    _noteDebounce?.cancel();
    _noteDebounce = Timer(const Duration(milliseconds: 800), () {
      ref
          .read(socialPostsProvider.notifier)
          .updatePost(
            widget.post.copyWith(
              personalNote: value.trim().isEmpty ? null : value,
            ),
          );
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || widget.post.tags.contains(tag)) return;
    _tagController.clear();
    ref
        .read(socialPostsProvider.notifier)
        .updatePost(widget.post.copyWith(tags: [...widget.post.tags, tag]));
  }

  void _removeTag(String tag) {
    final tags = List<String>.from(widget.post.tags)..remove(tag);
    ref
        .read(socialPostsProvider.notifier)
        .updatePost(widget.post.copyWith(tags: tags));
  }

  String _handle(SocialPost post) {
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
