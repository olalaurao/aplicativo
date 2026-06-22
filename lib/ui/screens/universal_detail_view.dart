// lib/ui/screens/universal_detail_view.dart
import 'package:flutter/material.dart';
import '../../models/reminder_config.dart';
import '../../services/notification_service.dart';
import '../widgets/reminder_config_sheet.dart';
import 'package:flutter/services.dart';
import '../../providers/history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/content_object.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/goal_model.dart';
import '../../models/journal_entry.dart';
import '../../models/mood_model.dart';
import '../../models/resource_model.dart';
import '../../models/people_model.dart';
import '../../models/project_model.dart';
import '../../models/tracker_model.dart';
import '../../models/snapshot_model.dart';
import '../../models/organizer_model.dart';
import '../../models/shared_types.dart' hide KPI;
import '../../models/kpi_model.dart';
import '../../providers/pomodoro_provider.dart';
import '../../services/kpi_engine.dart';
import '../../services/markdown_parser.dart';
import '../../providers/vault_provider.dart';
import 'pomodoro_screen.dart';
import '../theme.dart';
import '../../services/undo_service.dart';
import '../widgets/citrine_chart.dart';
import '../widgets/tracker_metric_card.dart';
import '../widgets/rich_text_editor.dart';
import '../widgets/outline_editor.dart';
import '../widgets/collection_view.dart';
import '../widgets/object_action_wrapper.dart';
import '../../models/note_model.dart';
import '../widgets/checklist_view.dart';
import '../../models/template_model.dart';
import '../widgets/wiki_text_view.dart';
import '../widgets/journal_body_view.dart';
import '../widgets/markdown_body_view.dart';
import '../widgets/universal_search_picker.dart';
import '../widgets/conflict_badge.dart';
import '../../providers/settings_provider.dart';
import '../forms/create_task_form.dart';
import '../forms/create_habit_form.dart';
import '../forms/create_goal_form.dart';
import '../forms/create_note_form.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_project_form.dart';
import '../forms/create_person_form.dart';
import '../forms/create_resource_form.dart';
import '../forms/create_tracker_form.dart';
import '../forms/create_organizer_form.dart';
import '../../services/google_auth_service.dart' as auth;
import '../../providers/google_calendar_provider.dart';
import '../forms/create_system_form.dart';
import '../../models/system_model.dart';
import 'system_detail_screen.dart';
import '../../providers/systems_provider.dart';
import '../widgets/linked_objects_section.dart';
import '../utils/social_ref_utils.dart';

class UniversalDetailView extends ConsumerStatefulWidget {
  final ContentObject object;
  final String? searchQuery;
  final String? searchSnippet;

  const UniversalDetailView({
    super.key,
    required this.object,
    this.searchQuery,
    this.searchSnippet,
  });

  @override
  ConsumerState<UniversalDetailView> createState() =>
      _UniversalDetailViewState();
}

class _UniversalDetailViewState extends ConsumerState<UniversalDetailView> {
  bool _isEditing = false;
  late ContentObject object;

