// lib/ui/screens/detail_sections/habit_detail_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/habit_model.dart';
import '../../../models/shared_types.dart';
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

  // Completion History card - shows all completion records
  if (habit.completionHistory.isNotEmpty) {
    // Sort reverse-chronological
    final sortedHistory = List<CompletionRecord>.from(habit.completionHistory)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    cards.add(PropertyCard(
      icon: Icons.history,
      label: 'History',
      state: PropertyCardState.normal,
      customChild: _CompletionHistoryList(entries: sortedHistory),
    ));
  }

  // Collection Log card - shown only if there are completion records with linkedRef
  final collectionLogEntries = habit.completionHistory
      .where((r) => r.linkedRef != null)
      .toList();
  
  if (collectionLogEntries.isNotEmpty) {
    // Sort reverse-chronological
    collectionLogEntries.sort((a, b) => b.date.compareTo(a.date));
    
    cards.add(PropertyCard(
      icon: Icons.link,
      label: 'Collection Log',
      state: PropertyCardState.normal,
      customChild: _CollectionLogList(entries: collectionLogEntries),
    ));
  }
  
  return cards;
}

class _CollectionLogList extends StatelessWidget {
  final List<CompletionRecord> entries;
  
  const _CollectionLogList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final record = entries[index];
        final ref = record.linkedRef!;
        final dateStr = DateFormat('MMM d').format(record.date);
        
        return InkWell(
          onTap: () {
            // Navigate to the source collection row
            if (ref.isRow) {
              // Navigate to note with block reference
              // TODO: Implement navigation to collection row
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Navigate to: ${ref.toWikiLink()}')),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$dateStr — ${ref.displayTitle}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompletionHistoryList extends StatelessWidget {
  final List<CompletionRecord> entries;
  
  const _CompletionHistoryList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final record = entries[index];
        final dateStr = DateFormat('MMM d, yyyy').format(record.date);
        final timeStr = DateFormat('HH:mm').format(record.date);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                record.successful ? Icons.check_circle : Icons.cancel,
                size: 12,
                color: record.successful 
                    ? Colors.green 
                    : Colors.red,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$dateStr $timeStr — ${record.completions} completions',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
