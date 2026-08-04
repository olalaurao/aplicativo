// lib/ui/screens/inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/goal_model.dart';
import '../../models/idea_model.dart';
import '../../models/inbox_model.dart';
import '../../models/project_model.dart';
import '../../models/saved_filter.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_idea_form.dart';
import '../forms/create_note_form.dart';
import '../forms/create_task_form.dart';
import '../navigation/object_navigation.dart';
import '../theme.dart';
import '../widgets/batch_selection_bar.dart';
import '../widgets/filter_sort_sheet.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final TextEditingController _captureController = TextEditingController();
  final FocusNode _captureFocus = FocusNode();
  final Set<InboxQueueKind> _expandedKinds = {};
  final Map<InboxQueueKind, SavedFilter?> _groupFilters = {};
  SavedFilter? _globalFilter;

  final Set<String> _selectedIds = {};
  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _captureFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _captureController.dispose();
    _captureFocus.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _selectAll(List<InboxQueueItem> items) {
    setState(() {
      _selectedIds.addAll(items.map((e) => e.id));
    });
  }

  Future<void> _batchDelete(List<InboxQueueItem> queue) async {
    final toDelete = queue.where((item) => _selectedIds.contains(item.id)).toList();
    if (toDelete.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Items'),
        content: Text('Are you sure you want to delete ${toDelete.length} item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final inboxNotifier = ref.read(inboxProvider.notifier);
    final vaultNotifier = ref.read(vaultProvider.notifier);

    int deleted = 0;
    for (final item in toDelete) {
      try {
        if (item.kind == InboxQueueKind.inbox && item.source is InboxItem) {
          await inboxNotifier.deleteItem(item.source as InboxItem);
        } else {
          await vaultNotifier.deleteObject(item.source);
        }
        deleted++;
      } catch (e) {
        debugPrint('Failed to delete item ${item.id}: $e');
      }
    }

    _clearSelection();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted $deleted item(s)')),
      );
    }
  }

  Future<void> _capture() async {
    final text = _captureController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    await ref.read(inboxProvider.notifier).addItem(text);
    _captureController.clear();
  }

  void _openQueueItem(BuildContext context, InboxQueueItem item) {
    if (item.kind == InboxQueueKind.inbox && item.source is InboxItem) {
      _showTriageSheet(context, item.source as InboxItem);
      return;
    }
    navigateToObject(context, item.source);
  }

  void _showTriageSheet(BuildContext context, InboxItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TriageSheet(item: item),
    );
  }

  void _openGlobalFilterSheet() {
    FilterSortSheet.show(
      context: context,
      ref: ref,
      targetType: 'inbox',
      currentFilter: _globalFilter,
      availableProperties: InboxFilterProperties.all,
      onApply: (filter) => setState(() => _globalFilter = filter),
    );
  }

  void _openGroupFilterSheet(InboxQueueKind kind) {
    FilterSortSheet.show(
      context: context,
      ref: ref,
      targetType: _targetTypeForKind(kind),
      currentFilter: _groupFilters[kind],
      availableProperties: InboxFilterProperties.all,
      onApply: (filter) => setState(() => _groupFilters[kind] = filter),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(inboxProvider, (prev, next) {
      if (!next.hasValue) return;
      final notifier = ref.read(inboxProvider.notifier);
      if (notifier.autoArchivedTitles.isEmpty) return;
      final titles = List<String>.from(notifier.autoArchivedTitles);
      notifier.clearAutoArchived();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${titles.length} old inbox item(s) archived automatically: ${titles.join(", ")}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: AppTheme.accentColor(context),
            duration: const Duration(seconds: 6),
          ),
        );
      });
    });

    final inboxAsync = ref.watch(inboxProvider);
    final queue = ref.watch(unifiedInboxQueueProvider);
    final globalQueue = _applyFilterAndSort(queue, _globalFilter);
    final grouped = _groupQueue(globalQueue);
    
    final taskItems = queue.where((i) => i.kind == InboxQueueKind.task && i.source is Task).map((i) => i.source as Task);
    final urgentCount = taskItems.where((t) => t.priority == TaskPriority.high).length;
    final importantCount = taskItems.where((t) => t.weight == TaskWeight.important).length;
    final circumstantialCount = taskItems.where((t) => t.weight == TaskWeight.circumstantial).length;

    final hasActiveFilters =
        _globalFilter != null ||
        _groupFilters.values.any((filter) => filter != null);
    final hasVisibleItems = grouped.values.any((items) => items.isNotEmpty);

    return Scaffold(
      appBar: _selectionMode
          ? BatchSelectionBar(
              selectedCount: _selectedIds.length,
              onCancel: _clearSelection,
              actions: [
                TextButton(
                  onPressed: () {
                    final allVisibleIds = grouped.values.expand((e) => e).map((e) => e.id).toSet();
                    if (_selectedIds.containsAll(allVisibleIds)) {
                      _clearSelection();
                    } else {
                      _selectAll(grouped.values.expand((e) => e).toList());
                    }
                  },
                  child: Text(
                    _selectedIds.length >= grouped.values.expand((e) => e).length
                        ? 'Deselect All'
                        : 'Select All',
                    style: TextStyle(
                      color: AppTheme.accentColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: () => _batchDelete(queue),
                  tooltip: 'Delete selected',
                ),
              ],
            )
          : AppBar(
              title: const Text('Inbox'),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: _globalFilter == null
                        ? AppColors.textSecondary
                        : AppTheme.accentColor(context),
                  ),
                  onPressed: _openGlobalFilterSheet,
                  tooltip: 'Filter and sort inbox',
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            _CaptureField(
              controller: _captureController,
              focusNode: _captureFocus,
              onCapture: _capture,
            ),
            _ActiveFilterChips(
              globalFilter: _globalFilter,
              groupFilters: _groupFilters,
              titleForKind: _sectionTitle,
              onClearGlobal: () => setState(() => _globalFilter = null),
              onClearGroup: (kind) =>
                  setState(() => _groupFilters[kind] = null),
            ),
            if (taskItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  'This week: $importantCount important · $urgentCount urgent · $circumstantialCount circumstantial',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(
              child: inboxAsync.isLoading && queue.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : queue.isEmpty || (!hasVisibleItems && !hasActiveFilters)
                  ? _EmptyInboxState(
                      onCapture: () => _captureFocus.requestFocus(),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      children: [
                        for (final kind in _groupOrder)
                          if (_shouldShowGroup(kind, grouped[kind] ?? const []))
                              _InboxGroupSection(
                                kind: kind,
                                title: _sectionTitle(kind),
                                items: grouped[kind] ?? const [],
                                isExpanded: _expandedKinds.contains(kind),
                                hasActiveFilter: _groupFilters[kind] != null,
                                selectedIds: _selectedIds,
                                selectionMode: _selectionMode,
                                onToggleSelection: _toggleSelection,
                                onToggle: () => setState(() {
                                if (_expandedKinds.contains(kind)) {
                                  _expandedKinds.remove(kind);
                                } else {
                                  _expandedKinds.add(kind);
                                }
                              }),
                              onFilter: () => _openGroupFilterSheet(kind),
                              onOpenItem: (item) =>
                                  _openQueueItem(context, item),
                              onTriage: (item) => _showTriageSheet(
                                context,
                                item.source as InboxItem,
                              ),
                              propertiesForItem: (item) =>
                                  _displayPropertiesForItem(
                                    item,
                                    _groupFilters[kind] ?? _globalFilter,
                                  ),
                            ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Map<InboxQueueKind, List<InboxQueueItem>> _groupQueue(
    List<InboxQueueItem> queue,
  ) {
    return {
      for (final kind in _groupOrder)
        if (queue.any((item) => item.kind == kind) ||
            _groupFilters[kind] != null)
          kind: _applyFilterAndSort(
            queue.where((item) => item.kind == kind).toList(),
            _groupFilters[kind] ?? _globalFilter,
          ),
    };
  }

  bool _shouldShowGroup(InboxQueueKind kind, List<InboxQueueItem> items) {
    return items.isNotEmpty || _groupFilters[kind] != null;
  }

  List<InboxQueueItem> _applyFilterAndSort(
    List<InboxQueueItem> items,
    SavedFilter? filter,
  ) {
    final filtered = filter == null
        ? List<InboxQueueItem>.from(items)
        : items
              .where(
                (item) =>
                    filter.rules.every((rule) => _matchesRule(item, rule)),
              )
              .toList();

    final sort = filter?.sortBy;
    if (sort == null) return filtered;

    filtered.sort((a, b) {
      final comparison = switch (sort) {
        SortField.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        SortField.created => _dateForSort(
          a.createdAt,
        ).compareTo(_dateForSort(b.createdAt)),
        SortField.modified => _dateForSort(
          a.source.updatedAt,
        ).compareTo(_dateForSort(b.source.updatedAt)),
        SortField.type => _kindLabel(a.kind).compareTo(_kindLabel(b.kind)),
        SortField.status => _statusForItem(a).compareTo(_statusForItem(b)),
        SortField.priority => _priorityRank(a).compareTo(_priorityRank(b)),
        SortField.manual => (a.source.order ?? 0).compareTo(
          b.source.order ?? 0,
        ),
        _ => 0,
      };
      return filter?.sortAscending == true ? comparison : -comparison;
    });
    return filtered;
  }

  bool _matchesRule(InboxQueueItem item, FilterRule rule) {
    final value = _propertyValue(item, rule.property);
    final ruleValue = rule.value?.toString().toLowerCase() ?? '';
    return switch (rule.op) {
      FilterOperator.equals => _stringValues(
        value,
      ).any((v) => v.toLowerCase() == ruleValue),
      FilterOperator.notEquals => !_stringValues(
        value,
      ).any((v) => v.toLowerCase() == ruleValue),
      FilterOperator.contains => _stringValues(
        value,
      ).any((v) => v.toLowerCase().contains(ruleValue)),
      FilterOperator.isEmpty =>
        value == null ||
            (value is String && value.trim().isEmpty) ||
            (value is Iterable && value.isEmpty),
      FilterOperator.greaterThan => false,
      FilterOperator.lessThan => false,
    };
  }

  Object? _propertyValue(InboxQueueItem item, String property) {
    final source = item.source;
    return switch (property) {
      'kind' => _kindLabel(item.kind),
      'title' => item.title,
      'status' => _statusForItem(item),
      'priority' => _priorityForItem(item),
      'created' => _dateKey(item.createdAt),
      'modified' => _dateKey(source.updatedAt),
      'tags' => source.tags,
      'organizers' =>
        source.organizers
            .expand((organizer) => [organizer.slug, organizer.title])
            .where((value) => value.trim().isNotEmpty)
            .toList(),
      'archived' => source.archived.toString(),
      'pinned' => source.pinned.toString(),
      _ => null,
    };
  }

  List<String> _stringValues(Object? value) {
    if (value == null) return const [];
    if (value is Iterable) {
      return value.map((item) => item.toString()).toList();
    }
    return [value.toString()];
  }

  DateTime _dateForSort(DateTime? date) {
    return date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _dateKey(DateTime? date) {
    if (date == null) return '';
    return date.toIso8601String().split('T').first;
  }

  String _statusForItem(InboxQueueItem item) {
    final source = item.source;
    if (source is IdeaDefinition) return source.status.name;
    if (source is Task) return source.stage.name;
    if (source is Project) return source.projectState.name;
    if (source is Goal) return source.state.name;
    if (source is InboxItem) return 'captured';
    return '';
  }

  String _priorityForItem(InboxQueueItem item) {
    final source = item.source;
    if (source is IdeaDefinition) return source.priority?.name ?? 'none';
    if (source is Task) return source.priority.name;
    if (source is Project) return source.projectPriority.name;
    return 'none';
  }

  int _priorityRank(InboxQueueItem item) {
    return switch (_priorityForItem(item)) {
      'high' => 3,
      'medium' => 2,
      'low' => 1,
      _ => 0,
    };
  }

  String _kindLabel(InboxQueueKind kind) {
    return switch (kind) {
      InboxQueueKind.inbox => 'captured',
      InboxQueueKind.idea => 'idea',
      InboxQueueKind.task => 'task',
      InboxQueueKind.project => 'project',
      InboxQueueKind.goal => 'goal',
    };
  }

  String _targetTypeForKind(InboxQueueKind kind) {
    return switch (kind) {
      InboxQueueKind.inbox => 'inbox_captured',
      InboxQueueKind.idea => 'inbox_idea',
      InboxQueueKind.task => 'inbox_task',
      InboxQueueKind.project => 'inbox_project',
      InboxQueueKind.goal => 'inbox_goal',
    };
  }

  List<_DisplayProperty> _displayPropertiesForItem(
    InboxQueueItem item,
    SavedFilter? filter,
  ) {
    final keys = _displayPropertyKeys(filter);
    return [
      for (final key in keys)
        if (_displayValueForItem(item, key).isNotEmpty)
          _DisplayProperty(
            label: _propertyLabel(key),
            value: _displayValueForItem(item, key),
          ),
    ];
  }

  List<String> _displayPropertyKeys(SavedFilter? filter) {
    if (filter == null) return const [];
    final keys = <String>[...filter.visibleProperties];
    if (filter.includeSortProperty) {
      final sortKey = _propertyKeyForSort(filter.sortBy);
      if (sortKey != null && !keys.contains(sortKey)) {
        keys.add(sortKey);
      }
    }
    keys.remove('title');
    return keys;
  }

  String? _propertyKeyForSort(SortField sort) {
    return switch (sort) {
      SortField.title => 'title',
      SortField.created => 'created',
      SortField.modified => 'modified',
      SortField.rating => 'rating',
      SortField.status => 'status',
      SortField.type => 'kind',
      SortField.priority => 'priority',
      SortField.deadline => 'deadline',
      SortField.streak => 'streak',
      SortField.lastContact => 'lastContact',
      SortField.manual => null,
    };
  }

  String _propertyLabel(String key) {
    for (final property in InboxFilterProperties.all) {
      if (property.key == key) return property.label;
    }
    return key;
  }

  String _displayValueForItem(InboxQueueItem item, String key) {
    final source = item.source;
    return switch (key) {
      'kind' => _kindLabel(item.kind),
      'status' => _statusForItem(item),
      'priority' => _priorityForItem(item),
      'created' => _dateLabel(item.createdAt),
      'modified' => _dateLabel(source.updatedAt),
      'tags' => source.tags.join(', '),
      'organizers' =>
        source.organizers
            .map((organizer) => organizer.title)
            .where((title) => title.trim().isNotEmpty)
            .join(', '),
      'archived' => source.archived ? 'yes' : 'no',
      'pinned' => source.pinned ? 'yes' : 'no',
      _ => '',
    };
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _sectionTitle(InboxQueueKind kind) {
    return switch (kind) {
      InboxQueueKind.inbox => 'Captured',
      InboxQueueKind.idea => 'Ideas',
      InboxQueueKind.task => 'Backlog Tasks',
      InboxQueueKind.project => 'Projects',
      InboxQueueKind.goal => 'Goals',
    };
  }
}

class _DisplayProperty {
  final String label;
  final String value;

  const _DisplayProperty({required this.label, required this.value});
}

const _groupOrder = [
  InboxQueueKind.inbox,
  InboxQueueKind.idea,
  InboxQueueKind.task,
  InboxQueueKind.project,
  InboxQueueKind.goal,
];

class _CaptureField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCapture;

  const _CaptureField({
    required this.controller,
    required this.focusNode,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: AppTheme.accentColor(context),
          width: AppBorder.normal,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor(context).withValues(alpha: 0.10),
            blurRadius: AppSpacing.md,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: 'Capture a loose thought...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
              style: const TextStyle(fontSize: AppTextSize.lg),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onCapture(),
            ),
          ),
          IconButton(
            onPressed: onCapture,
            icon: Icon(
              Icons.send_rounded,
              color: AppTheme.accentColor(context),
            ),
            tooltip: 'Capture',
          ),
        ],
      ),
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  final SavedFilter? globalFilter;
  final Map<InboxQueueKind, SavedFilter?> groupFilters;
  final String Function(InboxQueueKind kind) titleForKind;
  final VoidCallback onClearGlobal;
  final ValueChanged<InboxQueueKind> onClearGroup;

  const _ActiveFilterChips({
    required this.globalFilter,
    required this.groupFilters,
    required this.titleForKind,
    required this.onClearGlobal,
    required this.onClearGroup,
  });

  @override
  Widget build(BuildContext context) {
    final activeGroupFilters = groupFilters.entries
        .where((entry) => entry.value != null)
        .toList();
    if (globalFilter == null && activeGroupFilters.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        children: [
          if (globalFilter != null)
            _FilterChip(
              label: 'Inbox: ${globalFilter!.name}',
              onClear: onClearGlobal,
            ),
          for (final entry in activeGroupFilters)
            _FilterChip(
              label: '${titleForKind(entry.key)}: ${entry.value!.name}',
              onClear: () => onClearGroup(entry.key),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _FilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: AppTheme.accentColor(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: InkWell(
          onTap: onClear,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  size: AppIconSize.sm,
                  color: AppTheme.accentColor(context),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTextSize.sm,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentColor(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.close_rounded,
                  size: AppIconSize.sm,
                  color: AppTheme.accentColor(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxGroupSection extends StatelessWidget {
  final InboxQueueKind kind;
  final String title;
  final List<InboxQueueItem> items;
  final bool isExpanded;
  final bool hasActiveFilter;
  final Set<String> selectedIds;
  final bool selectionMode;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onToggle;
  final VoidCallback onFilter;
  final ValueChanged<InboxQueueItem> onOpenItem;
  final ValueChanged<InboxQueueItem> onTriage;
  final List<_DisplayProperty> Function(InboxQueueItem item) propertiesForItem;

  const _InboxGroupSection({
    required this.kind,
    required this.title,
    required this.items,
    required this.isExpanded,
    required this.hasActiveFilter,
    required this.selectedIds,
    required this.selectionMode,
    required this.onToggleSelection,
    required this.onToggle,
    required this.onFilter,
    required this.onOpenItem,
    required this.onTriage,
    required this.propertiesForItem,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForKind(context, kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppTheme.cardFillColor(context),
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                      child: Icon(_iconForKind(kind), size: 18, color: color),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTextSize.md,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _InboxCountBadge(count: items.length, color: color),
                          if (hasActiveFilter) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              Icons.filter_alt_rounded,
                              size: AppIconSize.sm,
                              color: AppTheme.accentColor(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.tune_rounded,
                        color: hasActiveFilter
                            ? AppTheme.accentColor(context)
                            : AppColors.textMuted,
                      ),
                      onPressed: onFilter,
                      tooltip: 'Filter and sort $title',
                    ),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'No items match this group filter.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTextSize.sm,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              )
            else
              for (final item in items)
                _InboxQueueCard(
                  item: item,
                  properties: propertiesForItem(item),
                  isSelected: selectedIds.contains(item.id),
                  isSelectionMode: selectionMode,
                  onTap: selectionMode
                      ? () => onToggleSelection(item.id)
                      : () => onOpenItem(item),
                  onLongPress: () => onToggleSelection(item.id),
                  onTriage:
                      item.kind == InboxQueueKind.inbox &&
                          item.source is InboxItem &&
                          !selectionMode
                      ? () => onTriage(item)
                      : null,
                ),
          ],
        ],
      ),
    );
  }

  IconData _iconForKind(InboxQueueKind kind) {
    return switch (kind) {
      InboxQueueKind.inbox => Icons.inbox_rounded,
      InboxQueueKind.idea => Icons.lightbulb_outline_rounded,
      InboxQueueKind.task => Icons.check_circle_outline_rounded,
      InboxQueueKind.project => Icons.assignment_outlined,
      InboxQueueKind.goal => Icons.flag_outlined,
    };
  }

  Color _colorForKind(BuildContext context, InboxQueueKind kind) {
    return switch (kind) {
      InboxQueueKind.inbox => AppTheme.accentColor(context),
      InboxQueueKind.idea => AppColors.warning,
      InboxQueueKind.task => AppColors.info,
      InboxQueueKind.project => AppColors.habitPurple,
      InboxQueueKind.goal => AppColors.success,
    };
  }
}

class _InboxCountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _InboxCountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: count == 0 ? 0.12 : 1),
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: count == 0 ? color : Colors.white,
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WeightChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WeightChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.accentColor(context).withValues(alpha: 0.15) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        side: BorderSide(
          color: selected ? AppTheme.accentColor(context) : AppTheme.dividerColor(context),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTextSize.xs,
              color: selected ? AppTheme.accentColor(context) : AppColors.textMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxQueueCard extends ConsumerWidget {
  final InboxQueueItem item;
  final List<_DisplayProperty> properties;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onTriage;

  const _InboxQueueCard({
    required this.item,
    required this.properties,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    this.onLongPress,
    this.onTriage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorForKind(context, item.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => onTap(),
                      activeColor: AppTheme.accentColor(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: Icon(_iconForKind(item.kind), size: 20, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTextSize.md,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${item.subtitle} • ${_formatDate(item.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTextSize.sm,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (item.kind == InboxQueueKind.task && item.source is Task) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            _WeightChip(
                              label: 'Important',
                              selected: (item.source as Task).weight == TaskWeight.important,
                              onTap: () => ref.read(vaultProvider.notifier)
                                  .updateObject((item.source as Task).copyWith(weight: TaskWeight.important)),
                            ),
                            const SizedBox(width: 6),
                            _WeightChip(
                              label: 'Circumstantial',
                              selected: (item.source as Task).weight == TaskWeight.circumstantial,
                              onTap: () => ref.read(vaultProvider.notifier)
                                  .updateObject((item.source as Task).copyWith(weight: TaskWeight.circumstantial)),
                            ),
                          ],
                        ),
                      ],
                      if (properties.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final property in properties)
                              _PropertyPill(property: property),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (onTriage != null)
                  OutlinedButton(
                    onPressed: onTriage,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      side: BorderSide(color: color.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                    ),
                    child: Text(
                      'Triage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppTextSize.sm, color: color),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForKind(InboxQueueKind kind) {
    return switch (kind) {
      InboxQueueKind.inbox => Icons.inbox_rounded,
      InboxQueueKind.idea => Icons.lightbulb_outline_rounded,
      InboxQueueKind.task => Icons.check_circle_outline_rounded,
      InboxQueueKind.project => Icons.assignment_outlined,
      InboxQueueKind.goal => Icons.flag_outlined,
    };
  }

  Color _colorForKind(BuildContext context, InboxQueueKind kind) {
    return switch (kind) {
      InboxQueueKind.inbox => AppTheme.accentColor(context),
      InboxQueueKind.idea => AppColors.warning,
      InboxQueueKind.task => AppColors.info,
      InboxQueueKind.project => AppColors.habitPurple,
      InboxQueueKind.goal => AppColors.success,
    };
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _EmptyInboxState extends StatelessWidget {
  final VoidCallback onCapture;

  const _EmptyInboxState({required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 72,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Inbox is clear',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTextSize.xxl,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Loose captures, ideas, backlog tasks, unstarted projects, and unstarted goals will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            FilledButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Capture now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentColor(context),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyPill extends StatelessWidget {
  final _DisplayProperty property;

  const _PropertyPill({required this.property});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      ),
      child: Text(
        '${property.label}: ${property.value}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppTextSize.xs,
          color: AppTheme.textSecondaryColor(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TriageSheet extends ConsumerWidget {
  final InboxItem item;

  const _TriageSheet({required this.item});

  Future<void> _openFormAndTriage(
    BuildContext context,
    WidgetRef ref,
    Widget form,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final inboxNotifier = ref.read(inboxProvider.notifier);
    navigator.pop();

    try {
      final saved = await navigator.push<bool>(
        MaterialPageRoute(builder: (_) => form),
      );
      if (saved == true) {
        await inboxNotifier.triageItem(item);
      }
    } catch (e) {
      debugPrint('Inbox triage failed: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not triage this item.')),
      );
    }
  }

  Future<void> _deleteAndClose(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final inboxNotifier = ref.read(inboxProvider.notifier);
    try {
      await inboxNotifier.deleteItem(item);
      navigator.pop();
    } catch (e) {
      debugPrint('Inbox delete failed: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete this item.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xxl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppBorderRadius.xs),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'What is this?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTextSize.xxl,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: AppTextSize.md,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _TriageOption(
                icon: Icons.check_box_outlined,
                color: AppColors.info,
                label: 'Task',
                subtitle: 'Create a task with this title',
                onTap: () async {
                  await _openFormAndTriage(
                    context,
                    ref,
                    CreateTaskForm(initialTitle: item.title),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _TriageOption(
                icon: Icons.description_outlined,
                color: AppColors.habitPink,
                label: 'Note',
                subtitle: 'Create a note with this content',
                onTap: () async {
                  await _openFormAndTriage(
                    context,
                    ref,
                    CreateNoteForm(initialTitle: item.title),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _TriageOption(
                icon: Icons.lightbulb_outline_rounded,
                color: AppColors.warning,
                label: 'Idea',
                subtitle: 'Save it in the idea backlog',
                onTap: () async {
                  await _openFormAndTriage(
                    context,
                    ref,
                    CreateIdeaForm(initialTitle: item.title),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _TriageOption(
                icon: Icons.menu_book_rounded,
                color: AppTheme.accentColor(context),
                label: 'Journal entry',
                subtitle: 'Add it to today\'s journal',
                onTap: () async {
                  await _openFormAndTriage(
                    context,
                    ref,
                    CreateEntryForm(initialBody: item.title),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _TriageOption(
                icon: Icons.delete_outline_rounded,
                color: AppColors.error,
                label: 'Delete',
                subtitle: 'Remove this capture',
                onTap: () async {
                  await _deleteAndClose(context, ref);
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriageOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _TriageOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTextSize.md,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTextSize.sm,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
