import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/idea_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../forms/create_idea_form.dart';

class IdeasScreen extends ConsumerWidget {
  const IdeasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider);

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
      body: allObjects.when(
        data: (objects) {
          final ideas = objects.whereType<IdeaDefinition>().toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (ideas.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
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
            itemCount: ideas.length,
            itemBuilder: (context, index) {
              final idea = ideas[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: AppTheme.cardDecoration(context),
                child: ListTile(
                  title: Text(
                    idea.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: idea.linkedTaskIds.isNotEmpty
                      ? Text(
                          '${idea.linkedTaskIds.length} tasks vinculadas',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        )
                      : null,
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateIdeaForm(existingIdea: idea),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
