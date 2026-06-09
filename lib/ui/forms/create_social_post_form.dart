// lib/ui/forms/create_social_post_form.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/shared_types.dart';
import '../../models/social_post.dart';
import '../../models/content_object.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/oembed_service.dart';
import '../theme.dart';
import '../widgets/organizer_selector_field.dart';
import '../widgets/social_post_grid_card.dart';
import '../widgets/universal_search_picker.dart';

class CreateSocialPostForm extends ConsumerStatefulWidget {
  final String? initialUrl;
  final SocialPost? existingPost;

  const CreateSocialPostForm({super.key, this.initialUrl, this.existingPost});

  @override
  ConsumerState<CreateSocialPostForm> createState() =>
      _CreateSocialPostFormState();
}

class _CreateSocialPostFormState extends ConsumerState<CreateSocialPostForm> {
  final OEmbedService _oembedService = OEmbedService();
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  late final TextEditingController _captionController;
  late final TextEditingController _noteController;
  late final TextEditingController _tagController;

  SocialPost? _draft;
  List<OrganizerReference> _organizers = [];
  final List<String> _socialRefs = [];
  final List<String> _tags = [];
  bool _isFetching = false;
  bool _urlLocked = false;
  bool _captionExpanded = false;
  String? _errorText;
  Timer? _autoFetchDebounce;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPost;
    _urlController = TextEditingController(
      text: existing?.url ?? widget.initialUrl ?? '',
    );
    _titleController = TextEditingController(text: existing?.title ?? '');
    _captionController = TextEditingController(text: existing?.caption ?? '');
    _noteController = TextEditingController(text: existing?.personalNote ?? '');
    _tagController = TextEditingController();
    _draft = existing;
    _urlLocked = existing != null;
    _organizers = List.of(existing?.organizers ?? []);
    _socialRefs.addAll(existing?.socialRefs ?? []);
    _tags.addAll(existing?.tags ?? []);

