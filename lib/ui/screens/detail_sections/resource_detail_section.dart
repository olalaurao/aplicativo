// lib/ui/screens/detail_sections/resource_detail_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/resource_model.dart';
import '../../widgets/property_grid.dart';

/// Resource-specific property cards for universal detail view
List<PropertyCard> buildResourcePropertyCards(Resource resource) {
  final cards = <PropertyCard>[];
  
  final readDateStr = resource.readDate != null
      ? DateFormat('d MMM yyyy').format(resource.readDate!)
      : 'Não lido';
  cards.add(PropertyCard(
    icon: Icons.menu_book,
    label: 'Status',
    value: readDateStr,
    state: resource.readDate == null ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  if (resource.author != null) {
    cards.add(PropertyCard(
      icon: Icons.person,
      label: 'Autor',
      value: resource.author!,
    ));
  }
  if (resource.year != null) {
    cards.add(PropertyCard(
      icon: Icons.calendar_today,
      label: 'Ano',
      value: resource.year.toString(),
    ));
  }
  if (resource.tags.isNotEmpty) {
    cards.add(PropertyCard(
      icon: Icons.local_offer,
      label: 'Tags',
      value: resource.tags.join(', '),
    ));
  }
  
  return cards;
}
