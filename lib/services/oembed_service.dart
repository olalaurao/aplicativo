// lib/services/oembed_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/social_post.dart';
import 'tiktok_video_resolver.dart';

class OEmbedService {
  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
        'Mobile/15E148 Safari/604.1',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  static SocialPlatform detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('tiktok.com')) return SocialPlatform.tiktok;
    if (lower.contains('instagram.com')) return SocialPlatform.instagram;
    if (lower.contains('substack.com')) return SocialPlatform.substack;
    if (lower.contains('linkedin.com')) return SocialPlatform.linkedin;
    if (lower.contains('pinterest.com') || lower.contains('pin.it')) {
      return SocialPlatform.pinterest;
    }
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return SocialPlatform.youtube;
    }
    if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return SocialPlatform.twitter;
    }
    if (lower.contains('reddit.com') || lower.contains('redd.it')) {
      return SocialPlatform.reddit;
    }
    return SocialPlatform.other;
  }

  static bool isSupportedUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    return detectPlatform(url) != SocialPlatform.other;
  }

  static SocialMediaType detectMediaType(SocialPlatform platform, String url) {
    final lower = url.toLowerCase();
    return switch (platform) {
      SocialPlatform.tiktok =>
        lower.contains('/photo/')
            ? SocialMediaType.carousel
            : SocialMediaType.video,
      SocialPlatform.youtube => SocialMediaType.video,
      SocialPlatform.instagram =>
        lower.contains('/reel/')
            ? SocialMediaType.video
            : SocialMediaType.image,
      SocialPlatform.substack => SocialMediaType.article,
      SocialPlatform.linkedin => SocialMediaType.other,
      SocialPlatform.pinterest => SocialMediaType.image,
      SocialPlatform.reddit => SocialMediaType.image,
      SocialPlatform.twitter || SocialPlatform.other => SocialMediaType.other,
    };
  }

  static String? buildEmbedUrl(SocialPlatform platform, String originalUrl) {
    switch (platform) {
      case SocialPlatform.tiktok:
        final id = RegExp(
          r'/(?:video|photo)/(\d+)',
        ).firstMatch(originalUrl)?.group(1);
        return id == null ? null : 'https://www.tiktok.com/embed/v2/$id';
      case SocialPlatform.instagram:
        final shortcode = RegExp(
          r'/(p|reel)/([A-Za-z0-9_-]+)',
        ).firstMatch(originalUrl)?.group(2);
        return shortcode == null
            ? null
            : 'https://www.instagram.com/p/$shortcode/embed/';
      case SocialPlatform.substack:
        return originalUrl;
      case SocialPlatform.linkedin:
        return null;
      case SocialPlatform.pinterest:
        final id =
            RegExp(r'/pin/(\d+)').firstMatch(originalUrl)?.group(1) ??
            Uri.tryParse(originalUrl)?.queryParameters['pin'];
        return id == null
            ? null
            : 'https://assets.pinterest.com/ext/embed.html?id=$id';
      case SocialPlatform.youtube:
        final id = _youtubeVideoId(originalUrl);
        return id == null ? null : 'https://www.youtube.com/embed/$id';
      case SocialPlatform.twitter:
        final id = RegExp(r'/status/(\d+)').firstMatch(originalUrl)?.group(1);
        return id == null
            ? null
            : 'https://platform.twitter.com/embed/Tweet.html?id=$id';
      case SocialPlatform.reddit:
        return null;
      case SocialPlatform.other:
        return null;
    }
  }

  Future<SocialPost> fetchMetadata(
    String url, {
    String? tiktokResolverEndpoint,
    String? tiktokResolverApiKey,
  }) async {
    final normalizedUrl = url.trim();
    final platform = detectPlatform(normalizedUrl);
    final mediaType = detectMediaType(platform, normalizedUrl);
    var embedUrl = buildEmbedUrl(platform, normalizedUrl);

    var title = normalizedUrl;
    String? caption;
    String? authorHandle;
    String? authorName;
    String? thumbnailUrl;
    String? videoUrl;

    try {
      final result = await switch (platform) {
        SocialPlatform.tiktok => _fetchTikTok(normalizedUrl),
        SocialPlatform.pinterest => _fetchOEmbed(
          'https://www.pinterest.com/oembed/?url=${Uri.encodeComponent(normalizedUrl)}',
        ),
        SocialPlatform.youtube => _fetchOEmbed(
          'https://www.youtube.com/oembed?url=${Uri.encodeComponent(normalizedUrl)}&format=json',
        ),
        SocialPlatform.instagram => _fetchInstagram(normalizedUrl),
        SocialPlatform.reddit => _fetchOEmbed(
          'https://www.reddit.com/oembed?url=${Uri.encodeComponent(normalizedUrl)}',
        ),
        SocialPlatform.substack ||
        SocialPlatform.linkedin ||
        SocialPlatform.twitter ||
        SocialPlatform.other => _fetchOpenGraph(normalizedUrl),
      };

      if (result != null) {
        title = _stringValue(result['title']) ?? title;
        caption =
            _stringValue(result['description']) ??
            _stringValue(result['og:description']);
        authorName =
            _stringValue(result['author_name']) ??
            _stringValue(result['site_name']);
        thumbnailUrl =
            _stringValue(result['thumbnail_url']) ??
            _stringValue(result['image']);
        authorHandle = _extractHandle(_stringValue(result['author_url']));
        if (platform == SocialPlatform.tiktok) {
          embedUrl ??= _tiktokEmbedUrlFromOEmbed(result);
        }
      }

      // TikTok fallback already handled inside _fetchTikTok

      if (platform == SocialPlatform.pinterest &&
          (thumbnailUrl == null || caption == null)) {
        final og = await _fetchOpenGraph(normalizedUrl);
        if (og != null) {
          title = _stringValue(og['title']) ?? title;
          caption ??=
              _stringValue(og['description']) ??
              _stringValue(og['og:description']);
          thumbnailUrl ??= _stringValue(og['image']);
          authorName ??= _stringValue(og['site_name']);
        }
      }

      if (platform == SocialPlatform.tiktok &&
          mediaType == SocialMediaType.video &&
          tiktokResolverEndpoint?.trim().isNotEmpty == true) {
        videoUrl = await TikTokVideoResolver(
          endpoint: tiktokResolverEndpoint!,
          apiKey: tiktokResolverApiKey,
        ).resolve(normalizedUrl);
      }
    } catch (error) {
      debugPrint('OEmbedService.fetchMetadata failed: $error');
    }

    return SocialPost(
      title: _truncateTitle(title),
      url: normalizedUrl,
      platform: platform,
      mediaType: mediaType,
      caption: caption,
      authorHandle: authorHandle,
      authorName: authorName,
      thumbnailUrl: thumbnailUrl,
      embedUrl: embedUrl,
      videoUrl: videoUrl,
      mediaUrls: thumbnailUrl == null ? const [] : [thumbnailUrl],
    );
  }

  Future<Map<String, dynamic>?> _fetchOEmbed(String oembedUrl) async {
    try {
      final response = await http
          .get(Uri.parse(oembedUrl), headers: _browserHeaders)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('OEmbed failed ${response.statusCode}: $oembedUrl');
    } catch (error) {
      debugPrint('OEmbed request failed: $error');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchOpenGraph(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _browserHeaders)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        debugPrint('OpenGraph failed ${response.statusCode}: $url');
        return null;
      }

      final html = response.body;
      final result = <String, dynamic>{};
      for (final key in ['title', 'description', 'image', 'site_name']) {
        final value = _metaContent(html, 'og:$key');
        if (value != null) result[key] = value;
      }
      result['image'] ??= _extractJsonLdImage(html);
      result['title'] ??= _titleTag(html);
      return result.isEmpty ? null : result;
    } catch (error) {
      debugPrint('OpenGraph request failed: $error');
      return null;
    }
  }

  /// Tries multiple strategies to get TikTok metadata + thumbnail:
  /// 1. noembed.com (public oEmbed proxy, more reliable)
  /// 2. Official tiktok.com/oembed
  /// 3. Scrape og:image from the TikTok embed page
  Future<Map<String, dynamic>?> _fetchTikTok(String url) async {
    // Strategy 1: noembed.com proxy
    try {
      final noembedUrl =
          'https://noembed.com/embed?url=${Uri.encodeComponent(url)}';
      final result = await _fetchOEmbed(noembedUrl);
      if (result != null &&
          (result['thumbnail_url'] != null || result['title'] != null)) {
        return result;
      }
    } catch (_) {}

    // Strategy 2: Official TikTok oEmbed
    try {
      final officialUrl =
          'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}';
      final result = await _fetchOEmbed(officialUrl);
      if (result != null && result['thumbnail_url'] != null) {
        return result;
      }
    } catch (_) {}

    // Strategy 3: Scrape og:image from embed page
    final videoId = RegExp(
      r'/(?:video|photo)/(\d+)',
    ).firstMatch(url)?.group(1);
    if (videoId != null) {
      try {
        final embedPage = 'https://www.tiktok.com/embed/v2/$videoId';
        final response = await http
            .get(Uri.parse(embedPage), headers: _browserHeaders)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final html = response.body;
          final image =
              _metaContent(html, 'og:image') ?? _extractJsonLdImage(html);
          final title = _metaContent(html, 'og:title') ?? _titleTag(html);
          final description = _metaContent(html, 'og:description');
          if (image != null) {
            return {
              'thumbnail_url': image,
              if (title != null) 'title': title,
              if (description != null) 'description': description,
              'site_name': 'TikTok',
            };
          }
        }
      } catch (_) {}
    }

    // Strategy 4: OpenGraph on original URL as last resort
    return _fetchOpenGraph(url);
  }

  Future<Map<String, dynamic>?> _fetchInstagram(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.path.isEmpty) return _fetchOpenGraph(url);
    final cleanPath = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    final embedPageUrl =
        'https://www.instagram.com${cleanPath}embed/captioned/';

    try {
      final response = await http
          .get(Uri.parse(embedPageUrl), headers: _browserHeaders)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final html = response.body;
        final image =
            RegExp(
              r'''<img[^>]*class=["'][^"']*EmbeddedMediaImage[^"']*["'][^>]*src=["']([^"']+)["']''',
              caseSensitive: false,
            ).firstMatch(html)?.group(1) ??
            _metaContent(html, 'og:image') ??
            _extractJsonLdImage(html);
        final caption = _metaContent(html, 'og:description');
        if (image != null && image.trim().isNotEmpty) {
          final result = {
            'image': _decodeHtml(image),
            'title': caption ?? 'Instagram post',
            'site_name': 'Instagram',
          };
          if (caption != null) result['description'] = caption;
          return result;
        }
      } else {
        debugPrint('Instagram embed failed ${response.statusCode}: $url');
      }
    } catch (error) {
      debugPrint('Instagram embed-page fetch failed: $error');
    }

    return _fetchOpenGraph(url);
  }

  static String? _extractJsonLdImage(String html) {
    final matches = RegExp(
      r'''<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>''',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);
    for (final match in matches) {
      try {
        final data = jsonDecode(match.group(1)!.trim());
        final image = data is Map ? data['image'] : null;
        if (image is String && image.trim().isNotEmpty) {
          return _decodeHtml(image);
        }
        if (image is List && image.isNotEmpty) {
          return _decodeHtml(image.first.toString());
        }
        if (image is Map && image['url'] != null) {
          return _decodeHtml(image['url'].toString());
        }
      } catch (error) {
        debugPrint('JSON-LD image parse failed: $error');
      }
    }
    return null;
  }

  static String? _metaContent(String html, String property) {
    final escaped = RegExp.escape(property);
    final patterns = [
      RegExp(
        '<meta[^>]+property=["\\\']$escaped["\\\'][^>]+content=["\\\']([^"\\\']*)["\\\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\\\']([^"\\\']*)["\\\'][^>]+property=["\\\']$escaped["\\\']',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) return _decodeHtml(match.group(1) ?? '');
    }
    return null;
  }

  static String? _titleTag(String html) {
    final match = RegExp(
      r'<title[^>]*>([^<]*)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    return match == null ? null : _decodeHtml(match.group(1) ?? '');
  }

  static String _decodeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  static String? _youtubeVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return uri.queryParameters['v'];
  }

  static String? _tiktokEmbedUrlFromOEmbed(Map<String, dynamic> result) {
    final html = _stringValue(result['html']);
    final authorUrl = _stringValue(result['author_url']);
    final candidates = [html, authorUrl, _stringValue(result['url'])];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final id =
          RegExp(
            r"""data-video-id=["']?(\d+)""",
          ).firstMatch(candidate)?.group(1) ??
          RegExp(r'/video/(\d+)').firstMatch(candidate)?.group(1);
      if (id != null) return 'https://www.tiktok.com/embed/v2/$id';
    }
    return null;
  }

  static String? _extractHandle(String? authorUrl) {
    if (authorUrl == null || !authorUrl.contains('@')) return null;
    return authorUrl.split('@').last.split('?').first.split('/').first;
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _truncateTitle(String title) {
    final normalized = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 80) return normalized;
    return '${normalized.substring(0, 80).trim()}...';
  }
}
