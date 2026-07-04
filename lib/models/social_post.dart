// lib/models/social_post.dart
import 'content_object.dart';
import 'reminder_config.dart';
import 'shared_types.dart';

enum SocialPlatform {
  tiktok,
  instagram,
  substack,
  linkedin,
  pinterest,
  youtube,
  twitter,
  reddit,
  other,
}

enum SocialMediaType { video, image, carousel, article, newsletter, other }

class SocialPost extends ContentObject {
  String url;
  SocialPlatform platform;
  SocialMediaType mediaType;
  String? caption;
  String? creator;
  String? authorHandle;
  String? authorName;
  String? thumbnailUrl;
  String? embedUrl;
  String? videoUrl;
  String? transcription;
  List<String> mediaUrls;
  int primaryMediaIndex;
  DateTime? postedAt;
  String? personalNote;
  bool watched;

  SocialPost({
    super.id,
    required super.title,
    required this.url,
    required this.platform,
    this.mediaType = SocialMediaType.other,
    this.caption,
    this.creator,
    this.authorHandle,
    this.authorName,
    this.thumbnailUrl,
    this.embedUrl,
    this.videoUrl,
    this.transcription,
    List<String>? mediaUrls,
    this.primaryMediaIndex = 0,
    this.postedAt,
    this.personalNote,
    this.watched = false,
    super.organizers,
    super.categories,
    super.tags,
    super.links,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
    super.archived,
    super.pinned,
    super.order,
    super.reminders,
  }) : mediaUrls = mediaUrls ?? [];

  @override
  String get type => 'social_post';

  @override
  bool get isIncomplete => title.trim().isEmpty || url.trim().isEmpty;

  @override
  String get displayType => platform.name.toUpperCase();

  String get socialSlug {
    if (obsidianPath.isNotEmpty) {
      return obsidianPath
          .split('/')
          .last
          .split('\\')
          .last
          .replaceAll('.md', '');
    }
    final fallbackTitle = title.trim().isEmpty ? url : title;
    final base = '${platform.name}-$fallbackTitle'
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final readable = base.isEmpty ? '${platform.name}-post' : base;
    final trimmed = readable.length > 48
        ? readable.substring(0, 48).replaceAll(RegExp(r'-+$'), '')
        : readable;
    final suffix = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final shortId = suffix.length > 8 ? suffix.substring(0, 8) : suffix;
    if (shortId.isEmpty || trimmed.endsWith('-$shortId')) return trimmed;
    return '$trimmed-$shortId';
  }

