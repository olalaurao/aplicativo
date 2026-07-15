// lib/ui/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/task_model.dart';
import '../theme.dart';
import '../forms/create_task_form.dart';
import 'universal_detail_view.dart';
import '../widgets/object_action_wrapper.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allObjectsAsync = ref.watch(allObjectsProvider);
    final tasks = allObjectsAsync.when(
      data: (objects) {
        final taskObjects = objects.whereType<Task>().toList();
        if (_searchQuery.isEmpty) return taskObjects;
        return taskObjects
            .where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
      },
      loading: () => [],
      error: (_, __) => [],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 20,
                color: AppTheme.accentColor(context),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateTaskForm(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: AppTheme.surfaceVariantColor(context),
              ),
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildTaskTile(context, task);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(BuildContext context, Task task) {
    return ObjectActionWrapper(
      object: task,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration(context),
        child: ListTile(
          title: Text(
            task.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: task.stage != null
              ? Text(
                  task.stage.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedColor(context),
                  ),
                )
              : null,
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppTheme.textMutedColor(context),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: task),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: AppTheme.accentColor(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No tasks yet' : 'No results found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (_searchQuery.isEmpty)
            Text(
              'Create tasks to track your work and progress',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMutedColor(context),
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }
}
