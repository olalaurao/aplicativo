// lib/ui/widgets/command_center_overlay.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../../providers/vault_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/systems_provider.dart';
import '../../models/content_object.dart';
import '../../models/note_model.dart';
import '../../models/journal_entry.dart';
import '../../models/task_model.dart';
import '../../models/organizer_model.dart';
import '../../models/system_model.dart';
import '../../models/event_model.dart';
import '../../services/search_service.dart';

import '../forms/create_task_form.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_tracker_form.dart';
import '../screens/universal_detail_view.dart';
import '../screens/organizer_detail_screen.dart';
import '../forms/create_system_form.dart';
import '../screens/system_detail_screen.dart';

class CommandCenterOverlay extends ConsumerStatefulWidget {
  const CommandCenterOverlay({super.key});

  @override
  ConsumerState<CommandCenterOverlay> createState() =>
      _CommandCenterOverlayState();
}

class _CommandCenterOverlayState extends ConsumerState<CommandCenterOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();

    // Auto-focus after the build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _close() {
    _searchFocus.unfocus();
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'task':
        return AppColors.info;
      case 'note':
        return AppColors.habitPink;
      case 'entry':
        return AppColors.primary;
      case 'goal':
        return AppColors.habitGreen;
      case 'habit':
        return AppColors.habitPurple;
      case 'organizer':
        return AppColors.warning;
      case 'tracker':
        return AppColors.error;
      case 'system':
        return AppColors.primary;
      case 'event':
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    final color = _typeColor(type);
    switch (type) {
      case 'task':
        icon = Icons.check_box_outlined;
        break;
      case 'note':
        icon = Icons.description_outlined;
        break;
      case 'entry':
        icon = Icons.menu_book_rounded;
        break;
      case 'goal':
        icon = Icons.flag_circle_rounded;
        break;
      case 'habit':
        icon = Icons.cached_rounded;
        break;
      case 'organizer':
        icon = Icons.folder_outlined;
        break;
      case 'tracker':
        icon = Icons.analytics_outlined;
        break;
      case 'system':
        icon = Icons.account_tree_outlined;
        break;
      case 'event':
        icon = Icons.event_rounded;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
    }
    return Icon(icon, size: 16, color: color);
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'task':
        return 'Tarefas';
      case 'note':
        return 'Notas';
      case 'entry':
        return 'Entradas';
      case 'goal':
        return 'Objetivos';
      case 'habit':
        return 'Hábitos';
      case 'organizer':
        return 'Organizadores';
      case 'tracker':
        return 'Trackers';
      case 'system':
        return 'Systems';
      case 'event':
        return 'Events';
      case 'reminder':
        return 'Lembretes';
      case 'person':
        return 'Pessoas';
      case 'resource':
        return 'Recursos';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  void _openObject(ContentObject item) {
    final navigator = Navigator.of(context);
    _close();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (item is Organizer) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => OrganizerDetailScreen(organizer: item),
          ),
        );
      } else {
        navigator.push(
          MaterialPageRoute(builder: (_) => UniversalDetailView(object: item)),
        );
      }
    });
  }

  void _quickRunSystem(SystemDefinition system) {
    final navigator = Navigator.of(context);
    _close();
    Future.delayed(const Duration(milliseconds: 200), () {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => SystemDetailScreen(system: system, autoStart: true),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();

    // Providers
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final history = ref.watch(historyProvider);
    final notes = ref.watch(notesProvider);
    final organizers = ref.watch(organizersProvider);
    final topSystems = ref.watch(topSystemsProvider);
    final events = allObjects.whereType<Event>().toList();

    // Upcoming events: upcoming (date after yesterday), top 3
    final now = DateTime.now();
    final upcomingEvents =
        events
            .where(
              (s) =>
                  s.date.isAfter(now.subtract(const Duration(days: 1))) &&
                  s.state != EventState.completed &&
                  s.state != EventState.cancelled,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final nextEvents = upcomingEvents.take(3).toList();

    // Notes sorted by updated at
    final sortedNotes = List<Note>.from(notes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recentNotes = sortedNotes.take(5).toList();

    // Organizers (first 5)
    final topOrganizers = organizers.take(5).toList();

    // Map history ids to real objects
    final recentObjects = history
        .map((h) => allObjects.where((o) => o.id == h.id).firstOrNull)
        .whereType<ContentObject>()
        .take(8)
        .toList();

    final isSearching = query.isNotEmpty;

    // Grouped search results: by type, max 4 per group
    Map<String, List<ContentObject>> groupedResults = {};
    if (isSearching) {
      final matched = allObjects
          .where((object) => _matchesQuery(object, query))
          .take(50)
          .toList();
      for (final obj in matched) {
        groupedResults.putIfAbsent(obj.type, () => []);
        if ((groupedResults[obj.type]?.length ?? 0) < 4) {
          groupedResults[obj.type]!.add(obj);
        }
      }
    }
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
      },
      child: Actions(
        actions: {
          _CloseIntent: CallbackAction<_CloseIntent>(
            onInvoke: (_) {
              _close();
              return null;
            },
          ),
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < -500) {
                _close(); // Swipe up to close
              }
            },
            child: Stack(
              children: [
                // Backdrop blur
                GestureDetector(
                  onTap: _close,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: AppTheme.surfaceColor(
                        context,
                      ).withValues(alpha: 0.6),
                    ),
                  ),
                ),

                // Sliding Panel
                SafeArea(
                  child: AnimatedBuilder(
                    animation: _slideAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          0,
                          -MediaQuery.of(context).size.height *
                              (1 - _slideAnimation.value),
                        ),
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        // Search bar area
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cardFillColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.dividerColor(context),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'O que você precisa?',
                                border: InputBorder.none,
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: AppColors.primary,
                                ),
                                suffixIcon: isSearching
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Quick Actions (always visible)
                        if (!isSearching)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildQuickAction(
                                    context,
                                    'Nova Entrada',
                                    Icons.menu_book_rounded,
                                    () {
                                      _close();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CreateEntryForm(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildQuickAction(
                                    context,
                                    'Nova Task',
                                    Icons.check_box_outlined,
                                    () {
                                      _close();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CreateTaskForm(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildQuickAction(
                                    context,
                                    'Novo Registro',
                                    Icons.analytics_outlined,
                                    () {
                                      _close();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CreateTrackerForm(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildQuickAction(
                                    context,
                                    'Novo System',
                                    Icons.account_tree_outlined,
                                    () {
                                      _close();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CreateSystemForm(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Search Results OR Sections
                        Expanded(
                          child: isSearching
                              ? _buildSearchResults(groupedResults)
                              : _buildDashboardSections(
                                  recentObjects,
                                  history,
                                  topSystems,
      nextEvents,
                                  recentNotes,
                                  topOrganizers,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // F3.2: Use shared SearchService instead of custom implementation
  bool _matchesQuery(ContentObject object, String query) {
    final searchService = SearchService();
    final results = searchService.search([object], query);
    return results.isNotEmpty;
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.dividerColor(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSections(
    List<ContentObject> recent,
    List<HistoryEntry> history,
    List<SystemDefinition> topSystems,
    List<Event> nextEvents,
    List<Note> notes,
    List<Organizer> organizers,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Recentes (dismissible) ──
        if (recent.isNotEmpty) _buildRecentSection(recent, history),

        // ── Systems (quick-run chips) ──
        if (topSystems.isNotEmpty) _buildSystemsSection(topSystems),

        // ── Upcoming events ──
        if (nextEvents.isNotEmpty) _buildEventsSection(nextEvents),

        // ── Notas Recentes ──
        if (notes.isNotEmpty)
          _buildHorizontalSection(
            'Notas Recentes',
            notes,
            (obj) => _buildObjectChip(obj),
          ),

        // ── Organizers ──
        if (organizers.isNotEmpty)
          _buildHorizontalSection(
            'Organizers',
            organizers,
            (obj) => _buildObjectChip(obj),
          ),
      ],
    );
  }

  // ─── Recentes: horizontal chips with swipe-to-dismiss ───────────────────
  Widget _buildRecentSection(
    List<ContentObject> recent,
    List<HistoryEntry> history,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Recentes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: recent.map((obj) {
                final histEntry = history
                    .where((h) => h.id == obj.id)
                    .firstOrNull;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Dismissible(
                    key: Key('recent_${obj.id}'),
                    direction: DismissDirection.up,
                    onDismissed: (_) => _removeFromHistory(obj, histEntry),
                    background: Container(
                      width: 140,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: 12),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                    ),
                    child: _buildObjectChip(obj),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _removeFromHistory(ContentObject obj, HistoryEntry? entry) {
    ref.read(historyProvider.notifier).remove(obj.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${obj.title} removido dos recentes'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: entry != null
            ? SnackBarAction(
                label: 'Desfazer',
                textColor: AppColors.primary,
                onPressed: () {
                  ref.read(historyProvider.notifier).push(obj);
                },
              )
            : null,
      ),
    );
  }

  // ─── Systems: quick-run chips ────────────────────────────────────────────
  Widget _buildSystemsSection(List<SystemDefinition> systems) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Systems',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: systems.map((system) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSystemChip(system),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemChip(SystemDefinition system) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _quickRunSystem(system),
        onLongPress: () => _openObject(system),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 148,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${system.runCount}x',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                system.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (system.estimatedMinutes > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '~${system.estimatedMinutes}m',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Upcoming events ─────────────────────────────────────────────────────
  Widget _buildEventsSection(List<Event> events) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Upcoming Events',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...events.map((event) => _buildEventTile(event)),
        ],
      ),
    );
  }

  Widget _buildEventTile(Event event) {
    final dotColor = AppColors.info;
    final isToday =
        event.date.day == DateTime.now().day &&
        event.date.month == DateTime.now().month &&
        event.date.year == DateTime.now().year;

    final dateLabel = isToday
        ? 'Today ${event.timeOfDay ?? ""}'.trim()
        : '${DateFormat('d/M').format(event.date)} ${event.timeOfDay ?? ""}'
              .trim();

    return InkWell(
      onTap: () => _openObject(event),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateLabel,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Generic horizontal section ──────────────────────────────────────────
  Widget _buildHorizontalSection<T extends ContentObject>(
    String title,
    List<T> items,
    Widget Function(T) builder,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: items
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: builder(e),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectChip(ContentObject obj) {
    return Material(
      color: AppTheme.surfaceVariantColor(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openObject(obj),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeIcon(obj.type),
              const SizedBox(height: 8),
              Text(
                obj.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Grouped Search Results ───────────────────────────────────────────────
  Widget _buildSearchResults(Map<String, List<ContentObject>> grouped) {
    if (grouped.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nenhum resultado encontrado.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final groups = grouped.entries.toList();

    return ListView.builder(
      itemCount: groups.fold<int>(0, (sum, e) => sum + e.value.length + 1),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (context, index) {
        // Build a flat list from grouped entries: [header, item, item, ..., header, ...]
        int cursor = 0;
        for (final entry in groups) {
          if (index == cursor) {
            // Group header
            return _buildGroupHeader(entry.key, entry.value.length);
          }
          cursor++;
          for (final obj in entry.value) {
            if (index == cursor) {
              return _buildSearchResultTile(obj);
            }
            cursor++;
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGroupHeader(String type, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          _buildTypeIcon(type),
          const SizedBox(width: 8),
          Text(
            _typeLabel(type),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _typeColor(type),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _typeColor(type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _typeColor(type),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(ContentObject obj) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _typeColor(obj.type).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildTypeIcon(obj.type),
      ),
      title: Text(
        obj.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      onTap: () => _openObject(obj),
    );
  }
}

// Intent for Escape key
class _CloseIntent extends Intent {
  const _CloseIntent();
}

void showCommandCenter(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Command Center',
    barrierColor: Colors.transparent, // We do our own backdrop blur
    transitionDuration: Duration.zero, // We do our own animation
    pageBuilder: (context, animation, secondaryAnimation) {
      return const CommandCenterOverlay();
    },
  );
}



