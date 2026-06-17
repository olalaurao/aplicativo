// lib/ui/widgets/create_menu_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../forms/create_task_form.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_pmn_form.dart';
import '../forms/create_habit_form.dart';
import '../forms/create_idea_form.dart';
import '../forms/create_goal_form.dart';
import '../forms/create_note_form.dart';
import '../forms/create_event_form.dart';
import '../forms/create_social_post_form.dart';
import '../forms/create_scan_document_form.dart';
import '../forms/create_reminder_form.dart';
import '../forms/create_project_form.dart';
import '../forms/create_person_form.dart';
import '../forms/create_resource_form.dart';
import '../forms/create_snapshot_form.dart';
import '../forms/create_tracker_form.dart';
import '../forms/create_system_form.dart';
import '../screens/pomodoro_screen.dart';

class MenuItemDef {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget Function(BuildContext)? targetBuilder;
  final void Function(BuildContext)? onTapOverride;

  MenuItemDef({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.targetBuilder,
    this.onTapOverride,
  });
}

class CreateMenuSheet extends ConsumerStatefulWidget {
  final String? initialTitle;
  const CreateMenuSheet({super.key, this.initialTitle});

  @override
  ConsumerState<CreateMenuSheet> createState() => _CreateMenuSheetState();
}

class _CreateMenuSheetState extends ConsumerState<CreateMenuSheet> {
  bool _isCaptureTab = true;
  bool _isReordering = false;

  late List<MenuItemDef> _captureItems;
  late List<MenuItemDef> _createItems;

  @override
  void initState() {
    super.initState();
    _initItems();
    _loadOrder();
  }

