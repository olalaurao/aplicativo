// lib/ui/screens/detail_sections/habit_content_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/habit_model.dart';

/// Habit-specific content section for universal detail view
List<Widget> buildHabitContentSection(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  Widget Function(BuildContext, WidgetRef, Habit) buildHabitLinkedItemsSliver,
  Widget Function(BuildContext, WidgetRef, Habit) buildHabitChecklistSliver,
  Widget Function(BuildContext, WidgetRef, Habit) buildHabitNormalSliver,
) {
  final linkedSliver = buildHabitLinkedItemsSliver(context, ref, habit);
  if (habit.isChecklistHabit) {
    return [
      buildHabitChecklistSliver(context, ref, habit),
      linkedSliver,
    ];
  }
  return [
    buildHabitNormalSliver(context, ref, habit),
    linkedSliver,
  ];
}
