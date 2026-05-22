// lib/ui/widgets/command_center_overlay.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';
import '../../providers/vault_provider.dart';
import '../../providers/history_provider.dart';
import '../../models/content_object.dart';
import '../../models/task_model.dart';
import '../../models/note_model.dart';
import '../../models/organizer_model.dart';

import '../forms/create_task_form.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_note_form.dart';
import '../forms/create_tracker_form.dart';
import '../screens/universal_detail_view.dart';
import '../screens/organizer_detail_screen.dart';

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

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'task':
        icon = Icons.check_box_outlined;
        color = AppColors.info;
        break;
      case 'note':
        icon = Icons.description_outlined;
        color = AppColors.habitPink;
        break;
      case 'journal_entry':
        icon = Icons.menu_book_rounded;
        color = AppColors.primary;
        break;
      case 'goal':
        icon = Icons.flag_circle_rounded;
        color = AppColors.habitGreen;
        break;
      case 'habit':
        icon = Icons.cached_rounded;
        color = AppColors.habitPurple;
        break;
      case 'organizer':
        icon = Icons.folder_outlined;
        color = AppColors.warning;
        break;
      case 'tracker':
        icon = Icons.analytics_outlined;
        color = AppColors.error;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
        color = Colors.grey;
    }
    return Icon(icon, size: 16, color: color);
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

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();

    // Providers
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final history = ref.watch(historyProvider);
    final notes = ref.watch(notesProvider);
    final organizers = ref.watch(organizersProvider);
    // Instead of sessions, let's just fetch tasks due today or upcoming
    final upcomingTasks =
        allObjects
            .whereType<Task>()
            .where(
              (t) =>
                  t.deadline != null &&
                  t.deadline!.isAfter(
                    DateTime.now().subtract(const Duration(days: 1)),
                  ),
            )
            .toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    final nextTasks = upcomingTasks.take(3).toList();

    // Notes sorted by updated at
    final sortedNotes = List<Note>.from(notes)
      ..sort((a, b) {
        final aTime = a.updatedAt;
        final bTime = b.updatedAt;
        return bTime.compareTo(aTime);
      });
    final recentNotes = sortedNotes.take(5).toList();

    // Organizers sorted by access frequency - actually we just take first 5
    final topOrganizers = organizers.take(5).toList();

    // Map history ids to real objects
    final recentObjects = history
        .map((h) => allObjects.where((o) => o.id == h.id).firstOrNull)
        .whereType<ContentObject>()
        .take(8)
        .toList();

    final isSearching = query.isNotEmpty;
    final searchResults = isSearching
        ? allObjects
              .where((o) => o.title.toLowerCase().contains(query))
              .take(15)
              .toList()
        : <ContentObject>[];

    return Scaffold(
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
                  color: AppTheme.surfaceColor(context).withValues(alpha: 0.6),
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
                                      builder: (_) => const CreateEntryForm(),
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
                                      builder: (_) => const CreateTaskForm(),
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
                                      builder: (_) => const CreateTrackerForm(),
                                    ),
                                  );
                                },
                              ),
                              _buildQuickAction(
                                context,
                                'Nova Nota',
                                Icons.description_outlined,
                                () {
                                  _close();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CreateNoteForm(),
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
                          ? _buildSearchResults(searchResults)
                          : _buildDashboardSections(
                              recentObjects,
                              recentNotes,
                              nextTasks,
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
    );
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
    List<Note> notes,
    List<Task> tasks,
    List<Organizer> organizers,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (recent.isNotEmpty)
          _buildHorizontalSection(
            'Recentes',
            recent,
            (obj) => _buildObjectChip(obj),
          ),
        if (notes.isNotEmpty)
          _buildHorizontalSection(
            'Notas Recentes',
            notes,
            (obj) => _buildObjectChip(obj),
          ),
        if (tasks.isNotEmpty)
          _buildHorizontalSection(
            'Próximas Tasks',
            tasks,
            (obj) => _buildObjectChip(obj),
          ),
        if (organizers.isNotEmpty)
          _buildHorizontalSection(
            'Organizers',
            organizers,
            (obj) => _buildObjectChip(obj),
          ),
      ],
    );
  }

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

  Widget _buildSearchResults(List<ContentObject> results) {
    if (results.isEmpty) {
      return const Center(child: Text('Nenhum resultado encontrado.'));
    }
    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final obj = results[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildTypeIcon(obj.type),
          ),
          title: Text(obj.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            obj.type.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          onTap: () => _openObject(obj),
        );
      },
    );
  }
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
