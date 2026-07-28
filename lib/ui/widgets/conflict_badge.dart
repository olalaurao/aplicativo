import 'package:flutter/material.dart';
import '../theme.dart';

class ConflictBadge extends StatelessWidget {
  final bool visible;
  final String? tooltip;

  const ConflictBadge({
    super.key,
    required this.visible,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Tooltip(
      message: tooltip ?? 'Conflito de tipo detectado',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: AppColors.error,
        ),
      ),
    );
  }
}
