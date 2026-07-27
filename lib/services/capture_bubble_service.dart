// lib/services/capture_bubble_service.dart
//
// Wrapper around flutter_overlay_window lifecycle for the floating quick-add
// bubble (Android only). Follows the same pattern as PomodoroBackgroundService.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class CaptureOverlayService {
  /// Width/height of the overlay window in dp — fixed 72dp square for the bubble.
  static const int _bubbleSize = 72;

  /// Starts the overlay service if not already running.
  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      final active = await FlutterOverlayWindow.isActive();
      if (active) return;
      await FlutterOverlayWindow.showOverlay(
        height: _bubbleSize,
        width: _bubbleSize,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilityPublic,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
      );
    } catch (e) {
      // If the overlay can't start (e.g. permission revoked between checks),
      // swallow silently — the bubble simply doesn't appear.
      debugPrint('[CaptureOverlayService] start failed: $e');
    }
  }

  /// Stops the overlay service completely.
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      final active = await FlutterOverlayWindow.isActive();
      if (active) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      debugPrint('[CaptureOverlayService] stop failed: $e');
    }
  }

  /// Sends a message to the overlay isolate to hide the bubble widget.
  static Future<void> hide() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterOverlayWindow.shareData('hide');
    } catch (e) {
      debugPrint('[CaptureOverlayService] hide failed: $e');
    }
  }

  /// Sends a message to the overlay isolate to show the bubble widget.
  static Future<void> show() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterOverlayWindow.shareData('show');
    } catch (e) {
      debugPrint('[CaptureOverlayService] show failed: $e');
    }
  }

  /// Returns true if the overlay is currently active.
  static Future<bool> isActive() async {
    if (!Platform.isAndroid) return false;
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (_) {
      return false;
    }
  }

  /// Listens for messages sent from the overlay isolate via
  /// [FlutterOverlayWindow.overlayListener]. Calls [onTap] when the bubble
  /// sends the "open_capture" event.
  static void listenForTaps(void Function() onTap) {
    if (!Platform.isAndroid) return;
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == 'open_capture') {
        onTap();
      }
    });
  }
}
