// lib/ui/screens/settings/sections/quick_capture_section.dart
//
// Settings section for the floating quick-add bubble.
// Only rendered on Android; iOS branch is suppressed at the call site
// (the widget itself also guards with Platform.isAndroid as a safety net).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../services/permission_service.dart';
import '../../../../services/capture_bubble_service.dart';

class QuickCaptureSection extends ConsumerStatefulWidget {
  const QuickCaptureSection({super.key});

  @override
  ConsumerState<QuickCaptureSection> createState() =>
      _QuickCaptureSectionState();
}

class _QuickCaptureSectionState extends ConsumerState<QuickCaptureSection> {
  bool _checkingPermission = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Listen for app resume to re-check permission in case the user
    // is coming back from the system settings screen.
    _lifecycleListener = AppLifecycleListener(
      onResume: _onResumed,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _onResumed() async {
    if (!Platform.isAndroid) return;
    // If the toggle is off, check if permission was granted in the background
    // and we were waiting for it. Actually, if permission is now granted,
    // we don't automatically turn it on unless they were just checking.
    // We'll handle it inside _handleToggle by using a flag or just polling.
  }

  @override
  Widget build(BuildContext context) {
    // Guard — entire section is Android-only.
    if (!Platform.isAndroid) return const SizedBox.shrink();

    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        leading: const Icon(Icons.add_circle_outline_rounded, size: 22),
        title: const Text(
          'Floating quick-add button',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text(
          'Android only. Shows a draggable button over other apps to '
          'capture something fast.',
          style: TextStyle(fontSize: 12),
        ),
        trailing: _checkingPermission
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch.adaptive(
                value: settings.floatingCaptureBubbleEnabled,
                activeThumbColor: AppTheme.accentColor(context),
                onChanged: (value) => _handleToggle(context, value, notifier),
              ),
      ),
    );
  }

  Future<void> _handleToggle(
    BuildContext context,
    bool value,
    SettingsNotifier notifier,
  ) async {
    if (!Platform.isAndroid) return;

    if (!value) {
      // Turning off → stop overlay immediately, then save.
      await CaptureOverlayService.stop();
      await notifier.updateFloatingCaptureBubbleEnabled(false);
      return;
    }

    // Turning on → check permission first.
    setState(() => _checkingPermission = true);
    try {
      final granted = await PermissionService.isOverlayPermissionGranted();

      if (granted) {
        // Already have permission — enable directly.
        await notifier.updateFloatingCaptureBubbleEnabled(true);
      } else {
        // Show explanatory dialog then redirect to system settings.
        if (!context.mounted) return;
        
        // Wait for the dialog to close. If they click 'Open Settings', it launches intent.
        await PermissionService.requestOverlayPermission(context);

        // We poll for up to 60 seconds while the user is in settings.
        // When they grant it, we immediately save and stop spinning.
        for (int i = 0; i < 60; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          
          final isNowGranted = await PermissionService.isOverlayPermissionGranted();
          if (isNowGranted) {
            await notifier.updateFloatingCaptureBubbleEnabled(true);
            if (mounted) setState(() => _checkingPermission = false);
            return;
          }
        }

        // If after 60 seconds they didn't grant it, revert toggle and show explanation.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permission not granted. Enable "Allow display over other '
                'apps" for Quartzo in system settings to use this feature.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _checkingPermission = false);
    }
  }
}
