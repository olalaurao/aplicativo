// lib/models/resource_model.dart
import 'content_object.dart';

enum ResourceStatus { toConsume, inProgress, completed, dropped }

class Resource extends ContentObject {
  String? coverImage;
  String resourceType; // Book, Movie, etc.
  ResourceStatus status;
  int rating; // 1-5 or 1-10
  String? synopsis;
  String? author;
  int? year;
  int? pages;
  String? category;
  DateTime? readDate;

  Resource({
    super.id,
    required super.title,
    required this.resourceType,
    this.coverImage,
    this.status = ResourceStatus.toConsume,
    this.rating = 0,
    this.synopsis,
    this.author,
    this.year,
    this.pages,
    this.category,
    this.readDate,
    super.organizers,
    super.categories,
    super.moc,
    super.createdAt,
    super.updatedAt,
    super.order,
    super.obsidianPath,
  });

  @override
  String get type => 'resource';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['resource_type'] = resourceType;
    if (coverImage != null) frontmatter['cover'] = coverImage;
    frontmatter['status'] = status.name;
    frontmatter['rating'] = rating;
    if (author != null) frontmatter['author'] = author;
    if (year != null) frontmatter['year'] = year;
    if (pages != null) frontmatter['pages'] = pages;
    if (category != null) frontmatter['category'] = category;
    if (readDate != null) {
      frontmatter['read'] = readDate!.toIso8601String().split('T')[0];
    }

    return generateMarkdown(frontmatter, synopsis ?? '');
  }

  factory Resource.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final resource = Resource(
      title: frontmatter['title'] is List ? (frontmatter['title'] as List).join(', ') : frontmatter['title']?.toString() ?? '',
      resourceType: frontmatter['resource_type'] is List ? (frontmatter['resource_type'] as List).join(', ') : frontmatter['resource_type']?.toString() ?? 'General',
    );
    resource.loadBaseMap(frontmatter);

    resource.coverImage =
        ((frontmatter['cover'] ?? frontmatter['cover_image']) is List ? (frontmatter['cover'] ?? frontmatter['cover_image'] as List).join(', ') : (frontmatter['cover'] ?? frontmatter['cover_image'])?.toString());
    if (frontmatter['status'] != null) {
      resource.status = ResourceStatus.values.firstWhere(
        (e) => e.name == frontmatter['status'],
        orElse: () => ResourceStatus.toConsume,
      );
    }
    final rating = frontmatter['rating'];
    resource.rating = rating is int ? rating : int.tryParse(rating?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;
    resource.author = frontmatter['author'] is List ? (frontmatter['author'] as List).join(', ') : frontmatter['author']?.toString();
    final year = frontmatter['year'];
    resource.year = year is int ? year : int.tryParse(year?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '');
    final pages = frontmatter['pages'];
    resource.pages = pages is int ? pages : int.tryParse(pages?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '');
    resource.category = frontmatter['category'] is List ? (frontmatter['category'] as List).join(', ') : frontmatter['category']?.toString();
    if (frontmatter['read'] != null) {
      resource.readDate = DateTime.tryParse(frontmatter['read'].toString());
    }
    resource.synopsis = body;

    return resource;
  }

  Resource copyWith({
    String? title,
    String? resourceType,
    String? coverImage,
    ResourceStatus? status,
    int? rating,
    String? synopsis,
    String? author,
    int? year,
    int? pages,
    String? category,
    DateTime? readDate,
    List<dynamic>? organizers,
    List<String>? categories,
    List<String>? moc,
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
      status: status ?? this.status,
      rating: rating ?? this.rating,
      synopsis: synopsis ?? this.synopsis,
      author: author ?? this.author,
      year: year ?? this.year,
      pages: pages ?? this.pages,
      category: category ?? this.category,
      readDate: readDate ?? this.readDate,
      organizers: this.organizers,
      categories: categories ?? this.categories,
      moc: moc ?? this.moc,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      order: order ?? this.order,
      obsidianPath: obsidianPath ?? this.obsidianPath,
    )..reminders = reminders;
  }
}
