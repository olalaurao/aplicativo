import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/saved_filter.dart';
import '../../providers/settings_provider.dart';
import '../theme.dart';
import 'filter_sort_sheet.dart';

class FilterableListHeader extends ConsumerWidget {
  final String targetType;
  final String searchQuery;
  final SavedFilter? activeFilter;
  final List<SavedFilter> savedFilters;
  final ViewMode? viewMode;
  final List<FilterProperty> availableProperties;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SavedFilter?> onFilterChanged;
  final ValueChanged<ViewMode>? onViewModeChanged;
  final VoidCallback? onAddPressed;

  const FilterableListHeader({
    super.key,
    required this.targetType,
    required this.searchQuery,
    required this.activeFilter,
    required this.savedFilters,
    this.viewMode,
    required this.availableProperties,
    required this.onSearchChanged,
    required this.onFilterChanged,
    this.onViewModeChanged,
    this.onAddPressed,
  });

  void _openFilterSheet(BuildContext context, WidgetRef ref) {
    FilterSortSheet.show(
      context: context,
      ref: ref,
      targetType: targetType,
      currentFilter: activeFilter,
      availableProperties: availableProperties,
      onApply: (f) {
        onFilterChanged(f);
        if (f != null && onViewModeChanged != null) {
          onViewModeChanged!(f.viewMode);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (onViewModeChanged != null)
              IconButton(
                icon: Icon(
                  viewMode == ViewMode.grid
                      ? Icons.grid_view_rounded
                      : Icons.view_list_rounded,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => onViewModeChanged!(
                  viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid,
                ),
              ),
            IconButton(
              icon: const Icon(
                Icons.tune_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
              onPressed: () => _openFilterSheet(context, ref),
            ),
            const SizedBox(width: 8),
            if (onAddPressed != null)
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
                onPressed: onAddPressed,
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            filled: true,
            fillColor: AppTheme.surfaceVariantColor(context),
          ),
        ),
        const SizedBox(height: 14),
        _buildFilterChips(context, ref),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, 'Todos', activeFilter == null, () => onFilterChanged(null)),
          ...savedFilters.map(
            (f) => _chip(context, f.name, activeFilter?.id == f.id, () => onFilterChanged(f)),
          ),
          GestureDetector(
            onTap: () => _openFilterSheet(context, ref),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: AppColors.info),
                  SizedBox(width: 4),
                  Text(
                    'Novo filtro',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentColor(context)
              : AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.transparent : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : AppTheme.textPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}
