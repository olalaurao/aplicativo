// lib/ui/screens/object_conflicts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/content_object.dart';

class ObjectConflictsScreen extends ConsumerWidget {
  const ObjectConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(typeConflictedObjectsProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Type Conflicts'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.accentColor(context)),
            onPressed: () {
              ref.invalidate(allObjectsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Atualizando vault...')),
              );
            },
            tooltip: 'Recarregar do disco',
          ),
        ],
      ),
      body: SafeArea(
        child: conflicts.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.habitGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: AppColors.habitGreen,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Nenhum conflito de tipo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Todos os objetos no vault estão alinhados com suas assinaturas de arquivo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: conflicts.length,
                itemBuilder: (context, index) {
                  final obj = conflicts[index];
                  final literalType = obj.literalType ?? 'N/A';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    color: Theme.of(context).cardColor,
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      obj.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      obj.obsidianPath,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              obj.conflictReason ?? 'Conflito de tipo desconhecido.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTransformationButtons(context, ref, obj, literalType, settings),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _getDefaultFolderForType(String type) {
    return switch (type) {
      'mood_definition' => 'moods',
      'combined_analysis' => 'analyses',
      'goal' => 'goals',
      'task' => 'tasks',
      'habit' => 'habits',
      'tracker_definition' => 'trackers',
      'note' => 'notes',
      'resource' => 'resources',
      'person' => 'organizers/people',
      'project' => 'organizers/projects',
      'area' => 'organizers/areas',
      'activity' => 'organizers/activities',
      'label' => 'organizers/labels',
      'event' => 'app',
      'reminder' => 'app',
      'idea' => 'notes/ideas',
      'system' => 'app',
      'snapshot' => 'app',
      'social_post' => 'app',
      'shopping_list' => 'app',
      'wellbeing_indicator' => 'app',
      'template' => 'app',
      'day_theme' => 'app',
      'time_block' => 'app',
      _ => 'app',
    };
  }

  Widget _buildTransformationButtons(
    BuildContext context,
    WidgetRef ref,
    ContentObject obj,
    String literalType,
    AppSettings settings,
  ) {
    final detectedType = obj.type;
    final suggestions = _getTransformationSuggestions(detectedType, literalType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transformar em:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((targetType) {
            return _TransformationButton(
              label: _getTypeDisplayName(targetType),
              icon: _getTypeIcon(targetType),
              onPressed: () => _transformObject(
                context,
                ref,
                obj,
                targetType,
                settings,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<String> _getTransformationSuggestions(String detectedType, String literalType) {
    final commonTypes = [
      'task',
      'note',
      'habit',
      'goal',
      'project',
      'resource',
      'event',
    ];

    if (literalType != 'N/A' && !commonTypes.contains(literalType)) {
      return [literalType, ...commonTypes];
    }

    return commonTypes;
  }

  String _getTypeDisplayName(String type) {
    return switch (type) {
      'task' => 'Tarefa',
      'note' => 'Nota',
      'habit' => 'Hábito',
      'goal' => 'Meta',
      'project' => 'Projeto',
      'resource' => 'Recurso',
      'event' => 'Evento',
      'person' => 'Pessoa',
      'area' => 'Área',
      'activity' => 'Atividade',
      'tracker_definition' => 'Rastreador',
      'reminder' => 'Lembrete',
      'idea' => 'Ideia',
      'social_post' => 'Post Social',
      'shopping_list' => 'Lista de Compras',
      'template' => 'Template',
      'system' => 'Sistema',
      'snapshot' => 'Snapshot',
      'wellbeing_indicator' => 'Indicador',
      'day_theme' => 'Tema do Dia',
      'time_block' => 'Bloco de Tempo',
      'combined_analysis' => 'Análise Combinada',
      'mood_definition' => 'Definição de Mood',
      _ => type,
    };
  }

  IconData _getTypeIcon(String type) {
    return switch (type) {
      'task' => Icons.check_circle_outline_rounded,
      'note' => Icons.description_outlined,
      'habit' => Icons.autorenew_rounded,
      'goal' => Icons.flag_outlined,
      'project' => Icons.folder_open_outlined,
      'resource' => Icons.menu_book_outlined,
      'event' => Icons.event_outlined,
      'person' => Icons.person_outline,
      'area' => Icons.category_outlined,
      'activity' => Icons.directions_run_outlined,
      'tracker_definition' => Icons.show_chart_outlined,
      'reminder' => Icons.alarm_outlined,
      'idea' => Icons.lightbulb_outline,
      'social_post' => Icons.share_outlined,
      'shopping_list' => Icons.shopping_cart_outlined,
      'template' => Icons.content_copy_outlined,
      'system' => Icons.settings_outlined,
      'snapshot' => Icons.camera_alt_outlined,
      'wellbeing_indicator' => Icons.favorite_outline,
      'day_theme' => Icons.calendar_today_outlined,
      'time_block' => Icons.access_time_outlined,
      'combined_analysis' => Icons.analytics_outlined,
      'mood_definition' => Icons.sentiment_satisfied_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  Future<void> _transformObject(
    BuildContext context,
    WidgetRef ref,
    ContentObject obj,
    String targetType,
    AppSettings settings,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final targetFolder = settings.folderPaths[targetType] ?? 
                          _getDefaultFolderForType(targetType);
      final newPath = '$targetFolder/${obj.obsidianFileName}.md';
      
      final service = ref.read(obsidianServiceProvider);
      
      if (obj.obsidianPath != newPath) {
        await service.moveFile(obj.obsidianPath, newPath);
      }
      
      obj.obsidianPath = newPath;
      
      ref.invalidate(allObjectsProvider);
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Transformado em ${_getTypeDisplayName(targetType)}'),
          backgroundColor: AppColors.habitGreen,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao transformar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _TransformationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _TransformationButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentColor(context).withValues(alpha: 0.1),
        foregroundColor: AppTheme.accentColor(context),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentColor(context).withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
