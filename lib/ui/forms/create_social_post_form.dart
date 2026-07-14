// lib/ui/forms/create_social_post_form.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/shared_types.dart';
import '../../models/social_post.dart';
import '../../models/content_object.dart';
import '../../models/task_model.dart';
import '../../models/project_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/oembed_service.dart';
import '../theme.dart';
import '../widgets/organizer_selector_field.dart';
import '../widgets/social_post_grid_card.dart';
import '../widgets/universal_search_picker.dart';
import '../widgets/organizer_picker_modal.dart';

enum _DuplicateAction { edit, doNothing, saveAnyway }

enum _LinkAction { createTask, createProject, linkExisting, addLabel, skip }

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
  final List<String> _links = [];
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
    _links.addAll(existing?.links ?? []);
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

    final isDirty =
        _urlController.text.trim().isNotEmpty ||
        _noteController.text.trim().isNotEmpty;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text(
              'Você possui alterações não salvas. Deseja sair mesmo assim?',
            ),
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
      child: Scaffold(
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
      ),
    );
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
          if (!_isFetching && !_hasThumbnail(draft)) ...[
            const SizedBox(height: 12),
            const Text(
              'Não conseguimos buscar a imagem automaticamente.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _retryFetch,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Tentar novamente'),
                ),
                TextButton.icon(
                  onPressed: _showManualImageUrlDialog,
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: const Text('Colar link da imagem'),
                ),
              ],
            ),
          ],
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
    final linked = _resolveRefs(objects, _links);
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
                            () => _links.removeWhere(
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
    final url = _normalizeUrl(_urlController.text.trim());
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
        // Only update the URL field if the post has a proper canonical URL
        // (contains /video/ or /photo/). Never replace the user's input with
        // a failed expansion like https://www.tiktok.com/?# or /?_r=1.
        final resolvedUrl = post.url;
        final isCanonical = resolvedUrl.contains('/video/') ||
            resolvedUrl.contains('/photo/');
        if (isCanonical && resolvedUrl.isNotEmpty &&
            resolvedUrl != _urlController.text.trim()) {
          _urlController.text = resolvedUrl;
        }
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

  Future<void> _retryFetch() => _fetchMetadata();

  Future<void> _showManualImageUrlDialog() async {
    final controller = TextEditingController();
    final imageUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Colar link da imagem'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Usar imagem'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (imageUrl == null || imageUrl.trim().isEmpty || !mounted) return;
    final base = _draft ?? _fallbackDraft();
    final currentMedia = base.mediaUrls
        .where((url) => url.trim().isNotEmpty && url.trim() != imageUrl)
        .toList();
    setState(() {
      _draft = base.copyWith(
        thumbnailUrl: imageUrl,
        mediaUrls: [imageUrl, ...currentMedia],
      );
    });
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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (widget.existingPost == null) {
      final url = _normalizeUrl(_urlController.text.trim());
      final existing = ref
          .read(socialPostsProvider)
          .where((p) => _normalizeUrl(p.url.trim()) == url)
          .toList();
      if (existing.isNotEmpty) {
        final existingPost = existing.first;
        final action = await showDialog<_DuplicateAction>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Link já salvo'),
            content: Text(
              'Este link já foi salvo em ${_formatDate(existingPost.createdAt)}. O que deseja fazer?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, _DuplicateAction.doNothing),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _DuplicateAction.edit),
                child: const Text('Editar existente'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, _DuplicateAction.saveAnyway),
                child: const Text('Salvar novo'),
              ),
            ],
          ),
        );
        if (action == null || action == _DuplicateAction.doNothing) return;
        if (action == _DuplicateAction.edit) {
          if (!mounted) return;
          navigator.pop();
          navigator.push(
            MaterialPageRoute(
              builder: (_) => CreateSocialPostForm(existingPost: existingPost),
            ),
          );
          return;
        }
      }
    }

    final post = _buildPostForSave();
    if (widget.existingPost == null) {
      await ref.read(socialPostsProvider.notifier).addPost(post);
    } else {
      await ref.read(socialPostsProvider.notifier).updatePost(post);
    }
    if (!mounted) return;

    if (post.organizers.isNotEmpty) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Post salvo e vinculado')));
      return;
    }

    final linkAction = await _showLinkOfferSheet(post);
    if (!mounted) return;
    if (linkAction == _LinkAction.createTask) {
      await _createAndLinkTask(post);
    } else if (linkAction == _LinkAction.createProject) {
      await _createAndLinkProject(post);
    } else if (linkAction == _LinkAction.linkExisting) {
      await _linkExistingObject(post);
    } else if (linkAction == _LinkAction.addLabel) {
      await _addLabel(post);
    }

    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Post salvo')));
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
      links: _links,
      tags: _tags,
      obsidianPath: existingPath,
    );
    if (existingPath != null && existingPath.isNotEmpty) return post;
    return post.copyWith(obsidianPath: 'app/${post.socialSlug}.md');
  }

  SocialPost _fallbackDraft() {
    final originalUrl = _urlController.text.trim();
    final normalizedUrl = _normalizeUrl(originalUrl);
    final platform = OEmbedService.detectPlatform(normalizedUrl);
    
    // Use originalUrl when our expansion only landed on the TikTok homepage
    final savedUrl = (normalizedUrl.contains('/video/') || normalizedUrl.contains('/photo/'))
        ? normalizedUrl
        : originalUrl;

    return SocialPost(
      title: 'Post social',
      url: savedUrl,
      platform: platform,
      mediaType: OEmbedService.detectMediaType(platform, savedUrl),
      embedUrl: OEmbedService.buildEmbedUrl(platform, savedUrl),
    );
  }

  bool _hasThumbnail(SocialPost post) {
    return socialPostImageSource(post)?.trim().isNotEmpty == true;
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
            if (!_links.any((ref) => _sameRef(ref, refLink, object))) {
              _links.add(refLink);
            }
          });
        },
      ),
    );
  }

  Future<_LinkAction?> _showLinkOfferSheet(SocialPost post) {
    return showModalBottomSheet<_LinkAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: AppTheme.sheetDecoration(context),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor(context),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Vincular este post?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_task_rounded),
                title: const Text('Criar tarefa relacionada'),
                onTap: () => Navigator.pop(ctx, _LinkAction.createTask),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Criar projeto relacionado'),
                onTap: () => Navigator.pop(ctx, _LinkAction.createProject),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded),
                title: const Text('Vincular a existente'),
                onTap: () => Navigator.pop(ctx, _LinkAction.linkExisting),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.label_outlined),
                title: const Text('Adicionar Label'),
                onTap: () => Navigator.pop(ctx, _LinkAction.addLabel),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, _LinkAction.skip),
                  child: const Text('Pular'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Future<void> _createAndLinkTask(SocialPost post) async {
    final postRef = _objectWikiLink(post);
    final task = Task(
      id: const Uuid().v4(),
      title: post.title,
      stage: TaskStage.todo,
      notes: [
        if (post.personalNote?.trim().isNotEmpty == true)
          post.personalNote!.trim(),
        if (post.caption?.trim().isNotEmpty == true) post.caption!.trim(),
        post.url,
      ],
      links: [postRef],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.read(vaultProvider.notifier).createObject(task);
    await _appendLink(post, _objectWikiLink(task));
  }

  Future<void> _createAndLinkProject(SocialPost post) async {
    final postRef = _objectWikiLink(post);
    final project = Project(
      id: const Uuid().v4(),
      title: post.title,
      description: post.personalNote ?? post.caption,
      quickAccessLinks: [postRef],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.read(projectsProvider.notifier).addProject(project);
    await _appendLink(post, _objectWikiLink(project));
  }

  Future<void> _linkExistingObject(SocialPost post) async {
    ContentObject? selected;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => UniversalSearchPickerSheet(
        title: 'Vincular objeto',
        showClear: false,
        onSelected: (object) {
          selected = object;
          Navigator.pop(sheetContext);
        },
      ),
    );
    final object = selected;
    if (object == null) return;

    await _appendLink(post, _objectWikiLink(object));

    final postRef = _objectWikiLink(post);
    if (object is Task && !object.links.contains(postRef)) {
      await ref
          .read(vaultProvider.notifier)
          .updateObject(
            object.copyWith(links: [...object.links, postRef]),
          );
    } else if (object is Project &&
        !object.quickAccessLinks.contains(postRef)) {
      object.quickAccessLinks = [...object.quickAccessLinks, postRef];
      object.updatedAt = DateTime.now();
      await ref.read(projectsProvider.notifier).updateProject(object);
    }
  }

  Future<void> _addLabel(SocialPost post) async {
    final selectedOrganizers = await showOrganizerPickerModal(
      context,
      ref,
      post.organizers,
      initialFilter: 'label',
    );
    if (selectedOrganizers == null) return;
    final updatedPost = post.copyWith(
      organizers: selectedOrganizers,
      updatedAt: DateTime.now(),
    );
    await ref.read(socialPostsProvider.notifier).updatePost(updatedPost);
  }

  Future<void> _appendLink(SocialPost post, String refLink) async {
    if (post.links.any((ref) => _sameRef(ref, refLink, post))) return;
    final updatedPost = post.copyWith(
      links: [...post.links, refLink],
      updatedAt: DateTime.now(),
    );
    await ref.read(socialPostsProvider.notifier).updatePost(updatedPost);
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

  String _normalizeUrl(String url) {
    var normalized = url.trim();
    // Remove trailing slash
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    // Remove common tracking parameters
    final uri = Uri.tryParse(normalized);
    if (uri != null) {
      final paramsToRemove = {
        'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
        'fbclid', 'igshid', '_nc_ht', '_nc_cat', 'si', 'ref'
      };
      final newQuery = uri.queryParameters.entries
          .where((e) => !paramsToRemove.contains(e.key))
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      normalized = uri.replace(query: newQuery.isEmpty ? '' : newQuery).toString();
    }
    return normalized;
  }

  String _objectWikiLink(ContentObject object) {
    final target = object.obsidianFileName.trim().isNotEmpty
        ? object.obsidianFileName
        : object.slug;
    if (target.isNotEmpty) {
      return '[[$target]]';
    }
    return '[[${object.slug}]]';
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
    SocialPlatform.reddit => AppColors.warning,
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
    SocialPlatform.reddit => Icons.forum_rounded,
    SocialPlatform.other => Icons.link_rounded,
  };
}


