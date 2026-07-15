// lib/ui/screens/detail_sections/pillar_detail_section.dart
import 'package:flutter/material.dart';
import '../../../models/pillar_model.dart';
import '../../widgets/property_grid.dart';

/// Pillar-specific property cards for universal detail view
List<PropertyCard> buildPillarPropertyCards(Pillar pillar) {
  final cards = <PropertyCard>[];

  cards.add(PropertyCard(
    icon: Icons.account_balance,
    label: 'Color',
    value: pillar.color,
    state: PropertyCardState.normal,
  ));

  if (pillar.why != null && pillar.why!.isNotEmpty) {
    cards.add(PropertyCard(
      icon: Icons.lightbulb_outline,
      label: 'Why',
      value: pillar.why!,
      state: PropertyCardState.normal,
    ));
  }

  final lastTouch = pillar.lastTouch;
  if (lastTouch != null) {
    final daysSince = DateTime.now().difference(lastTouch).inDays;
    cards.add(PropertyCard(
      icon: Icons.touch_app,
      label: 'Last touch',
      value: daysSince == 0 ? 'Today' : '$daysSince days ago',
      state: PropertyCardState.normal,
    ));
  }

  final touches7Days = pillar.touchesInLast(7);
  cards.add(PropertyCard(
    icon: Icons.history,
    label: 'Touches (7d)',
    value: '$touches7Days',
    state: touches7Days > 0 ? PropertyCardState.streakActive : PropertyCardState.empty,
  ));

  final touches30Days = pillar.touchesInLast(30);
  cards.add(PropertyCard(
    icon: Icons.calendar_month,
    label: 'Touches (30d)',
    value: '$touches30Days',
    state: PropertyCardState.normal,
  ));

  if (pillar.categories.isNotEmpty) {
    cards.add(PropertyCard(
      icon: Icons.category,
      label: 'Category',
      value: pillar.categories.first,
      state: PropertyCardState.normal,
    ));
  }

  return cards;
}
