// lib/providers/overlay_bridge_provider.dart
//
// Bridge between the overlay isolate (capture_bubble_overlay.dart) and the
// main app. Listens to FlutterOverlayWindow.overlayListener and fires a
// callback when the bubble sends "open_capture".
//
// Usage (from main.dart or the app shell):
//   OverlayBridgeService.init(onOpenCapture: () => showQuickCapture(context));

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayBridgeService {
  OverlayBridgeService._();

  static StreamSubscription<dynamic>? _sub;

  // Whether the user dismissed the bubble via drag-to-dismiss for this session.
  // The Settings toggle stays enabled; this only blocks re-showing within the
  // same background session (reset when app is foregrounded again).
  static bool _sessionDismissed = false;

  static bool get sessionDismissed => _sessionDismissed;

  /// Call once from _initApp (after Android platform check).
  /// [onOpenCapture] is called when the bubble is tapped — it should call
  /// showQuickCapture(context) or equivalent.
  static void init({required VoidCallback onOpenCapture}) {
    if (!Platform.isAndroid) return;
    _sub?.cancel();
    _sub = FlutterOverlayWindow.overlayListener.listen((data) {
      debugPrint('[OverlayBridge] received: $data');
      if (data == 'open_capture') {
        onOpenCapture();
      } else if (data == 'dismiss_session') {
        _sessionDismissed = true;
        debugPrint('[OverlayBridge] bubble dismissed for this session');
      }
    });
  }

  /// Resets the per-session dismiss flag. Call this when the app comes to
  /// foreground (onResume) so backgrounding again will show the bubble.
  static void resetSessionDismiss() {
    _sessionDismissed = false;
  }

  /// Dispose the listener. Call from dispose() if needed.
  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
