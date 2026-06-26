import 'dart:convert';

import 'package:http/http.dart' as http;

enum ResourceSource {
  openLibrary,
  googleBooks,
  imdb,
  amazon,
  goodreads,
  unknown,
}

class ResourceDraft {
  final String? title;
  final String? author;
  final String? resourceType;
  final String? synopsis;
  final String? coverUrl;
  final int? year;
  final int? pages;
  final String? category;
  final String? sourceUrl;
  final String? sourceId;
  final String? sourceName;

  const ResourceDraft({
    this.title,
    this.author,
    this.resourceType,
    this.synopsis,
    this.coverUrl,
    this.year,
    this.pages,
    this.category,
    this.sourceUrl,
    this.sourceId,
    this.sourceName,
  });
}

class ResourceMetadataService {
  static ResourceSource detectSource(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('openlibrary.org')) return ResourceSource.openLibrary;
    if (lower.contains('books.google.com') ||
        lower.contains('play.google.com/store/books')) {
      return ResourceSource.googleBooks;
    }
    if (lower.contains('imdb.com')) return ResourceSource.imdb;
    if (lower.contains('amazon.com') || lower.contains('amazon.com.br')) {
      return ResourceSource.amazon;
    }
    if (lower.contains('goodreads.com')) return ResourceSource.goodreads;
    return ResourceSource.unknown;
  }

  static bool isResourceUrl(String url) =>
      detectSource(url) != ResourceSource.unknown;

  static Future<ResourceDraft> fetchMetadata(String url) async {
    final source = detectSource(url);
    return switch (source) {
      ResourceSource.openLibrary => _fetchOpenLibrary(url),
      ResourceSource.googleBooks => _fetchGoogleBooks(url),
      ResourceSource.imdb => _fetchImdb(url),
      ResourceSource.amazon => _fetchViaOpenGraph(url, 'Amazon'),
      ResourceSource.goodreads => _fetchViaOpenGraph(url, 'Goodreads'),
      ResourceSource.unknown => _fetchViaOpenGraph(url, 'Web'),
    };
  }

  static Future<ResourceDraft> _fetchOpenLibrary(String url) async {
    try {
      final workId = RegExp(r'/works/(OL\w+)').firstMatch(url)?.group(1);
      final isbn = RegExp(r'/isbn/(\d{10,13})').firstMatch(url)?.group(1);
      final bookId = RegExp(r'/books/(OL\w+)').firstMatch(url)?.group(1);

      Map<String, dynamic>? data;

      if (workId != null) {
        data = await _getJson('https://openlibrary.org/works/$workId.json');
      } else if (isbn != null) {
        final book = await _getJson('https://openlibrary.org/isbn/$isbn.json');
        if (book != null) {
          data = book;
          final workKey =
              ((book['works'] as List?)?.firstOrNull as Map?)?['key']
                  as String?;
          if (workKey != null) {
            data =
                await _getJson('https://openlibrary.org$workKey.json') ?? book;
          }
        }
      } else if (bookId != null) {
        data = await _getJson('https://openlibrary.org/books/$bookId.json');
      }

      if (data == null) {
        return const ResourceDraft(sourceName: 'OpenLibrary');
      }

      String? coverId;
      final covers = data['covers'];
      if (covers is List && covers.isNotEmpty) {
        coverId = covers.first.toString();
      }
      final coverUrl = coverId == null
          ? null
          : 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';

      String? author;
      final authors = data['authors'];
      if (authors is List && authors.isNotEmpty) {
        final firstAuthor = authors.first;
        String? authorKey;
        if (firstAuthor is Map<String, dynamic>) {
          authorKey =
              (firstAuthor['author'] as Map<String, dynamic>?)?['key']
                  as String? ??
              firstAuthor['key'] as String?;
        }
        if (authorKey != null) {
          final authorJson = await _getJson(
            'https://openlibrary.org$authorKey.json',
          );
          author = authorJson?['name'] as String?;
        }
      }

      final description = data['description'];
      final synopsis = description is Map<String, dynamic>
          ? description['value'] as String?
          : description?.toString();

      final year = _parseYear(data['first_publish_date']?.toString());

      return ResourceDraft(
        title: _cleanTitle(data['title']?.toString()),
        author: author,
        resourceType: 'Livro',
        synopsis: _cleanText(synopsis),
        coverUrl: _normalizeImageUrl(coverUrl),
        year: year,
        sourceUrl: url,
        sourceId: workId ?? isbn ?? bookId,
        sourceName: 'OpenLibrary',
      );
    } catch (_) {
      return ResourceDraft(sourceUrl: url, sourceName: 'OpenLibrary');
    }
  }

  static Future<ResourceDraft> _fetchGoogleBooks(String url) async {
    try {
      final uri = Uri.tryParse(url);
      final id =
          uri?.queryParameters['id'] ??
          RegExp(r'[?&]id=([^&]+)').firstMatch(url)?.group(1);
      if (id == null || id.isEmpty) {
        return _fetchViaOpenGraph(url, 'Google Books');
      }

      final data = await _getJson(
        'https://www.googleapis.com/books/v1/volumes/$id',
      );
      if (data == null) return _fetchViaOpenGraph(url, 'Google Books');

      final info =
          (data['volumeInfo'] as Map?)?.cast<String, dynamic>() ?? const {};
      final authors = (info['authors'] as List?)
          ?.map((e) => e.toString())
          .join(', ');
      final imageLinks = (info['imageLinks'] as Map?)?.cast<String, dynamic>();
      final thumbnail = imageLinks?['thumbnail']?.toString();
      final coverUrl = thumbnail
          ?.replaceAll('zoom=1', 'zoom=3')
          .replaceAll('&edge=curl', '')
          .replaceFirst('http://', 'https://');

      return ResourceDraft(
        title: _cleanTitle(info['title']?.toString()),
        author: _cleanText(authors),
        resourceType: 'Livro',
        synopsis: _cleanText(info['description']?.toString()),
        coverUrl: _normalizeImageUrl(coverUrl),
        year: _parseYear(info['publishedDate']?.toString()),
        pages: info['pageCount'] is int
            ? info['pageCount'] as int
            : int.tryParse('${info['pageCount'] ?? ''}'),
        category: ((info['categories'] as List?)?.firstOrNull)?.toString(),
        sourceUrl: url,
        sourceId: id,
        sourceName: 'Google Books',
      );
    } catch (_) {
      return ResourceDraft(sourceUrl: url, sourceName: 'Google Books');
    }
  }

  static Future<ResourceDraft> _fetchImdb(String url) async {
    try {
      final ttId = RegExp(r'/(tt\d+)').firstMatch(url)?.group(1);
      final draft = await _fetchViaOpenGraph(url, 'IMDB');
      final lower = url.toLowerCase();
      final resourceType =
          lower.contains('episodes') || lower.contains('series')
          ? 'Série'
          : 'Filme';

      var title = draft.title;
      var year = draft.year;
      if (title != null) {
        final match = RegExp(r'\((\d{4})\)$').firstMatch(title.trim());
        if (match != null) {
          year ??= int.tryParse(match.group(1) ?? '');
          title = title.replaceAll(match.group(0)!, '').trim();
        }
      }

      return ResourceDraft(
        title: title,
        author: draft.author,
        resourceType: resourceType,
        synopsis: draft.synopsis,
        coverUrl: draft.coverUrl,
        year: year,
        sourceUrl: url,
        sourceId: ttId,
        sourceName: 'IMDB',
      );
    } catch (_) {
      return ResourceDraft(sourceUrl: url, sourceName: 'IMDB');
    }
  }

  static Future<ResourceDraft> _fetchViaOpenGraph(
    String url,
    String sourceName,
  ) async {
    try {
      final resp = await http
          .get(
            Uri.parse(url),
            headers: const {
              'User-Agent': 'Mozilla/5.0 (compatible; Citrine/1.0)',
              'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        return ResourceDraft(sourceUrl: url, sourceName: sourceName);
      }

      final body = resp.body;
      final jsonLdList = _extractJsonLd(body);
      final bestJsonLd =
          jsonLdList.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item != null && item.isNotEmpty,
            orElse: () => null,
          ) ??
          const <String, dynamic>{};

      final title =
          _metaProperty(body, 'og:title') ??
          bestJsonLd['name']?.toString() ??
          _metaName(body, 'title');
      final description =
          _metaProperty(body, 'og:description') ??
          bestJsonLd['description']?.toString() ??
          _metaName(body, 'description');
      final image = _metaProperty(body, 'og:image') ?? _jsonLdImage(bestJsonLd);
      final author = _jsonLdAuthor(bestJsonLd);

      final ldType = bestJsonLd['@type']?.toString().toLowerCase() ?? '';
      var resourceType = 'General';
      if (ldType.contains('book')) {
        resourceType = 'Livro';
      } else if (ldType.contains('movie')) {
        resourceType = 'Filme';
      } else if (ldType.contains('tvseries') || ldType.contains('series')) {
        resourceType = 'Série';
      } else if (sourceName == 'Goodreads') {
        resourceType = 'Livro';
      } else if (sourceName == 'IMDB') {
        resourceType = 'Filme';
      }

      final year = _parseYear(
        bestJsonLd['datePublished']?.toString() ??
            bestJsonLd['dateCreated']?.toString() ??
            title,
      );

      return ResourceDraft(
        title: _cleanTitle(title),
        author: _cleanText(author),
        resourceType: resourceType,
        synopsis: _cleanText(description),
        coverUrl: _normalizeImageUrl(image),
        year: year,
        sourceUrl: url,
        sourceName: sourceName,
      );
    } catch (_) {
      return ResourceDraft(sourceUrl: url, sourceName: sourceName);
    }
  }

  static Future<Map<String, dynamic>?> _getJson(String url) async {
    final resp = await http
        .get(
          Uri.parse(url),
          headers: const {
            'User-Agent': 'Mozilla/5.0 (compatible; Citrine/1.0)',
            'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  static String? _metaProperty(String html, String property) {
    final exp = RegExp(
      '<meta[^>]+property=["\']${RegExp.escape(property)}["\'][^>]+content=["\']([^"\']+)["\'][^>]*>',
      caseSensitive: false,
      dotAll: true,
    );
    return exp.firstMatch(html)?.group(1);
  }

  static String? _metaName(String html, String name) {
    final exp = RegExp(
      '<meta[^>]+name=["\']${RegExp.escape(name)}["\'][^>]+content=["\']([^"\']+)["\'][^>]*>',
      caseSensitive: false,
      dotAll: true,
    );
    return exp.firstMatch(html)?.group(1);
  }

  static List<Map<String, dynamic>> _extractJsonLd(String html) {
    final matches = RegExp(
      "<script[^>]*type=[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>",
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    final results = <Map<String, dynamic>>[];
    for (final match in matches) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          results.add(decoded);
        } else if (decoded is List) {
          results.addAll(
            decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()),
          );
        }
      } catch (_) {}
    }
    return results;
  }

  static String? _jsonLdImage(Map<String, dynamic> jsonLd) {
    final image = jsonLd['image'];
    if (image is String) return image;
    if (image is List && image.isNotEmpty) return image.first.toString();
    if (image is Map<String, dynamic>) return image['url']?.toString();
    return null;
  }

  static String? _jsonLdAuthor(Map<String, dynamic> jsonLd) {
    final author = jsonLd['author'];
    if (author is String) return author;
    if (author is Map<String, dynamic>) return author['name']?.toString();
    if (author is List && author.isNotEmpty) {
      final first = author.first;
      if (first is String) return first;
      if (first is Map<String, dynamic>) return first['name']?.toString();
    }
    return null;
  }

  static int? _parseYear(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'(19|20)\d{2}').firstMatch(raw);
    return int.tryParse(match?.group(0) ?? '');
  }

  static String? _normalizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    return url.trim().replaceFirst('http://', 'https://');
  }

  static String? _cleanTitle(String? value) {
    final text = _cleanText(value);
    if (text == null) return null;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _cleanText(String? value) {
    final text = value
        ?.replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .trim();
    return text == null || text.isEmpty ? null : text;
  }
}
