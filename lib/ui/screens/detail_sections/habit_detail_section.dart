// lib/ui/screens/detail_sections/habit_detail_section.dart
import 'package:flutter/material.dart';
import '../../../models/habit_model.dart';
import '../../widgets/property_grid.dart';

/// Habit-specific property cards for universal detail view
List<PropertyCard> buildHabitPropertyCards(Habit habit) {
  final cards = <PropertyCard>[];
  
  if (!habit.isChecklistHabit) {
    cards.add(PropertyCard(
      icon: Icons.repeat,
      label: 'Frequency',
      value: habit.scheduler?.rules.isNotEmpty == true 
          ? habit.scheduler!.rules.first.repeatType.name 
          : 'Not set',
      state: habit.scheduler == null || habit.scheduler!.rules.isEmpty 
          ? PropertyCardState.empty 
          : PropertyCardState.normal,
    ));
    cards.add(PropertyCard(
      icon: Icons.local_fire_department,
      label: 'Streak',
      value: '${habit.streak} 🔥',
      state: habit.streak > 0 ? PropertyCardState.streakActive : PropertyCardState.normal,
    ));
    cards.add(PropertyCard(
      icon: Icons.history,
      label: 'Last record',
      value: habit.daysSinceLastCompletion == 0 
          ? 'Today' 
          : '${habit.daysSinceLastCompletion} days ago',
      state: habit.completionHistory.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
    ));
    cards.add(PropertyCard(
      icon: Icons.category,
      label: 'Category',
      value: habit.categories.isNotEmpty ? habit.categories.first : 'Not set',
      state: habit.categories.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
    ));
  }
  
  return cards;
}
