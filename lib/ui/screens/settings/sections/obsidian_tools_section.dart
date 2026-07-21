import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../../providers/vault_provider.dart' show obsidianServiceProvider, projectsProvider, allObjectsProvider;
import '../../../../models/task_model.dart' show Task;
import '../../../../services/dataview_generator.dart' show DataviewGenerator;

class ObsidianToolsSection extends ConsumerWidget {
  const ObsidianToolsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.auto_fix_high_rounded,
              color: AppTheme.accentColor(context),
            ),
            title: const Text(
              'Regenerate Dataview Queries',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Generates index.md with Dataview queries in each vault folder',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _regenerateDataview(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateDataview(BuildContext context, WidgetRef ref) async {
    final obsidian = ref.read(obsidianServiceProvider);
    final gen = DataviewGenerator(obsidian);
    final projects = ref.read(projectsProvider);
    final allObjects = ref.read(allObjectsProvider).value ?? [];
    final tasks = allObjects.whereType<Task>().toList();
    try {
      await gen.regenerateAll(projects: projects, tasks: tasks);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dataview queries regenerated successfully!'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error regenerating: $e')));
    }
  }
}
