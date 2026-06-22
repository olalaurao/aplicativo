// lib/ui/widgets/create_menu_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../forms/create_task_form.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_pmn_form.dart';
import '../forms/create_idea_form.dart';
import '../forms/create_goal_form.dart';
import '../forms/create_note_form.dart';
import '../forms/create_reminder_form.dart';
import '../forms/create_tracker_form.dart';
import '../forms/create_system_form.dart';
import '../forms/create_record_form.dart';
import '../forms/create_calendar_session_form.dart';
import '../../providers/vault_provider.dart';
import '../../models/journal_entry.dart';
import '../../models/task_model.dart';

class CreateMenuSheet extends ConsumerStatefulWidget {
  final String? initialTitle;
  const CreateMenuSheet({super.key, this.initialTitle});

  @override
  ConsumerState<CreateMenuSheet> createState() => _CreateMenuSheetState();
}

class _CreateMenuSheetState extends ConsumerState<CreateMenuSheet> {
  int _selectedTab = 0; // 0 = Journal, 1 = Plan, 2 = Record, 3 = Note

  // Journal Tab state
  bool _isEntryStandard = true; // true = Entrada completa, false = Observação rápida
  String? _selectedCategory; // 'insight', 'energia', 'humor', 'encontro'
  final TextEditingController _quickTextController = TextEditingController();

  @override
  void dispose() {
    _quickTextController.dispose();
    super.dispose();
  }

  String _getCategoryPlaceholder(String category) {
    return switch (category) {
      'insight' => '💡 O que você percebeu?',
      'energia' => '⚡ Como está sua energia agora (1-5)?',
      'humor' => '😊 Como você está se sentindo?',
      'encontro' => '👥 Quem você encontrou? Do que conversaram?',
      _ => 'Digite sua observação...',
    };
  }

  Color _getCategoryColor(String category) {
    return switch (category) {
      'insight' => AppColors.warning,
      'energia' => AppColors.info,
      'humor' => AppColors.success,
      'encontro' => AppColors.habitPink,
      _ => AppColors.primary,
    };
  }

  String _getCategoryLabel(String category) {
    return switch (category) {
      'insight' => '💡 Insight',
      'energia' => '⚡ Energia',
      'humor' => '😊 Humor',
      'encontro' => '👥 Encontro',
      _ => category,
    };
  }