    final initial = widget.initialUrl?.trim();
    if (existing == null && initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMetadata());
    }
  }

  @override
  void dispose() {
    _autoFetchDebounce?.cancel();
    _urlController.dispose();
    _titleController.dispose();
    _captionController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _urlController.text.trim().isNotEmpty && !_isFetching;

    final isDirty = _urlController.text.trim().isNotEmpty || _noteController.text.trim().isNotEmpty;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text('Você possui alterações não salvas. Deseja sair mesmo assim?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if ((discard ?? false) && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child:  Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingPost == null ? 'Novo post social' : 'Editar post',
        ),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: const Text('Salvar'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUrlSection(),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _draft == null && _errorText == null
                    ? const SizedBox.shrink()
                    : _buildPreviewSection(),
              ),
              const SizedBox(height: 16),
              _buildNoteSection(),
              const SizedBox(height: 16),
              _buildOrganizerSection(),
              const SizedBox(height: 16),
              _buildLinkedObjectsSection(),
              const SizedBox(height: 16),
              _buildTagsSection(),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildUrlSection() {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'URL',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  readOnly: _urlLocked,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _fetchMetadata(),
                  onChanged: _onUrlChanged,
                  decoration: InputDecoration(
                    hintText: 'Cole o link aqui...',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: _urlLocked
                        ? const Icon(Icons.lock_outline_rounded, size: 18)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isFetching ? null : _fetchMetadata,
                child: _isFetching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Buscar'),
              ),
            ],
          ),
          if (_urlLocked)
            TextButton(onPressed: _unlockUrl, child: const Text('Mudar URL')),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    final draft = _draft ?? _fallbackDraft();
    return Container(
      key: ValueKey(draft.url),
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlatformBadge(platform: draft.platform),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(post: draft),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Título',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (draft.authorHandle?.isNotEmpty == true)
                      Text(
                        '@${draft.authorHandle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.info,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (draft.authorName?.isNotEmpty == true)
                      Text(
                        draft.authorName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            minLines: 1,
            maxLines: _captionExpanded ? null : 3,
            onTap: () => setState(() => _captionExpanded = true),
            decoration: const InputDecoration(
              hintText: 'Legenda do post',
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nota pessoal',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'O que esse post significa pra você?',
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizerSection() {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: OrganizerSelectorField(
        label: 'Coleções',
        selectedOrganizers: _organizers,
        onChanged: (value) => setState(() => _organizers = value),
      ),
    );
  }

  Widget _buildLinkedObjectsSection() {
    final objects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final linked = _resolveRefs(objects, _socialRefs);
    final grouped = <String, List<ContentObject>>{};
    for (final object in linked) {
      grouped.putIfAbsent(object.displayType, () => []).add(object);
    }

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Objetos vinculados',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _pickLinkedObject,
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Vincular'),
              ),
            ],
          ),
          if (linked.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Nenhum objeto vinculado',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            ...grouped.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((object) {
                        final refLink = _objectWikiLink(object);
                        return InputChip(
                          label: Text(
                            object.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () => setState(
                            () => _socialRefs.removeWhere(
                              (ref) => _sameRef(ref, refLink, object),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tags',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                ),
            ],
          ),
          TextField(
            controller: _tagController,
            textInputAction: TextInputAction.done,
            onChanged: _onTagChanged,
            onSubmitted: (_) => _commitTag(),
            decoration: const InputDecoration(
              hintText: 'Digite uma tag e pressione vírgula ou enter',
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  void _onUrlChanged(String value) {
    setState(() => _errorText = null);
    _autoFetchDebounce?.cancel();
    if (!OEmbedService.isSupportedUrl(value)) return;
    _autoFetchDebounce = Timer(
      const Duration(milliseconds: 500),
      _fetchMetadata,
    );
  }

  Future<void> _fetchMetadata() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _isFetching) return;

    setState(() {
      _isFetching = true;
      _errorText = null;
    });

    try {
      final settings = ref.read(settingsProvider);
      final post = await _oembedService.fetchMetadata(
        url,
        tiktokResolverEndpoint: settings.tiktokResolverEndpoint,
        tiktokResolverApiKey: settings.tiktokResolverApiKey,
      );
      if (!mounted) return;
      setState(() {
        _draft = post;
        _urlLocked = true;
        _titleController.text = post.title;
        _captionController.text = post.caption ?? '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _draft = _fallbackDraft();
        _titleController.text = _draft!.title;
        _errorText = 'Não conseguimos buscar esse link. Preencha manualmente.';
      });
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _unlockUrl() {
    setState(() {
      _urlLocked = false;
      _draft = null;
      _errorText = null;
    });
  }

  void _onTagChanged(String value) {
    if (value.endsWith(',') || value.endsWith('\n')) {
      _commitTag();
    }
  }

  void _commitTag() {
    final raw = _tagController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return;
    setState(() {
      if (!_tags.contains(raw)) _tags.add(raw);
      _tagController.clear();
    });
  }

  Future<void> _save() async {
    _commitTag();
    final post = _buildPostForSave();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (widget.existingPost == null) {
      await ref.read(socialPostsProvider.notifier).addPost(post);
    } else {
      await ref.read(socialPostsProvider.notifier).updatePost(post);
    }
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Post salvo')));
  }

  SocialPost _buildPostForSave() {
    final base = _draft ?? _fallbackDraft();
    final existingPath = widget.existingPost?.obsidianPath;
    final post = base.copyWith(
      title: _titleController.text.trim().isEmpty
          ? base.title
          : _titleController.text.trim(),
      caption: _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
      personalNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      organizers: _organizers,
      socialRefs: _socialRefs,
      tags: _tags,
      obsidianPath: existingPath,
    );
    if (existingPath != null && existingPath.isNotEmpty) return post;
    return post.copyWith(obsidianPath: 'social/${post.socialSlug}.md');
  }

  SocialPost _fallbackDraft() {
    final url = _urlController.text.trim();
    final platform = OEmbedService.detectPlatform(url);
    return SocialPost(
      title: url.isEmpty ? 'Post social' : url,
      url: url,
      platform: platform,
      mediaType: OEmbedService.detectMediaType(platform, url),
      embedUrl: OEmbedService.buildEmbedUrl(platform, url),
    );
  }

  Future<void> _pickLinkedObject() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => UniversalSearchPickerSheet(
        title: 'Vincular objeto',
        showClear: false,
        onSelected: (object) {
          Navigator.pop(sheetContext);
          final refLink = _objectWikiLink(object);
          setState(() {
            if (!_socialRefs.any((ref) => _sameRef(ref, refLink, object))) {
              _socialRefs.add(refLink);
            }
          });
        },
      ),
    );
  }

  List<ContentObject> _resolveRefs(
    List<ContentObject> objects,
    List<String> refs,
  ) {
    return refs
        .map((ref) => _resolveRef(objects, ref))
        .whereType<ContentObject>()
        .toList();
  }

  ContentObject? _resolveRef(List<ContentObject> objects, String ref) {
    final key = _cleanWikiRef(ref).toLowerCase();
    if (key.isEmpty) return null;
    return objects.where((object) {
      final keys = {
        object.id,
        object.slug,
        object.title,
        object.obsidianFileName,
        if (object.obsidianPath.isNotEmpty)
          object.obsidianPath.replaceAll(RegExp(r'\.md$'), ''),
      }.map((value) => value.trim().toLowerCase()).toSet();
      return keys.contains(key);
    }).firstOrNull;
  }

  bool _sameRef(String current, String refLink, ContentObject object) {
    final currentKey = _cleanWikiRef(current).toLowerCase();
    final refKey = _cleanWikiRef(refLink).toLowerCase();
    return currentKey == refKey ||
        currentKey == object.id.toLowerCase() ||
        currentKey == object.slug.toLowerCase() ||
        currentKey == object.obsidianFileName.toLowerCase();
  }

  String _cleanWikiRef(String ref) {
    var cleaned = ref.trim();
    if (cleaned.startsWith('[[') && cleaned.endsWith(']]')) {
      cleaned = cleaned.substring(2, cleaned.length - 2);
    }
    return cleaned.split('|').first.trim();
  }

  String _objectWikiLink(ContentObject object) {
    final target = object.obsidianFileName.trim().isNotEmpty
        ? object.obsidianFileName
        : object.slug;
    return '[[${target.isEmpty ? object.id : target}]]';
  }
}

class _PlatformBadge extends StatelessWidget {
  final SocialPlatform platform;

  const _PlatformBadge({required this.platform});

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(platform);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        platform.name.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final SocialPost post;

  const _Thumbnail({required this.post});

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(post.platform);
    final fallback = _fallback(color, post.platform);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: SocialPostImage(
          source: socialPostImageSource(post),
          fallback: fallback,
        ),
      ),
    );
  }

  Widget _fallback(Color color, SocialPlatform platform) {
    return ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Icon(_platformIcon(platform), color: color),
    );
  }
}

Color _platformColor(SocialPlatform platform) {
  return switch (platform) {
    SocialPlatform.tiktok => AppColors.textPrimary,
    SocialPlatform.instagram => AppColors.habitPink,
    SocialPlatform.substack => AppColors.warning,
    SocialPlatform.linkedin => AppColors.info,
    SocialPlatform.pinterest => AppColors.error,
    SocialPlatform.youtube => AppColors.error,
    SocialPlatform.twitter => AppColors.info,
    SocialPlatform.other => AppColors.primary,
  };
}

IconData _platformIcon(SocialPlatform platform) {
  return switch (platform) {
    SocialPlatform.youtube => Icons.play_circle_outline_rounded,
    SocialPlatform.substack => Icons.article_outlined,
    SocialPlatform.linkedin => Icons.business_center_outlined,
    SocialPlatform.pinterest => Icons.push_pin_outlined,
    SocialPlatform.instagram => Icons.camera_alt_outlined,
    SocialPlatform.tiktok => Icons.music_note_rounded,
    SocialPlatform.twitter => Icons.alternate_email_rounded,
    SocialPlatform.other => Icons.link_rounded,
  };
}
