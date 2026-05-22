// lib/ui/screens/timeline_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/vault_provider.dart';
import '../../models/task_model.dart';
import '../../models/journal_entry.dart';
import '../../models/mood_model.dart';
import '../theme.dart';
import '../widgets/object_action_wrapper.dart';
import '../widgets/journal_body_view.dart';
import '../../models/people_model.dart';
import '../../models/content_object.dart';
import '../../models/habit_model.dart';
import '../../models/resource_model.dart';
import '../../models/project_model.dart';
import 'universal_detail_view.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String _searchQuery = '';
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(allEntriesProvider);
    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    // Combine everything into a unified list
    final allItems = <ContentObject>[...entries, ...tasks, ...habits];

    // Sort by creation date
    allItems.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      return bTime.compareTo(aTime);
    });

    final filteredItems = allItems.where((item) {
      final matchesSearch = item.title.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesFilter =
          _activeFilter == 'All' ||
          (_activeFilter == 'Notes' && item is JournalEntry) ||
          (_activeFilter == 'Tasks' && item is Task) ||
          (_activeFilter == 'Habits' && item is Habit);
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          // ─── Header ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildFilterChips(),
                ],
              ),
            ),
          ),

          // ─── Timeline Feed ───
          if (filteredItems.isEmpty)
            _buildEmptyState()
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = filteredItems[index];
                  final showDate =
                      index == 0 ||
                      !_isSameDay(
                        item.createdAt,
                        filteredItems[index - 1].createdAt,
                      );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDate) _buildDateSeparator(item.createdAt),
                      _buildTimelineItem(context, item),
                    ],
                  );
                }, childCount: filteredItems.length),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: const InputDecoration(
          icon: Icon(Icons.search, size: 20, color: AppColors.textMuted),
          hintText: 'Search journal...',
          border: InputBorder.none,
          hintStyle: TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Notes', 'Tasks', 'Habits'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _activeFilter == f,
                  onSelected: (val) => setState(() => _activeFilter = f),
                  backgroundColor: Colors.transparent,
                  selectedColor: AppColors.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _activeFilter == f
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _activeFilter == f
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _activeFilter == f
                          ? AppColors.primary
                          : AppColors.divider,
                    ),
                  ),
                  showCheckmark: false,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final isToday = _isSameDay(date, DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        isToday ? 'Today' : DateFormat('EEEE, d MMMM').format(date),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, ContentObject item) {
    final moods = item is JournalEntry
        ? ref.watch(moodsProvider)
        : const <MoodDefinition>[];
    final moodSlugs = item is JournalEntry
        ? _moodSlugsForEntry(item)
        : const <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ObjectActionWrapper(
        object: item,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: item),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeIcon(item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(item.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (moodSlugs.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: moodSlugs
                              .map((slug) => _buildMoodFlag(slug, moods))
                              .toList(),
                        ),
                      ],
                      if (item is JournalEntry && item.body.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        JournalBodyView(
                          body: item.body,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodFlag(String moodSlug, List<MoodDefinition> moods) {
    final mood = moods
        .where((m) => m.id == moodSlug || m.slug == moodSlug)
        .firstOrNull;
    final emoji = mood?.emoji ?? _fallbackMoodEmoji(moodSlug);
    final label = mood?.title ?? moodSlug;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _moodSlugsForEntry(JournalEntry entry) {
    final moodSlug = entry.moodSlug;
    if (moodSlug == null || moodSlug.trim().isEmpty) return const [];
    return moodSlug
        .replaceAll('[[', '')
        .replaceAll(']]', '')
        .split(RegExp(r'[,;|]'))
        .map((slug) => slug.trim())
        .where((slug) => slug.isNotEmpty)
        .toSet()
        .toList();
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

  Widget _buildTypeIcon(ContentObject item) {
    IconData icon;
    Color color;
    if (item is Task) {
      icon = Icons.check_circle_outline_rounded;
      color = AppColors.info;
    } else if (item is Habit) {
      icon = Icons.cached_rounded;
      color = AppColors.habitGreen;
    } else if (item is Project) {
      icon = Icons.folder_copy_rounded;
      color = AppColors.primary;
    } else if (item is Person) {
      icon = Icons.person_rounded;
      color = AppColors.info;
    } else if (item is Resource) {
      icon = Icons.local_library_rounded;
      color = AppColors.warning;
    } else {
      icon = Icons.auto_stories_rounded;
      color = AppColors.habitPurple;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'No items found',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
