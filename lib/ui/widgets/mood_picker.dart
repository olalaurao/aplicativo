import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mood_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';

extension MoodDefinitionListX on List<MoodDefinition> {
  List<MoodDefinition> byQuadrant(MoodQuadrant q) {
    return where((m) => m.quadrant == q).toList();
  }
}

class MoodPicker extends ConsumerStatefulWidget {
  final MoodDefinition? initialMood;
  final void Function(MoodDefinition) onSelected;

  const MoodPicker({
    super.key,
    this.initialMood,
    required this.onSelected,
  });

  @override
  ConsumerState<MoodPicker> createState() => _MoodPickerState();
}

class _MoodPickerState extends ConsumerState<MoodPicker> {
  int _step = 1; // 1 = quadrant selection, 2 = specific mood
  MoodQuadrant? _selectedQuadrant;

  @override
  void initState() {
    super.initState();
    if (widget.initialMood != null) {
      _selectedQuadrant = widget.initialMood!.quadrant;
      _step = 2;
    }
  }

  String _quadrantLabel(MoodQuadrant q) {
    return switch (q) {
      MoodQuadrant.red => 'Alta energia · Desagradável',
      MoodQuadrant.yellow => 'Alta energia · Agradável',
      MoodQuadrant.green => 'Baixa energia · Agradável',
      MoodQuadrant.blue => 'Baixa energia · Desagradável',
    };
  }

  Widget _buildQuadrantStep(BuildContext context, List<MoodDefinition> moodState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Como você está?',
          style: AppTheme.sectionHeaderStyle(context),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: MoodQuadrant.values.map((q) {
            final color = MoodDefinition.quadrantColor(q);
            final count = moodState.byQuadrant(q).length;
            return _QuadrantCard(
              quadrant: q,
              color: color,
              label: _quadrantLabel(q),
              moodCount: count,
              onTap: () {
                setState(() {
                  _selectedQuadrant = q;
                  _step = 2;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMoodStep(BuildContext context, List<MoodDefinition> moodState) {
    final moods = moodState.byQuadrant(_selectedQuadrant!);
    final label = _quadrantLabel(_selectedQuadrant!);
    final quadrantColor = MoodDefinition.quadrantColor(_selectedQuadrant!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                setState(() {
                  _step = 1;
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: quadrantColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: moods.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final mood = moods[index];
              final isSelected = widget.initialMood?.id == mood.id;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: Text(
                  mood.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(
                  mood.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: mood.description != null && mood.description!.trim().isNotEmpty
                    ? Text(
                        mood.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
                selected: isSelected,
                selectedColor: AppColors.primary,
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(moodsProvider.notifier).ensureMoodFileExists(mood.id);
                  widget.onSelected(mood);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodsProvider);
    if (_step == 1) {
      return _buildQuadrantStep(context, moodState);
    } else {
      return _buildMoodStep(context, moodState);
    }
  }
}

class _QuadrantCard extends StatelessWidget {
  final MoodQuadrant quadrant;
  final Color color;
  final String label;
  final int moodCount;
  final VoidCallback onTap;

  const _QuadrantCard({
    required this.quadrant,
    required this.color,
    required this.label,
    required this.moodCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  '$moodCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
