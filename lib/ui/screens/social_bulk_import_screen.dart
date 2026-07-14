// lib/ui/screens/social_bulk_import_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/oembed_service.dart';
import '../theme.dart';

class SocialBulkImportScreen extends ConsumerStatefulWidget {
  const SocialBulkImportScreen({super.key});

  @override
  ConsumerState<SocialBulkImportScreen> createState() =>
      _SocialBulkImportScreenState();
}

class _SocialBulkImportScreenState
    extends ConsumerState<SocialBulkImportScreen> {
  final TextEditingController _controller = TextEditingController();
  final OEmbedService _oembedService = OEmbedService();
  bool _isImporting = false;
  int _imported = 0;
  int _failed = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _validUrls;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar URLs sociais'),
        actions: [
          TextButton(
            onPressed: urls.isEmpty || _isImporting
                ? null
                : () => _import(urls),
            child: const Text('Importar'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                minLines: 10,
                maxLines: 18,
                onChanged: (_) { if (mounted) setState(() {}); },
                decoration: const InputDecoration(
                  hintText: 'Cole um link por linha...',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${urls.length} URLs válidas detectadas',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (_isImporting) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: urls.isEmpty
                    ? null
                    : (_imported + _failed) / urls.length,
              ),
              const SizedBox(height: 8),
              Text(
                'Importados: $_imported · Falhas: $_failed',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> get _validUrls {
    final matches = RegExp(r'https?://\S+').allMatches(_controller.text);
    return matches
        .map((match) => match.group(0)!.trim())
        .where(OEmbedService.isSupportedUrl)
        .toSet()
        .toList();
  }

  Future<void> _import(List<String> urls) async {
    setState(() {
      _isImporting = true;
      _imported = 0;
      _failed = 0;
    });

    for (final url in urls) {
      try {
        final settings = ref.read(settingsProvider);
        final post = await _oembedService.fetchMetadata(
          url,
          tiktokResolverEndpoint: settings.tiktokResolverEndpoint,
          tiktokResolverApiKey: settings.tiktokResolverApiKey,
        );
        final withPath = post.copyWith(
          obsidianPath: 'social/${post.socialSlug}.md',
        );
        await ref.read(socialPostsProvider.notifier).addPost(withPath);
        _imported++;
      } catch (_) {
        _failed++;
      }
      if (mounted) setState(() {});
    }

    if (!mounted) return;
    setState(() => _isImporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Importados: $_imported · Falhas: $_failed')),
    );
  }
}
