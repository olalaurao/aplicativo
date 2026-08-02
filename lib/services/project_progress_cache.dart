// lib/services/project_progress_cache.dart
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/content_object.dart';
import 'kpi_engine.dart';
import 'project_hierarchy_service.dart';

/// Helper class to cache computed project progress to avoid duplicate calculations
class ProjectProgressCache {
  static final Map<String, double> _cache = {};
  static final Map<String, int> _linkedTaskCountCache = {};
  static final Map<String, int> _completedTaskCountCache = {};
  static final Map<String, List<Task>> _linkedTasksCache = {};
  
  // Hierarchical progress cache
  static final Map<String, double> _hierarchicalCache = {};
  static final Map<String, String> _hierarchicalModeCache = {}; // Store combination mode

  static List<Task> _getLinkedTasks(
    String projectId,
    Project project,
    List<Task> tasks,
  ) {
    if (_linkedTasksCache.containsKey(projectId))
      return _linkedTasksCache[projectId]!;
    final linkedTasks = tasks
        .where(
          (t) =>
              project.taskLinks.contains(t.slug) ||
              project.taskLinks.contains(t.id) ||
              t.organizers.any(
                (org) => org.matches(project.id, project.slug, project.title),
              ),
        )
        .toList();
    _linkedTasksCache[projectId] = linkedTasks;
    return linkedTasks;
  }

  static double getProgress(
    String projectId,
    Project project,
    List<Task> tasks,
  ) {
    if (_cache.containsKey(projectId)) return _cache[projectId]!;
    final progress = KPIEngine.calculateProjectProgress(project, tasks);
    _cache[projectId] = progress;
    return progress;
  }

  static int getLinkedTaskCount(
    String projectId,
    Project project,
    List<Task> tasks,
  ) {
    if (_linkedTaskCountCache.containsKey(projectId))
      return _linkedTaskCountCache[projectId]!;
    final linkedTasks = _getLinkedTasks(projectId, project, tasks);
    _linkedTaskCountCache[projectId] = linkedTasks.length;
    return linkedTasks.length;
  }

  static int getCompletedTaskCount(
    String projectId,
    Project project,
    List<Task> tasks,
  ) {
    if (_completedTaskCountCache.containsKey(projectId))
      return _completedTaskCountCache[projectId]!;
    final linkedTasks = _getLinkedTasks(projectId, project, tasks);
    final doneCount = linkedTasks.where((t) => t.isCompleted).length;
    _completedTaskCountCache[projectId] = doneCount;
    return doneCount;
  }

  /// Get hierarchical progress including children
  static double getHierarchicalProgress(
    String projectId,
    Project project,
    List<ContentObject> allObjects,
    List<Project> allProjects, {
    String? combinationMode = 'simple',
  }) {
    final cacheKey = '$projectId-$combinationMode';
    
    if (_hierarchicalCache.containsKey(cacheKey) && 
        _hierarchicalModeCache[projectId] == combinationMode) {
      return _hierarchicalCache[cacheKey]!;
    }

    final tasks = allObjects.whereType<Task>().toList();
    final progress = ProjectHierarchyService.calculateHierarchicalProgress(
      project,
      allProjects,
      tasks,
      combinationMode: combinationMode,
    );

    if (progress != null) {
      _hierarchicalCache[cacheKey] = progress;
      _hierarchicalModeCache[projectId] = combinationMode ?? 'simple';
    }

    return progress ?? 0.0;
  }

  static void clearCache() {
    _cache.clear();
    _linkedTaskCountCache.clear();
    _completedTaskCountCache.clear();
    _linkedTasksCache.clear();
    _hierarchicalCache.clear();
    _hierarchicalModeCache.clear();
  }

  static void invalidateForProject(String projectId) {
    _cache.remove(projectId);
    _linkedTaskCountCache.remove(projectId);
    _completedTaskCountCache.remove(projectId);
    _linkedTasksCache.remove(projectId);
    
    // Invalidate hierarchical cache entries for this project
    _hierarchicalCache.removeWhere((key, value) => key.startsWith('$projectId-'));
    _hierarchicalModeCache.remove(projectId);
  }

  static void invalidateForHierarchical(String projectId) {
    _hierarchicalCache.removeWhere((key, value) => key.startsWith('$projectId-'));
    _hierarchicalModeCache.remove(projectId);
  }

  static void invalidateForTask(Task task) {
    // Invalidate cache for all projects this task might be linked to
    // Since we don't have project list here, this is a partial invalidation
    // The full invalidation should be done from the provider side
    _linkedTasksCache.clear();
    _cache.clear();
    _linkedTaskCountCache.clear();
    _completedTaskCountCache.clear();
    _hierarchicalCache.clear();
    _hierarchicalModeCache.clear();
  }

  /// Invalidate hierarchical cache for a project and all its descendants
  static void invalidateForHierarchy(String projectId, List<Project> allProjects) {
    invalidateForHierarchical(projectId);
    
    // Also invalidate all descendants
    final descendantIds = ProjectHierarchyService.getDescendantIds(projectId, allProjects);
    for (final descId in descendantIds) {
      invalidateForHierarchical(descId);
    }
  }
}