  void _saveQuickObservation() async {
    final text = _quickTextController.text.trim();
    if (text.isEmpty || _selectedCategory == null) return;

    int? energyValue;
    if (_selectedCategory == 'energia') {
      energyValue = int.tryParse(text);
    }

    final entry = JournalEntry(
      id: const Uuid().v4(),
      body: text,
      date: DateTime.now(),
      entryType: JournalEntryType.fieldNote,
      category: _selectedCategory,
    );
    if (energyValue != null) {
      entry.energyValue = energyValue;
    }

    try {
      await ref.read(todayJournalProvider.notifier).addEntry(entry);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Observação rápida salva com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar observação: $e')),
        );
      }
    }
  }

  Widget _buildTabHeaderButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              color: isSelected ? AppColors.primary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segmented Control
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkCardFill
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isEntryStandard = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isEntryStandard
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkSurface
                              : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Entrada completa',
                      style: TextStyle(
                        fontWeight: _isEntryStandard ? FontWeight.w700 : FontWeight.w500,
                        color: _isEntryStandard
                            ? AppTheme.textPrimaryColor(context)
                            : AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isEntryStandard = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_isEntryStandard
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkSurface
                              : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Observação rápida',
                      style: TextStyle(
                        fontWeight: !_isEntryStandard ? FontWeight.w700 : FontWeight.w500,
                        color: !_isEntryStandard
                            ? AppTheme.textPrimaryColor(context)
                            : AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_isEntryStandard) ...[
          // Entrada completa
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEntryForm(initialTitle: widget.initialTitle),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              '📓 Nova entrada',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePmnForm()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              '📋 PMN da semana',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ] else ...[
          // Observação rápida (Field Note)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['insight', 'energia', 'humor', 'encontro'].map((cat) {
                final isSelected = _selectedCategory == cat;
                final color = _getCategoryColor(cat);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_getCategoryLabel(cat)),
                    selected: isSelected,
                    selectedColor: color,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    backgroundColor: color.withValues(alpha: 0.15),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = val ? cat : null;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _quickTextController,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _getCategoryPlaceholder(_selectedCategory!),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkCardFill
                    : AppColors.surfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _quickTextController.text.trim().isNotEmpty ? _saveQuickObservation : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Salvar observação',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPlanTab() {
    return Column(
      children: [
        _buildOptionRow(
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.info,
          label: '✅ Nova task',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTaskForm(initialTitle: widget.initialTitle),
              ),
            );
          },
        ),
        const Divider(),
        _buildOptionRow(
          icon: Icons.flag_outlined,
          color: AppColors.habitGreen,
          label: '🎯 Nova meta',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateGoalForm(initialTitle: widget.initialTitle),
              ),
            );
          },
        ),
        const Divider(),
        _buildOptionRow(
          icon: Icons.event_outlined,
          color: AppColors.secondary,
          label: '📅 Nova sessão',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateCalendarSessionForm(initialTitle: widget.initialTitle),
              ),
            );
          },
        ),
        const Divider(),
        _buildOptionRow(
          icon: Icons.alarm,
          color: AppColors.warning,
          label: '🔔 Novo lembrete',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateReminderForm()),
            );
          },
        ),
        const Divider(),
        _buildOptionRow(
          icon: Icons.inbox_outlined,
          color: AppColors.info,
          label: '📥 Adicionar ao backlog',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTaskForm(
                  initialTitle: widget.initialTitle,
                  initialStage: TaskStage.backlog,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordTab() {
    final trackers = ref.watch(trackersProvider);

    if (trackers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.show_chart_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'Você ainda não tem trackers.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateTrackerForm()),
                );
              },
              child: const Text('Criar um'),
            ),
          ],
        ),
      );
    }

    if (trackers.length == 1) {
      final t = trackers.first;
      return Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateRecordForm(tracker: t)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Registrar ${t.title}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trackers.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final t = trackers[index];
        final tColor = Color(int.tryParse(t.color.replaceAll('#', '0xFF')) ?? AppColors.primary.toARGB32());

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(Icons.show_chart_rounded, color: tColor),
          title: Text(
            t.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateRecordForm(tracker: t)),
            );
          },
        );
      },
    );
  }

  Widget _buildNoteTab() {
    return Column(
      children: [
        _buildOptionRow(
          icon: Icons.description_outlined,
          color: AppColors.primary,
          label: '📝 Nota de texto',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateNoteForm(
                  initialTitle: widget.initialTitle,
                  initialType: NoteType.text,
                ),
              ),
            );
          },
        ),
        const Divider(),
        _buildOptionRow(
          icon: Icons.format_list_bulleted,
          color: AppColors.info,
          label: '🗂 Nota de outline',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateNoteForm(
                  initialTitle: widget.initialTitle,
                  initialType: NoteType.outline,
                ),
              ),
            );
          },
        ),
        const Divider(),
        _buildOptionRow(
          icon: Icons.table_chart_outlined,
          color: AppColors.habitPink,
          label: '🗃 Coleção',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateNoteForm(
                  initialTitle: widget.initialTitle,
                  initialType: NoteType.collection,
                ),
              ),
            );
          },
        ),
        const Divider(),
        _buildOptionRow(
          icon: Icons.settings_outlined,
          color: AppColors.warning,
          label: '⚙️ System',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateSystemForm()),
            );
          },
        ),
        const Divider(),
        _buildOptionRow(
          icon: Icons.lightbulb_outline_rounded,
          color: AppColors.warning,
          label: '💡 Idea',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateIdeaForm(initialTitle: widget.initialTitle),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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

            // Tabs Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTabHeaderButton('Journal', 0),
                  _buildTabHeaderButton('Plan', 1),
                  _buildTabHeaderButton('Record', 2),
                  _buildTabHeaderButton('Note', 3),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedTab),
                    child: switch (_selectedTab) {
                      0 => _buildJournalTab(),
                      1 => _buildPlanTab(),
                      2 => _buildRecordTab(),
                      3 => _buildNoteTab(),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ),
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
