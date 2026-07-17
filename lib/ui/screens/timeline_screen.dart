// lib/ui/screens/timeline_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
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
import '../utils/object_icons.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String _searchQuery = '';
  String _activeFilter = 'All';

  int _currentPage = 1;
  static const _pageSize = 50;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (_currentPage * _pageSize < _getFilteredItems().length) {
          setState(() => _currentPage++);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<ContentObject> _getFilteredItems() {
    final entries = ref.watch(allEntriesProvider);
    final tasks = ref.watch(tasksListProvider);
    final habits = ref.watch(habitsProvider);
    // Combine everything into a unified list
    final allItems = <ContentObject>[...entries, ...tasks, ...habits];

    // Sort journal entries by their actual daily-note date/time, not parse time.
    allItems.sort((a, b) {
      final aTime = _timelineDate(a);
      final bTime = _timelineDate(b);
      return bTime.compareTo(aTime);
    });

    return allItems.where((item) {
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
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final paginatedItems = filteredItems.take(_pageSize * _currentPage).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        controller: _scrollController,
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
          if (paginatedItems.isEmpty)
            _buildEmptyState()
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = paginatedItems[index];
                  final itemDate = _timelineDate(item);
                  final showDate =
                      index == 0 ||
                      !_isSameDay(
                        itemDate,
                        _timelineDate(paginatedItems[index - 1]),
                      );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDate) _buildDateSeparator(itemDate),
                      _buildTimelineItem(context, item),
                    ],
                  );
                }, childCount: paginatedItems.length),
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
                  selectedColor: AppTheme.accentColor(context).withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _activeFilter == f
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _activeFilter == f
                        ? AppTheme.accentColor(context)
                        : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _activeFilter == f
                          ? AppTheme.accentColor(context)
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
    final itemDate = _timelineDate(item);
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(itemDate),
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
        color: AppTheme.accentColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.accentColor(context).withValues(alpha: 0.16)),
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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentColor(context),
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
    final iconData = ObjectIcons.iconDataForTypeWithSignatures(item.type, ref.read(settingsProvider).typeSignatures);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.accentColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          iconData ?? ObjectIcons.defaultIconDataForType(item.type),
          size: 18,
          color: AppTheme.accentColor(context),
        ),
      ),
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

  DateTime _timelineDate(ContentObject item) {
    if (item is JournalEntry) {
      final explicitTime = item.timeOfDay?.trim();
      if (explicitTime != null &&
          RegExp(r'^\d{1,2}:\d{2}$').hasMatch(explicitTime)) {
        final parts = explicitTime.split(':');
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null &&
            minute != null &&
            hour >= 0 &&
            hour < 24 &&
            minute >= 0 &&
            minute < 60) {
          return DateTime(
            item.date.year,
            item.date.month,
            item.date.day,
            hour,
            minute,
            item.date.second,
            item.date.millisecond,
            item.date.microsecond,
          );
        }
      }
      return item.date;
    }
    return item.createdAt;
  }
}
