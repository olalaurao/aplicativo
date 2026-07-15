// lib/models/routine_model.dart
import 'content_object.dart';
import 'organizer_model.dart';
import 'scheduler.dart';
import 'reminder_config.dart';
import 'shared_types.dart';

class RoutineItem {
  final String id;
  final String referencedObjectId; // WikiLink to any vault object
  final int order;
  final bool required;

  RoutineItem({
    required this.id,
    required this.referencedObjectId,
    required this.order,
    this.required = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'referenced_object_id': referencedObjectId,
    'order': order,
    'required': required,
  };

  factory RoutineItem.fromMap(Map<String, dynamic> map) => RoutineItem(
    id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    referencedObjectId: map['referenced_object_id']?.toString() ?? '',
    order: map['order'] as int? ?? 0,
    required: map['required'] == true,
  );

  RoutineItem copyWith({
    String? id,
    String? referencedObjectId,
    int? order,
    bool? required,
  }) => RoutineItem(
    id: id ?? this.id,
    referencedObjectId: referencedObjectId ?? this.referencedObjectId,
    order: order ?? this.order,
    required: required ?? this.required,
  );
}

class RoutineExecution {
  final DateTime executedAt;
  final Map<String, bool> itemCompletions; // itemId -> completed status
  final String? notes;
  final String? moodBefore;
  final String? moodAfter;

  RoutineExecution({
    required this.executedAt,
    required this.itemCompletions,
    this.notes,
    this.moodBefore,
    this.moodAfter,
  });

  Map<String, dynamic> toMap() => {
    'executed_at': executedAt.toIso8601String(),
    'item_completions': itemCompletions,
    if (notes != null) 'notes': notes,
    if (moodBefore != null) 'mood_before': moodBefore,
    if (moodAfter != null) 'mood_after': moodAfter,
  };

  factory RoutineExecution.fromMap(Map<String, dynamic> map) => RoutineExecution(
    executedAt: DateTime.tryParse(map['executed_at']?.toString() ?? '') ?? DateTime.now(),
    itemCompletions: Map<String, bool>.from(map['item_completions'] as Map? ?? {}),
    notes: map['notes']?.toString(),
    moodBefore: map['mood_before']?.toString(),
    moodAfter: map['mood_after']?.toString(),
  );

  RoutineExecution copyWith({
    DateTime? executedAt,
    Map<String, bool>? itemCompletions,
    String? notes,
    String? moodBefore,
    String? moodAfter,
  }) => RoutineExecution(
    executedAt: executedAt ?? this.executedAt,
    itemCompletions: itemCompletions ?? this.itemCompletions,
    notes: notes ?? this.notes,
    moodBefore: moodBefore ?? this.moodBefore,
    moodAfter: moodAfter ?? this.moodAfter,
  );
}

class Routine extends Organizer {
  final List<RoutineItem> items;
  final List<RoutineExecution> executionHistory;
  final bool showInPlanner;
  final String? moodTrigger;

  Routine({
    super.id,
    required super.title,
    this.items = const [],
    this.executionHistory = const [],
    this.showInPlanner = true,
    this.moodTrigger,
    super.parentId,
    super.startDate,
    super.endDate,
    super.color,
    super.icon,
    super.state,
    super.priority,
    super.statement,
    super.timeRanges = const [],
    super.energyLevel,
    super.daysOfWeek = const [],
    super.scheduler,
    super.reminders = const [],
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  }) : super(
    organizerType: OrganizerType.routine,
  );

  @override
  String get type => 'routine';

  @override
  bool get isIncomplete => title.trim().isEmpty;

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['organizer_type'] = organizerType.name;
    
    if (parentId != null) frontmatter['parent_id'] = parentId;
    if (startDate != null) {
      frontmatter['start_date'] = startDate!.toIso8601String();
    }
    if (endDate != null) frontmatter['end_date'] = endDate!.toIso8601String();
    if (color != null) frontmatter['color'] = color;
    if (icon != null) frontmatter['icon'] = icon;
    if (state != null) frontmatter['state'] = state;
    if (priority != null) frontmatter['priority'] = priority;
    if (statement != null) frontmatter['statement'] = statement;
    if (timeRanges.isNotEmpty) {
      frontmatter['time_ranges'] = timeRanges.map((tr) => tr.toMap()).toList();
    }
    if (energyLevel != null) frontmatter['energy_level'] = energyLevel;
    if (daysOfWeek.isNotEmpty) frontmatter['days_of_week'] = daysOfWeek;
    if (scheduler != null) frontmatter['scheduler'] = scheduler!.toMap();
    if (reminders.isNotEmpty) {
      frontmatter['reminders'] = reminders.map((r) => r.toMap()).toList();
    }
    
