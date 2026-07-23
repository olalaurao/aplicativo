// lib/models/navigation_item.dart
import 'package:flutter/material.dart';

enum NavSection {
  home,
  timeline,
  planner,
  organize,
  trackers,
  pomodoro,
  habits,
  people,
  resources,
  goals,
  notes,
  archive,
  reminders,
  deletedFiles,
  more,
  shortcut, // Added for custom shortcuts
  statistics,
  inbox,
  social,
  dayThemes,
  timeBlocks,
  tasks,
  pillarsValues,
  routines,
  systems,
  replanning,
  areas,
  projects,
  activities,
  labels,
  values,
}

class NavigationItem {
  final NavSection section;
  final String label;
  final String route;
  bool inBottomBar;
  final bool isCustom;
  final String? id; // For shortcuts (objectId or organizerId)
  final String? type; // For shortcuts (e.g., 'task', 'goal', 'area')
  final Map<String, String>? queryParams; // For filters, searches, etc.

  NavigationItem({
    required this.section,
    required this.label,
    required this.route,
    this.inBottomBar = true,
    this.isCustom = false,
    this.id,
    this.type,
    this.queryParams,
  });

  IconData get icon {
    if (isCustom) {
      return _getShortcutIcon(type, active: false);
    }
    return _getSectionIcon(section, active: false);
  }

  IconData get activeIcon {
    if (isCustom) {
      return _getShortcutIcon(type, active: true);
    }
    return _getSectionIcon(section, active: true);
  }

  static IconData _getShortcutIcon(String? type, {required bool active}) {
    switch (type) {
      case 'task':
        return active
            ? Icons.check_circle_rounded
            : Icons.check_circle_outline_rounded;
      case 'goal':
        return active ? Icons.flag_rounded : Icons.flag_outlined;
      case 'habit':
        return active ? Icons.repeat_rounded : Icons.repeat_outlined;
      case 'note':
        return active ? Icons.note_alt_rounded : Icons.note_alt_outlined;
      case 'area':
        return active ? Icons.category_rounded : Icons.category_outlined;
      case 'project':
        return active ? Icons.assignment_rounded : Icons.assignment_outlined;
      case 'person':
        return active ? Icons.person_rounded : Icons.person_outline_rounded;
      case 'social_post':
        return active ? Icons.bookmarks_rounded : Icons.bookmarks_outlined;
      case 'activity':
        return active
            ? Icons.local_activity_rounded
            : Icons.local_activity_outlined;
      default:
        return active ? Icons.link_rounded : Icons.link_outlined;
    }
  }

  static IconData _getSectionIcon(NavSection section, {required bool active}) {
    switch (section) {
      case NavSection.home:
        return active ? Icons.home_rounded : Icons.home_outlined;
      case NavSection.timeline:
        return active
            ? Icons.auto_awesome_motion_rounded
            : Icons.auto_awesome_motion_outlined;
      case NavSection.planner:
        return active
            ? Icons.calendar_today_rounded
            : Icons.calendar_today_outlined;
      case NavSection.organize:
        return active ? Icons.grid_view_rounded : Icons.grid_view_outlined;
      case NavSection.trackers:
        return active ? Icons.analytics_rounded : Icons.analytics_outlined;
      case NavSection.pomodoro:
        return active ? Icons.timer_rounded : Icons.timer_outlined;
      case NavSection.habits:
        return active ? Icons.repeat_rounded : Icons.repeat_outlined;
      case NavSection.people:
        return active ? Icons.people_rounded : Icons.people_outline_rounded;
      case NavSection.resources:
        return active ? Icons.folder_rounded : Icons.folder_outlined;
      case NavSection.goals:
        return active ? Icons.flag_rounded : Icons.flag_outlined;
      case NavSection.notes:
        return active ? Icons.note_alt_rounded : Icons.note_alt_outlined;
      case NavSection.archive:
        return active ? Icons.inventory_2_rounded : Icons.inventory_2_outlined;
      case NavSection.reminders:
        return active
            ? Icons.notifications_active_rounded
            : Icons.notifications_none_rounded;
      case NavSection.deletedFiles:
        return active ? Icons.delete_rounded : Icons.delete_outline_rounded;
      case NavSection.more:
        return active ? Icons.more_horiz_rounded : Icons.more_horiz_outlined;
      case NavSection.shortcut:
        return active ? Icons.link_rounded : Icons.link_outlined;
      case NavSection.statistics:
        return active ? Icons.bar_chart_rounded : Icons.bar_chart_outlined;
      case NavSection.inbox:
        return active ? Icons.inbox_rounded : Icons.inbox_outlined;
      case NavSection.social:
        return active ? Icons.bookmarks_rounded : Icons.bookmarks_outlined;
      case NavSection.dayThemes:
        return active ? Icons.wb_sunny_rounded : Icons.wb_sunny_outlined;
      case NavSection.timeBlocks:
        return active ? Icons.access_time_rounded : Icons.access_time_outlined;
      case NavSection.tasks:
        return active ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded;
      case NavSection.pillarsValues:
        return active ? Icons.star_rounded : Icons.star_outline_rounded;
      case NavSection.routines:
        return active ? Icons.sync_rounded : Icons.sync_outlined;
      case NavSection.systems:
        return active ? Icons.settings_suggest_rounded : Icons.settings_suggest_outlined;
      case NavSection.replanning:
        return active ? Icons.event_busy_rounded : Icons.event_busy_outlined;
      case NavSection.areas:
        return active ? Icons.category_rounded : Icons.category_outlined;
      case NavSection.projects:
        return active ? Icons.assignment_rounded : Icons.assignment_outlined;
      case NavSection.activities:
        return active ? Icons.local_activity_rounded : Icons.local_activity_outlined;
      case NavSection.labels:
        return active ? Icons.label_rounded : Icons.label_outline_rounded;
      case NavSection.values:
        return active ? Icons.star_rounded : Icons.star_outline_rounded;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'section': section.name,
      'label': label,
      'route': route,
      'inBottomBar': inBottomBar,
      'isCustom': isCustom,
      'id': id,
      'type': type,
      'queryParams': queryParams,
    };
  }

  factory NavigationItem.fromMap(Map<String, dynamic> map) {
    final queryParamsMap = map['queryParams'];
    Map<String, String>? queryParams;
    if (queryParamsMap != null && queryParamsMap is Map<String, dynamic>) {
      queryParams = queryParamsMap.map(
        (key, value) => MapEntry(key, value.toString()),
      );
    }

    return NavigationItem(
      section: NavSection.values.firstWhere(
        (e) => e.name == map['section'],
        orElse: () => NavSection.shortcut,
      ),
      label: map['label'],
      route: map['route'],
      inBottomBar: map['inBottomBar'] ?? true,
      isCustom: map['isCustom'] ?? false,
      id: map['id'],
      type: map['type'],
      queryParams: queryParams,
    );
  }
}
