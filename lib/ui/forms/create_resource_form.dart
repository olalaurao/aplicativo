// lib/ui/forms/create_resource_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/resource_model.dart';
import '../../models/shared_types.dart';
import '../theme.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';

class CreateResourceForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final Resource? existingResource;
  const CreateResourceForm({
    super.key,
    this.initialTitle,
    this.existingResource,
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
  int _rating = 0;
  List<OrganizerReference> _organizers = [];

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
      _resourceType = resource.resourceType;
      _status = resource.status;
      _rating = resource.rating;
      _readDate = resource.readDate;
      _organizers = List.from(resource.organizers);
    } else {
      final defaultType = ref
          .read(settingsProvider)
          .resourceTypeFilters
          .where((type) => type.trim().isNotEmpty)
          .firstOrNull;
      if (defaultType != null) _resourceType = defaultType;
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
            title: const Text('Descartar alteraÃ§Ãµes?'),
            content: const Text('VocÃª possui alteraÃ§Ãµes nÃ£o salvas. Deseja sair mesmo assim?'),
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
                        ),
                        const Divider(height: 16),
                        _buildRow(
                          'Cover URL',
                          _coverUrlController,
                          hint: 'https://...',
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

                  // Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€ Organizers Ã¢Â”Â€Ã¢Â”Â€Ã¢Â”Â€
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
    ));
  }

  Widget _buildTypeRow() {
    final configuredTypes = ref.watch(settingsProvider).resourceTypeFilters;
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          onChanged: (val) => setState(() => _resourceType = val!),
          items: types
              .map(
                (t) => DropdownMenuItem(
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
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
      ).showSnackBar(const SnackBar(content: Text('URL da capa invÃƒÂ¡lida')));
      return;
    }

    final resource = Resource(
      id:
          widget.existingResource?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: widget.existingResource?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      title: _titleController.text.trim(),
      resourceType: _resourceType,
      status: _status,
      rating: _rating,
      synopsis: _synopsisController.text.trim(),
      author: _authorController.text.trim(),
      year: int.tryParse(_yearController.text.trim()),
      pages: int.tryParse(_pagesController.text.trim()),
      category: _categoryController.text.trim(),
      readDate: _readDate,
      coverImage: coverUrl.isEmpty ? null : coverUrl,
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
}
