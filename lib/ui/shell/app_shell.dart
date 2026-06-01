// lib/ui/shell/app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../theme.dart';
import '../../providers/navigation_provider.dart';
import '../../models/navigation_item.dart';
import '../../providers/vault_provider.dart';
import '../../models/content_object.dart';
import '../widgets/create_menu_sheet.dart';
import '../../providers/history_provider.dart';
import '../screens/universal_detail_view.dart';
import '../screens/home_screen.dart';
import '../../providers/auth_provider.dart';
import '../widgets/command_center_overlay.dart';
import '../../providers/widget_sync_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Widget? _lastListChild;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastCommandCenterOverscrollAt;

  @override
  Widget build(BuildContext context) {
    final navItemsAsync = ref.watch(navigationProvider);
    final navItems = navItemsAsync.valueOrNull ?? [];
    final bottomBarItems = navItems.where((item) => item.inBottomBar).toList();
    ref.watch(widgetSyncProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLocked = ref.watch(lockProvider);

    // Determine current path
    String location = '/';
    try {
      location = GoRouterState.of(context).uri.path;
    } catch (_) {}

    final isDetailRoute =
        location.startsWith('/detail/') || location.startsWith('/organizer/');
    final currentIndex = _calculateSelectedIndex(location, bottomBarItems);

    // Update the last list screen if not on a detail view
    if (!isDetailRoute) {
      _lastListChild = widget.child;
    }

    final leftPane = _lastListChild ?? const HomeScreen();

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenCommandCenterIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _OpenCommandCenterIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _CreateNewItemIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            _CreateNewItemIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _OpenSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _OpenSearchIntent(),
        SingleActivator(LogicalKeyboardKey.digit1, control: true):
            _SwitchTabIntent(0),
        SingleActivator(LogicalKeyboardKey.digit1, meta: true):
            _SwitchTabIntent(0),
        SingleActivator(LogicalKeyboardKey.digit2, control: true):
            _SwitchTabIntent(1),
        SingleActivator(LogicalKeyboardKey.digit2, meta: true):
            _SwitchTabIntent(1),
        SingleActivator(LogicalKeyboardKey.digit3, control: true):
            _SwitchTabIntent(2),
        SingleActivator(LogicalKeyboardKey.digit3, meta: true):
            _SwitchTabIntent(2),
        SingleActivator(LogicalKeyboardKey.digit4, control: true):
            _SwitchTabIntent(3),
        SingleActivator(LogicalKeyboardKey.digit4, meta: true):
            _SwitchTabIntent(3),
        SingleActivator(LogicalKeyboardKey.digit5, control: true):
            _SwitchTabIntent(4),
        SingleActivator(LogicalKeyboardKey.digit5, meta: true):
            _SwitchTabIntent(4),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenCommandCenterIntent: CallbackAction<_OpenCommandCenterIntent>(
            onInvoke: (intent) {
              _openCommandCenter(context);
              return null;
            },
          ),
          _CreateNewItemIntent: CallbackAction<_CreateNewItemIntent>(
            onInvoke: (intent) {
              showCreateMenu(context);
              return null;
            },
          ),
          _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
            onInvoke: (intent) {
              context.go('/search');
              return null;
            },
          ),
          _SwitchTabIntent: CallbackAction<_SwitchTabIntent>(
            onInvoke: (intent) {
              final tabIndex = (intent).tabIndex;
              _onItemTapped(tabIndex, context, bottomBarItems);
              return null;
            },
          ),
        },
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final isSpacious = constraints.maxWidth >= 900;

                if (isWide) {
                  return Scaffold(
                    key: _scaffoldKey,
                    drawer: _buildHistoryDrawer(context, ref),
                    body: Row(
                      children: [
                        _buildSideRail(
                          context,
                          ref,
                          bottomBarItems,
                          currentIndex,
                          isSpacious,
                        ),
                        Expanded(
                          child: Container(
                            color: isDark
                                ? AppColors.darkBackground
                                : AppColors.background,
                            child: isDetailRoute
                                ? Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: _withCommandCenterOverscroll(
                                          context,
                                          leftPane,
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 1,
                                        thickness: 0.5,
                                        color:
                                            (isDark
                                                    ? AppColors.darkDivider
                                                    : AppColors.divider)
                                                .withValues(alpha: 0.5),
                                      ),
                                      Expanded(
                                        flex: 5,
                                        child: _withCommandCenterOverscroll(
                                          context,
                                          widget.child,
                                        ),
                                      ),
                                    ],
                                  )
                                : _withCommandCenterOverscroll(
                                    context,
                                    widget.child,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Standard phone layout
                return Scaffold(
                  key: _scaffoldKey,
                  drawer: _buildHistoryDrawer(context, ref),
                  body: _withCommandCenterOverscroll(context, widget.child),
                  floatingActionButton: GestureDetector(
                    onLongPress: () => _openCommandCenter(context),
                    child: FloatingActionButton(
                      onPressed: () => showCreateMenu(context),
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.endFloat,
                  bottomNavigationBar: bottomBarItems.length < 2
                      ? null
                      : ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    (isDark
                                            ? AppColors.darkSurface
                                            : AppColors.surface)
                                        .withValues(alpha: 0.8),
                                border: Border(
                                  top: BorderSide(
                                    color:
                                        (isDark
                                                ? AppColors.darkDivider
                                                : AppColors.divider)
                                            .withValues(alpha: 0.5),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: SafeArea(
                                top: false,
                                child: BottomNavigationBar(
                                  currentIndex: currentIndex,
                                  onTap: (int index) => _onItemTapped(
                                    index,
                                    context,
                                    bottomBarItems,
                                  ),
                                  type: BottomNavigationBarType.fixed,
                                  backgroundColor: Colors
                                      .transparent, // Important for glass effect
                                  elevation: 0,
                                  selectedFontSize: 10,
                                  unselectedFontSize: 10,
                                  selectedItemColor: AppColors.accent,
                                  unselectedItemColor: AppColors.textMuted,
                                  items: bottomBarItems.map((item) {
                                    final iconWidget = Icon(
                                      item.icon,
                                      size: 22,
                                    );
                                    final activeIconWidget = Icon(
                                      item.activeIcon,
                                      size: 22,
                                    );
                                    final isInboxInBottomBar = bottomBarItems
                                        .any(
                                          (it) =>
                                              it.section == NavSection.inbox,
                                        );
                                    final isMoreWithInboxBadge =
                                        item.section == NavSection.more &&
                                        !isInboxInBottomBar &&
                                        ref.watch(inboxCountProvider) > 0;
                                    final count =
                                        item.section == NavSection.inbox
                                        ? ref.watch(inboxCountProvider)
                                        : (isMoreWithInboxBadge
                                              ? ref.watch(inboxCountProvider)
                                              : 0);

                                    return BottomNavigationBarItem(
                                      icon: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: count > 0
                                            ? Badge(
                                                label: Text(count.toString()),
                                                child: iconWidget,
                                              )
                                            : iconWidget,
                                      ),
                                      activeIcon: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: count > 0
                                            ? Badge(
                                                label: Text(count.toString()),
                                                child: activeIconWidget,
                                              )
                                            : activeIconWidget,
                                      ),
                                      label: item.label,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                );
              },
            ),
            if (isLocked) _buildLockOverlay(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _withCommandCenterOverscroll(BuildContext context, Widget child) {
    return NotificationListener<OverscrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels <=
                notification.metrics.minScrollExtent + 2 &&
            notification.overscroll < -18) {
          final now = DateTime.now();
          final last = _lastCommandCenterOverscrollAt;
          if (last == null || now.difference(last).inSeconds > 1) {
            _lastCommandCenterOverscrollAt = now;
            _openCommandCenter(context);
          }
        }
        return false;
      },
      child: child,
    );
  }

  Widget _buildSideRail(
    BuildContext context,
    WidgetRef ref,
    List<NavigationItem> items,
    int currentIndex,
    bool isSpacious,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: isSpacious ? 240 : 76,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          right: BorderSide(
            color: (isDark ? AppColors.darkDivider : AppColors.divider)
                .withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo and Header
          const SizedBox(height: 16),
          if (isSpacious)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.blur_on_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Citrine',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.blur_on_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Action Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSpacious ? 16 : 8),
            child: isSpacious
                ? InkWell(
                    onTap: () => showCreateMenu(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Nova Captura',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : IconButton.filled(
                    onPressed: () => showCreateMenu(context),
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // Navigation Items
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              padding: EdgeInsets.symmetric(horizontal: isSpacious ? 12 : 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == currentIndex;
                final isInbox = item.section == NavSection.inbox;
                final isMore = item.section == NavSection.more;
                final isInboxInItems = items.any(
                  (it) => it.section == NavSection.inbox,
                );
                final isMoreWithInboxBadge =
                    isMore &&
                    !isInboxInItems &&
                    ref.watch(inboxCountProvider) > 0;

                final count = isInbox
                    ? ref.watch(inboxCountProvider)
                    : (isMoreWithInboxBadge
                          ? ref.watch(inboxCountProvider)
                          : 0);

                final iconWidget = Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected ? AppColors.accent : AppColors.textMuted,
                  size: 24,
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () => _onItemTapped(index, context, items),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: isSpacious ? 16 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: isSpacious
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          count > 0 && !isSpacious
                              ? Badge(
                                  label: Text(count.toString()),
                                  child: iconWidget,
                                )
                              : iconWidget,
                          if (isSpacious) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // History Button at Bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: isSpacious
                ? TextButton.icon(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text(
                      'Histórico',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                    ),
                  )
                : IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.history_rounded),
                    color: AppColors.textMuted,
                  ),
          ),
        ],
      ),
    );
  }

  void _openCommandCenter(BuildContext context) {
    showCommandCenter(context);
  }

  Widget _buildLockOverlay(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.background,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Citrine is locked',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use biometrics to unlock',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => ref.read(lockProvider.notifier).unlock(),
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Unlock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateSelectedIndex(String location, List<NavigationItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (items[i].route == '/') {
        if (location == '/') return i;
      } else if (location.startsWith(items[i].route)) {
        return i;
      }
    }
    // If not found in bottom bar, it might be in 'More'
    final moreIndex = items.indexWhere((it) => it.section == NavSection.more);
    return moreIndex != -1 ? moreIndex : 0;
  }

  Widget _buildHistoryDrawer(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Center(
              child: Text(
                'History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'No items visited',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      return ListTile(
                        leading: _buildTypeIcon(entry.type),
                        title: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          entry.type.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context); // Close drawer
                          final allObjects = await ref.read(
                            allObjectsProvider.future,
                          );
                          ContentObject? obj;
                          for (final object in allObjects) {
                            if (object.id == entry.id) {
                              obj = object;
                              break;
                            }
                          }
                          if (!context.mounted) return;
                          if (obj == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Este item nao esta mais disponivel.',
                                ),
                              ),
                            );
                            return;
                          }
                          final selectedObject = obj;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UniversalDetailView(object: selectedObject),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextButton.icon(
              onPressed: () => ref.read(historyProvider.notifier).clear(),
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              label: const Text('Clear History'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'task':
        icon = Icons.check_circle_outline;
        color = AppColors.info;
        break;
      case 'habit':
        icon = Icons.repeat;
        color = AppColors.habitGreen;
        break;
      case 'goal':
        icon = Icons.flag_outlined;
        color = AppColors.habitOrange;
        break;
      case 'note':
        icon = Icons.notes;
        color = AppColors.warning;
        break;
      default:
        icon = Icons.article_outlined;
        color = AppColors.textMuted;
    }
    return Icon(icon, color: color, size: 20);
  }

  void _onItemTapped(
    int index,
    BuildContext context,
    List<NavigationItem> items,
  ) {
    if (index >= 0 && index < items.length) {
      final currentRoute = GoRouterState.of(context).uri.path;
      if (currentRoute != items[index].route) {
        // Use go() for shell routes (tabs) to avoid stack accumulation.
        // For shortcuts pointing to detail routes (/detail/:id), use push
        // so the back button returns here.
        final route = items[index].route;
        if (route.startsWith('/detail/') || route.startsWith('/organizer/')) {
          context.push(route);
        } else {
          context.go(route);
        }
      }
    }
  }
}

class _OpenCommandCenterIntent extends Intent {
  const _OpenCommandCenterIntent();
}

class _CreateNewItemIntent extends Intent {
  const _CreateNewItemIntent();
}

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

class _SwitchTabIntent extends Intent {
  final int tabIndex;
  const _SwitchTabIntent(this.tabIndex);
}
