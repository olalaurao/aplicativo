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

  const TikTokResolvedData({
    this.videoUrl,
    this.thumbnailUrl,
    this.title,
    this.authorHandle,
    this.authorName,
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
      // Expand shortened URLs so tikwm can parse the video ID
      final expandedUrl = await _expandShortUrl(tiktokUrl);
      if (expandedUrl != tiktokUrl) {
        debugPrint('[TikTok] Expanded to: $expandedUrl');
      }
      final uri = _buildUri(configured, expandedUrl);
      debugPrint('[TikTok] API URI: $uri');
      final response = await _send(uri, expandedUrl)
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

  /// Expands shortened TikTok URLs (vt.tiktok.com, vm.tiktok.com) to their
  /// full form so tikwm can extract the video ID.
  Future<String> _expandShortUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.toLowerCase();
    // Only expand known short-link domains
    if (!host.contains('vt.tiktok.com') &&
        !host.contains('vm.tiktok.com') &&
        !host.contains('tiktok.com/t/')) {
      return url;
    }
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36');
      final response = await request.close().timeout(const Duration(seconds: 8));
      client.close();
      
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value('location');
        if (location != null && location.contains('tiktok.com')) {
          final clean = Uri.tryParse(location);
          if (clean != null) {
            // Strip query params
            return clean.replace(query: '', fragment: '').toString();
          }
          return location;
        }
      }
    } catch (_) {}
    return url;
  }

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
      if (videoUrl != null || thumbnailUrl != null) {
        return TikTokResolvedData(
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          title: title,
          authorHandle: authorHandle,
          authorName: authorName,
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
