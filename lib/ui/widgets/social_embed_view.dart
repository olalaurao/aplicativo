// lib/ui/widgets/social_embed_view.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../models/social_post.dart';
import 'social_post_grid_card.dart';

class SocialEmbedView extends StatefulWidget {
  final SocialPost post;

  const SocialEmbedView({super.key, required this.post});

  @override
  State<SocialEmbedView> createState() => _SocialEmbedViewState();
}

class _SocialEmbedViewState extends State<SocialEmbedView> {
  late final WebViewController _controller;
  Timer? _timeout;
  bool _isLoaded = false;
  bool _hasError = false;

  double get _height {
    return switch (widget.post.platform) {
      SocialPlatform.tiktok => 600,
      SocialPlatform.instagram =>
        widget.post.mediaType == SocialMediaType.video ? 560 : 480,
      SocialPlatform.youtube => 220,
      SocialPlatform.pinterest => 400,
      SocialPlatform.twitter => 280,
      SocialPlatform.linkedin => 260,
      SocialPlatform.substack => MediaQuery.of(context).size.height * 0.7,
      SocialPlatform.other => 400,
    };
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-A546E) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _timeout?.cancel();
            if (widget.post.platform == SocialPlatform.substack) {
              _controller.runJavaScript(_substackCleanupScript);
            }
            if (mounted) setState(() => _isLoaded = true);
          },
          onWebResourceError: (_) {
            if (mounted && !_isLoaded) setState(() => _hasError = true);
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _timeout = Timer(const Duration(seconds: 10), () {
      if (mounted && !_isLoaded) setState(() => _hasError = true);
    });

    final embedUrl = widget.post.embedUrl;
    if (widget.post.platform == SocialPlatform.substack) {
      _controller.loadRequest(Uri.parse(widget.post.url));
    } else if (embedUrl != null && embedUrl.isNotEmpty) {
      _controller.loadHtmlString(_buildEmbedHtml(widget.post));
    } else {
      _hasError = true;
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildFallback(context);

    return SizedBox(
      height: _height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: _isLoaded ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: WebViewWidget(controller: _controller),
            ),
            if (!_isLoaded) _buildLoading(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final color = socialPlatformColor(widget.post.platform);
    return ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Center(child: CircularProgressIndicator(color: color)),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final color = socialPlatformColor(widget.post.platform);
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: SocialPostThumbnail(post: widget.post, iconSize: 40),
          ),
          const SizedBox(height: 12),
          const Text(
            'Não foi possível carregar o embed deste post.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openOriginal,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text('Abrir no ${platformLabel(widget.post.platform)}'),
          ),
        ],
      ),
    );
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(widget.post.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _buildEmbedHtml(SocialPost post) {
    final embedUrl = post.embedUrl ?? '';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #000; overflow: hidden; }
    iframe { width: 100%; height: 100vh; border: none; }
  </style>
</head>
<body>
  <iframe src="$embedUrl"
    allowfullscreen
    allow="autoplay; encrypted-media; picture-in-picture; fullscreen">
  </iframe>
</body>
</html>
''';
  }

  String get _substackCleanupScript => '''
    document.querySelector('header')?.remove();
    document.querySelector('footer')?.remove();
    document.querySelector('.navbar')?.remove();
    document.querySelector('.subscribe-footer')?.remove();
    document.body.style.padding = '16px';
    document.body.style.maxWidth = '100%';
    document.body.style.fontSize = '16px';
    document.body.style.lineHeight = '1.7';
  ''';
}
