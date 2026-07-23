// lib/ui/screens/projects_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/organizer_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/overdue_section.dart';
import '../forms/create_organizer_form.dart';
import 'organizer_detail_screen.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final projects = allObjects
        .whereType<Organizer>()
        .where((o) => o.organizerType == OrganizerType.project)
        .toList();
    final activeProjects = projects
        .where((p) => p.state == 'active')
        .toList();
    final pausedProjects = projects
        .where((p) => p.state == 'paused')
        .toList();
    final completedProjects = projects
        .where((p) => p.state == 'completed')
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Projects',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Projetos',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${completedProjects.length}/${projects.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: projects.isEmpty
                          ? 0
                          : completedProjects.length / projects.length,
                      minHeight: 6,
                      backgroundColor: AppTheme.surfaceVariantColor(context),
                      valueColor: AlwaysStoppedAnimation(
                        AppTheme.accentColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${activeProjects.length} ativos · ${pausedProjects.length} pausados',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: projects.isEmpty
                  ? _buildEmptyState(context)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      children: [
                        const OverdueSection(filterTypes: ['project']),
                        if (activeProjects.isNotEmpty) ...[
                          _buildSectionHeader('ACTIVE'),
                          const SizedBox(height: 12),
                          ...activeProjects.map((p) => _ProjectCard(
                                key: ValueKey(p.id),
                                project: p,
                              )),
                        ],
                        if (pausedProjects.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildSectionHeader('PAUSED'),
                          const SizedBox(height: 12),
                          ...pausedProjects.map((p) => _ProjectCard(
                                key: ValueKey(p.id),
                                project: p,
                              )),
                        ],
                        if (completedProjects.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildSectionHeader('COMPLETED'),
                          const SizedBox(height: 12),
                          ...completedProjects.map((p) => _ProjectCard(
                                key: ValueKey(p.id),
                                project: p,
                                isCompleted: true,
                              )),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CreateOrganizerForm(
              initialType: OrganizerType.project,
            ),
          ),
        ),
        backgroundColor: AppTheme.accentColor(context),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.assignment_rounded,
      headline: 'Start your projects',
      subtext:
          'Organize your work into projects. Start by creating your first project.',
      ctaLabel: 'Create Project',
      onCta: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CreateOrganizerForm(
            initialType: OrganizerType.project,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final Organizer project;
  final bool isCompleted;

  const _ProjectCard({super.key, required this.project, this.isCompleted = false});

  Color _projectColor(String? rawColor) {
    if (rawColor == null || rawColor.trim().isEmpty) {
      return AppColors.info;
    }
    try {
      final normalized = rawColor.trim().replaceFirst('#', '0xFF');
      final parsed = int.tryParse(normalized);
      if (parsed == null) return AppColors.info;
      return Color(parsed);
    } catch (_) {
      return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _projectColor(project.color);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrganizerDetailScreen(organizer: project),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: AppTheme.cardDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.textMuted : color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (project.icon != null) ...[
                                Text(
                                  project.icon!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  project.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isCompleted
                                        ? AppColors.textMuted
                                        : AppColors.textPrimary,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (project.priority != null && project.priority != 'none') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(project.priority!).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    project.priority!.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: _getPriorityColor(project.priority!),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (project.endDate != null) ...[
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Due: ${DateFormat('d MMM yyyy').format(project.endDate!)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.priorityHigh;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.habitGreen;
      default:
        return AppColors.textMuted;
    }
  }
}
