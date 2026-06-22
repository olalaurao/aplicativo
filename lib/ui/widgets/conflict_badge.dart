import 'package:flutter/material.dart';

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
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          '⚠️',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
