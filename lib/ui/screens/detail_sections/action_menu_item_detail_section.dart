// lib/ui/screens/detail_sections/action_menu_item_detail_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/action_menu_item_model.dart';
import '../../../providers/vault_provider.dart';
import '../../widgets/property_grid.dart';
import '../../theme.dart';

List<PropertyCard> buildActionMenuItemPropertyCards(ActionMenuItem action) {
  final cards = <PropertyCard>[];

  cards.add(PropertyCard(
    icon: Icons.flash_on,
    label: 'Energy Level',
    value: action.energyLevel.name,
    state: PropertyCardState.normal,
  ));

  cards.add(PropertyCard(
    icon: Icons.battery_charging_full,
    label: 'Energy Cost',
    value: action.energyCost.name,
    state: PropertyCardState.normal,
  ));

  cards.add(PropertyCard(
    icon: Icons.priority_high,
    label: 'Priority',
    value: action.priority.name,
    state: PropertyCardState.normal,
  ));

  final lastLog = action.completionLog.isNotEmpty ? action.completionLog.last.date : null;
  if (lastLog != null) {
    final daysSince = DateTime.now().difference(lastLog).inDays;
    cards.add(PropertyCard(
      icon: Icons.history,
      label: 'Last logged',
      value: daysSince == 0 ? 'Today' : '$daysSince days ago',
      state: PropertyCardState.normal,
    ));
  }

  cards.add(PropertyCard(
    icon: Icons.check_circle_outline,
    label: 'Total logs',
    value: '${action.completionLog.length}',
    state: PropertyCardState.normal,
  ));

  return cards;
}

Widget buildActionMenuItemLogButtons(BuildContext context, WidgetRef ref, ActionMenuItem action) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Log this action',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (index) {
          final rating = index + 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < 4 ? 8.0 : 0),
              child: _RatingButton(
                rating: rating,
                onPressed: () => _registerLog(context, ref, action, rating),
              ),
            ),
          );
        }),
      ),
    ],
  );
}

class _RatingButton extends StatelessWidget {
  final int rating;
  final VoidCallback onPressed;

  const _RatingButton({required this.rating, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.accentColor(context).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            '$rating',
            style: TextStyle(
              color: AppTheme.accentColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _registerLog(
    BuildContext context, WidgetRef ref, ActionMenuItem action, int rating) async {
  final noteController = TextEditingController();
  final logged = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add a note? (Optional)'),
      content: TextField(
        controller: noteController,
        decoration: const InputDecoration(hintText: 'What happened?'),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log Action'),
        ),
      ],
    ),
  );

  if (logged == true) {
    final note = noteController.text.trim();
    final newLog = ActionLog(
      date: DateTime.now(),
      rating: rating,
      note: note.isNotEmpty ? note : null,
    );

    final updated = action.copyWith(
      completionLog: [...action.completionLog, newLog],
    );

    await ref.read(vaultProvider.notifier).updateObject(updated);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged ${action.title} (Rating: $rating)')),
      );
    }
  }
}
