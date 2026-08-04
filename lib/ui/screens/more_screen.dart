// lib/ui/screens/more_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../../providers/navigation_provider.dart';
import '../../models/navigation_item.dart';
import 'settings_screen.dart';
import 'shopping_list_screen.dart';
import 'vault_files_screen.dart';
import 'object_conflicts_screen.dart';
import 'day_theme_screen.dart';
import 'pillars_screen.dart';
import '../../providers/google_calendar_provider.dart';
import '../widgets/navigation_shortcut_picker.dart';
import '../widgets/universal_search_picker.dart';
import '../../providers/vault_provider.dart';
import '../../services/sync_manager.dart';
import '../../providers/settings_provider.dart';
import 'merge_flow_orchestrator.dart';
import '../../models/content_object.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _isEditingNav = false;
  bool _showHidden = false;
  bool _isNavContentExpanded = false;
  bool _isQuickAccessExpanded = false;

  @override
  Widget build(BuildContext context) {
    final navItemsAsync = ref.watch(navigationProvider);
    final navItems = navItemsAsync.valueOrNull ?? [];

    // Items to show in this screen: everything NOT in the bottom bar,
    // EXCEPT home and more itself (which are always present elsewhere)
    // Also filter out hidden items unless in edit mode with showHidden enabled
    final inMoreItems = navItems
        .where(
          (it) =>
              it.section != NavSection.home &&
              it.section != NavSection.more &&
              !it.inBottomBar &&
              (!_isEditingNav || _showHidden ? true : !it.hidden),
        )
        .toList();
    final hasDayThemeInNav = inMoreItems.any(
      (item) => item.route == '/day-themes',
    );

    // All items that CAN be in more (to show in edit mode)
    final editableItems = navItems
        .where((it) => it.section != NavSection.home)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('More'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_isEditingNav)
            IconButton(
              icon: Icon(
                Icons.add_link_rounded,
                color: AppTheme.accentColor(context),
              ),
              onPressed: () => _showAddShortcut(context),
            ),
          IconButton(
            icon: Icon(
              _isEditingNav ? Icons.check_rounded : Icons.tune_rounded,
              color: _isEditingNav
                  ? AppTheme.accentColor(context)
                  : AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _isEditingNav = !_isEditingNav),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSyncRow(context),
                _buildAppSyncToggle(context),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  'Navigation & Content',
                  isExpanded: _isNavContentExpanded,
                  onToggle: () => setState(() => _isNavContentExpanded = !_isNavContentExpanded),
                ),
                if (_isNavContentExpanded) ...[
                  if (_isEditingNav) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          'Drag to reorder. Eye icon pins to footer. Shortcuts can be deleted.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              'Show hidden',
                              style: TextStyle(
                                fontSize: 12,
                                color: _showHidden
                                    ? AppTheme.accentColor(context)
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _showHidden,
                              onChanged: (value) => setState(() => _showHidden = value),
                              activeColor: AppTheme.accentColor(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(navigationProvider.notifier)
                          .reorderVisibleItems(
                            editableItems,
                            oldIndex,
                            newIndex,
                          );
                    },
                    children: editableItems
                        .asMap()
                        .entries
                        .map(
                          (item) => _buildNavigationMenuRow(
                            context,
                            item.value,
                            reorderIndex: item.key,
                            key: ValueKey(
                              item.value.isCustom
                                  ? (item.value.id ?? item.value.route)
                                  : item.value.section.toString(),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else ...[
                  if (inMoreItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'All items are in the footer.\nTap adjust to add shortcuts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ...inMoreItems.map(
                      (item) => _buildNavigationMenuRow(
                        context,
                        item,
                        key: ValueKey(
                          item.isCustom
                              ? (item.id ?? item.route)
                              : item.section.toString(),
                        ),
                      ),
                    ),
                ],
                ],

                const SizedBox(height: 24),
                _buildSectionHeader(
                  'Quick Access',
                  isExpanded: _isQuickAccessExpanded,
                  onToggle: () => setState(() => _isQuickAccessExpanded = !_isQuickAccessExpanded),
                ),
                if (_isQuickAccessExpanded) ...[
                  const SizedBox(height: 12),
                  _buildMenuRow(
                    context,
                    'Shopping List',
                    Icons.shopping_cart_outlined,
                    AppColors.habitBlue,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShoppingListScreen(),
                        ),
                      );
                    },
                  ),

                  if (!hasDayThemeInNav) ...[
                    const SizedBox(height: 8),
                    _buildMenuRow(
                      context,
                      'Day Themes & Blocks',
                      Icons.wb_sunny_rounded,
                      AppColors.warning,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DayThemeScreen(),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                  ],

                  _buildMenuRow(
                    context,
                    'Year Overview',
                    Icons.calendar_month_rounded,
                    AppTheme.accentColor(context),
                    () {
                      context.push('/planning/year');
                    },
                  ),

                  const SizedBox(height: 8),
                  _buildMenuRow(
                    context,
                    'Vault Files',
                    Icons.folder_copy_outlined,
                    AppColors.textMuted,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VaultFilesScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),
                _buildMenuRow(
                  context,
                  'Pillars',
                  Icons.account_balance,
                  AppColors.habitPurple,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PillarsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final conflictsCount = ref
                        .watch(typeConflictedObjectsProvider)
                        .length;
                    return _buildMenuRow(
                      context,
                      'Type Conflicts${conflictsCount > 0 ? " ($conflictsCount)" : ""}',
                      Icons.warning_amber_rounded,
                      conflictsCount > 0 ? AppColors.error : AppColors.warning,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ObjectConflictsScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 8),
                _buildMenuRow(
                  context,
                  'Merge Objects',
                  Icons.merge_type_rounded,
                  AppColors.info,
                  () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => UniversalSearchPickerSheet(
                        title: 'Select Objects to Merge',
                        onSelected: (obj) {
                          // Single selection not allowed for merge
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select 2+ objects to merge'),
                            ),
                          );
                        },
                        allowMultiSelect: true,
                        onMultiSelected: (selectedObjects) {
                          Navigator.pop(context);
                          // Navigate to merge flow
                          _startMergeFlow(context, selectedObjects as List<ContentObject>);
                        },
                      ),
                    );
                  },
                ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool? isExpanded, VoidCallback? onToggle}) {
    final text = Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );

    if (isExpanded != null && onToggle != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 8),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                text,
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: text,
    );
  }


  void _showAddShortcut(BuildContext context) async {
    final result = await showModalBottomSheet<NavigationItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NavigationShortcutPicker(),
    );

    if (result != null) {
      ref.read(navigationProvider.notifier).addShortcut(result);
    }
  }

  void _startMergeFlow(BuildContext context, List selectedObjects) {
    // Use the merge flow orchestrator to handle the complete merge process
    MergeFlowOrchestrator.startMergeFlow(context, ref, selectedObjects as List<ContentObject>);
  }

  void _showRenameShortcut(BuildContext context, NavigationItem item) {
    final controller = TextEditingController(text: item.label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Shortcut'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Shortcut name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(navigationProvider.notifier)
                    .renameShortcut(item.id ?? '', controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationMenuRow(
    BuildContext context,
    NavigationItem item, {
    Key? key,
    int? reorderIndex,
  }) {
    final canDelete = _isEditingNav && item.isCustom;
    final canToggle =
        _isEditingNav &&
        item.section != NavSection.home &&
        item.section != NavSection.more;

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _isEditingNav ? null : () => context.go(item.route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: item.hidden && _isEditingNav
              ? AppTheme.cardDecoration(context).copyWith(
                  border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.3)),
                )
              : AppTheme.cardDecoration(context),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_isEditingNav) ...[
                if (reorderIndex != null)
                  ReorderableDragStartListener(
                    index: reorderIndex,
                    child: const Icon(
                      Icons.drag_indicator_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  )
                else
                  const Icon(
                    Icons.drag_indicator_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                const SizedBox(width: 12),
              ],
              (() {
                final iconContainer = Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        (item.isCustom ? AppTheme.accentColor(context) : AppTheme.accentColor(context))
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: item.isCustom ? AppTheme.accentColor(context) : AppTheme.accentColor(context),
                  ),
                );

                if (item.section == NavSection.inbox) {
                  final count = ref.watch(inboxCountProvider);
                  if (count > 0) {
                    return Badge(
                      label: Text(count.toString()),
                      child: iconContainer,
                    );
                  }
                }
                return iconContainer;
              })(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: item.hidden && _isEditingNav ? AppColors.textMuted : null,
                      ),
                    ),
                    if (item.isCustom)
                      Text(
                        item.type?.toUpperCase() ?? 'SHORTCUT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (_isEditingNav) ...[
                if (canToggle) ...[
                  IconButton(
                    icon: Icon(
                      item.hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: item.hidden
                          ? AppColors.textMuted
                          : AppTheme.accentColor(context),
                      size: 20,
                    ),
                    onPressed: () => ref
                        .read(navigationProvider.notifier)
                        .toggleHidden(
                          item.isCustom ? item.id : item.section,
                        ),
                  ),
                  IconButton(
                    icon: Icon(
                      item.inBottomBar
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: item.inBottomBar
                          ? AppTheme.accentColor(context)
                          : AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => ref
                        .read(navigationProvider.notifier)
                        .toggleInBottomBar(
                          item.isCustom ? item.id : item.section,
                        ),
                  ),
                ]
                else
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    onPressed: () => ref
                        .read(navigationProvider.notifier)
                        .removeShortcut(item.id ?? ''),
                  ),
                if (item.isCustom)
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => _showRenameShortcut(context, item),
                  ),
              ] else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncRow(BuildContext context) {
    final authAccount = ref.watch(googleAuthServiceProvider);
    final authNotifier = ref.read(googleAuthServiceProvider.notifier);
    final isSignedIn = authAccount != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          if (isSignedIn) {
            await authNotifier.signOut();
          } else {
            await authNotifier.signIn();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: AppTheme.cardDecoration(context),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSignedIn
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  size: 20,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      isSignedIn ? 'Connected' : 'Tap to connect',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSignedIn)
                const Text(
                  'Sign out',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.priorityHigh,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuRow(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: AppTheme.cardDecoration(context),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppSyncToggle(BuildContext context) {
    final authAccount = ref.watch(googleAuthServiceProvider);
    final isSignedIn = authAccount != null;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    
    // Only show sync toggle if user is signed in to Google
    if (!isSignedIn) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (settings.autoSync ? AppTheme.accentColor(context) : AppColors.textMuted).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                settings.autoSync ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                size: 20,
                color: settings.autoSync ? AppTheme.accentColor(context) : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App Sync (Google Drive)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    settings.autoSync ? 'Active - syncing changes' : 'Disabled (Obsidian Sync mode)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: settings.autoSync,
              onChanged: (value) async {
                await notifier.updateAutoSync(value);
                if (value) {
                  // Trigger immediate sync when enabled
                  ref.read(syncManagerProvider).performSync(debounce: true);
                }
              },
              activeThumbColor: AppTheme.accentColor(context),
            ),
          ],
        ),
      ),
    );
  }
}
