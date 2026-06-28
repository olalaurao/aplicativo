import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BookSearchResult {
  final String googleBooksId;
  final String titleOriginal;
  final String? titlePtBr;
  final String? author;
  final String? coverUrl;
  final String? coverUrlLarge;
  final int? year;
  final int? pages;
  final String? synopsis;
  final String? publisher;
  final String? language;
  final String? isbn;

  const BookSearchResult({
    required this.googleBooksId,
    required this.titleOriginal,
    this.titlePtBr,
    this.author,
    this.coverUrl,
    this.coverUrlLarge,
    this.year,
    this.pages,
    this.synopsis,
    this.publisher,
    this.language,
    this.isbn,
  });

  BookSearchResult copyWith({
    String? titlePtBr,
    String? coverUrl,
    String? coverUrlLarge,
    String? publisher,
    String? language,
    String? isbn,
  }) {
    return BookSearchResult(
      googleBooksId: googleBooksId,
      titleOriginal: titleOriginal,
      titlePtBr: titlePtBr ?? this.titlePtBr,
      author: author,
      coverUrl: coverUrl ?? this.coverUrl,
      coverUrlLarge: coverUrlLarge ?? this.coverUrlLarge,
      year: year,
      pages: pages,
      synopsis: synopsis,
      publisher: publisher ?? this.publisher,
      language: language ?? this.language,
      isbn: isbn ?? this.isbn,
    );
  }
}

class BookLookupService {
  final http.Client _client;

  BookLookupService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<BookSearchResult>> search(
    String query, {
    String apiKey = '',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = _volumesUri({
      'q': trimmed,
      'maxResults': '10',
      if (apiKey.trim().isNotEmpty) 'key': apiKey.trim(),
    });

    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Google Books request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final items = decoded is Map ? decoded['items'] : null;
    if (items is! List) return [];

    final results = items
        .whereType<Map>()
        .map((item) => _parseResult(Map<String, dynamic>.from(item)))
        .whereType<BookSearchResult>()
        .toList();

    return Future.wait(
      results.map((result) => _withPtBrEdition(result, apiKey: apiKey)),
    );
  }

  Uri _volumesUri(Map<String, String> params) {
    return Uri.https('www.googleapis.com', '/books/v1/volumes', params);
  }

  BookSearchResult? _parseResult(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    final volume = item['volumeInfo'];
    if (id == null || volume is! Map) return null;
    final info = Map<String, dynamic>.from(volume);
    final title = info['title']?.toString().trim();
    if (title == null || title.isEmpty) return null;

    final imageLinks = info['imageLinks'];
    final images = imageLinks is Map
        ? Map<String, dynamic>.from(imageLinks)
        : {};
    final authors = info['authors'] is List
        ? (info['authors'] as List).map((e) => e.toString()).join(', ')
        : null;

    return BookSearchResult(
      googleBooksId: id,
      titleOriginal: title,
      author: authors?.trim().isEmpty == true ? null : authors,
      coverUrl: _secureUrl(images['thumbnail']?.toString()),
      coverUrlLarge: _secureUrl(
        images['large']?.toString() ??
            images['medium']?.toString() ??
            images['thumbnail']?.toString(),
      ),
      year: _yearFromPublishedDate(info['publishedDate']?.toString()),
      pages: _intValue(info['pageCount']),
      synopsis: _stripHtml(info['description']?.toString() ?? ''),
      publisher: info['publisher']?.toString(),
      language: info['language']?.toString(),
      isbn: _isbnFromIndustryIds(info['industryIdentifiers']),
    );
  }

  Future<BookSearchResult> _withPtBrEdition(
    BookSearchResult result, {
    required String apiKey,
  }) async {
    if (result.author == null || result.author!.isEmpty) return result;
    try {
      final uri = _volumesUri({
        'q': '${result.titleOriginal} inauthor:${result.author}',
        'maxResults': '1',
        'langRestrict': 'pt',
        if (apiKey.trim().isNotEmpty) 'key': apiKey.trim(),
      });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return result;
      }
      final decoded = jsonDecode(response.body);
      final items = decoded is Map ? decoded['items'] : null;
      if (items is! List || items.isEmpty || items.first is! Map) {
        return result;
      }
      final ptResult = _parseResult(Map<String, dynamic>.from(items.first));
      final ptTitle = ptResult?.titleOriginal.trim();
      if (ptTitle == null ||
          ptTitle.isEmpty ||
          ptTitle.toLowerCase() == result.titleOriginal.toLowerCase()) {
        return result;
      }
      return result.copyWith(
        titlePtBr: ptTitle,
        coverUrl: result.coverUrl ?? ptResult?.coverUrl,
        coverUrlLarge: result.coverUrlLarge ?? ptResult?.coverUrlLarge,
        publisher: result.publisher ?? ptResult?.publisher,
        language: result.language ?? ptResult?.language,
        isbn: result.isbn ?? ptResult?.isbn,
      );
    } catch (e) {
      debugPrint('PT-BR Google Books lookup failed: $e');
      return result;
    }
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _secureUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.replaceFirst('http://', 'https://');
  }

  int? _yearFromPublishedDate(String? value) {
    if (value == null || value.length < 4) return null;
    return int.tryParse(value.substring(0, 4));
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? _isbnFromIndustryIds(dynamic raw) {
    if (raw is! List) return null;
    for (final item in raw.whereType<Map>()) {
      final mapped = Map<String, dynamic>.from(item);
      if (mapped['type']?.toString() == 'ISBN_13') {
        return mapped['identifier']?.toString();
      }
    }
    for (final item in raw.whereType<Map>()) {
      final identifier = item['identifier']?.toString();
      if (identifier != null && identifier.isNotEmpty) return identifier;
    }
    return null;
  }
}
