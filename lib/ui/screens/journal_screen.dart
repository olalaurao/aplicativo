import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/vault_provider.dart';
import '../../services/markdown_parser.dart';

import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/journal_body_view.dart';
import '../widgets/object_action_wrapper.dart';
import '../../models/journal_entry.dart';
import '../../models/habit_model.dart';
import '../forms/create_entry_form.dart';
import 'universal_detail_view.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _filterMood;
  bool _filterHasPhoto = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlySelectedDate = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _onlySelectedDate = true;
      });
    }
  }

  void _showMoodFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final moods = ref.watch(moodsProvider);
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter by Mood',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_filterMood != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _filterMood = null);
                            Navigator.pop(context);
                          },
                          child: const Text('Clear Filter'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ...moods.map((mood) {
                        final isSelected =
                            _filterMood == mood.id || _filterMood == mood.slug;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _filterMood = mood.id);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppTheme.surfaceVariantColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  mood.emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  mood.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppTheme.textPrimaryColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(allEntriesProvider);
    final habits = ref.watch(habitsProvider);

    // Grouping by date
    final Map<String, List<dynamic>> groupedItems = {};

    final filteredEntries = entries.where((e) {
      if (_filterMood != null && e.moodSlug != _filterMood) return false;
      if (_filterHasPhoto && !e.body.contains('![[')) return false;

      // Date filter
      if (_onlySelectedDate) {
        final sameDay =
            e.date.year == _selectedDate.year &&
            e.date.month == _selectedDate.month &&
            e.date.day == _selectedDate.day;
        if (!sameDay) return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final titleMatch = e.title.toLowerCase().contains(query);
        final bodyText = MarkdownParser.getPlainTextFromBody(
          e.body,
        ).toLowerCase();
        final bodyMatch = bodyText.contains(query);
        if (!titleMatch && !bodyMatch) return false;
      }

      return true;
    }).toList();

    for (final entry in filteredEntries) {
      final dateKey = DateFormat('yyyy-MM-dd').format(entry.date);
      groupedItems.putIfAbsent(dateKey, () => []).add(entry);
    }

    // Only show habits if not filtering for photo or mood or actively searching
    if (_filterMood == null && !_filterHasPhoto && _searchQuery.isEmpty) {
      for (final habit in habits) {
        for (final record in habit.completionHistory) {
          if (record.successful) {
            final sameDay =
                record.date.year == _selectedDate.year &&
                record.date.month == _selectedDate.month &&
                record.date.day == _selectedDate.day;

            if (!_onlySelectedDate || sameDay) {
              final dateKey = DateFormat('yyyy-MM-dd').format(record.date);
              groupedItems.putIfAbsent(dateKey, () => []).add({
                'type': 'habit_completion',
                'habit': habit,
                'record': record,
              });
            }
          }
        }
      }
    }

    final sortedDates = groupedItems.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Journal'),
            centerTitle: true,
            floating: true,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  _filterHasPhoto ? Icons.photo_rounded : Icons.photo_outlined,
                  color: _filterHasPhoto
                      ? AppColors.primary
                      : AppTheme.textMutedColor(context),
                ),
                onPressed: () =>
                    setState(() => _filterHasPhoto = !_filterHasPhoto),
                tooltip: 'Filter Photos',
              ),
              IconButton(
                icon: Icon(
                  _filterMood != null
                      ? Icons.mood_rounded
                      : Icons.mood_outlined,
                  color: _filterMood != null
                      ? AppColors.primary
                      : AppTheme.textMutedColor(context),
                ),
                onPressed: _showMoodFilter,
                tooltip: 'Filter Mood',
              ),
              IconButton(
                icon: Icon(
                  Icons.calendar_month_rounded,
                  color: _onlySelectedDate
                      ? AppColors.primary
                      : AppTheme.textMutedColor(context),
                ),
                onPressed: _pickCustomDate,
                tooltip: 'Go to Date',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildDateStrip(),
                _buildSearchAndFilterRow(),
                const Divider(height: 1),
              ],
            ),
          ),
          if (sortedDates.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final dateKey = sortedDates[index];
                  final items = groupedItems[dateKey]!;
                  final date = DateTime.parse(dateKey);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateHeader(date),
                      const SizedBox(height: 12),
                      ...items.map((item) {
                        if (item is JournalEntry) {
                          return _buildJournalEntryCard(context, item);
                        } else {
                          final habit = item['habit'] as Habit;
                          final record = item['record'] as CompletionRecord;
                          return _buildHabitCompletionCard(
                            context,
                            habit,
                            record,
                          );
                        }
                      }),
                      const SizedBox(height: 16),
                    ],
                  );
                }, childCount: sortedDates.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateEntryForm(initialDate: _selectedDate),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantColor(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search entries and tags...',
                hintStyle: TextStyle(color: AppTheme.textMutedColor(context)),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppTheme.textMutedColor(context),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // View all vs Single day toggle
                FilterChip(
                  label: Text(
                    _onlySelectedDate
                        ? 'Day: ${DateFormat('MMM d, yyyy').format(_selectedDate)}'
                        : 'All Days',
                  ),
                  selected: _onlySelectedDate,
                  onSelected: (val) {
                    setState(() => _onlySelectedDate = val);
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.1),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _onlySelectedDate
                        ? AppColors.primary
                        : AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_onlySelectedDate) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _onlySelectedDate = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Show All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_filterMood != null) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('Mood: $_filterMood'),
                    selected: true,
                    onSelected: (_) => setState(() => _filterMood = null),
                    selectedColor: AppColors.primary.withValues(alpha: 0.1),
                    checkmarkColor: AppColors.primary,
                    labelStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_filterHasPhoto) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('With Photo'),
                    selected: true,
                    onSelected: (_) => setState(() => _filterHasPhoto = false),
                    selectedColor: AppColors.primary.withValues(alpha: 0.1),
                    checkmarkColor: AppColors.primary,
                    labelStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.auto_stories_rounded,
      headline: 'Your journey starts here',
      subtext:
          'Record your thoughts, moods and daily wins to build a valuable personal history.',
      ctaLabel: 'Write Now',
      onCta: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateEntryForm(initialDate: _selectedDate),
          ),
        );
      },
    );
  }

  Widget _buildDateStrip() {
    // Generate week of selected date
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: AppTheme.surfaceColor(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(
              () => _selectedDate = _selectedDate.subtract(
                const Duration(days: 7),
              ),
            ),
          ),
          ...List.generate(7, (index) {
            final date = startOfWeek.add(Duration(days: index));
            final isSelected =
                date.year == _selectedDate.year &&
                date.month == _selectedDate.month &&
                date.day == _selectedDate.day;

            return GestureDetector(
              onTap: () => setState(() {
                _selectedDate = date;
                _onlySelectedDate = true;
              }),
              child: Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat(
                        'E',
                      ).format(date).substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textMutedColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => setState(
              () => _selectedDate = _selectedDate.add(const Duration(days: 7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday =
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;

    String label = DateFormat('EEEE, d MMM').format(date);
    if (isToday) label = 'Today, ${DateFormat('d MMM').format(date)}';
    if (isYesterday) label = 'Yesterday, ${DateFormat('d MMM').format(date)}';

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppTheme.textMutedColor(context),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildJournalEntryCard(BuildContext context, JournalEntry entry) {
    return ObjectActionWrapper(
      object: entry,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: entry),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (entry.moodSlug != null) ...[
                    Text(
                      _getMoodEmoji(entry.moodSlug!),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    DateFormat('HH:mm').format(entry.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: AppTheme.textMutedColor(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (entry.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              JournalBodyView(
                body: entry.body,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitCompletionCard(
    BuildContext context,
    Habit habit,
    CompletionRecord record,
  ) {
    final color = Color(int.parse(habit.color.replaceAll('#', '0xFF')));
    return ObjectActionWrapper(
      object: habit,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: habit),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Habit completed • ${DateFormat('HH:mm').format(record.date)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMoodEmoji(String moodId) {
    final mood = ref
        .read(moodsProvider)
        .where((m) => m.id == moodId || m.slug == moodId)
        .firstOrNull;
    if (mood != null) return mood.emoji;

    switch (moodId) {
      case 'terrible':
        return '😞';
      case 'bad':
        return '😕';
      case 'neutral':
        return '😐';
      case 'good':
        return '🙂';
      case 'great':
        return '😄';
      default:
        return '😐';
    }
  }
}
