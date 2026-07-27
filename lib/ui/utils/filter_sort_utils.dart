import '../../models/saved_filter.dart';
import '../../models/content_object.dart';
import '../../models/task_model.dart';
import '../../models/task_model.dart';

class FilterSortUtils {
  static List<T> applyFilterAndSort<T>(
    List<T> all,
    String searchQuery,
    SavedFilter? activeFilter,
  ) {
    var result = (activeFilter?.apply(all) ?? all).where((item) {
      if (item is ContentObject) {
        // Filter out crash reports and conflicts
        final path = item.obsidianPath ?? '';
        if (path.contains('_conflicts') ||
            path.contains('_crash') ||
            path.contains('crash_report')) {
          return false;
        }
        return searchQuery.isEmpty ||
            item.title.toLowerCase().contains(searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    final sort = activeFilter?.sortBy ?? SortField.modified;
    final asc = activeFilter?.sortAscending ?? false;
    
    result.sort((a, b) {
      if (a is ContentObject && b is ContentObject) {
        final cmp = switch (sort) {
          SortField.title => a.title.compareTo(b.title),
          SortField.created =>
            (a.createdAt).compareTo(b.createdAt),
          SortField.modified =>
            (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)),
          SortField.manual => (a.order ?? 0).compareTo(b.order ?? 0),
          SortField.priority => ((a is Task ? a.priority.index : 0)).compareTo(
            (b is Task ? b.priority.index : 0),
          ),
          SortField.rating => ((a as dynamic).rating ?? 0).compareTo((b as dynamic).rating ?? 0),
          _ => 0,
        };
        return asc ? cmp : -cmp;
      }
      return 0;
    });
    
    return result;
  }
}
