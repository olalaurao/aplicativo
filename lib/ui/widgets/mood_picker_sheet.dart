// lib/ui/widgets/mood_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mood_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';

/// 2-step mood picker as specified in gap-analysis.md:
/// Step 1: Quadrant selection (four big colored regions)
/// Step 2: Word grid with emoji + label + description
/// Lazy file creation on selection
class MoodPickerSheet extends ConsumerStatefulWidget {
  final Function(String moodSlug) onMoodSelected;

  const MoodPickerSheet({
    super.key,
    required this.onMoodSelected,
  });

  @override
  ConsumerState<MoodPickerSheet> createState() => _MoodPickerSheetState();
}

class _MoodPickerSheetState extends ConsumerState<MoodPickerSheet> {
  MoodQuadrant? _selectedQuadrant;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle pill
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    _selectedQuadrant == null 
                        ? 'How are you feeling?' 
                        : 'Pick a word',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedQuadrant != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedQuadrant = null),
                      child: const Text('Back'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Content
            Flexible(
              child: _selectedQuadrant == null
                  ? _QuadrantSelectionGrid(
                      onQuadrantSelected: (quadrant) {
                        setState(() => _selectedQuadrant = quadrant);
                      },
                    )
                  : _MoodWordGrid(
                      quadrant: _selectedQuadrant!,
                      onMoodSelected: widget.onMoodSelected,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuadrantSelectionGrid extends StatelessWidget {
  final ValueChanged<MoodQuadrant> onQuadrantSelected;

  const _QuadrantSelectionGrid({
    required this.onQuadrantSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: MoodQuadrant.values.map((quadrant) {
          return _QuadrantTile(
            quadrant: quadrant,
            onTap: () => onQuadrantSelected(quadrant),
          );
        }).toList(),
      ),
    );
  }
}

class _QuadrantTile extends StatelessWidget {
  final MoodQuadrant quadrant;
  final VoidCallback onTap;

  const _QuadrantTile({
    required this.quadrant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = MoodDefinition.quadrantColor(quadrant);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _quadrantIcon(quadrant),
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              _quadrantTitle(quadrant),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _quadrantDescription(quadrant),
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _quadrantIcon(MoodQuadrant quadrant) => switch (quadrant) {
    MoodQuadrant.red => Icons.bolt_rounded,
    MoodQuadrant.yellow => Icons.wb_sunny_rounded,
    MoodQuadrant.green => Icons.spa_rounded,
    MoodQuadrant.blue => Icons.water_drop_rounded,
  };

  String _quadrantTitle(MoodQuadrant quadrant) => switch (quadrant) {
    MoodQuadrant.red => 'High Energy',
    MoodQuadrant.yellow => 'Pleasant',
    MoodQuadrant.green => 'Calm',
    MoodQuadrant.blue => 'Low Energy',
  };

  String _quadrantDescription(MoodQuadrant quadrant) => switch (quadrant) {
    MoodQuadrant.red => 'Unpleasant',
    MoodQuadrant.yellow => 'High Energy',
    MoodQuadrant.green => 'Pleasant',
    MoodQuadrant.blue => 'Unpleasant',
  };
}

class _MoodWordGrid extends ConsumerWidget {
  final MoodQuadrant quadrant;
  final Function(String moodSlug) onMoodSelected;

  const _MoodWordGrid({
    required this.quadrant,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemMoods = MoodDefinition.systemMoods
        .where((mood) => mood.quadrant == quadrant)
        .toList();
    
    final userMoods = ref.watch(moodsProvider)
        .where((mood) => mood.quadrant == quadrant && mood.source == MoodSource.user)
        .toList();
    
    final allMoods = [...systemMoods, ...userMoods];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        itemCount: allMoods.length + 1, // +1 for Custom tile
        itemBuilder: (context, index) {
          if (index == allMoods.length) {
            return _CustomMoodTile(
              quadrant: quadrant,
              onTap: () {
                // TODO: Navigate to custom mood creation form
                // For now, just show a message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Custom mood creation coming soon')),
                );
              },
            );
          }
          
          final mood = allMoods[index];
          return _MoodWordTile(
            mood: mood,
            onTap: () async {
              // Lazy file creation
              await _lazyCreateMood(ref, mood);
              onMoodSelected(mood.id);
              if (context.mounted) Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Future<void> _lazyCreateMood(WidgetRef ref, MoodDefinition mood) async {
    // Check if mood file already exists
    final existingMoods = ref.read(moodsProvider);
    if (existingMoods.any((m) => m.id == mood.id)) {
      return; // Already exists, no need to create
    }
    
    // Create the mood file lazily
    await ref.read(moodsProvider.notifier).addMood(mood);
  }
}

class _MoodWordTile extends StatelessWidget {
  final MoodDefinition mood;
  final VoidCallback onTap;

  const _MoodWordTile({
    required this.mood,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = MoodDefinition.quadrantColor(mood.quadrant);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              mood.emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              mood.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (mood.description != null && mood.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                mood.description!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomMoodTile extends StatelessWidget {
  final MoodQuadrant quadrant;
  final VoidCallback onTap;

  const _CustomMoodTile({
    required this.quadrant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = MoodDefinition.quadrantColor(quadrant);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Custom',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
