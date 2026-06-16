// lib/ui/widgets/social_embed_view.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../models/social_post.dart';
import '../../services/oembed_service.dart';
import '../../services/tiktok_video_resolver.dart';
import 'social_native_video_player.dart';
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
  bool _resolvingVideo = false;
  String? _resolvedVideoUrl;
  SocialPost? _resolvedPost;

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
    _resolvedVideoUrl = widget.post.videoUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-A546E) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (widget.post.platform != SocialPlatform.tiktok) {
              return NavigationDecision.navigate;
            }
            if (!request.isMainFrame) return NavigationDecision.navigate;
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            final scheme = uri.scheme.toLowerCase();
            if (scheme != 'http' && scheme != 'https') {
              return NavigationDecision.prevent;
            }
            final host = uri.host.toLowerCase();
            if (!host.contains('tiktok.com') &&
                !host.contains('tiktokcdn.com') &&
                !host.contains('byteoversea.com')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            _timeout?.cancel();
            if (widget.post.platform == SocialPlatform.substack) {
              _controller.runJavaScript(_substackCleanupScript);
            }
            if (widget.post.platform == SocialPlatform.tiktok) {
              _controller.runJavaScript(_tiktokCleanupScript);
            }
            if (mounted) setState(() => _isLoaded = true);
          },
          onWebResourceError: (error) {
            final isMainFrame = error.isForMainFrame ?? true;
            if (mounted && !_isLoaded && isMainFrame) {
              setState(() => _hasError = true);
            }
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    final timeoutDuration = widget.post.platform == SocialPlatform.tiktok
        ? const Duration(seconds: 20)
        : const Duration(seconds: 10);
    _timeout = Timer(timeoutDuration, () {
      if (mounted && !_isLoaded) setState(() => _hasError = true);
    });

    if (_resolvedVideoUrl != null && _resolvedVideoUrl!.isNotEmpty) {
      _timeout?.cancel();
      return;
    }

    if (widget.post.platform == SocialPlatform.tiktok &&
        widget.post.mediaType == SocialMediaType.video) {
      _startTikTokPlayback();
      return;
    }

    if (widget.post.platform == SocialPlatform.tiktok) {
      _hasError = true;
      return;
    }

    final embedUrl = _embedUrlFor(widget.post);
    if (widget.post.platform == SocialPlatform.substack) {
      _controller.loadRequest(Uri.parse(widget.post.url));
    } else if (embedUrl != null && embedUrl.isNotEmpty) {
      _controller.loadHtmlString(
        _buildEmbedHtml(widget.post, embedUrl: embedUrl),
      );
    } else if (widget.post.platform == SocialPlatform.pinterest) {
      _resolvePinterestPreview();
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
    final videoUrl = _resolvedVideoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      return SocialNativeVideoPlayer(
        videoUrl: videoUrl,
        thumbnailUrl: widget.post.thumbnailUrl,
      );
    }

    if (_resolvingVideo) return _buildResolvingVideo();
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

  Widget _buildResolvingVideo() {
    final color = socialPlatformColor(widget.post.platform);
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: CircularProgressIndicator(color: color)),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final post = _resolvedPost ?? widget.post;
    final color = socialPlatformColor(widget.post.platform);
    final hasImage =
        post.thumbnailUrl?.isNotEmpty == true || post.mediaUrls.isNotEmpty;
    return Container(
      height: hasImage ? 360 : 220,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: hasImage ? _openImagePreview : _openOriginal,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SocialPostThumbnail(
              post: post,
              iconSize: 48,
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(widget.post.url);
    if (uri != null) {
      final opened = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!opened) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _startTikTokPlayback() async {
    final resolved = await _resolveTikTokVideoIfPossible();
    if (!mounted || resolved) return;
    _loadTikTokWebPlayback();
  }

  Future<bool> _resolveTikTokVideoIfPossible() async {
    if (widget.post.platform != SocialPlatform.tiktok ||
        widget.post.mediaType != SocialMediaType.video) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final endpoint = prefs.getString('tiktokResolverEndpoint') ?? '';
    if (endpoint.trim().isEmpty) return false;
    final apiKey = prefs.getString('tiktokResolverApiKey') ?? '';

    if (mounted) setState(() => _resolvingVideo = true);
    final resolved = await TikTokVideoResolver(
      endpoint: endpoint,
      apiKey: apiKey,
    ).resolve(widget.post.url);
    if (!mounted) return false;
    setState(() {
      _resolvingVideo = false;
      _resolvedVideoUrl = resolved;
      if (resolved != null) {
        _timeout?.cancel();
        _hasError = false;
      }
    });
    return resolved != null;
  }

  void _loadTikTokEmbedOrFallback() {
    final embedUrl = _embedUrlFor(widget.post);
    if (embedUrl == null || embedUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _timeout?.cancel();
          _hasError = true;
        });
      }
      return;
    }
    _controller.loadHtmlString(
      _buildEmbedHtml(widget.post, embedUrl: embedUrl),
    );
  }

  void _loadTikTokWebPlayback() {
    final uri = Uri.tryParse(widget.post.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _loadTikTokEmbedOrFallback();
      return;
    }
    _controller.loadRequest(uri);
  }

  void _openImagePreview() {
    final post = _resolvedPost ?? widget.post;
    final imageUrl = post.thumbnailUrl?.isNotEmpty == true
        ? post.thumbnailUrl!
        : post.mediaUrls.where((url) => url.trim().isNotEmpty).firstOrNull;
    if (imageUrl == null) {
      _openOriginal();
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resolvePinterestPreview() async {
    final resolved = await OEmbedService().fetchMetadata(widget.post.url);
    if (!mounted) return;
    final embedUrl = _embedUrlFor(resolved);
    if (embedUrl != null && embedUrl.isNotEmpty) {
      _controller.loadHtmlString(_buildEmbedHtml(resolved, embedUrl: embedUrl));
      return;
    }
    setState(() {
      _timeout?.cancel();
      _resolvedPost = resolved;
      _hasError = true;
    });
  }

  String? _embedUrlFor(SocialPost post) {
    return post.embedUrl ??
        OEmbedService.buildEmbedUrl(post.platform, post.url);
  }

  String _buildEmbedHtml(SocialPost post, {String? embedUrl}) {
    final resolvedEmbedUrl = embedUrl ?? post.embedUrl ?? '';
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
  <iframe src="$resolvedEmbedUrl"
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

  String get _tiktokCleanupScript => '''
    const selectors = [
      '.tiktok-header', '.author-uniqueId', '.video-meta-share',
      '.action-bar', '.tiktok-footer', '[class*="DivRecommentContainer"]',
      '[data-e2e="related-video"]'
    ];
    selectors.forEach(sel => {
      document.querySelectorAll(sel).forEach(el => el.remove());
    });

    const video = document.querySelector('video');
    if (video) {
      video.style.cssText = "width:100%!important;height:100%!important;object-fit:contain";
    }
  ''';
}
