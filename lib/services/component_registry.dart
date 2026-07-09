import 'package:flutter/material.dart';
import '../models/dashboard_block.dart';

class ComponentDefinition {
  final BlockType type;
  final String defaultTitle;
  final String description;
  final IconData icon;
  final Map<String, dynamic> defaultMetadata;
  final bool allowMultipleInstances;

  const ComponentDefinition({
    required this.type,
    required this.defaultTitle,
    required this.description,
    required this.icon,
    this.defaultMetadata = const {},
    this.allowMultipleInstances = false,
  });
}

const componentRegistry = <ComponentDefinition>[
  ComponentDefinition(
    type: BlockType.todayTimeline,
    defaultTitle: 'Timeline',
    description: 'Everything created or scheduled today, in order',
    icon: Icons.timeline_rounded,
    defaultMetadata: {'maxItems': 12, 'showUntimedGroup': true},
    allowMultipleInstances: false,
  ),
  ComponentDefinition(
    type: BlockType.todayDial,
    defaultTitle: 'Day Dial',
    description: '24-hour view of how your day is filling up',
    icon: Icons.donut_large_rounded,
    defaultMetadata: {'showLegend': true, 'showSummaryStats': true},
    allowMultipleInstances: false,
  ),
  ComponentDefinition(
    type: BlockType.shoppingQuickAdd,
    defaultTitle: 'Quick Add — Shopping',
    description: 'Add an item to a shopping list without leaving Home',
    icon: Icons.add_shopping_cart_rounded,
    defaultMetadata: {'shoppingListId': null, 'previewCount': 3},
    allowMultipleInstances: true,
  ),
  ComponentDefinition(
    type: BlockType.weekOverview,
    defaultTitle: 'This Week',
    description: '7-day glance at what is coming up',
    icon: Icons.view_week_rounded,
    defaultMetadata: {'weekStartsMonday': true, 'maxItemsPerDay': 3},
    allowMultipleInstances: false,
  ),
  ComponentDefinition(
    type: BlockType.monthOverview,
    defaultTitle: 'This Month',
    description: 'Full calendar-month glance',
    icon: Icons.calendar_view_month_rounded,
    defaultMetadata: {'maxChipsPerCell': 2},
    allowMultipleInstances: false,
  ),
  ComponentDefinition(
    type: BlockType.goalsProjectsOverview,
    defaultTitle: 'Goals & Projects',
    description: 'Progress at a glance',
    icon: Icons.flag_rounded,
    defaultMetadata: {
      'maxItems': 5,
      'sortMode': 'progress_asc', // progress_asc | progress_desc | manual
      'includeCompleted': false,
      'typeFilter': 'all', // all | goals_only | projects_only
    },
    allowMultipleInstances: true,
  ),
  ComponentDefinition(
    type: BlockType.todayCompletables,
    defaultTitle: "Today's Completables",
    description: 'Tasks, habits and more you can check off today',
    icon: Icons.checklist_rounded,
    defaultMetadata: {'maxItems': 8, 'includeEvents': false},
    allowMultipleInstances: false,
  ),
];
