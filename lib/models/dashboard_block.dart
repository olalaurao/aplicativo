// lib/models/dashboard_block.dart

import 'shared_types.dart';
import '../services/daily_schedule_service.dart';

// F3.8: V5 deduplicated list retired - panel system being redesigned from blank slate
// Only core mechanics preserved until redesign is complete
enum BlockType {
  todayHabits, // Kept for migration only
  todayCompletables,
  todayTimeline,
  todayDial,
  shoppingQuickAdd,
  weekOverview,
  monthOverview,
  goalsProjectsOverview,
  pinnedObject,      // Generic pinned ContentObject (any type)
  trackerAnalysis,   // Chart/stats for a specific tracker or mood
  weeklyFocus,       // This week's 3 focus tasks
  timeBalance,       // Block A
  whereTimeGoes,     // Block A
  rhythmHeatmap,     // Block B
  energyChart,       // Block B
  rechargeVsDrain,   // Block C
  focusByOrganizer,  // Block D
  plannedVsExecuted, // Block D
  custom,
  // Legacy types preserved for backward compatibility during migration
  universal,
  shortcuts,
  timeline,
  tasks,
  goals,
  notes,
  calendar,
}

class DashboardBlock {
  final String id;
  final BlockType type;
  final String title;
  bool visible;
  int order;
  final Map<String, dynamic> metadata;

  DashboardBlock({
    required this.id,
    required this.type,
    required this.title,
    this.visible = true,
    this.order = 0,
    this.metadata = const {},
  });

