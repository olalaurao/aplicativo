import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  Future<String?> resolve(String tiktokUrl) async {
    final configured = endpoint.trim();
    if (configured.isEmpty || tiktokUrl.trim().isEmpty) return null;

    try {
      final uri = _buildUri(configured, tiktokUrl);
      final response = await _send(
        uri,
        tiktokUrl,
      ).timeout(const Duration(seconds: 18));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'TikTokVideoResolver failed ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      final url = _findVideoUrl(decoded);
      if (url == null) return null;
      final parsed = Uri.tryParse(url);
      if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
        return null;
      }
      return url;
    } catch (error) {
      debugPrint('TikTokVideoResolver failed: $error');
      return null;
    }
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

  Future<http.Response> _send(Uri uri, String tiktokUrl) {
    final headers = <String, String>{
      'Accept': 'application/json',
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
          'url': tiktokUrl,
          'endpoint': '/',
          'params': {'url': tiktokUrl},
        }),
      );
    }
    return _client.get(uri, headers: headers);
  }

  String? _findVideoUrl(dynamic value) {
    if (value is Map) {
      const preferredKeys = [
        'video_url',
        'videoUrl',
        'direct_video_url',
        'download_url',
        'downloadUrl',
        'download_addr',
        'downloadAddr',
        'play',
        'playAddr',
        'play_addr',
        'url',
        'hdplay',
        'wmplay',
      ];
      for (final key in preferredKeys) {
        final found = _candidate(value[key]);
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
    return _candidate(value);
  }

  String? _candidate(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    if (!text.startsWith('http')) return null;
    final lower = text.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.contains('.mp4?') ||
        lower.contains('mime_type=video') ||
        lower.contains('/video/') ||
        lower.contains('tiktokcdn')) {
      return text;
    }
    return null;
  }
}
