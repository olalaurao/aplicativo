// lib/ui/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/task_model.dart';
import '../theme.dart';
import '../forms/create_task_form.dart';
import 'universal_detail_view.dart';
import '../widgets/object_action_wrapper.dart';
import 'merge_flow_orchestrator.dart';
import '../../models/content_object.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _searchQuery = '';
  bool _isMultiSelectMode = false;
  final Set<String> _selectedTaskIds = {};

  @override
  Widget build(BuildContext context) {
    final taskObjects = ref.watch(tasksListProvider);
    final tasks = _searchQuery.isEmpty 
        ? taskObjects 
        : taskObjects.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelectMode 
            ? Text('${_selectedTaskIds.length} selected')
            : const Text('Tasks'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_isMultiSelectMode) ...[
            if (_selectedTaskIds.length >= 2)
              TextButton(
                onPressed: () {
                  // Start merge flow with selected tasks
                  _startMergeFlow(context, tasks.where((t) => _selectedTaskIds.contains(t.id)).toList());
                },
                child: Text(
                  'Merge',
                  style: TextStyle(
                    color: AppTheme.accentColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedTaskIds.clear();
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = true;
                });
              },
            ),
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
          if (_isMultiSelectMode && _selectedTaskIds.isNotEmpty)
            _buildMultiSelectActionBar(context),
        ],
      ),
    );
  }

  Widget _buildTaskTile(BuildContext context, Task task) {
    final isSelected = _selectedTaskIds.contains(task.id);
    
    return InkWell(
      onTap: () {
        if (_isMultiSelectMode) {
          setState(() {
            if (_selectedTaskIds.contains(task.id)) {
              _selectedTaskIds.remove(task.id);
            } else {
              _selectedTaskIds.add(task.id);
            }
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: task),
            ),
          );
        }
      },
      onLongPress: () {
        if (!_isMultiSelectMode) {
          setState(() {
            _isMultiSelectMode = true;
            _selectedTaskIds.add(task.id);
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.accentColor(context).withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: AppTheme.accentColor(context),
                  width: 2,
                )
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _isMultiSelectMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedTaskIds.add(task.id);
                      } else {
                        _selectedTaskIds.remove(task.id);
                      }
                    });
                  },
                )
              : null,
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
          trailing: !_isMultiSelectMode
              ? Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.textMutedColor(context),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMultiSelectActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: AppTheme.dividerColor(context),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_selectedTaskIds.length} task${_selectedTaskIds.length == 1 ? '' : 's'} selected',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (_selectedTaskIds.length >= 2)
            ElevatedButton.icon(
              onPressed: () {
                _startMergeFlow(context, 
                  ref.read(tasksListProvider).where((t) => _selectedTaskIds.contains(t.id)).toList());
              },
              icon: const Icon(Icons.merge_type_rounded, size: 18),
              label: const Text('Merge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor(context),
                foregroundColor: Colors.white,
              ),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isMultiSelectMode = false;
                _selectedTaskIds.clear();
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _startMergeFlow(BuildContext context, List selectedTasks) {
    setState(() {
      _isMultiSelectMode = false;
      _selectedTaskIds.clear();
    });
    
    // Use the merge flow orchestrator to handle the complete merge process
    MergeFlowOrchestrator.startMergeFlow(context, ref, selectedTasks as List<ContentObject>);
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
