// lib/models/resource_model.dart
import 'content_object.dart';
import 'shared_types.dart';

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
  DateTime? readDate;
  List<String> socialRefs;

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
    this.readDate,
    List<String>? socialRefs,
    super.organizers,
    super.categories,
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
    frontmatter['resource_type'] = resourceType;
    if (coverImage != null) frontmatter['cover'] = coverImage;
    if (sourceUrl != null) frontmatter['source_url'] = sourceUrl;
    frontmatter['status'] = status.name;
    frontmatter['rating'] = rating;
    if (author != null) frontmatter['author'] = author;
    if (year != null) frontmatter['year'] = year;
    if (pages != null) frontmatter['pages'] = pages;
    if (category != null) frontmatter['category'] = category;
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
    resource.author = _stringValue(frontmatter['author']);
    resource.year = _intValue(frontmatter['year']);
    resource.pages = _intValue(frontmatter['pages']);
    resource.category = _stringValue(frontmatter['category']);
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
    DateTime? readDate,
    List<String>? socialRefs,
    List<OrganizerReference>? organizers,
    List<String>? categories,
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
      readDate: readDate ?? this.readDate,
      socialRefs: socialRefs ?? List<String>.from(this.socialRefs),
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
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
