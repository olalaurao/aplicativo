import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/idea_model.dart';
import '../../models/task_model.dart';
import '../../models/note_model.dart';
import '../../models/goal_model.dart';
import '../../models/organizer_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../forms/create_idea_form.dart';
import '../forms/create_task_form.dart';
import '../forms/create_note_form.dart';
import '../forms/create_goal_form.dart';
import '../forms/create_organizer_form.dart';
import '../widgets/overdue_section.dart';

class IdeasScreen extends ConsumerWidget {
  const IdeasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ideias',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateIdeaForm()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _IdeasList(ideas: ref.watch(ideasProvider)),
    );
  }
}

class _IdeasList extends StatelessWidget {
  final List<IdeaDefinition> ideas;

  const _IdeasList({required this.ideas});

  @override
  Widget build(BuildContext context) {
    final sortedIdeas = [...ideas]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (sortedIdeas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma ideia capturada',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMutedColor(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedIdeas.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: OverdueSection(filterTypes: ['idea']),
          );
        }
        final idea = sortedIdeas[index - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            title: Text(
              idea.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: idea.linkedTaskIds.isNotEmpty
                ? Text(
                    '${idea.linkedTaskIds.length} tasks vinculadas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  )
                : null,
            trailing: idea.isConverted
                ? const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    size: 20,
                  )
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateIdeaForm(existingIdea: idea),
                ),
              );
            },
            onLongPress: () {
              _showConvertMenu(context, ref, idea);
            },
          ),
        );
      },
    );
  }

  void _showConvertMenu(BuildContext context, WidgetRef ref, IdeaDefinition idea) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Converter para...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _ConvertOption(
              label: 'Tarefa',
              icon: Icons.check_circle_outline_rounded,
              onTap: () => _convertToTask(context, ref, idea),
            ),
            _ConvertOption(
              label: 'Projeto',
              icon: Icons.folder_outlined,
              onTap: () => _convertToProject(context, ref, idea),
            ),
            _ConvertOption(
              label: 'Objetivo',
              icon: Icons.track_changes_rounded,
              onTap: () => _convertToGoal(context, ref, idea),
            ),
            _ConvertOption(
              label: 'Nota',
              icon: Icons.article_outlined,
              onTap: () => _convertToNote(context, ref, idea),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertToTask(BuildContext context, WidgetRef ref, IdeaDefinition idea) async {
    Navigator.pop(context);
    final task = Task(
      title: idea.title,
      notes: idea.body.isNotEmpty ? [idea.body] : [],
      organizers: idea.organizers,
      tags: idea.tags,
    );
    await ref.read(tasksProvider.notifier).addTask(task);
    await _markIdeaAsConverted(ref, idea, 'task', task.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ideia convertida em Tarefa')),
      );
    }
  }

  Future<void> _convertToProject(BuildContext context, WidgetRef ref, IdeaDefinition idea) async {
    Navigator.pop(context);
    final project = Organizer(
      title: idea.title,
      organizerType: OrganizerType.project,
      organizers: idea.organizers,
      tags: idea.tags,
    );
    await ref.read(organizerListProvider.notifier).addOrganizer(project);
    await _markIdeaAsConverted(ref, idea, 'project', project.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ideia convertida em Projeto')),
      );
    }
  }

  Future<void> _convertToGoal(BuildContext context, WidgetRef ref, IdeaDefinition idea) async {
    Navigator.pop(context);
    final goal = Goal(
      title: idea.title,
      description: idea.body.isNotEmpty ? idea.body : null,
      organizers: idea.organizers,
      tags: idea.tags,
    );
    await ref.read(goalsProvider.notifier).addGoal(goal);
    await _markIdeaAsConverted(ref, idea, 'goal', goal.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ideia convertida em Objetivo')),
      );
    }
  }

  Future<void> _convertToNote(BuildContext context, WidgetRef ref, IdeaDefinition idea) async {
    Navigator.pop(context);
    final note = Note(
      title: idea.title,
      body: idea.body,
      organizers: idea.organizers,
      tags: idea.tags,
    );
    await ref.read(notesProvider.notifier).addNote(note);
    await _markIdeaAsConverted(ref, idea, 'note', note.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ideia convertida em Nota')),
      );
    }
  }

  Future<void> _markIdeaAsConverted(WidgetRef ref, IdeaDefinition idea, String targetType, String targetId) async {
    final updatedIdea = idea.copyWith(
      status: IdeaStatus.converted,
      convertedToType: targetType,
      convertedToId: targetId,
      updatedAt: DateTime.now(),
    );
    await ref.read(ideasProvider.notifier).updateIdea(updatedIdea);
  }
}

class _ConvertOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ConvertOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: onTap,
    );
  }
}
