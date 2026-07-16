// lib/ui/screens/detail_sections/pillar_detail_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../models/pillar_model.dart';
import '../../../models/action_menu_item_model.dart';
import '../../../models/content_object.dart';
import '../../../providers/vault_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/property_grid.dart';
import '../../widgets/object_timeline_feed.dart';
import '../../utils/object_icons.dart';
import '../../../services/timeline_aggregator_service.dart';

/// Pillar-specific property cards for universal detail view
List<PropertyCard> buildPillarPropertyCards(Pillar pillar) {
  final cards = <PropertyCard>[];

  cards.add(PropertyCard(
    icon: ObjectIcons.defaultIconDataForType('pillar') ?? Icons.account_balance,
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

/// Pillar-specific action buttons for registering touches
Widget buildPillarActionButtons(BuildContext context, WidgetRef ref, Pillar pillar) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Register Touch',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _EnergyButton(
              level: EnergyLevel.low,
              label: 'Low',
              color: Colors.green,
              onPressed: () => _registerTouch(context, ref, pillar, EnergyLevel.low),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _EnergyButton(
              level: EnergyLevel.mid,
              label: 'Medium',
              color: Colors.orange,
              onPressed: () => _registerTouch(context, ref, pillar, EnergyLevel.mid),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _EnergyButton(
              level: EnergyLevel.high,
              label: 'High',
              color: Colors.red,
              onPressed: () => _registerTouch(context, ref, pillar, EnergyLevel.high),
            ),
          ),
        ],
      ),
    ],
  );
}

class _EnergyButton extends StatelessWidget {
  final EnergyLevel level;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _EnergyButton({
    required this.level,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

  Future<void> _registerTouch(
  BuildContext context,
  WidgetRef ref,
  Pillar pillar,
  EnergyLevel energyLevel,
) async {
  // Get actions linked to this pillar with the specified energy level
  final allActions = ref.read(actionMenuItemsProvider);
  final matchingActions = allActions.where((action) =>
    action.energyLevel == energyLevel &&
    action.organizers.any((org) => org.type == 'pillar' && org.slug == pillar.slug)
  ).toList();

  if (matchingActions.isEmpty) {
    // No actions linked, just register a simple touch
    await _simpleTouch(context, ref, pillar, null);
    return;
  }

  // Show picker to select action or skip
  final selected = await showModalBottomSheet<ActionMenuItem?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Action',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Just mark touch (no specific action)'),
            onTap: () => Navigator.pop(sheetContext, null),
          ),
          const Divider(),
          ...matchingActions.map((action) => ListTile(
            leading: const Icon(Icons.bolt),
            title: Text(action.title),
            onTap: () => Navigator.pop(sheetContext, action),
          )),
        ],
      ),
    ),
  );

  await _simpleTouch(context, ref, pillar, selected?.id);
}

Future<void> _simpleTouch(
  BuildContext context,
  WidgetRef ref,
  Pillar pillar,
  String? actionId,
) async {
  HapticFeedback.lightImpact();
  
  final touch = PillarTouch(
    date: DateTime.now(),
    actionId: actionId,
    note: null,
  );
  
  final updatedPillar = pillar.copyWith(
    touchLog: [...pillar.touchLog, touch],
    updatedAt: DateTime.now(),
  );
  
  await ref.read(pillarsProvider.notifier).updatePillar(updatedPillar);
  
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Touch registered'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// Pillar-specific timeline section showing connected objects
Widget buildPillarTimelineSection(BuildContext context, WidgetRef ref, Pillar pillar) {
  final backlinksAsync = ref.watch(backlinksProvider(pillar.id));
  
  return backlinksAsync.when(
    data: (backlinks) {
      if (backlinks.isEmpty) {
        return const SizedBox.shrink();
      }
      
      final window = TimelineWindow(
        start: pillar.createdAt ?? DateTime(2020),
        end: DateTime.now(),
      );
      
      final timelineItems = TimelineAggregatorService.buildTimeline(
        backlinks,
        window,
      );
      
      if (timelineItems.isEmpty) {
        return const SizedBox.shrink();
      }
      
      final settings = ref.watch(settingsProvider);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'Connected Timeline',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ObjectTimelineFeed(
            items: timelineItems,
            typeSignatures: settings.typeSignatures,
          ),
        ],
      );
    },
    loading: () => const Center(
      child: CircularProgressIndicator(),
    ),
    error: (_, __) => const SizedBox.shrink(),
  );
}
