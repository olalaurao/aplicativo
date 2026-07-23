// lib/ui/screens/detail_sections/project_content_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../models/kpi_model.dart' as kpi;
import '../../widgets/wiki_text_view.dart';
import '../../theme.dart';
import 'project_detail_section.dart';

/// Project-specific content section for universal detail view
List<Widget> buildProjectContentSection(
  BuildContext context,
  WidgetRef ref,
  Project project,
  List<Task> tasks,
  double progress,
  int doneCount,
  int linkedTasksCount,
  Widget Function(BuildContext, WidgetRef, Project, List<Task>) buildRotationTasksSection,
  Widget Function(BuildContext, WidgetRef, String) buildSnapshotsSection,
  Widget Function(BuildContext, WidgetRef, Project, kpi.KPI) buildKPICard,
) {
  if (project.hasRotation) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (project.description != null &&
                  project.description!.isNotEmpty) ...[
                const Text(
                  'Descrição',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(context),
                  child: WikiTextView(
                    text: project.description!,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              buildRotationTasksSection(context, ref, project, tasks),
              if (project.kpis.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Indicadores de Sucesso (KPIs)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...project.kpis.map(
                  (k) => buildKPICard(context, ref, project, k),
                ),
              ],
              const SizedBox(height: 24),
              buildSnapshotsSection(context, ref, project.id),
            ],
          ),
        ),
      ),
    ];
  }

  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration(context),
              child: Column(
                children: [
                  Text(
                    '${(progress * 100).toInt()}% Completed',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$doneCount of $linkedTasksCount tasks',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 24,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.accentColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (project.description != null &&
                project.description!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Descrição',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration(context),
                child: WikiTextView(
                  text: project.description!,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
            ],
            if (project.kpis.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Indicadores de Sucesso (KPIs)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ...project.kpis.map(
                (k) => buildKPICard(context, ref, project, k),
              ),
            ],
            const SizedBox(height: 24),
            buildSnapshotsSection(context, ref, project.id),
            buildProjectChecklistSection(context, ref, project),
          ],
        ),
      ),
    ),
  ];
}
