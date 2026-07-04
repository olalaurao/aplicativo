// lib/models/wellbeing_indicator_model.dart
import 'package:uuid/uuid.dart';
import 'content_object.dart';
import 'shared_types.dart';

enum SignalStatus { healthy, watch, alert }

enum DisplayMode { individual, composite }

class SignalBand {
  final SignalStatus status;
  final double? min;
  final double? max;
  final int? daysSinceLastEntry; // For absence-based alerts
  final String? description;

  SignalBand({
    required this.status,
    this.min,
    this.max,
    this.daysSinceLastEntry,
    this.description,
  });

  Map<String, dynamic> toMap() => {
    'status': status.name,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (daysSinceLastEntry != null) 'days_since_last_entry': daysSinceLastEntry,
    if (description != null) 'description': description,
  };

  factory SignalBand.fromMap(Map<String, dynamic> map) => SignalBand(
    status: SignalStatus.values.firstWhere(
      (e) => e.name == map['status']?.toString(),
      orElse: () => SignalStatus.healthy,
    ),
    min: map['min']?.toDouble(),
    max: map['max']?.toDouble(),
    daysSinceLastEntry: map['days_since_last_entry']?.toInt(),
    description: map['description']?.toString(),
  );
}

class Signal {
  final String id;
  final DataSourceReference dataSource;
  final List<SignalBand> bands;
  final double? weight; // Optional, used for composite display mode
  final String? label;

  Signal({
    String? id,
    required this.dataSource,
    required this.bands,
    this.weight,
    this.label,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'data_source': dataSource.toMap(),
    'bands': bands.map((b) => b.toMap()).toList(),
    if (weight != null) 'weight': weight,
    if (label != null) 'label': label,
  };

  factory Signal.fromMap(Map<String, dynamic> map) => Signal(
    id: map['id']?.toString() ?? const Uuid().v4(),
    dataSource: DataSourceReference.fromMap(
      Map<String, dynamic>.from(map['data_source'] as Map),
    ),
    bands: (map['bands'] as List?)
        ?.map((b) => SignalBand.fromMap(Map<String, dynamic>.from(b as Map)))
        .toList() ?? [],
    weight: map['weight']?.toDouble(),
    label: map['label']?.toString(),
  );
}

class WellbeingIndicator extends ContentObject {
  final String? icon;
  final List<Signal> signals;
  final DisplayMode displayMode;

  WellbeingIndicator({
    super.id,
    required super.title,
    this.icon,
    this.signals = const [],
    this.displayMode = DisplayMode.individual,
    super.organizers,
    super.tags,
    super.aliases,
    super.archived,
    super.pinned,
    super.order,
    super.obsidianPath,
  });

  @override
  String get type => 'wellbeing_indicator';

  @override
  bool get isIncomplete => title.trim().isEmpty || signals.isEmpty;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['display_mode'] = displayMode.name;
    frontmatter['signals'] = signals.map((s) => s.toMap()).toList();
    return generateMarkdown(frontmatter, '');
  }

  factory WellbeingIndicator.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final indicator = WellbeingIndicator(
      id: frontmatter['id'] as String? ?? const Uuid().v4(),
      title: frontmatter['title'] as String? ?? '',
      icon: frontmatter['icon'] as String?,
      displayMode: DisplayMode.values.firstWhere(
        (e) => e.name == frontmatter['display_mode']?.toString(),
        orElse: () => DisplayMode.individual,
      ),
      signals: (frontmatter['signals'] as List?)
          ?.map((s) => Signal.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList() ?? [],
      organizers: (frontmatter['organizers'] as List?)
          ?.map((o) => OrganizerReference.fromWikiLink(o.toString()))
          .toList() ?? [],
      tags: List<String>.from(frontmatter['tags'] ?? []),
      aliases: List<String>.from(frontmatter['aliases'] ?? []),
      archived: frontmatter['archived'] as bool? ?? false,
      pinned: frontmatter['pinned'] as bool? ?? false,
      order: (frontmatter['order'] as num? ?? 0).toInt(),
      obsidianPath: frontmatter['obsidian_path'] as String? ?? '',
    );
    indicator.loadBaseMap(frontmatter);
    return indicator;
  }

  WellbeingIndicator copyWith({
    String? id,
    String? title,
    String? icon,
    List<Signal>? signals,
    DisplayMode? displayMode,
    List<OrganizerReference>? organizers,
    List<String>? tags,
    List<String>? aliases,
    bool? archived,
    bool? pinned,
    int? order,
    String? obsidianPath,
  }) {
    final copy = WellbeingIndicator(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      signals: signals ?? this.signals,
      displayMode: displayMode ?? this.displayMode,
      organizers: organizers ?? this.organizers,
      tags: tags ?? this.tags,
      aliases: aliases ?? this.aliases,
      archived: archived ?? this.archived,
      pinned: pinned ?? this.pinned,
      order: order ?? this.order,
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
    copy.loadBaseMap(toBaseMap());
    return copy;
  }
}
