// lib/ui/widgets/pin_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/navigation_provider.dart';
import '../theme.dart';

class PinButton extends ConsumerWidget {
  final String? customLabel;
  final String? customType;
  final IconData? icon;

  const PinButton({
    super.key,
    this.customLabel,
    this.customType,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String location = '/';
    Map<String, String> queryParams = {};
    
    try {
      final uri = GoRouterState.of(context).uri;
      location = uri.path;
      queryParams = uri.queryParameters;
    } catch (_) {}

    final isPinned = ref.read(navigationProvider.notifier).isScreenPinned(
      location,
      queryParams,
    );

    return IconButton(
      icon: Icon(
        isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
        color: isPinned ? AppTheme.accentColor(context) : AppColors.textSecondary,
      ),
      onPressed: () => _handlePin(context, ref, location, queryParams),
      tooltip: isPinned ? 'Unpin from bottom bar' : 'Pin to bottom bar',
    );
  }

  void _handlePin(
    BuildContext context,
    WidgetRef ref,
    String route,
    Map<String, String> queryParams,
  ) {
    final isPinned = ref.read(navigationProvider.notifier).isScreenPinned(
      route,
      queryParams,
    );

    if (isPinned) {
      ref.read(navigationProvider.notifier).unpinScreen(route, queryParams);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unpinned from bottom bar'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      _showPinDialog(context, ref, route, queryParams);
    }
  }

  void _showPinDialog(
    BuildContext context,
    WidgetRef ref,
    String route,
    Map<String, String> queryParams,
  ) {
    final controller = TextEditingController(text: customLabel ?? _getDefaultLabel(route));
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pin to Bottom Bar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Enter a name for this pin',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This screen will be added to your bottom navigation bar for quick access.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(navigationProvider.notifier).pinCurrentScreen(
                  controller.text,
                  route,
                  queryParams,
                  customType,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pinned to bottom bar'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child: const Text('Pin'),
          ),
        ],
      ),
    );
  }

  String _getDefaultLabel(String route) {
    // Generate a default label based on the route
    if (route == '/') return 'Home';
    if (route.startsWith('/detail/')) return 'Detail';
    if (route.startsWith('/organizer/')) return 'Organizer';
    if (route.startsWith('/search')) return 'Search';
    if (route.startsWith('/planner')) return 'Planner';
    if (route.startsWith('/timeline')) return 'Journal';
    if (route.startsWith('/trackers')) return 'Trackers';
    if (route.startsWith('/habits')) return 'Habits';
    if (route.startsWith('/goals')) return 'Goals';
    if (route.startsWith('/notes')) return 'Notes';
    if (route.startsWith('/people')) return 'People';
    if (route.startsWith('/resources')) return 'Resources';
    
    // Extract last segment from route
    final segments = route.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      return segments.last
          .split('-')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
    }
    
    return 'Screen';
  }
}
