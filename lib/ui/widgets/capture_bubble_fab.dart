// lib/ui/widgets/capture_bubble_fab.dart
//
// Reusable FAB widget that matches the design of the floating capture bubble overlay.
// Used throughout the app for consistent quick-add functionality.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CaptureBubbleFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String? tooltip;
  final Widget? heroTag;

  const CaptureBubbleFab({
    super.key,
    required this.onPressed,
    this.tooltip,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag ?? 'capture_bubble_fab',
      tooltip: tooltip,
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.92),
      elevation: 0,
      shape: const CircleBorder(),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: 0.45),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
