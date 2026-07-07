// lib/ui/forms/create_resource_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/resource_model.dart';
import '../../models/shared_types.dart';
import '../../services/resource_metadata_service.dart';
import '../theme.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';
import '../widgets/universal_search_picker.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';

class CreateResourceForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialUrl;
  final String? initialResourceType;
  final Resource? existingResource;
  final List<OrganizerReference>? initialOrganizers;
  const CreateResourceForm({
    super.key,
    this.initialTitle,
    this.initialUrl,
    this.initialResourceType,
    this.existingResource,
    this.initialOrganizers,
  });

  @override
  ConsumerState<CreateResourceForm> createState() => _CreateResourceFormState();
}

class _CreateResourceFormState extends ConsumerState<CreateResourceForm> {
  late final WikiLinkTextController _titleController;
  late final WikiLinkTextController _synopsisController;
  late final WikiLinkTextController _coverUrlController;
  late final WikiLinkTextController _authorController;
  late final TextEditingController _yearController;
  late final TextEditingController _pagesController;
  late final WikiLinkTextController _categoryController;
  DateTime? _readDate;
  String _resourceType = 'Book';
  ResourceStatus _status = ResourceStatus.toConsume;
  ResourcePriority _priority = ResourcePriority.none;
  int _rating = 0;
  List<OrganizerReference> _organizers = [];
  bool _isFetchingUrl = false;
  String? _fetchError;
  String? _sourceUrl;
  String? _sourceName;
  String? _imdbId;

