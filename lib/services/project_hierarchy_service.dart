// lib/services/project_hierarchy_service.dart
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/content_object.dart';
import 'project_progress_resolver.dart';

/// Maximum depth of project hierarchy to prevent performance issues
const int _maxHierarchyDepth = 3;

/// Service for managing project hierarchy (parent-child relationships)
class ProjectHierarchyService {
  /// Get direct child projects of a parent project
  static List<Project> getChildProjects(
    String parentId,
    List<Project> allProjects,
  ) {
    return allProjects
        .where((p) => p.parentId == parentId && !p.archived)
        .toList();
  }

  /// Get all descendant projects (recursive) of a parent project
  static List<Project> getAllDescendantProjects(
    String parentId,
    List<Project> allProjects, {
    int maxDepth = _maxHierarchyDepth,
  }) {
    return _getDescendantsRecursive(
      parentId,
      allProjects,
      currentDepth: 0,
      maxDepth: maxDepth,
    );
  }

  static List<Project> _getDescendantsRecursive(
    String parentId,
    List<Project> allProjects, {
    required int currentDepth,
    required int maxDepth,
  }) {
    if (currentDepth >= maxDepth) {
      return [];
    }

    final directChildren = getChildProjects(parentId, allProjects);
    final allDescendants = <Project>[...directChildren];

    for (final child in directChildren) {
      allDescendants.addAll(
        _getDescendantsRecursive(
          child.id,
          allProjects,
          currentDepth: currentDepth + 1,
          maxDepth: maxDepth,
        ),
      );
    }

    return allDescendants;
  }

  /// Check if a project has child projects
  static bool hasChildProjects(
    String parentId,
    List<Project> allProjects,
  ) {
    return getChildProjects(parentId, allProjects).isNotEmpty;
  }

  /// Detect if creating a parent-child relationship would create a cycle
  /// Returns true if a cycle would be created
  static bool detectCycle(
    String projectId,
    String targetParentId,
    List<Project> allProjects,
  ) {
    // A project cannot be its own parent
    if (projectId == targetParentId) {
      return true;
    }

    // Check if targetParentId is already a descendant of projectId
    final descendants = getAllDescendantProjects(projectId, allProjects);
    return descendants.any((p) => p.id == targetParentId);
  }

  /// Get all ancestor projects (up the hierarchy) of a project
  static List<Project> getAncestorProjects(
    String projectId,
    List<Project> allProjects,
  ) {
    final ancestors = <Project>[];
    String? currentId = projectId;

    while (currentId != null) {
      final parent = allProjects.firstWhere(
        (p) => p.id == currentId,
        orElse: () => allProjects.first, // fallback, won't match parentId
      );

      if (parent.parentId == null) {
        break;
      }

      final parentProject = allProjects.firstWhere(
        (p) => p.id == parent.parentId,
        orElse: () => parent, // fallback, shouldn't happen
      );

      ancestors.add(parentProject);
      currentId = parentProject.parentId;
    }

    return ancestors;
  }

  /// Calculate hierarchical progress including children
  /// combinationMode: 'simple' (average), 'weighted' (by task count), 'children_only'
  static double? calculateHierarchicalProgress(
    Project project,
    List<Project> allProjects,
    List<Task> allTasks, {
    String? combinationMode = 'simple',
  }) {
    // Calculate own progress first
    final ownProgress = ProjectProgressResolver.resolve(project, allTasks.cast<ContentObject>());

    // Get direct children
    final children = getChildProjects(project.id, allProjects);

    if (children.isEmpty) {
      return ownProgress;
    }

    // Calculate progress for each child
    final childProgresses = <double>[];
    for (final child in children) {
      final childProgress = calculateHierarchicalProgress(
        child,
        allProjects,
        allTasks,
        combinationMode: combinationMode,
      );
      if (childProgress != null) {
        childProgresses.add(childProgress);
      }
    }

    if (childProgresses.isEmpty) {
      return ownProgress;
    }

    // Combine based on mode
    switch (combinationMode) {
      case 'children_only':
        // Ignore own progress, use only children average
        return childProgresses.reduce((a, b) => a + b) / childProgresses.length;

      case 'weighted':
        // Weight by number of tasks
        final ownTaskCount = _getTaskCount(project, allTasks);
        final totalWeight = ownTaskCount +
            children.fold<int>(0, (sum, child) => sum + _getTaskCount(child, allTasks));

        if (totalWeight == 0) {
          return ownProgress ?? 0.0;
        }

        double weightedSum = 0.0;
        if (ownProgress != null && ownTaskCount > 0) {
          weightedSum += ownProgress * ownTaskCount;
        }

        for (var i = 0; i < children.length; i++) {
          final childTaskCount = _getTaskCount(children[i], allTasks);
          if (childTaskCount > 0 && childProgresses[i] != null) {
            weightedSum += childProgresses[i]! * childTaskCount;
          }
        }

        return weightedSum / totalWeight;

      case 'simple':
      default:
        // Simple average of own and children
        final allProgresses = <double>[];
        if (ownProgress != null) {
          allProgresses.add(ownProgress);
        }
        allProgresses.addAll(childProgresses);
        return allProgresses.reduce((a, b) => a + b) / allProgresses.length;
    }
  }

  /// Get task count for a project (linked tasks)
  static int _getTaskCount(Project project, List<Task> allTasks) {
    return allTasks
        .where((t) =>
            project.taskLinks.contains(t.slug) ||
            project.taskLinks.contains(t.id) ||
            t.organizers.any((org) => org.matches(project.id, project.slug, project.title)))
        .length;
  }

  /// Get IDs of all descendants for cache invalidation
  static List<String> getDescendantIds(
    String parentId,
    List<Project> allProjects,
  ) {
    return getAllDescendantProjects(parentId, allProjects).map((p) => p.id).toList();
  }

  /// Build project tree structure for visualization
  static Map<String, List<Project>> buildProjectTree(List<Project> allProjects) {
    final tree = <String, List<Project>>{};

    // Group by parentId
    for (final project in allProjects) {
      final parentId = project.parentId ?? 'root';
      if (!tree.containsKey(parentId)) {
        tree[parentId] = [];
      }
      tree[parentId]!.add(project);
    }

    return tree;
  }

  /// Validate hierarchy depth - returns true if within limits
  static bool validateDepth(
    String projectId,
    List<Project> allProjects, {
    int maxDepth = _maxHierarchyDepth,
  }) {
    return _getDepth(projectId, allProjects, 0) <= maxDepth;
  }

  static int _getDepth(String projectId, List<Project> allProjects, int currentDepth) {
    final children = getChildProjects(projectId, allProjects);
    if (children.isEmpty) {
      return currentDepth;
    }

    int maxChildDepth = currentDepth;
    for (final child in children) {
      final childDepth = _getDepth(child.id, allProjects, currentDepth + 1);
      if (childDepth > maxChildDepth) {
        maxChildDepth = childDepth;
      }
    }

    return maxChildDepth;
  }
}