  String get legacySocialSlug {
    final fallbackTitle = title.trim().isEmpty ? url : title;
    final base = '${platform.name}-$fallbackTitle'
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isEmpty) return '${platform.name}-post';
    return base.length > 60
        ? base.substring(0, 60).replaceAll(RegExp(r'-+$'), '')
        : base;
  }

  @override
  String get slug => socialSlug;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['url'] = url;
    frontmatter['platform'] = platform.name;
    frontmatter['media_type'] = mediaType.name;
    if (_hasText(caption)) frontmatter['caption'] = caption;
    if (_hasText(creator)) frontmatter['creator'] = creator;
    if (_hasText(authorHandle)) frontmatter['author_handle'] = authorHandle;
    if (_hasText(authorName)) frontmatter['author_name'] = authorName;
    if (_hasText(thumbnailUrl)) frontmatter['thumbnail'] = thumbnailUrl;
    if (_hasText(embedUrl)) frontmatter['embed_url'] = embedUrl;
    if (_hasText(videoUrl)) frontmatter['video_url'] = videoUrl;
    if (_hasText(transcription)) frontmatter['transcription'] = transcription;
    if (mediaUrls.isNotEmpty) frontmatter['media_urls'] = mediaUrls;
    frontmatter['primary_media_index'] = primaryMediaIndex;
    if (postedAt != null) {
      frontmatter['posted_at'] = postedAt!.toIso8601String();
    }
    frontmatter['watched'] = watched;

    final buffer = StringBuffer();
    if (_hasText(caption)) {
      buffer.writeln(caption!.trim());
    }
    if (_hasText(personalNote)) {
      if (buffer.isNotEmpty) buffer.writeln('\n---\n');
      buffer.writeln('## Nota pessoal\n');
      buffer.writeln(personalNote!.trim());
    }
    if (_hasText(transcription)) {
      if (buffer.isNotEmpty) buffer.writeln('\n---\n');
      buffer.writeln('## Transcription\n');
      buffer.writeln(transcription!.trim());
    }

    return generateMarkdown(frontmatter, buffer.toString().trimRight());
  }

  factory SocialPost.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final platform = _enumByName(
      SocialPlatform.values,
      _stringValue(frontmatter['platform']),
      SocialPlatform.other,
    );
    final mediaType = _enumByName(
      SocialMediaType.values,
      _stringValue(frontmatter['media_type']),
      SocialMediaType.other,
    );
    final caption = _stringValue(frontmatter['caption']);
    final url = _stringValue(frontmatter['url']) ?? '';
    final title =
        _stringValue(frontmatter['title']) ??
        _titleFromCaption(caption) ??
        _titleFromUrl(url);

    final post = SocialPost(
      title: title,
      url: url,
      platform: platform,
      mediaType: mediaType,
    );
    post.loadBaseMap(frontmatter);
    if (post.title.trim().isEmpty) post.title = title;
    post.caption = caption;
    post.creator =
        _stringValue(frontmatter['creator']) ??
        _stringValue(frontmatter['author_handle']) ??
        _stringValue(frontmatter['author_name']);
    post.authorHandle = _stringValue(frontmatter['author_handle']);
    post.authorName = _stringValue(frontmatter['author_name']);
    post.thumbnailUrl = _stringValue(
      frontmatter['thumbnail'] ??
          frontmatter['thumbnail_url'] ??
          frontmatter['image'] ??
          frontmatter['image_url'] ??
          frontmatter['cover'] ??
          frontmatter['cover_image'],
    );
    post.embedUrl =
        _stringValue(frontmatter['embed_url']) ??
        _embedUrlFromPlatformUrl(platform, url);
    post.videoUrl = _stringValue(
      frontmatter['video_url'] ?? frontmatter['direct_video_url'],
    );
    post.transcription = _stringValue(frontmatter['transcription']);
    post.mediaUrls = _stringList(
      frontmatter['media_urls'] ??
          frontmatter['media'] ??
          frontmatter['images'] ??
          frontmatter['image_urls'],
    );
    post.primaryMediaIndex =
        int.tryParse(frontmatter['primary_media_index']?.toString() ?? '') ?? 0;
    post.watched = _boolValue(frontmatter['watched']);
    post.postedAt = DateTime.tryParse(
      _stringValue(frontmatter['posted_at']) ?? '',
    );
    final legacyRefs = _stringList(
      frontmatter['social_refs'] ??
          frontmatter['linked_tasks'] ??
          frontmatter['linked_content'],
    );
    if (legacyRefs.isNotEmpty) {
      post.links = {...post.links, ...legacyRefs}.toList();
    }

    post.personalNote = _personalNoteFromBody(body, post.caption);
    post.transcription ??= _transcriptionFromBody(body);
    return post;
  }

  SocialPost copyWith({
    String? title,
    String? url,
    SocialPlatform? platform,
    SocialMediaType? mediaType,
    String? caption,
    String? creator,
    String? authorHandle,
    String? authorName,
    String? thumbnailUrl,
    String? embedUrl,
    String? videoUrl,
    String? transcription,
    List<String>? mediaUrls,
    int? primaryMediaIndex,
    DateTime? postedAt,
    String? personalNote,
    bool? watched,
    List<String>? links,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
    bool? archived,
    bool? pinned,
    int? order,
    List<ReminderConfig>? reminders,
  }) {
    return SocialPost(
      id: id,
      title: title ?? this.title,
      url: url ?? this.url,
      platform: platform ?? this.platform,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      creator: creator ?? this.creator,
      authorHandle: authorHandle ?? this.authorHandle,
      authorName: authorName ?? this.authorName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      embedUrl: embedUrl ?? this.embedUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      transcription: transcription ?? this.transcription,
      mediaUrls: mediaUrls ?? List<String>.from(this.mediaUrls),
      primaryMediaIndex: primaryMediaIndex ?? this.primaryMediaIndex,
      postedAt: postedAt ?? this.postedAt,
      personalNote: personalNote ?? this.personalNote,
      watched: watched ?? this.watched,
      links: links ?? List<String>.from(this.links),
      organizers: organizers ?? List<OrganizerReference>.from(this.organizers),
      categories: categories ?? List<String>.from(this.categories),
      tags: tags ?? List<String>.from(this.tags),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      order: order ?? this.order,
      reminders: reminders ?? List<ReminderConfig>.from(this.reminders),
    );
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => fallback,
    );
  }

  static String? _stringValue(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((item) => item.toString()).join(', ');
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes' || text == 'sim';
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return [];
    return [text];
  }

  static String? _titleFromCaption(String? caption) {
    final text = caption?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text == null || text.isEmpty) return null;
    return text.length <= 80 ? text : '${text.substring(0, 80).trim()}...';
  }

  static String _titleFromUrl(String url) {
    final parsed = Uri.tryParse(url);
    final segment = parsed?.pathSegments
        .where((part) => part.isNotEmpty)
        .lastOrNull;
    if (segment != null && segment.isNotEmpty) return segment;
    return url.isEmpty ? 'Post social' : url;
  }

  static String? _embedUrlFromPlatformUrl(SocialPlatform platform, String url) {
    if (platform != SocialPlatform.pinterest) return null;
    final pinId =
        RegExp(r'/pin/(\d+)').firstMatch(url)?.group(1) ??
        Uri.tryParse(url)?.queryParameters['pin'];
    if (pinId == null || pinId.isEmpty) return null;
    return 'https://assets.pinterest.com/ext/embed.html?id=$pinId';
  }

  static String? _personalNoteFromBody(String body, String? caption) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    const marker = '\n---\n\n## Nota pessoal\n';
    if (trimmed.contains(marker.trim())) {
      return trimmed.split(marker.trim()).last.trim();
    }
    const looseMarker = '## Nota pessoal';
    if (trimmed.contains(looseMarker)) {
      return trimmed.split(looseMarker).last.split('## Transcription').first.trim();
    }
    final captionText = caption?.trim();
    if (captionText != null && captionText.isNotEmpty) {
      final remainder = trimmed.replaceFirst(captionText, '').trim();
      return remainder.isEmpty || remainder == '---' ? null : remainder;
    }
    return trimmed;
  }

  static String? _transcriptionFromBody(String body) {
    const marker = '## Transcription';
    final index = body.indexOf(marker);
    if (index == -1) return null;
    final text = body.substring(index + marker.length).trim();
    return text.isEmpty ? null : text;
  }
}
