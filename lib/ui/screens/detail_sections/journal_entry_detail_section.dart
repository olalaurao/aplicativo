// lib/ui/screens/detail_sections/journal_entry_detail_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/journal_entry.dart';
import '../../../models/mood_model.dart';
import '../../widgets/property_grid.dart';

/// Journal Entry-specific property cards for universal detail view
List<PropertyCard> buildJournalEntryPropertyCards(JournalEntry entry, MoodDefinition? mood) {
  final cards = <PropertyCard>[];
  
  cards.add(PropertyCard(
    icon: Icons.mood,
    label: 'Mood',
    value: mood != null ? '${mood.emoji} ${mood.title}' : (entry.moodSlug ?? 'Não definido'),
    state: mood == null && (entry.moodSlug == null || entry.moodSlug!.isEmpty) ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  cards.add(PropertyCard(
    icon: Icons.access_time,
    label: 'Data/hora',
    value: DateFormat('d MMM yyyy • HH:mm').format(entry.date),
  ));
  if (entry.categories.isNotEmpty) {
    cards.add(PropertyCard(
      icon: Icons.category,
      label: 'Categoria',
      value: entry.categories.first,
    ));
  }
  
  return cards;
}