  @override
  void initState() {
    super.initState();
    _titleController = WikiLinkTextController(
      context: context,
      text: widget.existingResource?.title ?? widget.initialTitle ?? '',
    );
    _synopsisController = WikiLinkTextController(
      context: context,
      text: widget.existingResource?.synopsis ?? '',
    );
    _coverUrlController = WikiLinkTextController(
      context: context,
      text: widget.existingResource?.coverImage ?? '',
    );
    _authorController = WikiLinkTextController(
      context: context,
      text: widget.existingResource?.author ?? '',
    );
    _yearController = TextEditingController(
      text: widget.existingResource?.year?.toString() ?? '',
    );
    _pagesController = TextEditingController(
      text: widget.existingResource?.pages?.toString() ?? '',
    );
    _categoryController = WikiLinkTextController(
      context: context,
      text: widget.existingResource?.category ?? '',
    );

    if (widget.existingResource != null) {
      final resource = widget.existingResource!;
      _resourceType = resource.mediaType;
      _status = resource.status;
      _priority = resource.priority;
      _rating = resource.rating;
      _readDate = resource.readDate;
      _organizers = List.from(resource.organizers);
      _sourceUrl = resource.sourceUrl;
      _imdbId = resource.imdbId;
    } else {
      final defaultType = ref
          .read(settingsProvider)
          .mediaTypeFilters
          .where((type) => type.trim().isNotEmpty)
          .firstOrNull;
      if (widget.initialResourceType?.trim().isNotEmpty == true) {
        _resourceType = widget.initialResourceType!.trim();
      } else if (defaultType != null) {
        _resourceType = defaultType;
      }
      if (widget.initialOrganizers != null) {
        _organizers = List.from(widget.initialOrganizers!);
      }
    }

    if (widget.existingResource == null && widget.initialUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchFromUrl());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _synopsisController.dispose();
    _coverUrlController.dispose();
    _authorController.dispose();
    _yearController.dispose();
    _pagesController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = _titleController.text.trim().isNotEmpty;

    final isDirty = _titleController.text.trim().isNotEmpty;

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Resource',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              centerTitle: true,
            ),
            if (_isFetchingUrl)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            if (_fetchError != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Erro ao buscar metadados: $_fetchError',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            if (_sourceUrl != null && !_isFetchingUrl && _fetchError == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _buildSourceBanner(),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Resource Title',
                        hintStyle: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: -0.5,
                        ),
                        border: InputBorder.none,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTypeRow(),
                          const Divider(height: 16),
                          _buildPriorityRow(),
                          const Divider(height: 16),
                          _buildRow(
                            'Author',
                            _authorController,
                            hint: 'Author name',
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRow(
                                  'Year',
                                  _yearController,
                                  hint: 'YYYY',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildRow(
                                  'Pages',
                                  _pagesController,
                                  hint: '0',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          _buildRow(
                            'Category',
                            _categoryController,
                            hint: 'Genre or category',
                            trailing: IconButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (sheetContext) => UniversalSearchPickerSheet(
                                    title: 'Vincular Categoria/Objeto',
                                    onSelected: (obj) {
                                      setState(() {
                                        _categoryController.text = '[[${obj.slug}]]';
                                      });
                                      Navigator.pop(sheetContext);
                                    },
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.link_rounded,
                                size: 18,
                              ),
                              tooltip: 'Vincular objeto',
                            ),
                          ),
                          const Divider(height: 16),
                          _buildRow(
                            'Cover URL',
                            _coverUrlController,
                            hint: 'https://...',
                            trailing: IconButton(
                              onPressed: _pasteCoverUrl,
                              icon: const Icon(
                                Icons.content_paste_rounded,
                                size: 18,
                              ),
                              tooltip: 'Colar URL',
                            ),
                          ),
                          const Divider(height: 16),
                          _buildStatusRow(),
                          const Divider(height: 16),
                          _buildReadDateRow(),
                          const Divider(height: 16),
                          _buildRatingRow(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // âÂ”Â€âÂ”Â€âÂ”Â€ Organizers âÂ”Â€âÂ”Â€âÂ”Â€
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: OrganizerSelectorField(
                        selectedOrganizers: _organizers,
                        onChanged: (val) => setState(() => _organizers = val),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SYNOPSIS & HIGHLIGHTS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _synopsisController,
                            maxLines: null,
                            minLines: 5,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText:
                                  'Synopsis or notes... Use markdown # * [[]]',
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: hasTitle ? _saveResource : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  widget.existingResource == null
                      ? 'Add Resource'
                      : 'Save Resource',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeRow() {
    final configuredTypes = ref.watch(settingsProvider).mediaTypeFilters;
    final types = {
      if (_resourceType.trim().isNotEmpty) _resourceType.trim(),
      ...configuredTypes.where((type) => type.trim().isNotEmpty),
    }.toList()..sort();

    return Row(
      children: [
        const Text(
          'Type',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        DropdownButton<String>(
          value: _resourceType,
          underline: const SizedBox(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.accentColor(context),
          ),
          onChanged: (val) => setState(() => _resourceType = val!),
          items: types
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      t.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPriorityRow() {
    return Row(
      children: [
        const Text(
          'Priority',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        DropdownButton<ResourcePriority>(
          value: _priority,
          underline: const SizedBox(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.accentColor(context),
          ),
          onChanged: (val) => setState(() => _priority = val!),
          items: ResourcePriority.values
              .map(
                (p) => DropdownMenuItem<ResourcePriority>(
                  value: p,
                  child: Text(p.name.toUpperCase()),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        const Text(
          'Status',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        DropdownButton<ResourceStatus>(
          value: _status,
          underline: const SizedBox(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.accentColor(context),
          ),
          onChanged: (val) => setState(() => _status = val!),
          items: ResourceStatus.values
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.name.toUpperCase()),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRatingRow() {
    return Row(
      children: [
        const Text(
          'Rating',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Row(
          children: List.generate(
            5,
            (index) => GestureDetector(
              onTap: () => setState(() => _rating = index + 1),
              child: Icon(
                index < _rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: index < _rating
                    ? AppColors.warning
                    : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.end,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentColor(context),
            ),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 4), trailing],
      ],
    );
  }

  Widget _buildSourceBanner() {
    final coverUrl = _coverUrlController.text.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentColor(context).withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          if (coverUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                coverUrl,
                width: 42,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            )
          else
            Container(
              width: 42,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.accentColor(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.accentColor(context),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dados importados de ${_sourceName ?? 'uma fonte externa'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _sourceUrl ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Editar manualmente')),
        ],
      ),
    );
  }

  Widget _buildReadDateRow() {
    return Row(
      children: [
        const Text(
          'Read Date',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        TextButton(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _readDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) setState(() => _readDate = date);
          },
          child: Text(
            _readDate != null
                ? "${_readDate!.day}/${_readDate!.month}/${_readDate!.year}"
                : 'Select Date',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveResource() async {
    final coverUrl = _coverUrlController.text.trim();
    if (coverUrl.isNotEmpty && !_isValidCoverUrl(coverUrl)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL da capa inválida')));
      return;
    }

    final resource = Resource(
      id:
          widget.existingResource?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: widget.existingResource?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      title: _titleController.text.trim(),
      mediaType: _resourceType,
      status: _status,
      rating: _rating,
      synopsis: _synopsisController.text.trim(),
      author: _authorController.text.trim(),
      year: int.tryParse(_yearController.text.trim()),
      pages: int.tryParse(_pagesController.text.trim()),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      readDate: _readDate,
      priority: _priority,
      coverImage: coverUrl.isEmpty ? null : coverUrl,
      sourceUrl: _sourceUrl,
      googleBooksId: widget.existingResource?.googleBooksId,
      imdbId: _imdbId,
      obsidianPath: widget.existingResource?.obsidianPath ?? '',
      organizers: _organizers,
      categories: widget.existingResource?.categories,
    );

    try {
      if (widget.existingResource != null) {
        await ref.read(vaultProvider.notifier).updateObject(resource);
      } else {
        await ref.read(resourcesProvider.notifier).addResource(resource);
      }
    } catch (e) {
      debugPrint('Failed to save resource: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar recurso: $e')));
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Resource "${resource.title}" ${widget.existingResource != null ? 'updated' : 'added'} successfully!',
        ),
      ),
    );
  }

  bool _isValidCoverUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.isAbsolute &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _fetchFromUrl() async {
    final url = widget.initialUrl?.trim() ?? '';
    if (url.isEmpty) return;

    setState(() {
      _isFetchingUrl = true;
      _fetchError = null;
    });

    try {
      final omdbKey = ref.read(settingsProvider).omdbApiKey;
      final draft = await ResourceMetadataService.fetchMetadata(
        url,
        omdbApiKey: omdbKey.isEmpty ? null : omdbKey,
      );
      if (!mounted) return;
      setState(() {
        _isFetchingUrl = false;
        _sourceUrl = draft.sourceUrl ?? url;
        _sourceName = draft.sourceName;
        if ((draft.title ?? '').trim().isNotEmpty) {
          _titleController.text = draft.title!.trim();
        }
        if ((draft.author ?? '').trim().isNotEmpty) {
          _authorController.text = draft.author!.trim();
        }
        if ((draft.synopsis ?? '').trim().isNotEmpty) {
          _synopsisController.text = draft.synopsis!.trim();
        }
        if ((draft.coverUrl ?? '').trim().isNotEmpty) {
          _coverUrlController.text = draft.coverUrl!.trim();
        }
        if (draft.year != null) {
          _yearController.text = draft.year.toString();
        }
        if (draft.pages != null) {
          _pagesController.text = draft.pages.toString();
        }
        if ((draft.category ?? '').trim().isNotEmpty) {
          _categoryController.text = draft.category!.trim();
        }
        if ((draft.mediaType ?? '').trim().isNotEmpty) {
          _resourceType = _normalizeResourceType(draft.mediaType!);
        }
        // Persist IMDb id when sourced from IMDB
        if (_sourceName == 'IMDB' && (draft.sourceId ?? '').isNotEmpty) {
          _imdbId = draft.sourceId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingUrl = false;
        _fetchError = e.toString();
      });
    }
  }

  String _normalizeResourceType(String value) {
    final trimmed = value.trim();
    final configured = ref.read(settingsProvider).mediaTypeFilters;
    // First check for exact case-insensitive match in configured list
    final match = configured.firstWhere(
      (type) => type.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => '',
    );
    if (match.isNotEmpty) return match;
    // Accept well-known types directly even if not in configured list
    const knownTypes = ['Book', 'Movie', 'Show', 'General'];
    final known = knownTypes.firstWhere(
      (type) => type.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => '',
    );
    return known.isNotEmpty ? known : trimmed;
  }

  Future<void> _pasteCoverUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!_isValidCoverUrl(text)) return;
    setState(() {
      _coverUrlController.text = text;
    });
  }
}

