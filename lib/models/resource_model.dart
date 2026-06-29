// lib/models/resource_model.dart
import 'content_object.dart';
import 'shared_types.dart';
import 'task_model.dart'; // For TaskPriority

enum ResourceStatus { toConsume, inProgress, completed, dropped }

class Resource extends ContentObject {
  String? coverImage;
  String? sourceUrl;
  String resourceType; // Book, Movie, etc.
  ResourceStatus status;
  int rating; // 1-5 or 1-10
  String? synopsis;
  String? author;
  int? year;
  int? pages;
  String? category;
  String? isbnOriginal;
  String? titlePtBr;
  String? titleOriginal;
  String? publisher;
  String? language;
  String? googleBooksId;
  String? imdbId;
  DateTime? readDate;
  List<String> socialRefs;
  TaskPriority priority;

  Resource({
    super.id,
    required super.title,
    required this.resourceType,
    this.coverImage,
    this.sourceUrl,
    this.status = ResourceStatus.toConsume,
    this.rating = 0,
    this.synopsis,
    this.author,
    this.year,
    this.pages,
    this.category,
    this.isbnOriginal,
    this.titlePtBr,
    this.titleOriginal,
    this.publisher,
    this.language,
    this.googleBooksId,
    this.imdbId,
    this.readDate,
    List<String>? socialRefs,
    this.priority = TaskPriority.none,
    super.organizers,
    super.categories,
    super.tags,
    super.aliases,
    super.links,
    super.reminders,
    super.createdAt,
    super.updatedAt,
    super.order,
    super.obsidianPath,
  }) : socialRefs = socialRefs ?? [];

  @override
  String get type => 'resource';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    final aliasesForMarkdown = List<String>.from(aliases);
    final original = titleOriginal?.trim();
    if (original != null &&
        original.isNotEmpty &&
        original != title &&
        !aliasesForMarkdown.contains(original)) {
      aliasesForMarkdown.add(original);
      frontmatter['aliases'] = aliasesForMarkdown;
    }
    frontmatter['resource_type'] = resourceType;
    if (coverImage != null) frontmatter['cover'] = coverImage;
    if (sourceUrl != null) frontmatter['source_url'] = sourceUrl;
    frontmatter['status'] = status.name;
    frontmatter['rating'] = rating;
    frontmatter['priority'] = priority.name;
    if (author != null) frontmatter['author'] = author;
    if (year != null) frontmatter['year'] = year;
    if (pages != null) frontmatter['pages'] = pages;
    if (category != null) frontmatter['category'] = category;
    if (isbnOriginal != null) frontmatter['isbn'] = isbnOriginal;
    if (titlePtBr != null) frontmatter['title_pt_br'] = titlePtBr;
    if (titleOriginal != null) frontmatter['title_original'] = titleOriginal;
    if (publisher != null) frontmatter['publisher'] = publisher;
    if (language != null) frontmatter['language'] = language;
    if (googleBooksId != null) frontmatter['google_books_id'] = googleBooksId;
    if (imdbId != null) frontmatter['imdb_id'] = imdbId;
    if (readDate != null) {
      frontmatter['read'] = readDate!.toIso8601String().split('T')[0];
    }
    if (socialRefs.isNotEmpty) {
      frontmatter['social_refs'] = socialRefs;
    }

    return generateMarkdown(frontmatter, synopsis ?? '');
  }

  factory Resource.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final resource = Resource(
      title: _stringValue(frontmatter['title']) ?? '',
      resourceType: _stringValue(frontmatter['resource_type']) ?? 'General',
    );
    resource.loadBaseMap(frontmatter);

    resource.coverImage = _stringValue(
      frontmatter['cover'] ?? frontmatter['cover_image'],
    );
    resource.sourceUrl = _stringValue(frontmatter['source_url']);
    final rawStatus = _stringValue(frontmatter['status'])?.toLowerCase();
    if (rawStatus != null) {
      resource.status = ResourceStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == rawStatus,
        orElse: () => ResourceStatus.toConsume,
      );
    }
    resource.rating = _intValue(frontmatter['rating']) ?? 0;
    if (frontmatter['priority'] != null) {
      resource.priority = TaskPriority.values.firstWhere(
        (e) => e.name == frontmatter['priority']?.toString(),
        orElse: () => TaskPriority.none,
      );
    }
    resource.author = _stringValue(frontmatter['author']);
    resource.year = _intValue(frontmatter['year']);
    resource.pages = _intValue(frontmatter['pages']);
    resource.category = _stringValue(frontmatter['category']);
    resource.isbnOriginal = _stringValue(frontmatter['isbn']);
    resource.titlePtBr = _stringValue(frontmatter['title_pt_br']);
    resource.titleOriginal = _stringValue(frontmatter['title_original']);
    resource.publisher = _stringValue(frontmatter['publisher']);
    resource.language = _stringValue(frontmatter['language']);
    resource.googleBooksId = _stringValue(frontmatter['google_books_id']);
    resource.imdbId = _stringValue(frontmatter['imdb_id']);
    if (frontmatter['read'] != null) {
      resource.readDate = DateTime.tryParse(frontmatter['read'].toString());
    }
    if (frontmatter['social_refs'] != null) {
      resource.socialRefs = (frontmatter['social_refs'] as List)
          .map((e) => e.toString())
          .toList();
    }
    resource.synopsis = body;

    return resource;
  }

  Resource copyWith({
    String? title,
    String? resourceType,
    String? coverImage,
    String? sourceUrl,
    ResourceStatus? status,
    int? rating,
    String? synopsis,
    String? author,
    int? year,
    int? pages,
    String? category,
    String? isbnOriginal,
    String? titlePtBr,
    String? titleOriginal,
    String? publisher,
    String? language,
    String? googleBooksId,
    String? imdbId,
    DateTime? readDate,
    List<String>? socialRefs,
    TaskPriority? priority,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    List<String>? aliases,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? order,
    String? obsidianPath,
  }) {
    return Resource(
      id: id,
      title: title ?? this.title,
      resourceType: resourceType ?? this.resourceType,
      coverImage: coverImage ?? this.coverImage,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      synopsis: synopsis ?? this.synopsis,
      author: author ?? this.author,
      year: year ?? this.year,
      pages: pages ?? this.pages,
      category: category ?? this.category,
      isbnOriginal: isbnOriginal ?? this.isbnOriginal,
      titlePtBr: titlePtBr ?? this.titlePtBr,
      titleOriginal: titleOriginal ?? this.titleOriginal,
      publisher: publisher ?? this.publisher,
      language: language ?? this.language,
      googleBooksId: googleBooksId ?? this.googleBooksId,
      imdbId: imdbId ?? this.imdbId,
      readDate: readDate ?? this.readDate,
      socialRefs: socialRefs ?? List<String>.from(this.socialRefs),
      priority: priority ?? this.priority,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      aliases: aliases ?? this.aliases,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      order: order ?? this.order,
      obsidianPath: obsidianPath ?? this.obsidianPath,
    )..reminders = reminders;
  }

  static String? _stringValue(dynamic value) {
    if (value is List) {
      final joined = value.map((item) => item.toString()).join(', ').trim();
      return joined.isEmpty ? null : joined;
    }
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value?.toString();
    if (text == null) return null;
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9-]'), ''));
  }
}