  @override
  void initState() {
    super.initState();
    object = widget.object;
    // Push to history once on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(historyProvider.notifier).push(object);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch active object reactively from the provider
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final found = allObjects.cast<ContentObject?>().firstWhere(
      (o) => o != null && o.id == object.id,
      orElse: () => null,
    );
    // Use the found object if available, otherwise fall back to cached
    final currentObject = found ?? object;
    // Safely update the cached reference after the frame — never during build
    if (found != null && !identical(found, object)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) object = found;
      });
    }

    final mentionsAsync = ref.watch(backlinksProvider(currentObject.id));
    final conflictGroup = _conflictGroupFor(
      currentObject,
      ref.watch(conflictingObjectsProvider),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildBreadcrumbs(context, ref),
          // ─── Header ───
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text(
              _typeLabel(object).toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
            actions: [
              if (object is Task)
                IconButton(
                  icon: const Icon(Icons.event_available_outlined),
                  onPressed: () => _handleAction(context, ref, 'export_google'),
                  tooltip: 'Export to Google Calendar',
                ),
              if (object is Task || object is Project)
                IconButton(
                  icon: const Icon(
                    Icons.timer_outlined,
                    color: AppColors.error,
                  ),
                  onPressed: () => _handleAction(context, ref, 'focus'),
                ),
              _buildOverflowMenu(context, ref),
            ],
          ),

          // ─── Title Area ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          object is MoodDefinition
                              ? '${(object as MoodDefinition).emoji} ${object.title}'
                              : (object.obsidianFileName.isNotEmpty
                                    ? object.obsidianFileName
                                    : 'Untitled'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      ConflictBadge(
                        visible: currentObject.hasTypeConflict,
                        tooltip: currentObject.conflictReason,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _typeLabel(object),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (object is Project) _buildProjectProgress(context, ref),
                  if (conflictGroup.length > 1)
                    _buildObjectConflictBanner(context, conflictGroup),
                  if (widget.searchSnippet != null &&
                      widget.searchSnippet!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Search Match',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _highlightSearchSnippet(
                              widget.searchSnippet!,
                              widget.searchQuery ?? '',
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Properties Card ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                decoration: AppTheme.cardDecoration(context),
                child: Column(
                  children: [
                    if (object is! Resource) ...[
                      _divider(),
                      _buildPropertyRow(
                        context,
                        'Status',
                        _getStatus(object),
                        onTap: () => _onPropertyTap(
                          context,
                          ref,
                          'Status',
                          _getStatus(object),
                        ),
                      ),
                    ],
                    _divider(),
                    _buildPropertyRow(
                      context,
                      'Created',
                      DateFormat('EEE, d MMM, yyyy').format(object.createdAt),
                    ),
                    _divider(),
                    _buildPropertyRow(
                      context,
                      'Modified',
                      DateFormat('EEE, d MMM, yyyy').format(object.updatedAt),
                    ),
                    ..._buildTypeSpecificProperties(context, ref),
                  ],
                ),
              ),
            ),
          ),

          // ─── Linked Organizers (Connections) ───
          if (object.organizers.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Conexões',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _badge(object.organizers.length.toString()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      child: Column(
                        children: [
                          ...object.organizers.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final refObj = entry.value;
                            return Column(
                              children: [
                                Consumer(
                                  builder: (context, ref, _) {
                                    final allObjects =
                                        ref.watch(allObjectsProvider).value ??
                                        [];
                                    final linkedObj = allObjects
                                        .cast<ContentObject?>()
                                        .firstWhere(
                                          (o) =>
                                              o != null && o.id == refObj.slug,
                                          orElse: () => null,
                                        );

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        child: Icon(
                                          _typeIcon(refObj.type),
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      title: Text(
                                        linkedObj?.title ?? refObj.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        refObj.type.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: AppColors.textMuted,
                                      ),
                                      onTap: linkedObj != null
                                          ? () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    UniversalDetailView(
                                                      object: linkedObj,
                                                    ),
                                              ),
                                            )
                                          : null,
                                    );
                                  },
                                ),
                                if (idx != object.organizers.length - 1)
                                  const Divider(
                                    height: 1,
                                    indent: 56,
                                    color: AppColors.divider,
                                  ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: LinkedObjectsSection(
                owner: object,
                socialRefs: getSocialRefs(object),
                onAdd: (selected) => addSocialRef(object, selected, ref),
                onRemove: (slug) => removeSocialRef(object, slug, ref),
              ),
            ),
          ),

          // ─── Type-Specific Content ───
          ..._buildTypeSpecificContent(context, ref),

          // ─── Mentions / Backlinks ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Mentions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  mentionsAsync.when(
                    data: (items) => _badge(items.length.toString()),
                    loading: () => const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, _) => _badge('0'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return mentionsAsync.maybeWhen(
                    data: (items) {
                      if (items.isEmpty) {
                        return const Text(
                          'No mentions yet',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        );
                      }
                      final item = items[index];
                      return _buildMentionRow(context, item);
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
                childCount: mentionsAsync.maybeWhen(
                  data: (items) => items.isEmpty ? 1 : items.length,
                  orElse: () => 0,
                ),
              ),
            ),
          ),

          // ─── Reminders ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.alarm_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Reminders',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _badge(object.reminders.length.toString()),
                        ],
                      ),
                      IconButton(
                        onPressed: () => _showAddReminderSheet(context, ref),
                        icon: const Icon(
                          Icons.add_alarm_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (object.reminders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(context),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 20,
                            color: AppColors.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'No reminders set',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      child: Column(
                        children: [
                          ...object.reminders.map((rem) {
                            final triggerTime = rem.calculateTriggerTime(
                              object.baseTime ?? object.createdAt,
                            );
                            return Column(
                              children: [
                                ListTile(
                                  leading: Icon(
                                    rem.type == NotificationType.alarm
                                        ? Icons.alarm_rounded
                                        : (rem.type == NotificationType.popup
                                              ? Icons.picture_in_picture_rounded
                                              : Icons
                                                    .notifications_active_rounded),
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  title: Text(
                                    '${triggerTime.hour}:${triggerTime.minute.toString().padLeft(2, '0')} - ${triggerTime.day}/${triggerTime.month}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    rem.notificationBody ??
                                        (rem.type == NotificationType.alarm
                                            ? 'Alarm'
                                            : 'Reminder'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () => _removeReminder(ref, rem),
                                  ),
                                  dense: true,
                                ),
                                if (rem != object.reminders.last)
                                  const Divider(
                                    height: 1,
                                    indent: 48,
                                    color: AppColors.divider,
                                  ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildProjectProgress(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final progress = KPIEngine.calculateProjectProgress(
      object as Project,
      tasks,
    );
    final percentage = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PROGRESS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color != null
            ? color.withValues(alpha: 0.1)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.divider,
    );
  }

  List<ContentObject> _conflictGroupFor(
    ContentObject current,
    Map<String, List<ContentObject>> conflicts,
  ) {
    for (final group in conflicts.values) {
      if (group.any((object) => object.id == current.id)) return group;
    }
    return const [];
  }

  Widget _buildObjectConflictBanner(
    BuildContext context,
    List<ContentObject> group,
  ) {
    final labels = group
        .map((object) => '${_typeLabel(object)}: ${object.displayTitle}')
        .join(' • ');

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Possível conflito de tipo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    labels,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
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

  Widget _buildOverflowMenu(BuildContext context, WidgetRef ref) {
    final Map<String, List<String>> typeActions = {
      'task': [
        'focus',
        'edit',
        'change_type',
        'merge_note',
        'save_template',
        'archive',
        'delete',
        'obsidian',
      ],
      'habit': ['edit', 'change_type', 'merge_note', 'archive', 'delete'],
      'note': [
        'convert_to_checklist',
        'edit',
        'change_type',
        'merge_note',
        'save_template',
        'archive',
        'delete',
        'obsidian',
      ],
      'project': ['edit', 'change_type', 'merge_note', 'archive', 'delete'],
      'person': ['edit', 'change_type', 'merge_note', 'delete'],
      'resource': ['edit', 'change_type', 'merge_note', 'archive', 'delete'],
      'entry': [
        'edit',
        'change_type',
        'save_template',
        'delete',
        'obsidian',
      ],
      'goal': ['edit', 'change_type', 'merge_note', 'archive', 'delete'],
    };

    final actions =
        typeActions[object.type] ?? ['edit', 'change_type', 'delete'];

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (val) {
        if (val == 'edit' &&
            (object is Note || object is Resource || object is JournalEntry)) {
          setState(() => _isEditing = !_isEditing);
        } else {
          _handleAction(context, ref, val);
        }
      },
      itemBuilder: (ctx) => actions.map((action) {
        switch (action) {
          case 'edit':
            return const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 12),
                  Text('Edit'),
                ],
              ),
            );
          case 'convert_to_checklist':
            return PopupMenuItem(
              value: 'convert_to_checklist',
              child: Row(
                children: [
                  const Icon(Icons.checklist_rtl_rounded, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    (object as Note).isChecklist
                        ? 'Reverter para Nota'
                        : 'Converter para Checklist',
                  ),
                ],
              ),
            );
          case 'save_template':
            return const PopupMenuItem(
              value: 'save_template',
              child: Row(
                children: [
                  Icon(Icons.copy_all_rounded, size: 18),
                  SizedBox(width: 12),
                  Text('Salvar como Template'),
                ],
              ),
            );
          case 'change_type':
            return const PopupMenuItem(
              value: 'change_type',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 18),
                  SizedBox(width: 12),
                  Text('Alterar Tipo'),
                ],
              ),
            );
          case 'merge_note':
            return const PopupMenuItem(
              value: 'merge_note',
              child: Row(
                children: [
                  Icon(Icons.call_merge_rounded, size: 18),
                  SizedBox(width: 12),
                  Text('Mesclar com outra nota'),
                ],
              ),
            );
          case 'delete':
            return const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ],
              ),
            );
          case 'archive':
            return const PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive_outlined, size: 18),
                  SizedBox(width: 12),
                  Text('Archive'),
                ],
              ),
            );
          case 'obsidian':
            return const PopupMenuItem(
              value: 'obsidian',
              child: Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 18),
                  SizedBox(width: 12),
                  Text('Open in Obsidian'),
                ],
              ),
            );
          case 'focus':
            return const PopupMenuItem(
              value: 'focus',
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18),
                  SizedBox(width: 12),
                  Text('Focus Session'),
                ],
              ),
            );
          default:
            return PopupMenuItem(
              value: action,
              child: Text(action.toUpperCase()),
            );
        }
      }).toList(),
    );
  }

  Widget _buildPropertyRow(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: onTap != null ? AppColors.primary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeSpecificProperties(
    BuildContext context,
    WidgetRef ref,
  ) {
    if (object is Task) {
      final task = object as Task;
      return [
        ..._buildLinkedGoogleEventRows(context, task),
        _divider(),
        _buildPropertyRow(
          context,
          'Priority',
          task.priority.name.toUpperCase(),
          onTap: () => _showTaskPriorityPicker(context, ref, task),
        ),
        if (task.endDate != null) ...[
          _divider(),
          _buildPropertyRow(
            context,
            'Due Date',
            DateFormat('MMM d, yyyy').format(task.endDate!),
            onTap: () => _showTaskDueDatePicker(context, ref, task),
          ),
        ],
      ];
    }
    if (object is Habit) {
      final habit = object as Habit;
      return [
        _divider(),
        _buildPropertyRow(context, 'Streak', '${habit.streak} days'),
        _divider(),
        _buildPropertyRow(
          context,
          'Days Since',
          habit.daysSinceLastCompletion == 0
              ? 'Today'
              : '${habit.daysSinceLastCompletion} days ago',
        ),
      ];
    }
    if (object is Project) {
      final project = object as Project;
      return [
        ..._buildLinkedGoogleEventRows(context, project),
        _divider(),
        _buildPropertyRow(
          context,
          'State',
          project.projectState.name.toUpperCase(),
          onTap: () => _showProjectStatePicker(context, ref, project),
        ),
        _divider(),
        _buildPropertyRow(
          context,
          'Priority',
          project.projectPriority.name.toUpperCase(),
          onTap: () => _showProjectPriorityPicker(context, ref, project),
        ),
      ];
    }
    if (object is Person) {
      final person = object as Person;
      return [
        _divider(),
        _buildPropertyRow(
          context,
          'Priority',
          person.contactPriority.name.toUpperCase(),
          onTap: () => _showPersonPriorityPicker(context, ref, person),
        ),
        if (person.contactFrequency != null) ...[
          _divider(),
          _buildPropertyRow(
            context,
            'Frequency',
            'Every ${person.contactFrequency!.inDays} days',
            onTap: () => _showFrequencyPicker(context, ref, person),
          ),
        ],
      ];
    }
    if (object is JournalEntry) {
      final entry = object as JournalEntry;
      final mood = _moodForEntry(entry);
      return [
        _divider(),
        _buildPropertyRow(
          context,
          'Date',
          DateFormat('EEE, d MMM, yyyy').format(entry.date),
        ),
        _divider(),
        _buildPropertyRow(
          context,
          'Time',
          DateFormat('HH:mm').format(entry.date),
        ),
        if (mood != null) ...[
          _divider(),
          _buildPropertyRow(context, 'Mood', '${mood.emoji} ${mood.title}'),
        ] else if (entry.moodSlug != null && entry.moodSlug!.isNotEmpty) ...[
          _divider(),
          _buildPropertyRow(
            context,
            'Mood',
            '${_fallbackMoodEmoji(entry.moodSlug!)} ${entry.moodSlug}',
          ),
        ],
      ];
    }
    if (object is Resource) {
      final resource = object as Resource;
      return [
        _divider(),
        _buildPropertyRow(
          context,
          'Status',
          resource.status.name.toUpperCase(),
          onTap: () => _showResourceStatusPicker(context, ref, resource),
        ),
        _divider(),
        _buildPropertyRow(context, 'Author', resource.author ?? 'Unknown'),
        _divider(),
        _buildPropertyRow(context, 'Year', resource.year?.toString() ?? 'N/A'),
        _divider(),
        _buildPropertyRow(
          context,
          'Pages',
          resource.pages?.toString() ?? 'N/A',
        ),
        _divider(),
        _buildPropertyRow(
          context,
          'Category',
          resource.category ?? 'Uncategorized',
        ),
        _divider(),
        _buildPropertyRow(
          context,
          'Read Date',
          resource.readDate != null
              ? DateFormat('MMM d, yyyy').format(resource.readDate!)
              : 'Not set',
        ),
        _divider(),
        _buildPropertyRow(context, 'Rating', '${resource.rating}/5'),
      ];
    }
    if (object is Goal) {
      final goal = object as Goal;
      final habits = ref.watch(habitsProvider);
      final trackerRecords = ref.watch(trackingRecordsProvider);
      final entries = ref.watch(allEntriesProvider);
      final moods = ref.watch(moodsProvider);
      final notes = ref.watch(notesProvider);
      final tasks = ref.watch(tasksProvider);

      // Calculate live progress
      double total = 0;
      double completed = 0;
      for (final kpi in goal.kpis) {
        total += 1;
        final val = KPIEngine.calculateKPIValue(
          kpi: kpi,
          habits: habits,
          trackerRecords: trackerRecords,
          entries: entries,
          moods: moods,
          notes: notes,
          tasks: tasks,
        );
        completed += (val / kpi.targetValue).clamp(0.0, 1.0);
      }
      for (final st in goal.subtasks) {
        total += 1;
        if (st.completed) completed += 1;
      }
      final progress = total > 0 ? (completed / total) : 0.0;

      return [
        ..._buildLinkedGoogleEventRows(context, goal),
        _divider(),
        _buildPropertyRow(
          context,
          'Estado',
          goal.state.name.toUpperCase(),
          onTap: () => _showGoalStatePicker(context, ref, goal),
        ),
        _divider(),
        _buildPropertyRow(
          context,
          'Tipo',
          goal.goalType == GoalType.repeating ? 'Recorrente' : 'Pontual',
        ),
        _divider(),
        _buildPropertyRow(context, 'Progresso', '${(progress * 100).toInt()}%'),
        if (goal.deadline != null) ...[
          _divider(),
          _buildPropertyRow(
            context,
            'Prazo',
            DateFormat('d MMM yyyy').format(goal.deadline!),
          ),
        ],
        if (goal.startDate != null) ...[
          _divider(),
          _buildPropertyRow(
            context,
            'Home',
            DateFormat('d MMM yyyy').format(goal.startDate!),
          ),
        ],
      ];
    }

    return [];
  }

  List<Widget> _buildLinkedGoogleEventRows(
    BuildContext context,
    Object source,
  ) {
    String? id;
    String? title;
    String? date;
    String? url;

    if (source is Task) {
      id = source.linkedGoogleEventId;
      title = source.linkedGoogleEventTitle;
      date = source.linkedGoogleEventDate;
      url = source.linkedGoogleEventUrl;
    } else if (source is Goal) {
      id = source.linkedGoogleEventId;
      title = source.linkedGoogleEventTitle;
      date = source.linkedGoogleEventDate;
      url = source.linkedGoogleEventUrl;
    } else if (source is Project) {
      id = source.linkedGoogleEventId;
      title = source.linkedGoogleEventTitle;
      date = source.linkedGoogleEventDate;
      url = source.linkedGoogleEventUrl;
    }

    if (id == null || id.isEmpty) return [];
    final parsedDate = date == null ? null : DateTime.tryParse(date);
    final dateLabel = parsedDate == null
        ? null
        : DateFormat('d MMM yyyy HH:mm').format(parsedDate.toLocal());
    final label = [title ?? 'Evento Google', ?dateLabel].join(' · ');

    return [
      _divider(),
      _buildPropertyRow(
        context,
        'Evento Google',
        label,
        onTap: url == null || url.isEmpty
            ? null
            : () => launchUrl(
                Uri.parse(url!),
                mode: LaunchMode.externalApplication,
              ),
      ),
    ];
  }

  List<Widget> _buildTypeSpecificContent(BuildContext context, WidgetRef ref) {
    if (object is Task) {
      final task = object as Task;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.notes.isNotEmpty) ...[
                  const Text(
                    'Notes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.cardDecoration(context),
                    child: WikiTextView(
                      text: task.notes.join('\n'),
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (task.dependsOn.isNotEmpty) ...[
                  const Text(
                    'Depende de (Bloqueantes)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildDependsOnList(context, ref, task.dependsOn),
                  const SizedBox(height: 24),
                ],
                if (task.subtasks.isNotEmpty) ...[
                  const Text(
                    'Subtasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildSubtaskList(context, ref, task.subtasks),
                ] else ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.account_tree_rounded, size: 16),
                    label: const Text('Aplicar System (Via B)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showApplySystemSheet(context, ref, task),
                  ),
                ],
                // ── V2.8.3 Time Estimates vs Actuals ──
                if (task.estimatedMinutes != null ||
                    task.actualMinutes > 0 ||
                    (task.pomodoroCount != null &&
                        task.pomodoroCount! > 0)) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Tempo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildTimeEstimateCard(context, task),
                ],
              ],
            ),
          ),
        ),
      ];
    }

    if (object is SystemDefinition) {
      // Redirect to dedicated System Detail Screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SystemDetailScreen(system: object as SystemDefinition),
            ),
          );
        }
      });
      return [];
    }

    if (object is JournalEntry) {
      final entry = object as JournalEntry;
      final mood = _moodForEntry(entry);
      final plainBody = MarkdownParser.getPlainTextFromBody(entry.body).trim();
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Container(
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          mood?.emoji ??
                              (entry.moodSlug != null
                                  ? _fallbackMoodEmoji(entry.moodSlug!)
                                  : '📝'),
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'EEE, d MMM yyyy • HH:mm',
                              ).format(entry.date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMutedColor(context),
                              ),
                            ),
                            if (mood != null)
                              Text(
                                mood.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (entry.title.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_isEditing)
                    SizedBox(
                      height: 360,
                      child: RichTextEditor(
                        content: entry.body,
                        onChanged: (newVal) {
                          final updated = entry.copyWith(body: newVal);
                          ref
                              .read(vaultProvider.notifier)
                              .updateObject(updated);
                          setState(() => object = updated);
                        },
                      ),
                    )
                  else if (plainBody.isEmpty)
                    Text(
                      'Sem texto nesta entry.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppTheme.textMutedColor(context),
                      ),
                    )
                  else
                    JournalBodyView(
                      body: entry.body,
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    if (object is Project) {
      final project = object as Project;
      final tasks = ref.watch(tasksProvider);
      final progress = KPIEngine.calculateProjectProgress(project, tasks);

      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Project Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(progress * 100).toInt()}% Completed',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          const Icon(
                            Icons.rocket_launch_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 24,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (project.description != null &&
                    project.description!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.cardDecoration(context),
                    child: WikiTextView(
                      text: project.description!,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildSnapshotsSection(context, ref, project.id),
              ],
            ),
          ),
        ),
      ];
    }
    if (object is Goal) {
      final goal = object as Goal;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Indicadores de Sucesso (KPIs)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...goal.kpis.map((kpi) => _buildKPICard(context, ref, kpi)),
                const SizedBox(height: 24),
                const Text(
                  'Sub-metas / Checklist',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _buildSubtaskList(context, ref, goal.subtasks),
                const SizedBox(height: 24),
                _buildSnapshotsSection(context, ref, goal.id),
              ],
            ),
          ),
        ),
      ];
    }
    if (object is Resource) {
      final resource = object as Resource;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              children: [
                if (resource.coverImage != null)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(
                        image: NetworkImage(resource.coverImage!),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (resource.coverImage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              resource.coverImage!,
                              width: double.infinity,
                              fit: BoxFit.contain, // Not cropped
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _badge(
                            resource.resourceType.toUpperCase(),
                            color: AppColors.info,
                          ),
                          _badge(
                            resource.status.name.toUpperCase(),
                            color: _statusColor(resource.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'SYNOPSIS & HIGHLIGHTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isEditing)
                        RichTextEditor(
                          content: resource.synopsis ?? '',
                          onChanged: (newVal) {
                            final updated = resource.copyWith(synopsis: newVal);
                            ref
                                .read(vaultProvider.notifier)
                                .updateObject(updated);
                            setState(() => object = updated);
                          },
                        )
                      else
                        MarkdownBodyView(
                          content: resource.synopsis?.isNotEmpty == true
                              ? resource.synopsis!
                              : 'No synopsis or highlights provided.',
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'RATING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            Icons.star_rounded,
                            size: 32,
                            color: i < resource.rating
                                ? AppColors.warning
                                : AppColors.textMuted.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: LinkedObjectsSection(
            owner: resource,
            socialRefs: resource.socialRefs,
            onAdd: (selected) async {
              final ref = '[[${selected.slug}]]';
              if (resource.socialRefs.contains(ref)) return;
              final updated = resource.copyWith(
                socialRefs: [...resource.socialRefs, ref],
                updatedAt: DateTime.now(),
              );
              await this.ref
                  .read(resourcesProvider.notifier)
                  .updateResource(updated);
              if (mounted) setState(() => object = updated);
            },
            onRemove: (slug) async {
              final updated = resource.copyWith(
                socialRefs: resource.socialRefs
                    .where((r) => r != slug)
                    .toList(),
                updatedAt: DateTime.now(),
              );
              await this.ref
                  .read(resourcesProvider.notifier)
                  .updateResource(updated);
              if (mounted) setState(() => object = updated);
            },
          ),
        ),
      ];
    }
    if (object is Person) {
      final person = object as Person;
      final daysSince = person.lastContactDate != null
          ? DateTime.now().difference(person.lastContactDate!).inDays
          : null;
      final isOverdue = person.isDueForContact;
      final frequencyDays = person.contactFrequency?.inDays ?? 0;
      final progress = (daysSince != null && frequencyDays > 0)
          ? (daysSince / frequencyDays).clamp(0.0, 1.0)
          : 0.0;

      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.surfaceVariant,
                        backgroundImage: person.photo != null
                            ? NetworkImage(person.photo!)
                            : null,
                        child: person.photo == null
                            ? Text(
                                person.title.isNotEmpty
                                    ? person.title.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _contactActionButton(
                            context,
                            ref,
                            Icons.chat_bubble_outline_rounded,
                            'WhatsApp',
                            const Color(0xFF25D366),
                          ),
                          _contactActionButton(
                            context,
                            ref,
                            Icons.message_outlined,
                            'Message',
                            AppColors.primary,
                          ),
                          _contactActionButton(
                            context,
                            ref,
                            Icons.call_outlined,
                            'Call',
                            AppColors.habitGreen,
                          ),
                          _contactActionButton(
                            context,
                            ref,
                            Icons.mail_outline_rounded,
                            'Email',
                            AppColors.info,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _personGoogleEventBanner(context, ref, person),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'CONTACT FREQUENCY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (isOverdue)
                            _badge('OVERDUE', color: AppColors.error)
                          else if (frequencyDays > 0)
                            Text(
                              '${frequencyDays - (daysSince ?? 0)} days left',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverdue ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        person.lastContactDate != null
                            ? 'Last contact: ${DateFormat('MMMM d, yyyy').format(person.lastContactDate!)}'
                            : 'Never contacted through Citrine',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ─── Contact History ───
                const Text(
                  'CONTACT HISTORY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (ctx) {
                    final historyAsync = ref.watch(
                      backlinksProvider(person.id),
                    );
                    return historyAsync.when(
                      data: (mentions) {
                        if (mentions.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: AppTheme.cardDecoration(ctx),
                            child: const Text(
                              'No contact entries yet.\nMention this person in journal entries or tasks to build the history.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final sorted = mentions.toList()
                          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                        final display = sorted.take(10).toList();
                        return Container(
                          decoration: AppTheme.cardDecoration(ctx),
                          child: Column(
                            children: display.asMap().entries.map((e) {
                              final item = e.value;
                              final isLast = e.key == display.length - 1;
                              return Column(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: _typeColorForMention(
                                        item.type,
                                      ).withValues(alpha: 0.1),
                                      child: Icon(
                                        _typeIconForMention(item.type),
                                        size: 16,
                                        color: _typeColorForMention(item.type),
                                      ),
                                    ),
                                    title: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      DateFormat(
                                        'd MMM yyyy',
                                      ).format(item.updatedAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    trailing: _badge(
                                      item.type,
                                      color: _typeColorForMention(item.type),
                                    ),
                                    dense: true,
                                    onTap: () => Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            UniversalDetailView(object: item),
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    const Divider(
                                      height: 1,
                                      indent: 56,
                                      color: AppColors.divider,
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (object is Habit) {
      final habit = object as Habit;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activity (Last 30 Days)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  decoration: AppTheme.cardDecoration(context),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: habit.inputType == HabitInputType.boolean
                      ? _buildHabitFrequencyChart(habit)
                      : _buildHabitNumericTrendChart(habit),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    if (object is MoodDefinition) {
      final mood = object as MoodDefinition;
      final entries = ref.watch(allEntriesProvider);
      final moodEntries = entries.where((e) => e.moodSlug == mood.id).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mood Frequency',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  decoration: AppTheme.cardDecoration(context),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: _buildMoodFrequencyChart(moodEntries),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Monthly Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: AppTheme.cardDecoration(context),
                  padding: const EdgeInsets.all(16),
                  child: CitrineChart(
                    type: ChartType.heatmap,
                    color: AppColors.habitPurple,
                    data: List.generate(30, (i) {
                      final date = DateTime.now().subtract(
                        Duration(days: 29 - i),
                      );
                      final hasEntry = entries.any(
                        (e) =>
                            e.moodSlug == mood.id && _isSameDay(e.date, date),
                      );
                      return ChartDataPoint(
                        label: '',
                        value: hasEntry ? 1.0 : 0.0,
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Entries',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (moodEntries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No entries with this mood yet.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              final entry = moodEntries[index];
              return _buildMentionRow(context, entry);
            }, childCount: moodEntries.isEmpty ? 1 : moodEntries.length),
          ),
        ),
      ];
    }
    if (object is TrackerDefinition) {
      final tracker = object as TrackerDefinition;
      final allRecords = ref.watch(trackingRecordsProvider);
      final trackerRecords =
          allRecords
              .where(
                (r) =>
                    r.trackerId == tracker.id ||
                    r.trackerId == tracker.slug ||
                    r.trackerId == tracker.title,
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      return [
        // ─── Summaries ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'General Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: tracker.sections.expand((s) => s.inputFields).map(
                      (field) {
                        final values = trackerRecords
                            .map((r) => r.fieldValues[field.id])
                            .whereType<num>()
                            .map((n) => n.toDouble())
                            .toList();

                        final latestValue = trackerRecords.isNotEmpty
                            ? trackerRecords.first.fieldValues[field.id]
                            : null;

                        return TrackerMetricCard(
                          definition: tracker,
                          fieldId: field.id,
                          value: latestValue,
                          history: values.reversed.toList(),
                        );
                      },
                    ).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Distribution ───
        ...tracker.sections
            .expand((s) => s.inputFields)
            .where(
              (f) =>
                  f.type == InputFieldType.selection ||
                  f.type == InputFieldType.checklist,
            )
            .map((field) {
              final Map<String, int> counts = {};
              for (var r in trackerRecords) {
                final val = r.fieldValues[field.id];
                if (val is String) {
                  counts[val] = (counts[val] ?? 0) + 1;
                } else if (val is List) {
                  for (var item in val) {
                    if (item is String) {
                      counts[item] = (counts[item] ?? 0) + 1;
                    }
                  }
                }
              }

              if (counts.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribution: ${field.title}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: AppTheme.cardDecoration(context),
                        padding: const EdgeInsets.all(16),
                        child: CitrineChart(
                          type: ChartType.pie,
                          data: counts.entries
                              .map(
                                (e) => ChartDataPoint(
                                  label: e.key,
                                  value: e.value.toDouble(),
                                  color:
                                      Colors.primaries[counts.keys
                                              .toList()
                                              .indexOf(e.key) %
                                          Colors.primaries.length],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

        // ─── Activity Heatmap ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Activity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: AppTheme.cardDecoration(context),
                  padding: const EdgeInsets.all(16),
                  child: CitrineChart(
                    type: ChartType.heatmap,
                    color: _parseColor(tracker.color),
                    data: List.generate(30, (i) {
                      final date = DateTime.now().subtract(
                        Duration(days: 29 - i),
                      );
                      final count = trackerRecords
                          .where((r) => _isSameDay(r.date, date))
                          .length;
                      return ChartDataPoint(label: '', value: count.toDouble());
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Records List ───
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
            child: Text(
              'Records History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final record = trackerRecords[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: InkWell(
                onTap: () => _showRecordDetails(context, ref, tracker, record),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(context),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _parseColor(
                            tracker.color,
                          ).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          color: _parseColor(tracker.color),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'dd MMM yyyy HH:mm',
                              ).format(record.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${record.fieldValues.length} fields filled',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }, childCount: trackerRecords.length),
        ),
      ];
    }
    if (object is Habit) {
      final habit = object as Habit;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Frequency',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: AppTheme.cardDecoration(context),
                  padding: const EdgeInsets.all(16),
                  child: CitrineChart(
                    type: ChartType.heatmap,
                    color: Color(
                      int.parse(habit.color.replaceAll('#', '0xFF')),
                    ),
                    data: List.generate(30, (i) {
                      final date = DateTime.now().subtract(
                        Duration(days: 29 - i),
                      );
                      final record = habit.completionHistory
                          .where(
                            (r) =>
                                r.date.year == date.year &&
                                r.date.month == date.month &&
                                r.date.day == date.day,
                          )
                          .firstOrNull;
                      return ChartDataPoint(
                        label: '',
                        value: (record != null && record.successful)
                            ? 1.0
                            : 0.0,
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ];
    }
    if (object is Note) {
      final note = object as Note;
      final allNotes = ref.watch(notesProvider);
      final childNotes = allNotes
          .where((n) => n.parentNoteId == note.id)
          .toList();

      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Container(
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(16),
              child: _isEditing
                  ? _buildNoteEditor(context, note)
                  : _buildNoteViewer(context, note),
            ),
          ),
        ),
        if (childNotes.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
              child: Text(
                'Nested Notes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildNoteListItem(context, childNotes[index]),
                childCount: childNotes.length,
              ),
            ),
          ),
        ],
      ];
    }
    return [];
  }

  Widget _buildNoteEditor(BuildContext context, Note note) {
    switch (note.subtype) {
      case NoteSubtype.text:
        return RichTextEditor(
          content: note.body,
          expands: false,
          onChanged: (v) {
            final updated = note.copyWith(body: v);
            ref.read(vaultProvider.notifier).updateObject(updated);
            setState(() => object = updated);
          },
        );
      case NoteSubtype.outline:
        return OutlineEditor(
          initialContent: note.body,
          onChanged: (v) {
            final updated = note.copyWith(body: v);
            ref.read(vaultProvider.notifier).updateObject(updated);
            setState(() => object = updated);
          },
        );
      case NoteSubtype.collection:
        return CollectionView(
          content: note.body,
          onChanged: (v) {
            final updated = note.copyWith(body: v);
            ref.read(vaultProvider.notifier).updateObject(updated);
            setState(() => object = updated);
          },
        );
    }
  }

  Widget _buildNoteViewer(BuildContext context, Note note) {
    if (note.isChecklist && note.subtype == NoteSubtype.text) {
      return ChecklistView(note: note);
    }
    switch (note.subtype) {
      case NoteSubtype.outline:
        return OutlineEditor(
          initialContent: note.body,
          onWikiLinkTap: (slug) => _navigateToSlug(context, ref, slug),
          onChanged: (v) {
            final updated = note.copyWith(body: v);
            ref.read(vaultProvider.notifier).updateObject(updated);
            setState(() => object = updated);
          },
        );
      case NoteSubtype.collection:
        return CollectionView(content: note.body);
      case NoteSubtype.text:
        return MarkdownBodyView(content: note.body);
    }
  }

  void _navigateToSlug(BuildContext context, WidgetRef ref, String slug) {
    final all = ref.read(allObjectsProvider).valueOrNull ?? [];
    final target = all.cast<ContentObject?>().firstWhere(
      (o) =>
          o != null &&
          (o.slug == slug || o.title.toLowerCase() == slug.toLowerCase()),
      orElse: () => null,
    );
    if (target != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UniversalDetailView(object: target)),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Objeto "$slug" não encontrado')));
    }
  }

  Widget _buildNoteListItem(BuildContext context, Note note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ObjectActionWrapper(
        object: note,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: note),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 18,
                color: AppColors.info,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitFrequencyChart(Habit habit) {
    // Generate last 30 days data
    final today = DateTime.now();
    final data = List.generate(30, (i) {
      final date = today.subtract(Duration(days: 29 - i));
      final record = habit.completionHistory
          .where(
            (r) =>
                r.date.year == date.year &&
                r.date.month == date.month &&
                r.date.day == date.day,
          )
          .firstOrNull;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: record != null && record.successful ? 1 : 0.1,
            color: record != null && record.successful
                ? AppColors.habitGreen
                : AppColors.surfaceVariant,
            width: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 1.1,
        barGroups: data,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
      ),
    );
  }

  Widget _buildHabitNumericTrendChart(Habit habit) {
    final history = habit.completionHistory
        .where((r) => r.value != null)
        .toList();
    if (history.isEmpty) {
      return const Center(child: Text('No numeric data recorded'));
    }

    final data = history
        .map(
          (r) => ChartDataPoint(
            label: DateFormat('dd/MM').format(r.date),
            value: r.value!,
          ),
        )
        .toList();

    return CitrineChart(
      type: ChartType.line,
      data: data,
      color: Color(int.parse(habit.color.replaceAll('#', '0xFF'))),
    );
  }

  Widget _buildMoodFrequencyChart(List<JournalEntry> entries) {
    if (entries.isEmpty) return const Center(child: Text('Not enough data'));

    // Group by day for last 14 days
    final today = DateTime.now();
    final spots = List.generate(14, (i) {
      final date = today.subtract(Duration(days: 13 - i));
      final count = entries
          .where(
            (e) =>
                e.date.year == date.year &&
                e.date.month == date.month &&
                e.date.day == date.day,
          )
          .length;
      return FlSpot(i.toDouble(), count.toDouble());
    });

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
      ),
    );
  }

  Widget _buildMentionRow(BuildContext context, ContentObject item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ObjectActionWrapper(
        object: item,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: item),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.cardDecoration(context),
            child: Row(
              children: [
                Icon(
                  _typeIcon(item.type),
                  size: 18,
                  color: _typeColor(item.type),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatus(ContentObject obj) {
    if (obj is Task) return obj.stage.name.toUpperCase();
    if (obj is Project) return obj.projectState.name.toUpperCase();
    if (obj is Resource) return obj.status.name.toUpperCase();
    if (obj is Goal) return obj.state.name.toUpperCase();
    return 'ACTIVE';
  }

  MoodDefinition? _moodForEntry(JournalEntry entry) {
    final moodSlug = entry.moodSlug;
    if (moodSlug == null || moodSlug.isEmpty) return null;
    return ref
        .read(moodsProvider)
        .where((mood) => mood.id == moodSlug || mood.slug == moodSlug)
        .firstOrNull;
  }

  String _fallbackMoodEmoji(String moodSlug) {
    return switch (moodSlug) {
      'terrible' => '😞',
      'bad' => '😕',
      'neutral' => '😐',
      'good' => '🙂',
      'great' => '😄',
      _ => '😐',
    };
  }

  void _showApplySystemSheet(BuildContext context, WidgetRef ref, Task task) {
    final systems = ref.read(systemsProvider);
    if (systems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum System disponível. Crie um primeiro.'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aplicar System à Tarefa',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Os steps do System serão adicionados como subtasks.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMutedColor(ctx),
              ),
            ),
            const SizedBox(height: 16),
            ...systems.map(
              (system) => ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_tree_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                title: Text(
                  system.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${system.steps.length} steps • ${system.estimatedMinutes > 0 ? '${system.estimatedMinutes}min' : 'sem estimativa'}',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final newSubtasks = [
                    ...task.subtasks,
                    ...system.steps.map((s) => Subtask(title: s.title)),
                  ];
                  final updatedTask = task.copyWith(
                    subtasks: newSubtasks,
                    estimatedMinutes:
                        task.estimatedMinutes ??
                        (system.estimatedMinutes > 0
                            ? system.estimatedMinutes
                            : null),
                  );
                  await ref
                      .read(vaultProvider.notifier)
                      .updateObject(updatedTask);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${system.steps.length} steps de "${system.title}" aplicados.',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    HapticFeedback.mediumImpact();
    switch (action) {
      case 'focus':
        _startFocusSession(context, ref);
        break;
      case 'edit':
        _editObject(context);
        break;
      case 'convert_to_checklist':
        _convertToChecklist(context, ref);
        break;
      case 'change_type':
        _showChangeTypeSheet(context, ref);
        break;
      case 'merge_note':
        _showMergeTargetPicker(context, ref);
        break;
      case 'save_template':
        _saveAsTemplate(context, ref);
        break;
      case 'archive':
        _archiveObject(context, ref);
        break;
      case 'obsidian':
        _openInObsidian(context, ref);
        break;
      case 'delete':
        _showDeleteConfirm(context, ref);
        break;
      case 'export_google':
        _exportToGoogleCalendar(context, ref);
        break;
    }
  }

  void _convertToChecklist(BuildContext context, WidgetRef ref) {
    if (object is! Note) return;
    final note = object as Note;
    final updated = note.copyWith(isChecklist: !note.isChecklist);
    ref.read(vaultProvider.notifier).updateObject(updated);
    setState(() => object = updated);
  }

  Future<void> _showMergeTargetPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerContext) => UniversalSearchPickerSheet(
        title: 'Escolher nota correta',
        initialFilter: 'note',
        showClear: false,
        onSelected: (target) async {
          Navigator.pop(pickerContext);
          if (target.id == object.id ||
              target.obsidianPath == object.obsidianPath) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Escolha uma nota diferente.')),
            );
            return;
          }
          await _confirmMergeIntoTarget(context, ref, target);
        },
      ),
    );
  }

  Future<void> _confirmMergeIntoTarget(
    BuildContext context,
    WidgetRef ref,
    ContentObject target,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mesclar notas?'),
        content: Text(
          'Todas as conexões de "${object.title}" serão redirecionadas para '
          '"${target.title}". O conteúdo será anexado à nota correta e a nota '
          'errada será movida para a lixeira.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Mesclar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(vaultProvider.notifier)
          .redirectAndDeleteObject(source: object, target: target);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${object.title}" mesclada em "${target.title}".'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao mesclar notas: $e')));
      }
    }
  }

  void _saveAsTemplate(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController(
      text: '${object.title} Template',
    );
    String bodyContent = '';
    String templateType = 'note';
    Map<String, dynamic> fmDefaults = {};

    if (object is Task) {
      final task = object as Task;
      bodyContent = task.notes.join('\n');
      templateType = 'task';
      fmDefaults = {'priority': task.priority.name};
    } else if (object is Note) {
      final note = object as Note;
      bodyContent = note.body;
      templateType = 'note';
      fmDefaults = {'pinned': note.pinned};
    } else if (object is JournalEntry) {
      final entry = object as JournalEntry;
      bodyContent = entry.body;
      templateType = 'entry';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar como Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Digite o nome para este template:'),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Nome do Template',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );

    if (confirmed == true && titleController.text.trim().isNotEmpty) {
      final newTemplate = TemplateDefinition.create(
        title: titleController.text.trim(),
        templateType: templateType,
        body: bodyContent,
        frontmatterDefaults: fmDefaults,
      );

      await ref.read(templatesProvider.notifier).addTemplate(newTemplate);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Template "${newTemplate.title}" criado com sucesso!',
            ),
          ),
        );
      }
    }
    titleController.dispose();
  }

  void _showChangeTypeSheet(BuildContext context, WidgetRef ref) {
    final types = [
      {
        'type': 'task',
        'label': 'Tarefa',
        'icon': Icons.check_circle_outline_rounded,
      },
      {'type': 'habit', 'label': 'Hábito', 'icon': Icons.loop_rounded},
      {
        'type': 'goal',
        'label': 'Objetivo',
        'icon': Icons.track_changes_rounded,
      },
      {'type': 'note', 'label': 'Nota', 'icon': Icons.article_outlined},
      {'type': 'project', 'label': 'Projeto', 'icon': Icons.folder_outlined},
      {'type': 'area', 'label': 'Área', 'icon': Icons.layers_outlined},
      {'type': 'activity', 'label': 'Atividade', 'icon': Icons.sports_outlined},
      {
        'type': 'label',
        'label': 'Etiqueta',
        'icon': Icons.label_outline_rounded,
      },
      {
        'type': 'person',
        'label': 'Pessoa',
        'icon': Icons.person_outline_rounded,
      },
      {'type': 'place', 'label': 'Lugar', 'icon': Icons.place_outlined},
      {
        'type': 'resource',
        'label': 'Recurso',
        'icon': Icons.menu_book_outlined,
      },
      {
        'type': 'tracker_definition',
        'label': 'Rastreador',
        'icon': Icons.analytics_outlined,
      },
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Alterar Tipo de Objeto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Converter "${object.title}" para:',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: types.length,
                itemBuilder: (context, index) {
                  final t = types[index];
                  return ListTile(
                    leading: Icon(
                      t['icon'] as IconData,
                      color: AppColors.primary,
                    ),
                    title: Text(t['label'] as String),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _confirmAndChangeType(
                        context,
                        ref,
                        t['type'] as String,
                        t['label'] as String,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndChangeType(
    BuildContext context,
    WidgetRef ref,
    String targetType,
    String targetLabel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Alterar para $targetLabel?'),
        content: Text(
          'Tem certeza que deseja converter "${object.title}" em $targetLabel? Os dados compatíveis serão migrados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      String newType = targetType;
      Map<String, dynamic> extraFields = {};

      if (const ['area', 'activity', 'label', 'place'].contains(targetType)) {
        newType = 'organizer';
        extraFields['organizerType'] = targetType;
      }

      await ref
          .read(vaultProvider.notifier)
          .changeObjectType(object, newType, extraFields: extraFields);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${object.title}" convertido para $targetLabel com sucesso!',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao converter tipo: $e')));
      }
    }
  }

  Future<void> _exportToGoogleCalendar(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final calendarService = ref.read(googleCalendarServiceProvider);
      final authService = ref.read(auth.googleAuthServiceProvider);

      final client = await authService.ensureClient();
      if (client == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please login to Google first in settings.'),
          ),
        );
        return;
      }

      calendarService.init(client);

      if (object is Task) {
        final task = object as Task;
        if (task.endDate == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Task needs a date to be exported.')),
          );
          return;
        }

        final exportedId = await calendarService.pushTaskToCalendar(task);

        // Update task with exported ID if needed
        if (exportedId != null && exportedId != task.exportedCalendarId) {
          await ref
              .read(vaultProvider.notifier)
              .updateObject(task.copyWith(exportedCalendarId: exportedId));
        }
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Exported to Google Calendar successfully!'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error exporting: $e')));
    }
  }

  void _archiveObject(BuildContext context, WidgetRef ref) {
    ref.read(vaultProvider.notifier).archiveObject(object);

    Navigator.pop(context); // Go back to the list

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${object.title}" archived'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () =>
              ref.read(vaultProvider.notifier).unarchiveObject(object),
        ),
      ),
    );
  }

  void _editObject(BuildContext context) {
    Widget? formPage;
    if (object is Task) {
      formPage = CreateTaskForm(existingTask: object as Task);
    } else if (object is Habit) {
      formPage = CreateHabitForm(existingHabit: object as Habit);
    } else if (object is Goal) {
      formPage = CreateGoalForm(existingGoal: object as Goal);
    } else if (object is Note) {
      formPage = CreateNoteForm(existingNote: object as Note);
    } else if (object is JournalEntry) {
      formPage = CreateEntryForm(existingEntry: object as JournalEntry);
    } else if (object is Project) {
      formPage = CreateProjectForm(existingProject: object as Project);
    } else if (object is Person) {
      formPage = CreatePersonForm(existingPerson: object as Person);
    } else if (object is Resource) {
      formPage = CreateResourceForm(existingResource: object as Resource);
    } else if (object is TrackerDefinition) {
      formPage = CreateTrackerForm(tracker: object as TrackerDefinition);
    } else if (object is Organizer) {
      formPage = CreateOrganizerForm(organizer: object as Organizer);
    } else if (object is SystemDefinition) {
      formPage = CreateSystemForm(existingSystem: object as SystemDefinition);
    }
    if (formPage != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => formPage!));
    }
  }

  void _onPropertyTap(
    BuildContext context,
    WidgetRef ref,
    String key,
    String value,
  ) {
    if (key == 'Status' || key == 'Estado') {
      if (object is Task) {
        _showTaskStatePicker(context, ref, object as Task);
      } else if (object is Project) {
        _showProjectStatePicker(context, ref, object as Project);
      } else if (object is Resource) {
        _showResourceStatusPicker(context, ref, object as Resource);
      } else if (object is Goal) {
        _showGoalStatePicker(context, ref, object as Goal);
      }
    } else if (key == 'Priority' || key == 'Prioridade') {
      if (object is Task) {
        _showTaskPriorityPicker(context, ref, object as Task);
      } else if (object is Project) {
        _showProjectPriorityPicker(context, ref, object as Project);
      }
    } else {
      debugPrint('No action for $key');
    }
  }

  void _showTaskStatePicker(BuildContext context, WidgetRef ref, Task task) {
    _showOptionSheet<TaskStage>(
      context: context,
      title: 'Estado da Tarefa',
      values: TaskStage.values,
      label: (value) => _translateStage(value),
      onSelected: (value) {
        task.stage = value;
        ref.read(vaultProvider.notifier).updateObject(task);
      },
    );
  }

  String _translateStage(TaskStage stage) {
    switch (stage) {
      case TaskStage.idea:
        return 'Ideia';
      case TaskStage.backlog:
        return 'Backlog';
      case TaskStage.todo:
        return 'A Fazer';
      case TaskStage.inProgress:
        return 'Em Progresso';
      case TaskStage.pending:
        return 'Pendente';
      case TaskStage.finalized:
        return 'Finalizado';
    }
  }

  void _showTaskPriorityPicker(BuildContext context, WidgetRef ref, Task task) {
    _showOptionSheet<TaskPriority>(
      context: context,
      title: 'Task Priority',
      values: TaskPriority.values,
      label: (value) => value.name,
      onSelected: (value) {
        task.priority = value;
        ref.read(vaultProvider.notifier).updateObject(task);
      },
    );
  }

  Future<void> _showTaskDueDatePicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    task.endDate = picked;
    await ref.read(vaultProvider.notifier).updateObject(task);
  }

  void _showProjectStatePicker(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) {
    _showOptionSheet<ProjectState>(
      context: context,
      title: 'Project State',
      values: ProjectState.values,
      label: (value) => value.name,
      onSelected: (value) {
        project.projectState = value;
        ref.read(vaultProvider.notifier).updateObject(project);
      },
    );
  }

  void _showGoalStatePicker(BuildContext context, WidgetRef ref, Goal goal) {
    final labels = {
      GoalStatus.active: 'Active',
      GoalStatus.completed: 'Completed',
      GoalStatus.onHold: 'On Hold',
      GoalStatus.cancelled: 'Cancelled',
    };
    _showOptionSheet<GoalStatus>(
      context: context,
      title: 'Goal Status',
      values: GoalStatus.values,
      label: (value) => labels[value] ?? value.name,
      onSelected: (value) {
        goal.state = value;
        ref.read(goalsProvider.notifier).updateGoal(goal);
      },
    );
  }

  void _showProjectPriorityPicker(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) {
    _showOptionSheet<TaskPriority>(
      context: context,
      title: 'Project Priority',
      values: TaskPriority.values,
      label: (value) => value.name,
      onSelected: (value) {
        project.projectPriority = value;
        ref.read(vaultProvider.notifier).updateObject(project);
      },
    );
  }

  void _showPersonPriorityPicker(
    BuildContext context,
    WidgetRef ref,
    Person person,
  ) {
    _showOptionSheet<TaskPriority>(
      context: context,
      title: 'Contact Priority',
      values: TaskPriority.values,
      label: (value) => value.name,
      onSelected: (value) {
        person.contactPriority = value;
        ref.read(vaultProvider.notifier).updateObject(person);
      },
    );
  }

  void _showResourceStatusPicker(
    BuildContext context,
    WidgetRef ref,
    Resource resource,
  ) {
    _showOptionSheet<ResourceStatus>(
      context: context,
      title: 'Resource Status',
      values: ResourceStatus.values,
      label: (value) => value.name,
      onSelected: (value) {
        resource.status = value;
        ref.read(vaultProvider.notifier).updateObject(resource);
      },
    );
  }

  void _showOptionSheet<T>({
    required BuildContext context,
    required String title,
    required List<T> values,
    required String Function(T value) label,
    required ValueChanged<T> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...values.map(
                (value) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label(value).toUpperCase()),
                  onTap: () {
                    // Pop first to avoid context issues during rebuild
                    Navigator.pop(ctx);
                    onSelected(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startFocusSession(BuildContext context, WidgetRef ref) {
    ref.read(pomodoroProvider.notifier).setCurrentItem(object.id, object.title);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PomodoroScreen()),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text(
          'Are you sure you want to delete "${object.title}"? The item will stay in the trash for 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              final oldObject = object;
              final originalPath = object.obsidianPath;
              if (object is JournalEntry) {
                ref
                    .read(todayJournalProvider.notifier)
                    .deleteEntry(object as JournalEntry);
              } else {
                ref.read(vaultProvider.notifier).deleteObject(object);
              }

              Navigator.pop(ctx);
              Navigator.pop(context);

              if (!context.mounted) return;
              if (oldObject is JournalEntry) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Entrada removida do diário.')),
                );
              } else {
                UndoService.showUndoSnackbar(
                  context: context,
                  message: '"${oldObject.title}" moved to trash',
                  onUndo: () {
                    ref
                        .read(vaultProvider.notifier)
                        .restoreObject(oldObject, originalPath);
                  },
                );
              }
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInObsidian(BuildContext context, WidgetRef ref) async {
    final vaultName = ref.read(settingsProvider).vaultName;
    final path = object.obsidianPath;
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File path not set for this object')),
      );
      return;
    }

    final encodedVault = Uri.encodeComponent(vaultName);
    final cleanPath = path.endsWith('.md')
        ? path.substring(0, path.length - 3)
        : path;
    final encodedFile = Uri.encodeComponent(cleanPath);
    final uri = Uri.parse(
      'obsidian://open?vault=$encodedVault&file=$encodedFile',
    );
    debugPrint('Opening Obsidian: $uri');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obsidian not found. Please install the app.'),
          ),
        );
      }
    }
  }

  String _typeLabel(ContentObject obj) {
    if (obj is Organizer) {
      switch (obj.organizerType) {
        case OrganizerType.area:
          return 'Área';
        case OrganizerType.project:
          return 'Projeto';
        case OrganizerType.activity:
          return 'Atividade';
        case OrganizerType.label:
          return 'Etiqueta';
        case OrganizerType.person:
          return 'Pessoa';
        case OrganizerType.place:
          return 'Lugar';
        case OrganizerType.task:
          return 'Tarefa';
        case OrganizerType.goal:
          return 'Objetivo';
        case OrganizerType.habit:
          return 'Hábito';
        case OrganizerType.tracker:
          return 'Rastreador';
      }
    }
    switch (obj.type) {
      case 'task':
        return 'Tarefa';
      case 'habit':
        return 'Hábito';
      case 'goal':
        return 'Objetivo';
      case 'entry':
        return 'Diário';
      case 'calendar_session':
        return 'Evento';
      case 'project':
        return 'Projeto';
      case 'person':
        return 'Pessoa';
      case 'resource':
        return 'Recurso';
      case 'note':
        return 'Nota';
      case 'tracker':
        return 'Rastreador';
      case 'system':
        return 'System';
      default:
        return obj.type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'task':
        return AppColors.info;
      case 'habit':
        return AppColors.habitGreen;
      case 'goal':
        return AppColors.habitOrange;
      case 'entry':
        return AppColors.habitPurple;
      case 'calendar_session':
        return AppColors.primary;
      case 'project':
        return AppColors.priorityHigh;
      case 'person':
        return AppColors.habitPink;
      case 'resource':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline;
      case 'habit':
        return Icons.cached_rounded;
      case 'goal':
        return Icons.flag_outlined;
      case 'entry':
        return Icons.auto_stories_rounded;
      case 'calendar_session':
        return Icons.calendar_today_outlined;
      case 'project':
        return Icons.rocket_launch_rounded;
      case 'person':
        return Icons.person_outline_rounded;
      case 'resource':
        return Icons.local_library_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  Widget _buildKPICard(BuildContext context, WidgetRef ref, KPI kpi) {
    final habits = ref.watch(habitsProvider);
    final trackerRecords = ref.watch(trackingRecordsProvider);
    final entries = ref.watch(allEntriesProvider);
    final moods = ref.watch(moodsProvider);
    final notes = ref.watch(notesProvider);
    final tasks = ref.watch(tasksProvider);

    final currentValue = KPIEngine.calculateKPIValue(
      kpi: kpi,
      habits: habits,
      trackerRecords: trackerRecords,
      entries: entries,
      moods: moods,
      notes: notes,
      tasks: tasks,
    );

    final progress = kpi.targetValue <= 0
        ? 0.0
        : (currentValue / kpi.targetValue).clamp(0.0, 1.0);
    final isComplete = kpi.completed || currentValue >= kpi.targetValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kpi.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '✓ Atingido',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                )
              else
                Text(
                  '${currentValue.toInt()} / ${kpi.targetValue.toInt()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            kpi.sourceType.label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? AppColors.success : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtaskList(
    BuildContext context,
    WidgetRef ref,
    List<Subtask> subtasks,
  ) {
    return _SubtaskListView(subtasks: subtasks, parent: object);
  }

  Widget _buildTimeEstimateCard(BuildContext context, Task task) {
    final estimated = task.estimatedMinutes ?? 0;
    final actual = task.actualMinutes;

    double progress = 0;
    if (estimated > 0) {
      progress = (actual / estimated).clamp(0.0, 1.0);
    }

    final isOvertime = actual > estimated && estimated > 0;

    String formatTime(int minutes) {
      if (minutes <= 0) return '--';
      if (minutes < 60) return '$minutes min';
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimado',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Text(
                    formatTime(estimated),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Real',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Text(
                    formatTime(actual),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isOvertime
                          ? AppColors.warning
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (estimated > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOvertime ? AppColors.warning : AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDependsOnList(
    BuildContext context,
    WidgetRef ref,
    List<String> dependsOnSlugs,
  ) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: dependsOnSlugs.asMap().entries.map((entry) {
          final idx = entry.key;
          final slug = entry.value;
          return Consumer(
            builder: (context, ref, _) {
              final allObjects = ref.watch(allObjectsProvider).value ?? [];
              final cleanRef = slug
                  .replaceAll('[[', '')
                  .replaceAll(']]', '')
                  .trim();
              final blockingTask =
                  allObjects.cast<ContentObject?>().firstWhere(
                        (o) =>
                            o is Task &&
                            (o.slug == cleanRef || o.id == cleanRef),
                        orElse: () => null,
                      )
                      as Task?;

              final isFinalized = blockingTask?.stage == TaskStage.finalized;

              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isFinalized
                          ? Icons.check_circle_rounded
                          : Icons.lock_rounded,
                      color: isFinalized
                          ? AppColors.habitGreen
                          : AppColors.error,
                    ),
                    title: Text(
                      blockingTask?.title ?? slug,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: isFinalized
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 16),
                    onTap: blockingTask != null
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UniversalDetailView(object: blockingTask),
                            ),
                          )
                        : null,
                  ),
                  if (idx != dependsOnSlugs.length - 1)
                    const Divider(
                      height: 1,
                      indent: 48,
                      color: AppColors.divider,
                    ),
                ],
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSnapshotsSection(
    BuildContext context,
    WidgetRef ref,
    String parentId,
  ) {
    final snapshots = ref
        .watch(snapshotsProvider)
        .where((s) => s.parentId == parentId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Snapshots / Reflections',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _createSnapshot(context, ref, parentId),
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('New'),
            ),
          ],
        ),
        if (snapshots.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No snapshots recorded.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ...snapshots.map(
          (s) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(s.date),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.reflection,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _createSnapshot(BuildContext context, WidgetRef ref, String parentId) {
    final controller = TextEditingController();

    // Capture current values
    final Map<String, double> currentKPIs = {};
    if (object is Goal) {
      final goal = object as Goal;
      final habits = ref.read(habitsProvider);
      final trackerRecords = ref.read(trackingRecordsProvider);
      final entries = ref.read(allEntriesProvider);
      final moods = ref.read(moodsProvider);
      final notes = ref.read(notesProvider);
      final tasks = ref.read(tasksProvider);

      for (final kpi in goal.kpis) {
        currentKPIs[kpi.title] = KPIEngine.calculateKPIValue(
          kpi: kpi,
          habits: habits,
          trackerRecords: trackerRecords,
          entries: entries,
          moods: moods,
          notes: notes,
          tasks: tasks,
        );
      }
    } else if (object is Project) {
      final project = object as Project;
      final tasks = ref.read(tasksProvider);
      currentKPIs['Progress'] = KPIEngine.calculateProjectProgress(
        project,
        tasks,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Snapshot / Reflection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentKPIs.isNotEmpty) ...[
              const Text(
                'Current Data:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              ...currentKPIs.entries.map(
                (e) => Text(
                  '${e.key}: ${e.value.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'How is progress going? What are the learnings?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;

              final snapshot = Snapshot(
                title:
                    'Snapshot ${DateFormat('dd/MM/yy').format(DateTime.now())}',
                parentId: parentId,
                kpiValues: currentKPIs,
                reflection: controller.text.trim(),
                date: DateTime.now(),
              );

              ref.read(snapshotsProvider.notifier).addSnapshot(snapshot);
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Snapshot saved successfully!')),
              );
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _statusColor(ResourceStatus status) {
    switch (status) {
      case ResourceStatus.toConsume:
        return AppColors.textSecondary;
      case ResourceStatus.inProgress:
        return AppColors.info;
      case ResourceStatus.completed:
        return AppColors.habitGreen;
      case ResourceStatus.dropped:
        return AppColors.error;
    }
  }

  Widget _personGoogleEventBanner(
    BuildContext context,
    WidgetRef ref,
    Person person,
  ) {
    final email = person.email?.trim().toLowerCase();
    final frequencyDays = person.contactFrequency?.inDays;
    final daysSince = person.lastContactDate == null
        ? null
        : DateTime.now().difference(person.lastContactDate!).inDays;
    if (email == null || email.isEmpty) return const SizedBox.shrink();

    final eventsAsync = ref.watch(
      googleCalendarRangeEventsProvider(
        GoogleCalendarParams(startDate: DateTime.now(), days: 30),
      ),
    );

    return eventsAsync.maybeWhen(
      data: (events) {
        dynamic nextEvent;
        for (final event in events) {
          final start = event.start?.dateTime ?? event.start?.date;
          if (start == null || start.isBefore(DateTime.now())) continue;
          final attendees = event.attendees ?? const [];
          final hasPerson = attendees.any(
            (attendee) => attendee.email?.trim().toLowerCase() == email,
          );
          if (hasPerson) {
            nextEvent = event;
            break;
          }
        }
        if (nextEvent == null) return const SizedBox.shrink();

        final start = nextEvent.start?.dateTime ?? nextEvent.start?.date;
        final isTomorrow =
            start != null &&
            _isSameDay(
              start.toLocal(),
              DateTime.now().add(const Duration(days: 1)),
            );
        final overBy = daysSince != null && frequencyDays != null
            ? daysSince - frequencyDays
            : null;
        final prefix = overBy != null && overBy > 0
            ? 'Você está há $overBy dias a mais sem falar do que gostaria.'
            : 'Próximo contato programado.';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.24)),
          ),
          child: Text(
            '$prefix ${isTomorrow ? 'Amanhã' : 'Em breve'} tem evento: ${nextEvent.summary ?? 'Sem título'}.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.info,
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _contactActionButton(
    BuildContext context,
    WidgetRef ref,
    IconData icon,
    String label,
    Color color,
  ) {
    return InkWell(
      onTap: () async {
        final person = object as Person;
        String? url;
        if (label == 'WhatsApp') {
          url =
              'https://wa.me/${person.phone?.replaceAll(RegExp(r"[^\d+]"), "") ?? ""}';
        } else if (label == 'Message') {
          // Try WhatsApp or SMS
          url = 'sms:${person.phone ?? ""}';
        } else if (label == 'Call') {
          url = 'tel:${person.phone ?? ""}';
        } else if (label == 'Email') {
          url = 'mailto:${person.email ?? ""}';
        }

        if (url != null && await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));

          // Update last contact date
          final updatedPerson = person.copyWith(
            lastContactDate: DateTime.now(),
          );
          await ref.read(vaultProvider.notifier).updateObject(updatedPerson);
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not start $label. Check if phone/email is set.',
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReminderConfigSheet(
        onSave: (config) async {
          object.reminders.add(config);
          await ref.read(vaultProvider.notifier).updateObject(object);

          // Schedule notification
          await NotificationService().scheduleReminder(
            id: config.id.hashCode,
            title: object.title,
            config: config,
            payload: object.id,
          );
        },
      ),
    );
  }

  Future<void> _removeReminder(WidgetRef ref, ReminderConfig config) async {
    object.reminders.remove(config);
    await ref.read(vaultProvider.notifier).updateObject(object);
    await NotificationService().cancelNotification(config.id.hashCode);
  }

  Widget _highlightSearchSnippet(String snippet, String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return Text(
        snippet,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      );
    }

    final lowerSnippet = snippet.toLowerCase();
    final lowerQuery = normalizedQuery.toLowerCase();
    final index = lowerSnippet.indexOf(lowerQuery);
    if (index < 0) {
      return Text(
        snippet,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        children: [
          TextSpan(text: snippet.substring(0, index)),
          TextSpan(
            text: snippet.substring(index, index + normalizedQuery.length),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: snippet.substring(index + normalizedQuery.length)),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, WidgetRef ref) {
    // Removed object == null check because object is late and it causes dead code compiler crash
    final history = ref.watch(historyProvider);
    if (history.length < 2) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final trail = history.reversed.toList();

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: AppColors.background.withValues(alpha: 0.5),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < trail.length - 1; i++) ...[
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UniversalDetailView(
                        object: _findObjectById(ref, trail[i].id),
                      ),
                    ),
                  ),
                  child: Text(
                    trail[i].title,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              Text(
                object.title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  dynamic _findObjectById(WidgetRef ref, String id) {
    final all = ref
        .read(allObjectsProvider)
        .maybeWhen(data: (d) => d, orElse: () => []);
    return all.firstWhere((o) => o.id == id, orElse: () => object);
  }

  void _showFrequencyPicker(
    BuildContext context,
    WidgetRef ref,
    Person person,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        int days = person.contactFrequency?.inDays ?? 7;
        return AlertDialog(
          title: const Text('Contact Frequency'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Every $days days',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: days.toDouble(),
                    min: 1,
                    max: 90,
                    divisions: 89,
                    onChanged: (val) => setState(() => days = val.toInt()),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = person.copyWith(
                  contactFrequency: Duration(days: days),
                );
                await ref.read(vaultProvider.notifier).updateObject(updated);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  Color _typeColorForMention(String type) {
    switch (type) {
      case 'task':
        return AppColors.info;
      case 'entry':
        return AppColors.primary;
      case 'habit':
        return AppColors.habitGreen;
      case 'goal':
        return AppColors.habitOrange;
      case 'project':
        return AppColors.primaryLight;
      case 'note':
        return AppColors.warning;
      case 'resource':
        return AppColors.habitPurple;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _typeIconForMention(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline_rounded;
      case 'entry':
        return Icons.book_rounded;
      case 'habit':
        return Icons.cached_rounded;
      case 'goal':
        return Icons.flag_rounded;
      case 'project':
        return Icons.folder_rounded;
      case 'note':
        return Icons.article_rounded;
      case 'resource':
        return Icons.collections_bookmark_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  void _showRecordDetails(
    BuildContext context,
    WidgetRef ref,
    TrackerDefinition tracker,
    TrackingRecord record,
  ) {
    String formatFieldValue(dynamic val, InputField field) {
      if (val == null) return 'Não preenchido';

      switch (field.type) {
        case InputFieldType.checkbox:
          return (val == true || val == 'true') ? 'Sim' : 'Não';
        case InputFieldType.duration:
          final mins = int.tryParse(val.toString()) ?? 0;
          final h = mins ~/ 60;
          final m = mins % 60;
          if (h > 0 && m > 0) return '${h}h ${m}m';
          if (h > 0) return '${h}h';
          return '${m}m';
        case InputFieldType.mood:
          final slug = val.toString().replaceAll(RegExp(r'\[\[|\]\]'), '');
          final moods = ref.read(moodsProvider);
          final mood = moods.where((m) => m.slug == slug).firstOrNull;
          if (mood != null) return '${mood.emoji} ${mood.title}';
          return slug;
        case InputFieldType.checklist:
          if (val is List) return val.join(', ');
          return val.toString();
        case InputFieldType.media:
          if (val is List) return '${val.length} anexo(s)';
          return 'Mídia anexada';
        case InputFieldType.quantity:
        case InputFieldType.range:
          return val.toString();
        default:
          return val.toString();
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracker.title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMMM, yyyy').format(record.date),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(record.date),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _parseColor(tracker.color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: _parseColor(tracker.color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            ...tracker.sections.expand((s) => s.inputFields).map((field) {
              final val = record.fieldValues[field.id];
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        formatFieldValue(val, field),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Fechar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtaskListView extends StatefulWidget {
  final List<Subtask> subtasks;
  final ContentObject parent;
  const _SubtaskListView({required this.subtasks, required this.parent});

  @override
  State<_SubtaskListView> createState() => _SubtaskListViewState();
}

class _SubtaskListViewState extends State<_SubtaskListView> {
  final Set<String> _collapsedSessions = {};

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        List<Widget> children = [];
        String currentSession = "Geral";
        bool isCurrentCollapsed = false;

        for (final st in widget.subtasks) {
          if (st.isHeader) {
            currentSession = st.title;
            isCurrentCollapsed = _collapsedSessions.contains(currentSession);

            children.add(
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (_collapsedSessions.contains(currentSession)) {
                        _collapsedSessions.remove(currentSession);
                      } else {
                        _collapsedSessions.add(currentSession);
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        isCurrentCollapsed
                            ? Icons.chevron_right_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        st.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
              ),
            );
          } else {
            if (!isCurrentCollapsed) {
              children.add(_buildItem(context, ref, st));
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, WidgetRef ref, Subtask st) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            st.completed = !st.completed;
          });
          ref.read(vaultProvider.notifier).updateObject(widget.parent);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                st.completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: st.completed
                    ? AppColors.habitGreen
                    : AppTheme.textMutedColor(context),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  st.title,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: st.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: st.completed
                        ? AppTheme.textMutedColor(context)
                        : AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              if (st.slug != null)
                const Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
