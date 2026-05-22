import 'package:uuid/uuid.dart';
import 'content_object.dart';
import 'shared_types.dart';

class TemplateDefinition extends ContentObject {
  final String templateType; // 'entry', 'task', 'note', 'habit', 'tracker'
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
    super.moc,
  });

  @override
  String get type => 'template';

  TemplateDefinition copyWith({
    String? id,
    String? title,
    String? templateType,
    String? body,
    Map<String, dynamic>? frontmatterDefaults,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrganizerReference>? organizers,
    List<String>? moc,
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
      moc: moc ?? this.moc,
    );
    t.obsidianPath = obsidianPath;
    t.archived = archived;
    t.pinned = pinned;
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

  factory TemplateDefinition.fromMap(Map<String, dynamic> map, String id, {String? body}) {
    final fmDefaults = map['frontmatterDefaults'] != null 
        ? Map<String, dynamic>.from(map['frontmatterDefaults'] as Map)
        : <String, dynamic>{};
        
    final t = TemplateDefinition(
      id: id,
      title: map['title'] as String? ?? 'Sem Título',
      templateType: map['templateType'] as String? ?? 'note',
      body: body ?? '',
      frontmatterDefaults: fmDefaults,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
      moc: (map['moc'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
    t.loadBaseMap(map, fallbackId: id);
    return t;
  }

  @override
  Map<String, dynamic> toMap() {
    final map = toBaseMap();
    map.addAll({
      'templateType': templateType,
      'frontmatterDefaults': frontmatterDefaults,
    });
    return map;
  }

  @override
  String toMarkdown() {
    final fm = toMap();
    fm.remove('body'); // Ensure body is not in frontmatter
    return generateMarkdown(fm, body);
  }
}
