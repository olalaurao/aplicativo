import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Metadata resolved from a third-party TikTok API (e.g. tikwm.com).
class TikTokResolvedData {
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? title;
  final String? authorHandle;
  final String? authorName;
  final List<String>? images;

  const TikTokResolvedData({
    this.videoUrl,
    this.thumbnailUrl,
    this.title,
    this.authorHandle,
    this.authorName,
    this.images,
  });
}

class TikTokVideoResolver {
  TikTokVideoResolver({
    required this.endpoint,
    this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final String? apiKey;
  final http.Client _client;

  bool get isConfigured => endpoint.trim().isNotEmpty;

  /// Resolves a TikTok URL and returns full metadata including video URL,
  /// thumbnail, title, etc. Returns null on failure.
  Future<TikTokResolvedData?> resolveAll(String tiktokUrl) async {
    final configured = endpoint.trim();
    if (configured.isEmpty || tiktokUrl.trim().isEmpty) return null;

    try {
      debugPrint('[TikTok] Resolving: $tiktokUrl');
      // Try to expand shortened URLs so tikwm can parse the video ID.
      // But only use the expanded URL if it actually contains the video ID —
      // if expansion lands on the TikTok homepage (/?# etc.), fall back to
      // the original short link because tikwm handles vt/vm.tiktok.com directly.
      final expandedUrl = await _expandShortUrl(tiktokUrl);
      final expandedIsCanonical = expandedUrl.contains('/video/') ||
          expandedUrl.contains('/photo/');
      final urlForApi = expandedIsCanonical ? expandedUrl : tiktokUrl;
      if (expandedIsCanonical && expandedUrl != tiktokUrl) {
        debugPrint('[TikTok] Expanded to canonical: $expandedUrl');
      } else if (!expandedIsCanonical && expandedUrl != tiktokUrl) {
        debugPrint('[TikTok] Expansion non-canonical ($expandedUrl) – using original: $tiktokUrl');
      }
      final uri = _buildUri(configured, urlForApi);
      debugPrint('[TikTok] API URI: $uri');
      final response = await _send(uri, urlForApi)
          .timeout(const Duration(seconds: 18));
      debugPrint('[TikTok] Response ${response.statusCode}: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('TikTokVideoResolver failed ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      final result = _parseResponse(decoded);
      debugPrint('[TikTok] Parsed → videoUrl=${result?.videoUrl}, thumbnailUrl=${result?.thumbnailUrl}');
      return result;
    } catch (error) {
      debugPrint('TikTokVideoResolver failed: $error');
      return null;
    }
  }


  /// Expands shortened TikTok URLs (vt.tiktok.com, vm.tiktok.com, tiktok.com/t/)
  /// to their full canonical form so the video ID can be extracted.
  ///
  /// Manually follows redirects hop-by-hop and stops the moment a URL
  /// containing /video/ or /photo/ is found, preventing TikTok's secondary
  /// meta-redirect from overwriting the canonical URL with the homepage.
  static Future<String> expandShortUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.toLowerCase();
    // Only bother for known TikTok short-link patterns
    if (!host.contains('vt.tiktok.com') &&
        !host.contains('vm.tiktok.com') &&
        !host.contains('tiktok.com/t/') &&
        !_looksLikeTikTokShortLink(uri)) {
      return url;
    }
    try {
      const ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
          'Mobile/15E148 Safari/604.1';

      Uri current = uri;
      // Follow up to 6 hops manually so we can inspect each Location header
      for (int hop = 0; hop < 6; hop++) {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);

        final request = await client
            .getUrl(current)
            .timeout(const Duration(seconds: 12));
        request.followRedirects = false; // <-- manual hop-by-hop
        request.headers.set('User-Agent', ua);

        final response = await request.close();
        client.close();

        final location = response.headers.value('location');

        // If TikTok already gave us a canonical video URL, return it now
        // before any further redirect can clobber it.
        final isVideoUrl = current.path.contains('/video/') ||
            current.path.contains('/photo/');
        if (isVideoUrl && current.host.contains('tiktok.com')) {
          return current.replace(query: '', fragment: '').toString();
        }

        if (location == null ||
            response.statusCode < 300 ||
            response.statusCode >= 400) {
          // No further redirect – use the current URL if it's a TikTok page
          if (current.host.contains('tiktok.com')) {
            final clean = current.replace(query: '', fragment: '');
            return clean.toString();
          }
          break;
        }

        // Resolve relative URLs (e.g. "/path?x=1" → absolute)
        final next = current.resolve(location);

        // Check the Location header URL directly before following
        final nextPath = next.path;
        if (next.host.contains('tiktok.com') &&
            (nextPath.contains('/video/') || nextPath.contains('/photo/'))) {
          // Found the video URL — return it without following further
          debugPrint('[TikTok] Short-link resolved to: ${next.replace(query: '', fragment: '')}');
          return next.replace(query: '', fragment: '').toString();
        }

        current = next;
      }
    } catch (e) {
      debugPrint('[TikTok] URL expansion failed: $e');
    }
    return url;
  }

  /// Returns true if this looks like a TikTok short link that needs expansion.
  static bool _looksLikeTikTokShortLink(Uri uri) {
    // A full TikTok video URL has /@username/video/ID in the path
    // If the path is very short (like /zscwxklqx), it's a short link
    final path = uri.path;
    return uri.host.contains('tiktok.com') &&
        !path.contains('/video/') &&
        !path.contains('/photo/') &&
        !path.contains('/@') &&
        path.length < 20 &&
        path.length > 1;
  }

  /// Instance wrapper kept for backwards-compat inside resolveAll.
  Future<String> _expandShortUrl(String url) => expandShortUrl(url);

  /// Convenience: returns only the video URL (backwards-compat).
  Future<String?> resolve(String tiktokUrl) async {
    final data = await resolveAll(tiktokUrl);
    return data?.videoUrl;
  }

  Uri _buildUri(String configured, String tiktokUrl) {
    final expanded = configured.replaceAll(
      '{url}',
      Uri.encodeComponent(tiktokUrl),
    );
    final uri = Uri.parse(expanded);
    if (configured.contains('{url}')) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'url': tiktokUrl},
    );
  }

  Future<http.Response> _send(Uri uri, String expandedUrl) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      if (apiKey?.trim().isNotEmpty == true) 'x-api-key': apiKey!.trim(),
    };

    final method = uri.queryParameters['method']?.toUpperCase();
    if (method == 'POST') {
      final cleanUri = uri.replace(
        queryParameters: Map<String, String>.from(uri.queryParameters)
          ..remove('method'),
      );
      return _client.post(
        cleanUri,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': expandedUrl,
          'endpoint': '/',
          'params': {'url': expandedUrl},
        }),
      );
    }
    return _client.get(uri, headers: headers);
  }

  /// Parses the API response into a [TikTokResolvedData].
  /// Supports tikwm.com-style `{ code: 0, data: { play, cover, title, ... } }`
  /// and generic flat responses.
  TikTokResolvedData? _parseResponse(dynamic decoded) {
    if (decoded is! Map) return null;

    // tikwm.com: { code: 0, data: { play, wmplay, hdplay, cover, title, author } }
    final data = decoded['data'];
    if (data is Map) {
      // Trust tikwm's own play/hdplay/wmplay fields directly — no pattern validation needed
      final videoUrl = _firstHttpUrl([data['hdplay'], data['play'], data['wmplay']]);
      final thumbnailUrl = _firstHttpUrl([
        data['cover'],
        data['origin_cover'],
        data['ai_dynamic_cover'],
        data['dynamic_cover'],
      ]);
      final title = data['title']?.toString() ?? data['desc']?.toString();
      final author = data['author'];
      String? authorHandle;
      String? authorName;
      if (author is Map) {
        authorHandle = author['unique_id']?.toString() ??
            author['uniqueId']?.toString();
        authorName = author['nickname']?.toString();
      }
      
      List<String>? images;
      if (data['images'] is List) {
        images = (data['images'] as List)
            .map((e) => e.toString())
            .where((url) => url.isNotEmpty)
            .toList();
      }

      if (videoUrl != null || thumbnailUrl != null || (images != null && images.isNotEmpty)) {
        return TikTokResolvedData(
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl ?? (images != null && images.isNotEmpty ? images.first : null),
          title: title,
          authorHandle: authorHandle,
          authorName: authorName,
          images: images,
        );
      }
    }

    // Generic flat response — search for video URL.
    final videoUrl = _findVideoUrl(decoded);
    final thumbnailUrl = _firstHttpUrl([
      decoded['cover'],
      decoded['thumbnail'],
      decoded['thumbnail_url'],
      decoded['image'],
    ]);
    if (videoUrl != null || thumbnailUrl != null) {
      return TikTokResolvedData(
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        title: decoded['title']?.toString() ?? decoded['desc']?.toString(),
      );
    }

    return null;
  }

  /// Returns the first non-empty http/https string from [candidates].
  String? _firstHttpUrl(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is String && c.trim().startsWith('http') && c.trim().isNotEmpty) {
        return c.trim();
      }
    }
    return null;
  }

  String? _findVideoUrl(dynamic value) {
    if (value is Map) {
      const preferredKeys = [
        'video_url', 'videoUrl', 'direct_video_url',
        'download_url', 'downloadUrl', 'download_addr', 'downloadAddr',
        'play', 'playAddr', 'play_addr', 'url', 'hdplay', 'wmplay',
      ];
      for (final key in preferredKeys) {
        final found = _candidate(value[key], isVideo: true);
        if (found != null) return found;
      }
      for (final entry in value.entries) {
        final found = _findVideoUrl(entry.value);
        if (found != null) return found;
      }
    }
    if (value is List) {
      for (final item in value) {
        final found = _findVideoUrl(item);
        if (found != null) return found;
      }
    }
    return _candidate(value, isVideo: true);
  }

  String? _candidate(dynamic value, {required bool isVideo}) {
    if (value is! String) return null;
    final text = value.trim();
    if (!text.startsWith('http')) return null;
    if (isVideo) {
      final lower = text.toLowerCase();
      if (lower.endsWith('.mp4') ||
          lower.contains('.mp4?') ||
          lower.contains('mime_type=video') ||
          lower.contains('/video/') ||
          lower.contains('tiktokcdn') ||
          lower.contains('tiktok.com')) {
        return text;
      }
      return null;
    } else {
      // For images: accept any http URL that looks like an image or CDN
      return text.isNotEmpty ? text : null;
    }
  }
}
