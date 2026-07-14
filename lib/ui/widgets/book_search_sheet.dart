import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/resource_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/book_lookup_service.dart';
import '../forms/create_resource_form.dart';
import '../theme.dart';

class BookSearchSheet extends ConsumerStatefulWidget {
  final String? linkedPostId;
  final VoidCallback? onSaved;

  const BookSearchSheet({super.key, this.linkedPostId, this.onSaved});

  @override
  ConsumerState<BookSearchSheet> createState() => _BookSearchSheetState();
}

class _BookSearchSheetState extends ConsumerState<BookSearchSheet> {
  final _queryController = TextEditingController();
  final _lookup = BookLookupService();
  List<BookSearchResult> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref.watch(googleBooksApiKeyProvider);
    final hasApiKey = apiKey.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Save books from post',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasApiKey) _buildMissingApiKey(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    enabled: hasApiKey && !_loading,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(apiKey),
                    decoration: const InputDecoration(
                      hintText: 'Book title',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: hasApiKey && !_loading
                      ? () => _search(apiKey)
                      : null,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentColor(context),
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, index) =>
                          _buildResultTile(_results[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingApiKey() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_off_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Add a Google Books API Key in Settings to search books.',
              style: TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _addManually,
            child: const Text('Add manually'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(BookSearchResult result) {
    final title = result.titlePtBr?.trim().isNotEmpty == true
        ? result.titlePtBr!.trim()
        : result.titleOriginal;
    final subtitleTitle = title == result.titleOriginal
        ? null
        : result.titleOriginal;
    final meta = [
      if (result.author?.trim().isNotEmpty == true) result.author!.trim(),
      if (result.year != null) result.year.toString(),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        leading: _buildCover(result.coverUrl ?? result.coverUrlLarge),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitleTitle != null)
              Text(
                subtitleTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            if (meta.isNotEmpty)
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _addResult(result),
          child: const Text('Add'),
        ),
      ),
    );
  }

  Widget _buildCover(String? url) {
    return SizedBox(
      width: 40,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: url == null || url.isEmpty
            ? const ColoredBox(
                color: AppColors.surfaceVariant,
                child: Icon(Icons.menu_book_outlined),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.surfaceVariant,
                  child: Icon(Icons.menu_book_outlined),
                ),
              ),
      ),
    );
  }

  Future<void> _search(String apiKey) async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _lookup.search(query, apiKey: apiKey);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Book search failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addResult(BookSearchResult result) async {
    final title = result.titlePtBr?.trim().isNotEmpty == true
        ? result.titlePtBr!.trim()
        : result.titleOriginal;
    final aliases = <String>[
      if (result.titleOriginal.trim().isNotEmpty &&
          result.titleOriginal.trim() != title)
        result.titleOriginal.trim(),
    ];
    final resource = Resource(
      title: title,
      mediaType: 'Livro',
      coverImage: result.coverUrlLarge ?? result.coverUrl,
      sourceUrl: 'https://books.google.com/books?id=${result.googleBooksId}',
      author: result.author,
      year: result.year,
      pages: result.pages,
      synopsis: result.synopsis,
      isbnOriginal: result.isbn,
      titlePtBr: result.titlePtBr,
      titleOriginal: result.titleOriginal,
      publisher: result.publisher,
      language: result.language,
      googleBooksId: result.googleBooksId,
      links: [
        if (widget.linkedPostId?.trim().isNotEmpty == true)
          widget.linkedPostId!,
      ],
      aliases: aliases,
    );

    await ref.read(vaultProvider.notifier).createObject(resource);
    widget.onSaved?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title added to your library')));
  }

  Future<void> _addManually() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateResourceForm(initialResourceType: 'Livro'),
      ),
    );
    widget.onSaved?.call();
  }
}


