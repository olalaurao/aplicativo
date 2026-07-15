import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/timeline_card.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/markdown_parser.dart';
import '../../services/timeline_aggregator_service.dart';

import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/journal_body_view.dart';
import '../widgets/object_action_wrapper.dart';
import '../widgets/object_timeline_feed.dart';
import '../../models/journal_entry.dart';
import '../../models/habit_model.dart';
import '../../models/mood_model.dart';
import '../../models/reminder_model.dart';
import '../../services/scheduler_service.dart';
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
              seedColor: AppTheme.accentColor(context),
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
                                  ? AppTheme.accentColor(context).withValues(alpha: 0.1)
                                  : AppTheme.surfaceVariantColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.accentColor(context)
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
                                        ? AppTheme.accentColor(context)
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
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final entries = ref.watch(allEntriesProvider);
    final habits = allObjects.whereType<Habit>().toList();
    final reminders = ref.watch(remindersProvider);
    final moods = ref.watch(moodsProvider);

    // Check if there's already an entry for the FAB target date.
    final today = DateTime.now();
    final isSelectedDateToday = _isSameDay(_selectedDate, today);
    final hasItemsToday = entries.any(
      (e) => _isSameDay(_journalEntryDisplayDate(e), _selectedDate),
    );
    final selectedDateEntry =
        entries
            .where(
              (e) => _isSameDay(_journalEntryDisplayDate(e), _selectedDate),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final isFirstEntryToday = isSelectedDateToday && !hasItemsToday;

    // Grouping by date
    final Map<String, List<dynamic>> groupedItems = {};

    final filteredEntries =
        entries.where((e) {
          if (_filterMood != null &&
              !_entryMatchesMood(e, _filterMood!, moods)) {
            return false;
          }
          if (_filterHasPhoto && !e.body.contains('![[')) return false;

          // Date filter
          if (_onlySelectedDate) {
            bool matches = _isSameDay(_journalEntryDisplayDate(e), _selectedDate);
            if (!matches && e.entryType == JournalEntryType.pmn) {
              matches = e.referencedDates.any((d) => _isSameDay(d, _selectedDate));
            }
            if (!matches) {
              return false;
            }
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
        }).toList()..sort(
          (a, b) => _journalEntryDisplayDate(
            b,
          ).compareTo(_journalEntryDisplayDate(a)),
        );

    final moodOverviewEntries = entries.where((entry) {
      if (_filterHasPhoto && !entry.body.contains('![[')) return false;
      if (_onlySelectedDate) {
        bool matches = _isSameDay(_journalEntryDisplayDate(entry), _selectedDate);
        if (!matches && entry.entryType == JournalEntryType.pmn) {
          matches = entry.referencedDates.any((d) => _isSameDay(d, _selectedDate));
        }
        if (!matches) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final titleMatch = entry.title.toLowerCase().contains(query);
        final bodyMatch = MarkdownParser.getPlainTextFromBody(
          entry.body,
        ).toLowerCase().contains(query);
        if (!titleMatch && !bodyMatch) return false;
      }
      return entry.moodSlug != null && entry.moodSlug!.isNotEmpty;
    }).toList();

    final showDailyReminderSummary =
        _onlySelectedDate &&
        _filterMood == null &&
        !_filterHasPhoto &&
        _searchQuery.isEmpty;
    final pendingReminders = showDailyReminderSummary
        ? (reminders.where((reminder) {
            if (reminder.isCompleted) return false;
            return _isSameDay(reminder.time, _selectedDate) ||
                (reminder.scheduler != null &&
                    SchedulerService.shouldFire(
                      reminder.scheduler!,
                      _selectedDate,
                    ));
          }).toList()..sort((a, b) => a.time.compareTo(b.time)))
        : <Reminder>[];

    for (final entry in filteredEntries) {
      if (entry.entryType == JournalEntryType.pmn && entry.referencedDates.isNotEmpty) {
        if (_onlySelectedDate) {
          final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
          groupedItems.putIfAbsent(dateKey, () => []).add(entry);
        } else {
          final datesToGroup = { _journalEntryDisplayDate(entry), ...entry.referencedDates };
          for (final d in datesToGroup) {
            final dateKey = DateFormat('yyyy-MM-dd').format(d);
            groupedItems.putIfAbsent(dateKey, () => []).add(entry);
          }
        }
      } else {
        final dateKey = DateFormat('yyyy-MM-dd').format(_journalEntryDisplayDate(entry));
        groupedItems.putIfAbsent(dateKey, () => []).add(entry);
      }
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

    // Convert grouped items to TodayItems for ObjectTimelineFeed
    final timelineItems = <TodayItem>[];
    
    for (final dateKey in groupedItems.keys) {
      final items = groupedItems[dateKey]!;
      for (final item in items) {
        if (item is JournalEntry) {
          timelineItems.add(TodayItem(
            id: item.id,
            title: item.title.isNotEmpty ? item.title : 'Journal Entry',
            date: _journalEntryDisplayDate(item),
            origin: TodayItemOrigin.happened,
            kind: TodayItemKind.journalEntry,
            objectId: item.id,
            subtitle: item.body.isNotEmpty ? item.body.substring(0, 50) : null,
          ));
        } else if (item is Map) {
          final habit = item['habit'] as Habit;
          final record = item['record'] as CompletionRecord;
          timelineItems.add(TodayItem(
            id: '${habit.id}_${record.date.toIso8601String()}',
            title: habit.title,
            date: record.date,
            origin: TodayItemOrigin.happened,
            kind: TodayItemKind.habit,
            objectId: habit.id,
            subtitle: 'Completed (${record.completions}/${habit.dailyGoal})',
          ));
        }
      }
    }
    
    // Sort timeline items by date descending
    timelineItems.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        key: const PageStorageKey('journal-scroll'),
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
                      ? AppTheme.accentColor(context)
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
                      ? AppTheme.accentColor(context)
                      : AppTheme.textMutedColor(context),
                ),
                onPressed: _showMoodFilter,
                tooltip: 'Filter Mood',
              ),
              IconButton(
                icon: Icon(
                  Icons.calendar_month_rounded,
                  color: _onlySelectedDate
                      ? AppTheme.accentColor(context)
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
                if (moodOverviewEntries.isNotEmpty)
                  _buildMoodOverview(moodOverviewEntries, moods),
                const Divider(height: 1),
                // Active filter banner
                if (_filterMood != null || _filterHasPhoto || _onlySelectedDate)
                  _buildActiveFilterBanner(moods),
              ],
            ),
          ),

          if (pendingReminders.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildPendingRemindersSummary(pendingReminders),
            ),
          if (timelineItems.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverToBoxAdapter(
              child: ObjectTimelineFeed(
                items: timelineItems,
                showDateSeparators: true,
                typeSignatures: ref.watch(settingsProvider).typeSignatures,
                itemBuilder: (context, ref, item) {
                  // Map TodayItem back to original objects for custom rendering
                  if (item.kind == TodayItemKind.journalEntry) {
                    final entry = entries.firstWhere((e) => e.id == item.objectId, orElse: () => entries.first);
                    return _buildJournalEntryCard(context, entry);
                  } else if (item.kind == TodayItemKind.habit) {
                    final habit = habits.firstWhere((h) => h.id == item.objectId, orElse: () => habits.first);
                    final record = habit.completionHistory.firstWhere(
                      (r) => r.date.toIso8601String().split('T').first == 
                             item.date.toIso8601String().split('T').first,
                      orElse: () => habit.completionHistory.first,
                    );
                    return _buildHabitCompletionCard(context, habit, record);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final entryToEdit = selectedDateEntry.isNotEmpty
              ? selectedDateEntry.first
              : null;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateEntryForm(
                initialDate: _selectedDate,
                existingEntry: entryToEdit,
              ),
            ),
          );
        },
        backgroundColor: AppTheme.accentColor(context),
        icon: Icon(
          isFirstEntryToday
              ? Icons.wb_sunny_rounded
              : hasItemsToday
              ? Icons.edit_note_rounded
              : Icons.add_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          isFirstEntryToday
              ? 'Começar o dia'
              : hasItemsToday
              ? 'Editar entrada'
              : 'Nova entrada',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildMoodOverview(
    List<JournalEntry> entries,
    List<MoodDefinition> moods,
  ) {
    final counts = <String, int>{};
    for (final entry in entries) {
      for (final moodSlug in _moodSlugsForEntry(entry)) {
        final mood = _moodForSlug(moodSlug, moods);
        final key = mood?.id ?? moodSlug;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final items = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final mood = _moodForSlug(item.key, moods);
          final selected =
              _filterMood != null &&
              _moodKeysMatch(_filterMood!, item.key, moods);
          final emoji = mood?.emoji ?? _getMoodEmoji(item.key);

          return InkWell(
            onTap: () {
              setState(() {
                _filterMood = selected ? null : (mood?.id ?? item.key);
              });
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.accentColor(context).withValues(alpha: 0.12)
                    : AppTheme.surfaceVariantColor(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? AppTheme.accentColor(context)
                      : AppTheme.dividerColor(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    item.value.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppTheme.accentColor(context)
                          : AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
                  selectedColor: AppTheme.accentColor(context).withValues(alpha: 0.1),
                  checkmarkColor: AppTheme.accentColor(context),
                  labelStyle: TextStyle(
                    color: _onlySelectedDate
                        ? AppTheme.accentColor(context)
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
                        color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear_rounded,
                            size: 14,
                            color: AppTheme.accentColor(context),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Show All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentColor(context),
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
                    selectedColor: AppTheme.accentColor(context).withValues(alpha: 0.1),
                    checkmarkColor: AppTheme.accentColor(context),
                    labelStyle: TextStyle(
                      color: AppTheme.accentColor(context),
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
                    selectedColor: AppTheme.accentColor(context).withValues(alpha: 0.1),
                    checkmarkColor: AppTheme.accentColor(context),
                    labelStyle: TextStyle(
                      color: AppTheme.accentColor(context),
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

  String _resolveMoodLabel(WidgetRef ref, String moodId) {
    final moods = ref.read(moodsProvider);
    final mood = moods.where((m) => m.id == moodId || m.slug == moodId).firstOrNull;
    return mood != null ? '${mood.emoji} ${mood.title}' : moodId;
  }

  Widget _activeFilterChip(String label, VoidCallback onRemove) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.accentColor(context).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(
        fontSize: 11, color: AppTheme.accentColor(context), fontWeight: FontWeight.w600)),
      const SizedBox(width: 4),
      GestureDetector(onTap: onRemove,
        child: Icon(Icons.close_rounded, size: 12, color: AppTheme.accentColor(context))),
    ]));

  Widget _buildActiveFilterBanner(List<MoodDefinition> moods) {
    return Container(
      color: AppTheme.accentColor(context).withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Icon(Icons.filter_list_rounded, size: 14, color: AppTheme.accentColor(context)),
        const SizedBox(width: 6),
        if (_filterMood != null) ...[
          _activeFilterChip(
            _resolveMoodLabel(ref, _filterMood!),
            () => setState(() => _filterMood = null)),
          const SizedBox(width: 6),
        ],
        if (_filterHasPhoto) ...[
          _activeFilterChip('📷 Com foto', () => setState(() => _filterHasPhoto = false)),
          const SizedBox(width: 6),
        ],
        if (_onlySelectedDate)
          _activeFilterChip(
            DateFormat('d MMM', 'pt_BR').format(_selectedDate),
            () => setState(() => _onlySelectedDate = false)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() {
            _filterMood = null;
            _filterHasPhoto = false;
            _onlySelectedDate = false;
          }),
          child: Text('Limpar', style: TextStyle(
            fontSize: 11, color: AppTheme.accentColor(context), fontWeight: FontWeight.w600))),
      ]),
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
                  color: isSelected ? AppTheme.accentColor(context) : Colors.transparent,
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
    final isToday = _isSameDay(date, now);
    final isYesterday = _isSameDay(date, now.subtract(const Duration(days: 1)));

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
    if (entry.entryType == JournalEntryType.pmn) {
      return ObjectActionWrapper(
        object: entry,
        child: PmnCard(
          title: entry.title.isNotEmpty ? entry.title : 'PMN',
          week: entry.week ?? '',
          plusCount: entry.plus.length,
          minusCount: entry.minus.length,
          nextCount: entry.next.length,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UniversalDetailView(object: entry),
              ),
            );
          },
        ),
      );
    }

    final displayDate = _journalEntryDisplayDate(entry);
    final moods = ref.watch(moodsProvider);
    final moodSlugs = _moodSlugsForEntry(entry);

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
                  Text(
                    DateFormat('HH:mm').format(displayDate),
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
              const SizedBox(height: 8),
              if (moodSlugs.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: moodSlugs
                      .map((slug) => _buildMoodFlag(context, slug, moods))
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              if (entry.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

  Widget _buildMoodFlag(
    BuildContext context,
    String moodSlug,
    List<MoodDefinition> moods,
  ) {
    final mood = _moodForSlug(moodSlug, moods);
    final label = mood?.title ?? moodSlug;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accentColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.accentColor(context).withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mood?.emoji ?? _getMoodEmoji(moodSlug),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Flexible(
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
                      habit.displayTitle,
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

  Widget _buildPendingRemindersSummary(List<Reminder> reminders) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${reminders.length} lembrete(s) pendente(s) para revisar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...reminders
                .take(3)
                .map(
                  (reminder) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            DateFormat('HH:mm').format(reminder.time),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMutedColor(context),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            reminder.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (reminders.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${reminders.length - 3} outros',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getMoodEmoji(String moodId) {
    final mood = _moodForSlug(moodId, ref.read(moodsProvider));
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

  MoodDefinition? _moodForSlug(String? moodSlug, List<MoodDefinition> moods) {
    if (moodSlug == null || moodSlug.isEmpty) return null;
    return moods
        .where((mood) => mood.id == moodSlug || mood.slug == moodSlug)
        .firstOrNull;
  }

  bool _entryMatchesMood(
    JournalEntry entry,
    String filterMood,
    List<MoodDefinition> moods,
  ) {
    final moodSlugs = _moodSlugsForEntry(entry);
    if (moodSlugs.isEmpty) return false;
    return moodSlugs.any(
      (moodSlug) => _moodKeysMatch(moodSlug, filterMood, moods),
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

  bool _moodKeysMatch(String left, String right, List<MoodDefinition> moods) {
    if (left == right) return true;
    final leftMood = _moodForSlug(left, moods);
    final rightMood = _moodForSlug(right, moods);
    if (leftMood == null || rightMood == null) return false;
    return leftMood.id == rightMood.id || leftMood.slug == rightMood.slug;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _itemDate(dynamic item) {
    if (item is JournalEntry) return _journalEntryDisplayDate(item);
    if (item is Map && item['type'] == 'habit_completion') {
      return (item['record'] as CompletionRecord).date;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _journalEntryDisplayDate(JournalEntry entry) {
    final match = RegExp(
      r'daily[/\\](\d{4}-\d{2}-\d{2})\.md$',
    ).firstMatch(entry.obsidianPath);
    if (match == null) return entry.date;

    final dailyDate = DateTime.tryParse(match.group(1)!);
    if (dailyDate == null) return entry.date;

    final explicitTime = entry.timeOfDay;
    if (explicitTime != null && explicitTime.contains(':')) {
      final parts = explicitTime.split(':');
      return DateTime(
        dailyDate.year,
        dailyDate.month,
        dailyDate.day,
        int.tryParse(parts[0]) ?? entry.date.hour,
        parts.length > 1 ? int.tryParse(parts[1]) ?? entry.date.minute : 0,
        entry.date.second,
        entry.date.millisecond,
        entry.date.microsecond,
      );
    }

    return DateTime(
      dailyDate.year,
      dailyDate.month,
      dailyDate.day,
      entry.date.hour,
      entry.date.minute,
      entry.date.second,
      entry.date.millisecond,
      entry.date.microsecond,
    );
  }
}
