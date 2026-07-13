// lib/ui/screens/detail_sections/mood_detail_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/mood_model.dart';
import '../../widgets/property_grid.dart';

/// Mood-specific property cards for universal detail view
List<PropertyCard> buildMoodPropertyCards(MoodDefinition mood) {
  final cards = <PropertyCard>[];
  
  cards.add(PropertyCard(
    icon: Icons.sentiment_satisfied_alt,
    label: 'Emoji',
    value: mood.emoji,
    customChild: Text(
      mood.emoji,
      style: const TextStyle(fontSize: 24),
    ),
  ));
  cards.add(PropertyCard(
    icon: Icons.category,
    label: 'Categoria',
    value: mood.category,
  ));
  cards.add(PropertyCard(
    icon: Icons.calendar_today,
    label: 'Criado',
    value: DateFormat('d MMM yyyy').format(mood.createdAt),
  ));
  
  return cards;
}