  void _initItems() {
    _captureItems = [
      MenuItemDef(
        id: 'mercado',
        icon: Icons.shopping_cart_outlined,
        title: 'Mercado',
        subtitle: 'Lista de compras',
        color: AppColors.accent,
        onTapOverride: (context) {
          context.push('/shopping');
          Navigator.of(context).pop();
        },
      ),
      MenuItemDef(
        id: 'ideia',
        icon: Icons.lightbulb_outline_rounded,
        title: 'Ideia',
        subtitle: 'Captura rápida',
        color: AppColors.warning,
        targetBuilder: (_) => CreateIdeaForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'tarefa',
        icon: Icons.check_box_outlined,
        title: 'Tarefa',
        subtitle: 'Add something to your list',
        color: AppColors.info,
        targetBuilder: (_) => CreateTaskForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'journal',
        icon: Icons.menu_book_rounded,
        title: 'Journal',
        subtitle: 'Registre seus pensamentos',
        color: AppColors.primary,
        targetBuilder: (_) => CreateEntryForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'note',
        icon: Icons.description_outlined,
        title: 'Note',
        subtitle: 'Create reference material',
        color: AppColors.habitPink,
        targetBuilder: (_) => CreateNoteForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'foto',
        icon: Icons.camera_alt_outlined,
        title: 'Foto',
        subtitle: 'Quick photo entry',
        color: AppColors.warning,
        targetBuilder: (_) => CreateSnapshotForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'sessao',
        icon: Icons.timer_outlined,
        title: 'Sessão',
        subtitle: 'Start a Pomodoro session',
        color: AppColors.error,
        targetBuilder: (_) => const PomodoroScreen(),
      ),
      MenuItemDef(
        id: 'social',
        icon: Icons.play_circle_outline_rounded,
        title: 'Post social',
        subtitle: 'Salvar link de uma rede',
        color: AppColors.info,
        targetBuilder: (_) => const CreateSocialPostForm(),
      ),
      MenuItemDef(
        id: 'escanear',
        icon: Icons.document_scanner_outlined,
        title: 'Escanear',
        subtitle: 'Scan a physical document',
        color: AppColors.habitGreen,
        targetBuilder: (_) => CreateScanDocumentForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'pmn',
        icon: Icons.view_week_rounded,
        title: 'PMN',
        subtitle: 'Plus, Minus, Next da semana',
        color: AppColors.primary,
        targetBuilder: (_) => const CreatePmnForm(),
      ),
    ];

    _createItems = [
      MenuItemDef(
        id: 'projeto',
        icon: Icons.rocket_launch_rounded,
        title: 'Projeto',
        subtitle: 'Large goal com tasks',
        color: AppColors.priorityHigh,
        targetBuilder: (_) => CreateProjectForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'habit',
        icon: Icons.cached_rounded,
        title: 'Habit',
        subtitle: 'Rastreie um comportamento',
        color: AppColors.habitPurple,
        targetBuilder: (_) => CreateHabitForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'goal',
        icon: Icons.flag_circle_rounded,
        title: 'Goal',
        subtitle: 'Defina uma meta',
        color: AppColors.habitGreen,
        targetBuilder: (_) => CreateGoalForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'rastreador',
        icon: Icons.show_chart_rounded,
        title: 'Rastreador',
        subtitle: 'Create a data form',
        color: AppColors.error,
        targetBuilder: (_) => const CreateTrackerForm(),
      ),
      MenuItemDef(
        id: 'resource',
        icon: Icons.local_library_rounded,
        title: 'Resource',
        subtitle: 'Media to consume',
        color: AppColors.warning,
        targetBuilder: (_) => CreateResourceForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'person',
        icon: Icons.person_outline_rounded,
        title: 'Person',
        subtitle: 'CRM e contatos',
        color: AppColors.habitPink,
        targetBuilder: (_) => CreatePersonForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'lembrete',
        icon: Icons.notifications_none_rounded,
        title: 'Lembrete',
        subtitle: 'Quick alert',
        color: AppColors.warning,
        targetBuilder: (_) => const CreateReminderForm(),
      ),
      MenuItemDef(
        id: 'evento',
        icon: Icons.event_rounded,
        title: 'Evento',
        subtitle: 'Criar no Google Calendar',
        color: AppColors.info,
        targetBuilder: (_) => CreateEventForm(initialTitle: widget.initialTitle),
      ),
      MenuItemDef(
        id: 'system',
        icon: Icons.account_tree_rounded,
        title: 'System',
        subtitle: 'SOP reutilizável com steps',
        color: AppColors.habitPurple,
        targetBuilder: (_) => const CreateSystemForm(),
      ),
    ];
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final capOrder = prefs.getStringList('menuOrder_capture');
    if (capOrder != null) {
      setState(() {
        _captureItems.sort((a, b) {
          final aIdx = capOrder.indexOf(a.id);
          final bIdx = capOrder.indexOf(b.id);
          if (aIdx == -1 && bIdx == -1) return 0;
          if (aIdx == -1) return 1;
          if (bIdx == -1) return -1;
          return aIdx.compareTo(bIdx);
        });
      });
    }

    final creOrder = prefs.getStringList('menuOrder_create');
    if (creOrder != null) {
      setState(() {
        _createItems.sort((a, b) {
          final aIdx = creOrder.indexOf(a.id);
          final bIdx = creOrder.indexOf(b.id);
          if (aIdx == -1 && bIdx == -1) return 0;
          if (aIdx == -1) return 1;
          if (bIdx == -1) return -1;
          return aIdx.compareTo(bIdx);
        });
      });
    }
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('menuOrder_capture', _captureItems.map((e) => e.id).toList());
    await prefs.setStringList('menuOrder_create', _createItems.map((e) => e.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Title row with close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Criar Novo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isReordering ? Icons.check_circle_rounded : Icons.edit_rounded,
                      color: _isReordering ? AppColors.accent : AppTheme.textSecondaryColor(context),
                    ),
                    onPressed: () {
                      setState(() {
                        _isReordering = !_isReordering;
                      });
                      if (!_isReordering) {
                        _saveOrder();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariantColor(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // ─── Tabs ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCardFill
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTabButton('Capture', true),
                    _buildTabButton('Criar', false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Grid or Reorderable List ───
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _isReordering ? _buildReorderableList(context) : _buildDynamicGrid(context),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool isCapture) {
    final isSelected = _isCaptureTab == isCapture;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!_isReordering) {
            setState(() => _isCaptureTab = isCapture);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurface
                      : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppTheme.textPrimaryColor(context)
                  : (_isReordering ? AppTheme.textMutedColor(context) : AppTheme.textSecondaryColor(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReorderableList(BuildContext context) {
    final items = _isCaptureTab ? _captureItems : _createItems;
    
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        setState(() {
          final item = items.removeAt(oldIndex);
          items.insert(newIndex, item);
        });
      },
      children: items.map((item) {
        return Container(
          key: ValueKey(item.id),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkCardFill
                : AppColors.cardFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            trailing: const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDynamicGrid(BuildContext context) {
    final items = _isCaptureTab ? _captureItems : _createItems;
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 40 - 12) / 2; // 40 horizontal padding, 12 spacing

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) {
        return SizedBox(
          width: itemWidth,
          child: _buildCreateCard(
            context,
            icon: item.icon,
            title: item.title,
            subtitle: item.subtitle,
            color: item.color,
            targetBuilder: item.targetBuilder,
            onTapOverride: item.onTapOverride,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCreateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    Widget Function(BuildContext)? targetBuilder,
    void Function(BuildContext)? onTapOverride,
  }) {
    return InkWell(
      onTap: () {
        if (_isReordering) return;
        if (onTapOverride != null) {
          onTapOverride(context);
        } else {
          final nav = Navigator.of(context);
          nav.pop();
          if (targetBuilder != null) {
            nav.push(MaterialPageRoute(builder: targetBuilder));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title is currently unavailable')),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkCardFill
              : AppColors.cardFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkDivider
                : AppColors.divider,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

void showCreateMenu(BuildContext context, {String? initialTitle}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CreateMenuSheet(initialTitle: initialTitle),
  );
}
