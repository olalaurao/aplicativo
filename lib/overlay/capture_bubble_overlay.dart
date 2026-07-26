// lib/overlay/capture_bubble_overlay.dart
//
// Overlay isolate entry point + draggable quick-capture bubble widget.
//
// This file runs in a SEPARATE ISOLATE from the main app — no Riverpod,
// no Navigator, no shared state. It only sends an event to the main
// isolate when tapped, via FlutterOverlayWindow.shareData().
//
// Behaviour:
//   - Drag anywhere on screen via FlutterOverlayWindow.moveOverlay()
//   - On release: snap to the nearest horizontal edge (magnetic behaviour)
//   - Bottom 15%: reveal dismiss target; release there stops the overlay
//   - Tap (< 10px movement): sends "open_capture" event to main isolate

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void overlayMain() {
  runApp(const CaptureBubbleApp());
}

// ─── Minimal app shell ────────────────────────────────────────────────────────

class CaptureBubbleApp extends StatelessWidget {
  const CaptureBubbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: CaptureBubbleWidget(),
      ),
    );
  }
}

// ─── Bubble widget ────────────────────────────────────────────────────────────

class CaptureBubbleWidget extends StatefulWidget {
  const CaptureBubbleWidget({super.key});

  @override
  State<CaptureBubbleWidget> createState() => _CaptureBubbleWidgetState();
}

class _CaptureBubbleWidgetState extends State<CaptureBubbleWidget>
    with SingleTickerProviderStateMixin {
  // Tracks how far the user has moved during a pan gesture to distinguish
  // tap (small movement) from drag (large movement).
  double _dragDistance = 0;

  // Whether the bubble is currently hovering over the dismiss zone.
  bool _inDismissZone = false;

  // Animation controller for the magnetic snap.
  late final AnimationController _snapController;

  // Current position within the overlay window (relative to centre).
  // FlutterOverlayWindow exposes its own position — we only track vertical
  // offset for dismiss-zone detection.
  double _rawY = 0;

  // Screen height captured once at build time.
  double _screenHeight = 800;

  static const double _dismissThreshold = 0.85; // bottom 15%

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _dragDistance = 0;
    _snapController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.distance;
    _rawY += details.delta.dy;

    // Move the overlay window by the delta reported by the gesture.
    FlutterOverlayWindow.moveOverlay(
      OverlayPosition(details.delta.dx, details.delta.dy),
    );

    // Check dismiss zone: bottom 15% of the screen.
    final inZone = _rawY > _screenHeight * _dismissThreshold;
    if (inZone != _inDismissZone) {
      HapticFeedback.selectionClick();
      setState(() => _inDismissZone = inZone);
    }
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (_inDismissZone) {
      // User released in the dismiss zone — stop the overlay for this session.
      // The Settings toggle stays enabled; it comes back next time the app
      // is backgrounded. See spec: "drag-to-dismiss only hides for session."
      HapticFeedback.heavyImpact();
      await FlutterOverlayWindow.shareData('dismiss_session');
      await FlutterOverlayWindow.closeOverlay();
      return;
    }

    // Snap to nearest horizontal edge.
    // FlutterOverlayWindow.moveOverlay with large X offsets snaps the window
    // to the left/right edge thanks to PositionGravity.auto — we push it.
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.dx > 0) {
      // Moving right → snap right edge.
      await FlutterOverlayWindow.moveOverlay(const OverlayPosition(1000.0, 0.0));
    } else {
      // Moving left (or no horizontal velocity) → snap left edge.
      await FlutterOverlayWindow.moveOverlay(const OverlayPosition(-1000.0, 0.0));
    }
    setState(() => _inDismissZone = false);
  }

  Future<void> _onTap() async {
    // Only treat gesture as tap if the user barely moved.
    if (_dragDistance > 10) return;
    HapticFeedback.lightImpact();
    // Send event to main isolate; main app will open the quick-capture sheet.
    await FlutterOverlayWindow.shareData('open_capture');
  }

  @override
  Widget build(BuildContext context) {
    _screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: _onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _inDismissZone
              ? Colors.red.withValues(alpha: 0.9)
              : const Color(0xFFF97316).withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(
              color: (_inDismissZone ? Colors.red : const Color(0xFFF97316))
                  .withValues(alpha: 0.45),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _inDismissZone ? Icons.close_rounded : Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
