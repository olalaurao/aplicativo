import '../models/content_object.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/kpi_model.dart';

class ProjectProgressResolver {
  /// Returns a value between 0.0 and 1.0 representing the progress of the project,
  /// or null if the project has no computable progress (e.g. no KPIs and no task links).
  static double? resolve(Project project, List<ContentObject> allObjects) {
    // 1. If Project.primaryKpiId is set and resolves to a KPI in Project.kpis
    if (project.primaryKpiId != null && project.kpis.isNotEmpty) {
      try {
        final kpi = project.kpis.firstWhere((k) => k.id == project.primaryKpiId);
        if (kpi.targetValue > 0) {
          return (kpi.currentValue / kpi.targetValue).clamp(0.0, 1.0);
        }
      } catch (_) {
        // KPI not found in the list, fall through
      }
    }

    // Task resolution helper
    List<Task> resolveTasks(List<String> links) {
      final tasks = <Task>[];
      for (final link in links) {
        // Strip wiki link brackets if present
        final slug = link.replaceAll(RegExp(r'\[\[|\]\]'), '').trim();
        if (slug.isEmpty) continue;
        
        try {
          final obj = allObjects.firstWhere(
            (o) => o is Task && (o.id == slug || o.slug == slug || o.title.toLowerCase() == slug.toLowerCase()),
          );
          tasks.add(obj as Task);
        } catch (_) {
          // Dangling link, ignore
        }
      }
      return tasks;
    }

    // 2. Else, if Project.phases is non-empty
    if (project.phases.isNotEmpty) {
      final allLinks = project.phases.expand((p) => p.taskLinks).toList();
      if (allLinks.isNotEmpty) {
        final resolvedTasks = resolveTasks(allLinks);
        if (resolvedTasks.isNotEmpty) {
          final completed = resolvedTasks.where((t) => t.stage == TaskStage.finalized).length;
          return (completed / resolvedTasks.length).clamp(0.0, 1.0);
        }
        // If links exist but none resolved, it effectively has no computable progress
        return null;
      }
    }

    // 3. Else, if Project.taskLinks is non-empty
    if (project.taskLinks.isNotEmpty) {
      final resolvedTasks = resolveTasks(project.taskLinks);
      if (resolvedTasks.isNotEmpty) {
        final completed = resolvedTasks.where((t) => t.stage == TaskStage.finalized).length;
        return (completed / resolvedTasks.length).clamp(0.0, 1.0);
      }
      return null;
    }

    // 4. Else (no KPI, no phases, no task links)
    return null;
  }
}
