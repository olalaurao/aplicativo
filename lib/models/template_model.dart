import 'package:uuid/uuid.dart';
import 'content_object.dart';
import 'shared_types.dart';

class TemplateDefinition extends ContentObject {
  /// V5: The object type this template applies to.
  /// One of: 'entry', 'task', 'note', 'habit', 'tracker', 'goal', 'project', 'event', 'reminder'
  final String templateType;
  final String body;
  final Map<String, dynamic> frontmatterDefaults;

  TemplateDefinition({
    super.id,
    required super.title,
    required this.templateType,
    this.body = '',
    this.frontmatterDefaults = const {},
    super.createdAt,
    super.updatedAt,
    super.organizers,
    super.tags,
    super.categories,
    super.obsidianPath,
    super.archived,
    super.pinned,
  });

  @override
  String get type => 'template';

  @override
  bool get isIncomplete => title.trim().isEmpty || templateType.trim().isEmpty;

  TemplateDefinition copyWith({
    String? id,
    String? title,
    String? templateType,
    String? body,
    Map<String, dynamic>? frontmatterDefaults,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrganizerReference>? organizers,
    List<String>? tags,
    List<String>? categories,
    String? obsidianPath,
    bool? archived,
    bool? pinned,
  }) {
    final t = TemplateDefinition(
      id: id ?? this.id,
      title: title ?? this.title,
      templateType: templateType ?? this.templateType,
      body: body ?? this.body,
      frontmatterDefaults: frontmatterDefaults ?? this.frontmatterDefaults,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      organizers: organizers ?? this.organizers,
      tags: tags ?? this.tags,
      categories: categories ?? this.categories,
      obsidianPath: obsidianPath ?? this.obsidianPath,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
    );
    return t;
  }

  factory TemplateDefinition.create({
    required String title,
    required String templateType,
    String body = '',
    Map<String, dynamic> frontmatterDefaults = const {},
  }) {
    return TemplateDefinition(
      id: const Uuid().v4(),
      title: title,
      templateType: templateType,
      body: body,
      frontmatterDefaults: frontmatterDefaults,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// V5: Reads from Obsidian-style markdown frontmatter (snake_case keys).
  factory TemplateDefinition.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    // Support both snake_case (new) and camelCase (legacy) keys
    final tmplType = frontmatter['template_type']?.toString()
        ?? frontmatter['templateType']?.toString()
        ?? 'note';
    final rawDefaults = frontmatter['frontmatter_defaults']
        ?? frontmatter['frontmatterDefaults'];
    final defaults = rawDefaults is Map
        ? Map<String, dynamic>.from(rawDefaults)
        : <String, dynamic>{};

    final t = TemplateDefinition(
      title: frontmatter['title']?.toString() ?? 'Sem Título',
      templateType: tmplType,
      body: body,
      frontmatterDefaults: defaults,
    );
    t.loadBaseMap(frontmatter);
    return t;
  }

  /// Legacy fromMap for backwards compatibility.
  factory TemplateDefinition.fromMap(
    Map<String, dynamic> map,
    String id, {
    String? body,
  }) {
    final fmDefaults = map['frontmatter_defaults'] != null
        ? Map<String, dynamic>.from(map['frontmatter_defaults'] as Map)
        : map['frontmatterDefaults'] != null
            ? Map<String, dynamic>.from(map['frontmatterDefaults'] as Map)
            : <String, dynamic>{};

    final t = TemplateDefinition(
      id: id,
      title: map['title'] as String? ?? 'Sem Título',
      templateType: map['template_type'] as String?
          ?? map['templateType'] as String?
          ?? 'note',
      body: body ?? '',
      frontmatterDefaults: fmDefaults,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
    t.loadBaseMap(map, fallbackId: id);
    return t;
  }

  Map<String, dynamic> toMap() {
    final map = toBaseMap();
    map.addAll({
      'template_type': templateType,
      'frontmatter_defaults': frontmatterDefaults,
    });
    return map;
  }

  @override
  String toMarkdown() {
    final fm = toMap();
    return generateMarkdown(fm, body);
  }
}
