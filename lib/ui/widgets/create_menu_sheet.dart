// lib/ui/widgets/create_menu_sheet.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import '../forms/create_task_form.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_pmn_form.dart';
import '../forms/create_habit_form.dart';
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

class CreateMenuSheet extends StatefulWidget {
  final String? initialTitle;
  const CreateMenuSheet({super.key, this.initialTitle});

  @override
  State<CreateMenuSheet> createState() => _CreateMenuSheetState();
}

class _CreateMenuSheetState extends State<CreateMenuSheet> {
  bool _isCaptureTab = true;

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
        child: SingleChildScrollView(
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

              // ─── Grid ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _isCaptureTab
                    ? _buildCaptureGrid(context)
                    : _buildCreateGrid(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool isCapture) {
    final isSelected = _isCaptureTab == isCapture;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isCaptureTab = isCapture),
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
                  : AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildCreateCard(
              context,
              icon: Icons.check_box_outlined,
              title: 'Tarefa',
              subtitle: 'Add something to your list',
              color: AppColors.info,
              targetForm: CreateTaskForm(initialTitle: widget.initialTitle),
            ),
            const SizedBox(width: 12),
            _buildCreateCard(
              context,
              icon: Icons.menu_book_rounded,
              title: 'Journal',
              subtitle: 'Registre seus pensamentos',
              color: AppColors.primary,
              targetForm: CreateEntryForm(initialTitle: widget.initialTitle),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCreateCard(
              context,
              icon: Icons.description_outlined,
              title: 'Note',
              subtitle: 'Create reference material',
              color: AppColors.habitPink,
              targetForm: CreateNoteForm(initialTitle: widget.initialTitle),
            ),
            const SizedBox(width: 12),
            _buildCreateCard(
              context,
              icon: Icons.camera_alt_outlined,
              title: 'Foto',
              subtitle: 'Quick photo entry',
              color: AppColors.warning,
              targetForm: CreateSnapshotForm(initialTitle: widget.initialTitle),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCreateCard(
              context,
              icon: Icons.timer_outlined,
              title: 'Sessão',
              subtitle: 'Start a Pomodoro session',
              color: AppColors.error,
              targetForm: const PomodoroScreen(),
            ),
            const SizedBox(width: 12),
            _buildCreateCard(
              context,
              icon: Icons.play_circle_outline_rounded,
              title: 'Post social',
              subtitle: 'Salvar link de uma rede',
              color: AppColors.info,
              targetForm: const CreateSocialPostForm(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCreateCard(
              context,
              icon: Icons.document_scanner_outlined,
              title: 'Escanear',
              subtitle: 'Scan a physical document',
              color: AppColors.habitGreen,
              targetForm: CreateScanDocumentForm(
                initialTitle: widget.initialTitle,
              ),
            ),
            const SizedBox(width: 12),
            _buildCreateCard(
              context,
              icon: Icons.view_week_rounded,
              title: 'PMN',
              subtitle: 'Plus, Minus, Next da semana',
              color: AppColors.primary,
              targetForm: const CreatePmnForm(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreateGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildCreateCard(
              context,
              icon: Icons.rocket_launch_rounded,
              title: 'Projeto',
              subtitle: 'Large goal com tasks',
              color: AppColors.priorityHigh,
              targetForm: CreateProjectForm(initialTitle: widget.initialTitle),
            ),
            const SizedBox(width: 12),
            _buildCreateCard(
              context,
              icon: Icons.cached_rounded,
              title: 'Habit',
              subtitle: 'Rastreie um comportamento',
              color: AppColors.habitPurple,
              targetForm: CreateHabitForm(initialTitle: widget.initialTitle),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCreateCard(
              context,
              icon: Icons.flag_circle_rounded,
              title: 'Goal',
              subtitle: 'Defina uma meta',
              color: AppColors.habitGreen,
              targetForm: CreateGoalForm(initialTitle: widget.initialTitle),
            ),
            const SizedBox(width: 12),
            _buildCreateCard(
              context,
              icon: Icons.show_chart_rounded,
              title: 'Rastreador',
              subtitle: 'Create a data form',
              color: AppColors.error,
              targetForm: const CreateTrackerForm(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCreateCard(
              context,
              icon: Icons.local_library_rounded,
              title: 'Resource',
              subtitle: 'Media to consume',
              color: AppColors.warning,
              targetForm: CreateResourceForm(initialTitle: widget.initialTitle),
            ),
            const SizedBox(width: 12),
            _buildCreateCard(
              context,
              icon: Icons.person_outline_rounded,
              title: 'Person',
              subtitle: 'CRM e contatos',
              color: AppColors.habitPink,
              targetForm: CreatePersonForm(initialTitle: widget.initialTitle),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCreateCard(
              context,
              icon: Icons.notifications_none_rounded,
              title: 'Lembrete',
              subtitle: 'Quick alert',
              color: AppColors.warning,
              targetForm: const CreateReminderForm(),
            ),
            const SizedBox(width: 12),
            _buildCreateCard(
              context,
              icon: Icons.event_rounded,
              title: 'Evento',
              subtitle: 'Criar no Google Calendar',
              color: AppColors.info,
              targetForm: CreateEventForm(initialTitle: widget.initialTitle),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCreateCard(
              context,
              icon: Icons.account_tree_rounded,
              title: 'System',
              subtitle: 'SOP reutilizável com steps',
              color: AppColors.habitPurple,
              targetForm: const CreateSystemForm(),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildCreateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    Widget? targetForm,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          final nav = Navigator.of(context);
          nav.pop();
          if (targetForm != null) {
            nav.push(MaterialPageRoute(builder: (_) => targetForm));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title is currently unavailable')),
            );
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
