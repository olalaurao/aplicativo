// lib/overlay/capture_bubble_overlay.dart
//
// Overlay isolate entry point + draggable quick-capture bubble widget.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

@pragma('vm:entry-point')
void overlayMain() {
  runApp(const CaptureBubbleApp());
}

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

class CaptureBubbleWidget extends StatefulWidget {
  const CaptureBubbleWidget({super.key});

  @override
  State<CaptureBubbleWidget> createState() => _CaptureBubbleWidgetState();
}

class _CaptureBubbleWidgetState extends State<CaptureBubbleWidget>
    with SingleTickerProviderStateMixin {
  bool _inDismissZone = false;
  bool _isVisible = true;
  late final AnimationController _snapController;
  double _rawY = 0;
  double _screenHeight = 800;

  static const double _dismissThreshold = 0.85;
  static const String _bridgePortName = 'quartzo_quick_capture_overlay_bridge';

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == 'hide' && _isVisible) {
        if (mounted) setState(() => _isVisible = false);
      } else if (event == 'show' && !_isVisible) {
        if (mounted) setState(() => _isVisible = true);
      }
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _snapController.stop();
    FlutterOverlayWindow.getOverlayPosition().then((position) {
      if (mounted) _rawY = position.y;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isVisible) return;
    _rawY += details.delta.dy;

    final inZone = _rawY > _screenHeight * _dismissThreshold;
    if (inZone != _inDismissZone) {
      HapticFeedback.selectionClick();
      setState(() => _inDismissZone = inZone);
    }
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (!_isVisible) return;
    if (_inDismissZone) {
      HapticFeedback.heavyImpact();
      await _sendToMainApp('dismiss_session');
      await FlutterOverlayWindow.closeOverlay();
      return;
    }

    final velocity = details.velocity.pixelsPerSecond;
    await FlutterOverlayWindow.moveOverlay(
      OverlayPosition(velocity.dx > 0 ? 1000.0 : -1000.0, 0.0),
    );
    setState(() => _inDismissZone = false);
  }

  Future<void> _onTap() async {
    HapticFeedback.lightImpact();
    debugPrint('[CaptureBubble] tap -> open_capture');
    await _sendToMainApp('open_capture');
  }

  Future<void> _sendToMainApp(Object message) async {
    final port = IsolateNameServer.lookupPortByName(_bridgePortName);
    if (port != null) {
      port.send(message);
      return;
    }
    await FlutterOverlayWindow.shareData(message);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final display = View.of(context).display;
    _screenHeight = display.size.height / display.devicePixelRatio;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: _onTap,
      child: Center(
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
      ),
    );
  }
}
