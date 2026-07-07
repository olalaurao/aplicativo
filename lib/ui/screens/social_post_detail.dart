// lib/ui/screens/social_post_detail.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/content_object.dart';
import '../../models/social_post.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../forms/create_social_post_form.dart';
import '../forms/create_resource_form.dart';
import '../theme.dart';
import '../widgets/organizer_picker_modal.dart';
import '../widgets/organizer_selector_field.dart';
import '../widgets/social_embed_view.dart';
import '../widgets/social_post_grid_card.dart';
import 'universal_detail_view.dart';
import '../widgets/linked_objects_section.dart';
import '../widgets/book_search_sheet.dart';
import '../utils/social_ref_utils.dart';

class SocialPostDetail extends ConsumerStatefulWidget {
  final SocialPost post;

  const SocialPostDetail({super.key, required this.post});

  @override
  ConsumerState<SocialPostDetail> createState() => _SocialPostDetailState();
}

class _SocialPostDetailState extends ConsumerState<SocialPostDetail> {
  late final TextEditingController _noteController;
  late final TextEditingController _tagController;
  Timer? _noteDebounce;
  Timer? _savedIndicatorTimer;
  bool _showFullCaption = false;
  bool _showSavedIndicator = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.post.personalNote ?? '',
    );
    _tagController = TextEditingController();
  }

  @override
  void dispose() {
    _noteDebounce?.cancel();
    _savedIndicatorTimer?.cancel();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = _currentPost;
    final backlinks = ref.watch(backlinksProvider(post.id));

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                tooltip: 'Voltar',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      _titleFor(post),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SocialPlatformBadge(platform: post.platform),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Save books from post',
                  icon: const Icon(Icons.menu_book_outlined),
                  onPressed: () => _showBookSearchSheet(post),
                ),
                IconButton(
                  tooltip: 'Abrir original',
                  icon: const Icon(Icons.open_in_new_rounded),
                  onPressed: () => _openOriginal(post),
                ),
                IconButton(
                  tooltip: 'Mais ações',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () => _showActionSheet(post),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (post.videoUrl?.isNotEmpty == true ||
                      post.embedUrl != null ||
                      post.platform == SocialPlatform.pinterest ||
                      (post.platform == SocialPlatform.tiktok &&
                          post.mediaType == SocialMediaType.video) ||
                      post.platform == SocialPlatform.substack)
                    SocialEmbedView(post: post)
                  else
                    _buildEmbedPlaceholder(post),
                  if (post.caption?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _buildCaptionSection(post),
                  ],
                  const SizedBox(height: 12),
                  _buildNoteSection(post),
                  const SizedBox(height: 12),
                  _buildOrganizerSection(post),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  _buildLinkedObjectsSection(post),
                  _buildTagsSection(post),
                  backlinks.when(
                    data: (items) => items.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildBacklinksSection(items),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  _buildMetadataSection(post),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SocialPost get _currentPost {
    final posts = ref.watch(socialPostsProvider);
    return posts.firstWhere(
      (candidate) => candidate.id == widget.post.id,
      orElse: () => widget.post,
    );
  }

  void _showBookSearchSheet(SocialPost post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BookSearchSheet(linkedPostId: post.id),
    );
  }

  Widget _buildEmbedPlaceholder(SocialPost post) {
    final color = socialPlatformColor(post.platform);
    final imageSource = socialPostImageSource(post);
    final fallback = Center(
      child: Icon(socialPlatformIcon(post.platform), size: 48, color: color),
    );
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: imageSource == null
            ? () => _openOriginal(post)
            : () => _openImagePreview(imageSource),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SocialPostImage(
              source: imageSource,
              fallback: fallback,
              fit: BoxFit.cover,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => _openOriginal(post),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir em navegador interno'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionSection(SocialPost post) {
    final paragraphs = post.caption!.trim().split(RegExp(r'\n\s*\n'));
    final text = _showFullCaption || paragraphs.length <= 5
        ? post.caption!.trim()
        : paragraphs.take(5).join('\n\n');
    return _section(
      title: 'Caption',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            text,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          if (paragraphs.length > 5 && !_showFullCaption)
            TextButton(
              onPressed: () => setState(() => _showFullCaption = true),
              child: const Text('Ver tudo'),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(SocialPost post) {
    if (_noteController.text != (post.personalNote ?? '') &&
        !_noteController.selection.isValid) {
      _noteController.text = post.personalNote ?? '';
    }
    return _section(
      title: 'Nota pessoal',
      trailing: AnimatedOpacity(
        opacity: _showSavedIndicator ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: const Icon(Icons.circle, size: 8, color: AppColors.success),
      ),
      child: TextField(
        controller: _noteController,
        minLines: 2,
        maxLines: null,
        onChanged: (value) => _scheduleNoteSave(post, value),
        decoration: const InputDecoration(
          hintText: 'Adicione uma nota sobre esse post...',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildOrganizerSection(SocialPost post) {
    return _section(
      title: 'Coleções',
      child: OrganizerSelectorField(
        label: 'Coleções',
        selectedOrganizers: post.organizers,
        onChanged: (value) => ref
            .read(socialPostsProvider.notifier)
            .updatePost(post.copyWith(organizers: value)),
      ),
    );
  }

  Widget _buildLinkedObjectsSection(SocialPost post) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinkedObjectsSection(
            owner: post,
            links: getSocialRefs(post),
            onAdd: (selected) => addSocialRef(post, selected, ref),
            onRemove: (slug) => removeSocialRef(post, slug, ref),
            addButtonLabel: 'Vincular',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _quickCreateResource(post),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Criar Livro/Recurso e Vincular'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickCreateResource(SocialPost post) async {
    final newResource = await Navigator.push<ContentObject>(
      context,
      MaterialPageRoute(builder: (_) => const CreateResourceForm()),
    );
    if (newResource != null) {
      await addSocialRef(post, newResource, ref);
    }
  }

  Widget _buildTagsSection(SocialPost post) {
    return _section(
      title: 'Tags',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in post.tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () {
                    final tags = List<String>.from(post.tags)..remove(tag);
                    ref
                        .read(socialPostsProvider.notifier)
                        .updatePost(post.copyWith(tags: tags));
                  },
                ),
            ],
          ),
          TextField(
            controller: _tagController,
            onSubmitted: (_) => _addTag(post),
            decoration: const InputDecoration(
              hintText: 'Adicionar tag',
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBacklinksSection(List<ContentObject> items) {
    return _section(
      title: 'Citado em',
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_rounded),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(item.displayType),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversalDetailView(object: item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(SocialPost post) {
    final formatter = DateFormat('dd/MM/yyyy');
    return _section(
      title: 'Metadata',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metadataLine('Salvo em', formatter.format(post.createdAt)),
          if (post.postedAt != null)
            _metadataLine('Postado em', formatter.format(post.postedAt!)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _openOriginal(post),
            child: Text(
              post.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.info,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metadataLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  void _scheduleNoteSave(SocialPost post, String value) {
    _noteDebounce?.cancel();
    _noteDebounce = Timer(const Duration(milliseconds: 800), () async {
      await ref
          .read(socialPostsProvider.notifier)
          .updatePost(
            post.copyWith(personalNote: value.trim().isEmpty ? null : value),
          );
      if (!mounted) return;
      setState(() => _showSavedIndicator = true);
      _savedIndicatorTimer?.cancel();
      _savedIndicatorTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showSavedIndicator = false);
      });
    });
  }

  void _addTag(SocialPost post) {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || post.tags.contains(tag)) return;
    final tags = [...post.tags, tag];
    _tagController.clear();
    ref
        .read(socialPostsProvider.notifier)
        .updatePost(post.copyWith(tags: tags));
  }

  Future<void> _showActionSheet(SocialPost post) async {
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
              _actionTile(context,
                icon: Icons.edit_outlined,
                label: 'Editar post',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateSocialPostForm(existingPost: post),
                    ),
                  );
                },
              ),
              _actionTile(context,
                icon: Icons.folder_outlined,
                label: 'Adicionar a coleção',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _addToCollection(post);
                },
              ),
              _actionTile(context,
                icon: post.watched
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                label: post.watched
                    ? 'Marcar como não visto'
                    : 'Marcar como visto',
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref.read(socialPostsProvider.notifier).toggleWatched(post);
                },
              ),
              _actionTile(context,
                icon: Icons.open_in_new_rounded,
                label: 'Abrir no Obsidian',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openInObsidian(post);
                },
              ),
              _actionTile(context,
                icon: Icons.copy_rounded,
                label: 'Copiar URL',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: post.url));
                },
              ),
              _actionTile(context,
                icon: Icons.inventory_2_outlined,
                label: 'Arquivar',
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref
                      .read(socialPostsProvider.notifier)
                      .updatePost(post.copyWith(archived: true));
                },
              ),
              _actionTile(context,
                icon: Icons.delete_outline_rounded,
                label: 'Deletar post',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(post);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? AppTheme.accentColor(context);

    return ListTile(
      leading: Icon(icon, color: effectiveColor),
      title: Text(
        label,
        style: TextStyle(color: color == AppColors.error ? effectiveColor : null),
      ),
      onTap: onTap,
    );
  }

  Future<void> _addToCollection(SocialPost post) async {
    final selected = await showOrganizerPickerModal(
      context,
      ref,
      post.organizers,
    );
    if (!mounted || selected == null) return;
    await ref
        .read(socialPostsProvider.notifier)
        .updatePost(post.copyWith(organizers: selected));
  }

  Future<void> _confirmDelete(SocialPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar post?'),
        content: const Text('O arquivo será movido para a lixeira.'),
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
    await ref.read(socialPostsProvider.notifier).deletePost(post);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openOriginal(SocialPost post) async {
    final uri = Uri.tryParse(post.url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link.')),
        );
      }
    }
  }

  void _openImagePreview(String imageSource) {
    const fallback = Icon(
      Icons.broken_image_rounded,
      color: Colors.white,
      size: 56,
    );
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(
            child: SocialPostImage(
              source: imageSource,
              fit: BoxFit.contain,
              fallback: fallback,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInObsidian(SocialPost post) async {
    final settings = ref.read(settingsProvider);
    final file = post.obsidianPath.isNotEmpty
        ? post.obsidianPath
        : 'social/${post.socialSlug}.md';
    final uri = Uri.parse(
      'obsidian://open?vault=${Uri.encodeComponent(settings.vaultName)}&file=${Uri.encodeComponent(file)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _titleFor(SocialPost post) {
    final value = post.authorHandle ?? post.authorName;
    if (value == null || value.isEmpty) return 'Post salvo';
    return value.startsWith('@') ? value : '@$value';
  }
}
