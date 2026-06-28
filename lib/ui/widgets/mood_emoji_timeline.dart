import 'package:flutter/material.dart';

import '../theme.dart';
import 'citrine_chart.dart';

class MoodEmojiTimeline extends StatelessWidget {
  final List<ChartDataPoint> points;
  final int days;

  const MoodEmojiTimeline({
    super.key,
    required this.points,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final visibleColumns = days > 14 ? 14 : days;
    return SizedBox(
      height: 52,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / visibleColumns;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final point in points)
                  SizedBox(
                    width: itemWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          point.emoji?.trim().isNotEmpty == true
                              ? point.emoji!
                              : '.',
                          style: TextStyle(
                            fontSize: point.emoji == null ? 12 : 18,
                            color: point.emoji == null
                                ? AppColors.textMuted
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          point.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
