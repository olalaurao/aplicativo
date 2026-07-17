// lib/ui/screens/detail_sections/tracker_detail_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/tracker_model.dart';
import '../../widgets/property_grid.dart';

/// Tracker-specific property cards for universal detail view
List<PropertyCard> buildTrackerPropertyCards(TrackerDefinition tracker) {
  final cards = <PropertyCard>[];
  
  cards.add(PropertyCard(
    icon: Icons.category,
    label: 'Tipo',
    value: tracker.isHealthTracker ? 'Health Tracker' : 'Tracker',
  ));
  cards.add(PropertyCard(
    icon: Icons.calendar_today,
    label: 'Criado',
    value: DateFormat('d MMM yyyy').format(tracker.createdAt),
  ));
  cards.add(PropertyCard(
    icon: Icons.list,
    label: 'Seções',
    value: tracker.sections.length.toString(),
  ));
  
  return cards;
}
