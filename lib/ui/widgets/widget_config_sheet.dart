// lib/ui/widgets/widget_config_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../models/shared_types.dart';
import '../../models/content_object.dart';
import '../../models/goal_model.dart';
import '../../models/organizer_model.dart';
import '../../models/dashboard_block.dart';
import '../../providers/dashboard_provider.dart';
import '../theme.dart';

class WidgetConfigSheet extends ConsumerStatefulWidget {
  const WidgetConfigSheet({super.key});

  @override
  ConsumerState<WidgetConfigSheet> createState() => _WidgetConfigSheetState();
}

class _WidgetConfigSheetState extends ConsumerState<WidgetConfigSheet> {
  final Map<String, bool> _expanded = {
    'quick': false,
    'calendar': false,
    'habit': false,
    'note': false,
    'filter': false,
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final organizers = ref.watch(organizerListProvider);
    final dashboardBlocks = ref.watch(dashboardProvider).valueOrNull ?? [];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Widgets Nativos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure os atalhos e dados na tela inicial',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // --- QUICK-ADD WIDGET ---
                  _buildWidgetHeader(
                    key: 'quick',
                    title: 'Quick-Add (2x1)',
                    desc: 'Atalhos configuráveis de entrada rápida.',
                    icon: Icons.add_box_rounded,
                  ),
                  if (_expanded['quick'] == true) ...[
                    _buildQuickAddConfig(settings),
                    const SizedBox(height: 12),
                  ],

                  // --- CALENDAR WIDGET ---
                  _buildWidgetHeader(
                    key: 'calendar',
                    title: 'Calendário (4x2)',
                    desc:
                        'Visão semanal/mensal integrada com tarefas e hábitos.',
                    icon: Icons.calendar_today_rounded,
                  ),
                  if (_expanded['calendar'] == true) ...[
                    _buildCalendarConfig(settings),
                    const SizedBox(height: 12),
                  ],

                  // --- HABIT SUMMARY WIDGET ---
                  _buildWidgetHeader(
                    key: 'habit',
                    title: 'Resumo de Hábitos (2x2)',
                    desc: 'Sua taxa de conclusão e hábitos ativos por área.',
                    icon: Icons.loop_rounded,
                  ),
                  if (_expanded['habit'] == true) ...[
                    _buildHabitConfig(settings, organizers),
                    const SizedBox(height: 12),
                  ],

                  // --- FILTER WIDGET ---
                  _buildWidgetHeader(
                    key: 'filter',
                    title: 'Filtro (4x2)',
                    desc:
                        'Filtro de tarefas, hábitos e outros por organizador.',
                    icon: Icons.filter_alt_rounded,
                  ),
                  if (_expanded['filter'] == true) ...[
                    _buildFilterConfig(dashboardBlocks),
                    const SizedBox(height: 12),
                  ],

                  // --- OBSIDIAN NOTE WIDGET ---
                  _buildWidgetHeader(
                    key: 'note',
                    title: 'Nota Fixada (2x2)',
                    desc:
                        'Fixe uma nota específica do Obsidian na tela inicial.',
                    icon: Icons.sticky_note_2_rounded,
                  ),
                  if (_expanded['note'] == true) ...[
                    _buildNoteConfig(settings),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Trigger sync visual feedback
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Configurações dos Widgets sincronizadas com sucesso!',
                  ),
                  backgroundColor: AppColors.primary,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'SALVAR E SINCRONIZAR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetHeader({
    required String key,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isExpanded = _expanded[key] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _expanded[key] = !isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isExpanded
                      ? AppColors.primary
                      : AppTheme.textMutedColor(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppTheme.textMutedColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddConfig(AppSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Botão 1 (Esquerda)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  controller:
                      TextEditingController(
                          text: settings.quickAddWidgetButton1Label,
                        )
                        ..selection = TextSelection.collapsed(
                          offset: settings.quickAddWidgetButton1Label.length,
                        ),
                  onChanged: (val) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateWidgetQuickAddSettings(btn1Label: val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Ação',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: settings.quickAddWidgetButton1Target,
                  items: const [
                    DropdownMenuItem(value: 'journal', child: Text('Diário')),
                    DropdownMenuItem(value: 'task', child: Text('Tarefa')),
                    DropdownMenuItem(value: 'habit', child: Text('Hábito')),
                    DropdownMenuItem(value: 'note', child: Text('Nota')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateWidgetQuickAddSettings(btn1Target: val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Botão 2 (Direita)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  controller:
                      TextEditingController(
                          text: settings.quickAddWidgetButton2Label,
                        )
                        ..selection = TextSelection.collapsed(
                          offset: settings.quickAddWidgetButton2Label.length,
                        ),
                  onChanged: (val) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateWidgetQuickAddSettings(btn2Label: val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Ação',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: settings.quickAddWidgetButton2Target,
                  items: const [
                    DropdownMenuItem(value: 'journal', child: Text('Diário')),
                    DropdownMenuItem(value: 'task', child: Text('Tarefa')),
                    DropdownMenuItem(value: 'habit', child: Text('Hábito')),
                    DropdownMenuItem(value: 'note', child: Text('Nota')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateWidgetQuickAddSettings(btn2Target: val);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarConfig(AppSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de Visualização',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: settings.calendarWidgetType,
            items: const [
              DropdownMenuItem(value: 'week', child: Text('Semana')),
              DropdownMenuItem(value: 'month', child: Text('Mês')),
            ],
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(settingsProvider.notifier)
                    .updateWidgetCalendarSettings(type: val);
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Exibir no Calendário',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            title: const Text(
              'Tarefas agendadas',
              style: TextStyle(fontSize: 13),
            ),
            value: settings.calendarWidgetShowTasks,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            dense: true,
            onChanged: (val) {
              ref
                  .read(settingsProvider.notifier)
                  .updateWidgetCalendarSettings(showTasks: val);
            },
          ),
          SwitchListTile.adaptive(
            title: const Text(
              'Hábitos frequentes',
              style: TextStyle(fontSize: 13),
            ),
            value: settings.calendarWidgetShowHabits,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            dense: true,
            onChanged: (val) {
              ref
                  .read(settingsProvider.notifier)
                  .updateWidgetCalendarSettings(showHabits: val);
            },
          ),
          SwitchListTile.adaptive(
            title: const Text(
              'Foco do Dia e Pomodoros',
              style: TextStyle(fontSize: 13),
            ),
            value: settings.calendarWidgetShowSessions,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            dense: true,
            onChanged: (val) {
              ref
                  .read(settingsProvider.notifier)
                  .updateWidgetCalendarSettings(showSessions: val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHabitConfig(
    AppSettings settings,
    List<OrganizerReference> organizers,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrar Hábitos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: settings.habitWidgetFilterType,
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('Todos os hábitos ativos'),
              ),
              DropdownMenuItem(
                value: 'organizer',
                child: Text('Por Organizador (Área/Projeto)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(settingsProvider.notifier)
                    .updateWidgetHabitSettings(filterType: val);
              }
            },
          ),
          if (settings.habitWidgetFilterType == 'organizer') ...[
            const SizedBox(height: 16),
            const Text(
              'Selecionar Organizador',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              initialValue: settings.habitWidgetOrganizer.isEmpty
                  ? null
                  : settings.habitWidgetOrganizer,
              hint: const Text('Selecione uma área/projeto'),
              items: organizers.map((o) {
                return DropdownMenuItem(
                  value: o.slug,
                  child: Text('${o.title} (${o.type.toUpperCase()})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateWidgetHabitSettings(organizer: val);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteConfig(AppSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Modo de Exibição de Nota',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: settings.universalWidgetType == 'note'
                ? 'fixed'
                : 'latest',
            items: const [
              DropdownMenuItem(
                value: 'latest',
                child: Text('Última nota modificada'),
              ),
              DropdownMenuItem(
                value: 'fixed',
                child: Text('Nota fixada específica'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                final type = val == 'fixed' ? 'note' : 'daily';
                ref
                    .read(settingsProvider.notifier)
                    .updateUniversalWidgetSettings(type: type);
              }
            },
          ),
          if (settings.universalWidgetType == 'note') ...[
            const SizedBox(height: 12),
            const Text(
              'Acesse a nota diretamente no app e toque em "Fixar na tela inicial" para sincronizar este widget.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterConfig(List<DashboardBlock> blocks) {
    final block = blocks.where((b) => b.id == 'home-area').firstOrNull;
    if (block == null) {
      return const SizedBox.shrink();
    }

    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final organizers = [
      ...allObjects.whereType<Organizer>().cast<ContentObject>(),
      ...allObjects.whereType<Goal>().cast<ContentObject>(),
    ]..sort((a, b) => a.title.compareTo(b.title));

    final metadata = block.metadata;
    var organizerSlug =
        metadata['organizerSlug'] as String? ??
        (organizers.isNotEmpty ? organizers.first.slug : null);

    final rawTypes = metadata['filterObjectTypes'] ?? metadata['objectTypes'];
    final selectedObjectTypes = rawTypes is List
        ? rawTypes.map((item) => item.toString()).toSet()
        : {'task', 'habit'};

    const filterObjectTypes = <String, String>{
      'task': 'Tarefas',
      'habit': 'Hábitos',
      'pomodoro': 'Pomodoros',
      'goal': 'Goals',
      'note': 'Notas',
      'journal_entry': 'Journal',
      'resource': 'Recursos',
      'person': 'Pessoas',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecionar Organizador',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: organizers.any((o) => o.slug == organizerSlug)
                ? organizerSlug
                : null,
            hint: const Text('Selecione uma área/projeto/goal'),
            items: organizers.map((o) {
              return DropdownMenuItem(
                value: o.slug,
                child: Text(
                  o is Goal ? 'Goal · ${o.title}' : o.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                final updatedMetadata = Map<String, dynamic>.from(
                  block.metadata,
                );
                updatedMetadata['organizerSlug'] = val;
                ref
                    .read(dashboardProvider.notifier)
                    .updateBlock(block.copyWith(metadata: updatedMetadata));
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Tipos de Objeto',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filterObjectTypes.entries.map((entry) {
              final selected = selectedObjectTypes.contains(entry.key);
              return FilterChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: (value) {
                  final next = Set<String>.from(selectedObjectTypes);
                  value ? next.add(entry.key) : next.remove(entry.key);
                  final updatedMetadata = Map<String, dynamic>.from(
                    block.metadata,
                  );
                  updatedMetadata['filterObjectTypes'] = next.toList();
                  updatedMetadata['objectTypes'] = next.toList();
                  ref
                      .read(dashboardProvider.notifier)
                      .updateBlock(block.copyWith(metadata: updatedMetadata));
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.16),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