  DashboardBlock copyWith({
    String? id,
    BlockType? type,
    String? title,
    bool? visible,
    int? order,
    Map<String, dynamic>? metadata,
  }) {
    return DashboardBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      visible: visible ?? this.visible,
      order: order ?? this.order,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'visible': visible,
      'order': order,
      'metadata': metadata,
    };
  }

  factory DashboardBlock.fromMap(Map<String, dynamic> map) {
    return DashboardBlock(
      id: map['id'] as String? ?? 'block-${DateTime.now().millisecondsSinceEpoch}',
      type: BlockType.values.firstWhere(
        (e) => e.name == map['type'],
        // Fallback seguro: tipos obsoletos/desconhecidos caem em custom
        orElse: () => BlockType.custom,
      ),
      title: map['title'] as String? ?? '',
      visible: map['visible'] as bool? ?? true,
      order: map['order'] as int? ?? 0,
      metadata: (map['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}

// ScheduleSurfaceFilter - reusable filter model for dashboard blocks and widget config
class ScheduleSurfaceFilter {
  final Set<DailyScheduleKind> visibleKinds;
  final bool includeTimed;
  final bool includeAllDay;
  final bool includeCompletableOnly;
  final bool includeCompleted;
  final List<OrganizerReference>? organizerRefs;
  final int? maxItems;
  final int? maxItemsPerDay;
  final int? maxChipsPerCell;

  ScheduleSurfaceFilter({
    Set<DailyScheduleKind>? visibleKinds,
    this.includeTimed = true,
    this.includeAllDay = true,
    this.includeCompletableOnly = false,
    this.includeCompleted = false,
    this.organizerRefs,
    this.maxItems,
    this.maxItemsPerDay,
    this.maxChipsPerCell,
  }) : visibleKinds = visibleKinds ?? _defaultVisibleKinds;

  static Set<DailyScheduleKind> get _defaultVisibleKinds => {
        DailyScheduleKind.task,
        DailyScheduleKind.habit,
        DailyScheduleKind.event,
        DailyScheduleKind.googleCalendar,
        DailyScheduleKind.reminder,
        DailyScheduleKind.pomodoro,
        DailyScheduleKind.trackerRecord,
        DailyScheduleKind.journalEntry,
        DailyScheduleKind.timeBlock,
        DailyScheduleKind.system,
        DailyScheduleKind.rotationZone,
        DailyScheduleKind.personContact,
      };

  Map<String, dynamic> toMap() {
    return {
      'visibleKinds': visibleKinds.map((k) => k.name).toList(),
      'includeTimed': includeTimed,
      'includeAllDay': includeAllDay,
      'includeCompletableOnly': includeCompletableOnly,
      'includeCompleted': includeCompleted,
      if (organizerRefs != null && organizerRefs!.isNotEmpty)
        'organizerRefs': organizerRefs!.map((r) => r.toMap()).toList(),
      if (maxItems != null) 'maxItems': maxItems,
      if (maxItemsPerDay != null) 'maxItemsPerDay': maxItemsPerDay,
      if (maxChipsPerCell != null) 'maxChipsPerCell': maxChipsPerCell,
    };
  }

  factory ScheduleSurfaceFilter.fromMap(Map<String, dynamic> map) {
    final rawKinds = map['visibleKinds'] as List?;
    final visibleKinds = rawKinds != null
        ? rawKinds
            .map((k) => DailyScheduleKind.values.firstWhere(
                  (e) => e.name == k,
                  orElse: () => DailyScheduleKind.task,
                ))
            .toSet()
        : null;

    final rawOrganizerRefs = map['organizerRefs'] as List?;
    final organizerRefs = rawOrganizerRefs != null
        ? rawOrganizerRefs
            .map((r) => OrganizerReference.fromMap(r as Map<String, dynamic>))
            .toList()
        : null;

    return ScheduleSurfaceFilter(
      visibleKinds: visibleKinds,
      includeTimed: map['includeTimed'] as bool? ?? true,
      includeAllDay: map['includeAllDay'] as bool? ?? true,
      includeCompletableOnly: map['includeCompletableOnly'] as bool? ?? false,
      includeCompleted: map['includeCompleted'] as bool? ?? false,
      organizerRefs: organizerRefs,
      maxItems: map['maxItems'] as int?,
      maxItemsPerDay: map['maxItemsPerDay'] as int?,
      maxChipsPerCell: map['maxChipsPerCell'] as int?,
    );
  }

  ScheduleSurfaceFilter copyWith({
    Set<DailyScheduleKind>? visibleKinds,
    bool? includeTimed,
    bool? includeAllDay,
    bool? includeCompletableOnly,
    bool? includeCompleted,
    List<OrganizerReference>? organizerRefs,
    int? maxItems,
    int? maxItemsPerDay,
    int? maxChipsPerCell,
  }) {
    return ScheduleSurfaceFilter(
      visibleKinds: visibleKinds ?? this.visibleKinds,
      includeTimed: includeTimed ?? this.includeTimed,
      includeAllDay: includeAllDay ?? this.includeAllDay,
      includeCompletableOnly: includeCompletableOnly ?? this.includeCompletableOnly,
      includeCompleted: includeCompleted ?? this.includeCompleted,
      organizerRefs: organizerRefs ?? this.organizerRefs,
      maxItems: maxItems ?? this.maxItems,
      maxItemsPerDay: maxItemsPerDay ?? this.maxItemsPerDay,
      maxChipsPerCell: maxChipsPerCell ?? this.maxChipsPerCell,
    );
  }

  static ScheduleSurfaceFilter get defaultPlannerFilter => ScheduleSurfaceFilter();

  static ScheduleSurfaceFilter get defaultTodayTimelineFilter =>
      ScheduleSurfaceFilter();

  static ScheduleSurfaceFilter get defaultCompletablesFilter =>
      ScheduleSurfaceFilter(
        includeCompletableOnly: true,
        visibleKinds: {
          DailyScheduleKind.task,
          DailyScheduleKind.habit,
        },
      );

  static ScheduleSurfaceFilter get defaultWeekOverviewFilter =>
      ScheduleSurfaceFilter(maxItemsPerDay: 10);

  static ScheduleSurfaceFilter get defaultMonthOverviewFilter =>
      ScheduleSurfaceFilter(maxChipsPerCell: 3);
}