    // Routine-specific fields
    if (items.isNotEmpty) {
      frontmatter['items'] = items.map((i) => i.toMap()).toList();
    }
    frontmatter['show_in_planner'] = showInPlanner;
    if (moodTrigger != null) frontmatter['mood_trigger'] = moodTrigger;

    // Build body with execution history
    final buffer = StringBuffer();
    if (executionHistory.isNotEmpty) {
      buffer.writeln('## Execution History');
      for (final execution in executionHistory) {
        final dateStr = execution.executedAt.toIso8601String().split('T').first;
        final timeStr = execution.executedAt.toIso8601String().split('T')[1].substring(0, 5);
        final completedCount = execution.itemCompletions.values.where((v) => v).length;
        final totalCount = execution.itemCompletions.length;
        
        buffer.writeln('### $dateStr $timeStr');
        buffer.writeln('Completed: $completedCount/$totalCount');
        if (execution.moodBefore != null) {
          buffer.writeln('Mood before: ${execution.moodBefore}');
        }
        if (execution.moodAfter != null) {
          buffer.writeln('Mood after: ${execution.moodAfter}');
        }
        if (execution.notes != null && execution.notes!.isNotEmpty) {
          buffer.writeln('Notes: ${execution.notes}');
        }
        buffer.writeln();
      }
    }

    return generateMarkdown(frontmatter, buffer.toString());
  }

  factory Routine.fromMarkdown(Map<String, dynamic> frontmatter, String body) {
    final routine = Routine(
      title: frontmatter['title'] is List
          ? (frontmatter['title'] as List).join(', ')
          : frontmatter['title']?.toString() ?? '',
    );
    routine.loadBaseMap(frontmatter);

    routine.parentId = frontmatter['parent_id'] as String?;
    if (frontmatter['start_date'] != null) {
      routine.startDate = DateTime.tryParse(frontmatter['start_date']);
    }
    if (frontmatter['end_date'] != null) {
      routine.endDate = DateTime.tryParse(frontmatter['end_date']);
    }
    routine.color = frontmatter['color'] as String?;
    routine.icon = frontmatter['icon'] as String?;
    routine.state = frontmatter['state'] as String?;
    routine.priority = frontmatter['priority'] as String?;
    routine.statement = frontmatter['statement'] as String?;

    routine.timeRanges =
        (frontmatter['time_ranges'] as List?)
            ?.map((e) => TimeRange.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    routine.energyLevel = frontmatter['energy_level'] as int?;
    routine.daysOfWeek = List<String>.from(
      frontmatter['days_of_week'] as List? ?? [],
    );
    if (frontmatter['scheduler'] is Map) {
      routine.scheduler = Scheduler.fromMap(
        Map<String, dynamic>.from(frontmatter['scheduler'] as Map),
      );
    }
    if (frontmatter['reminders'] is List) {
      routine.reminders = (frontmatter['reminders'] as List)
          .map((e) => ReminderConfig.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    // Routine-specific fields
    final routineItems = frontmatter['items'] is List
        ? (frontmatter['items'] as List)
            .whereType<Map>()
            .map((m) => RoutineItem.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <RoutineItem>[];
    final routineShowInPlanner = frontmatter['show_in_planner'] == true;
    final routineMoodTrigger = frontmatter['mood_trigger']?.toString();

    return routine.copyWith(
      items: routineItems,
      showInPlanner: routineShowInPlanner,
      moodTrigger: routineMoodTrigger,
    );
  }

  Routine copyWith({
    String? title,
    OrganizerType? organizerType,
    List<RoutineItem>? items,
    List<RoutineExecution>? executionHistory,
    bool? showInPlanner,
    String? moodTrigger,
    String? parentId,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
    String? icon,
    String? state,
    String? priority,
    String? statement,
    List<TimeRange>? timeRanges,
    int? energyLevel,
    List<String>? daysOfWeek,
    Scheduler? scheduler,
    List<ReminderConfig>? reminders,
    List<OrganizerReference>? organizers,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? obsidianPath,
  }) {
    return Routine(
      id: id,
      title: title ?? this.title,
      items: items ?? this.items,
      executionHistory: executionHistory ?? this.executionHistory,
      showInPlanner: showInPlanner ?? this.showInPlanner,
      moodTrigger: moodTrigger ?? this.moodTrigger,
      parentId: parentId ?? this.parentId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      state: state ?? this.state,
      priority: priority ?? this.priority,
      statement: statement ?? this.statement,
      timeRanges: timeRanges ?? this.timeRanges,
      energyLevel: energyLevel ?? this.energyLevel,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      scheduler: scheduler ?? this.scheduler,
      reminders: reminders ?? this.reminders,
      organizers: organizers ?? this.organizers,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      obsidianPath: obsidianPath ?? this.obsidianPath,
    );
  }
}
