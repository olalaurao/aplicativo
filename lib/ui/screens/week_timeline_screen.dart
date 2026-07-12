import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../providers/today_provider.dart';
import '../../providers/pomodoro_provider.dart';
import '../../providers/vault_provider.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../services/today_aggregator_service.dart';
import '../theme.dart';
import '../navigation/object_navigation.dart';
import 'pomodoro_screen.dart';

class WeekTimelineScreen extends ConsumerStatefulWidget {
  const WeekTimelineScreen({super.key});

  @override
  ConsumerState<WeekTimelineScreen> createState() => _WeekTimelineScreenState();
}

class _WeekTimelineScreenState extends ConsumerState<WeekTimelineScreen> {
  late final ScrollController _scrollController;
  late final List<DateTime> _loadedDates;
  int _previousDaysLoaded = 0;
  bool _showTodayButton = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Load Today + next 13 days (2 weeks)
    _loadedDates = List.generate(14, (i) => today.add(Duration(days: i)));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      // Show Today button if scrolled away from top
      _showTodayButton = _scrollController.position.pixels > 100;
    });
    
    // Forward infinite scroll: load more days when near bottom
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreForwardDays();
    }
  }

  void _loadMoreForwardDays() {
    final lastDate = _loadedDates.last;
    final newDates = List.generate(7, (i) => lastDate.add(Duration(days: i + 1)));
    setState(() {
      _loadedDates.addAll(newDates);
    });
  }

  void _loadPreviousDays() {
    final firstDate = _loadedDates.first;
    final newDates = List.generate(7, (i) => firstDate.subtract(Duration(days: 7 - i)));
    
    // Preserve current scroll position to prevent visual jump
    final currentScrollOffset = _scrollController.offset;
    
    setState(() {
      _loadedDates.insertAll(0, newDates);
      _previousDaysLoaded += 7;
    });

    // Adjust scroll position to account for new items added at top
    // Approximate height per day section (header + items)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final estimatedHeightPerDay = 200.0; // Approximate height
      final totalNewHeight = newDates.length * estimatedHeightPerDay;
      _scrollController.jumpTo(currentScrollOffset + totalNewHeight);
    });
  }

  void _scrollToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final todayIndex = _loadedDates.indexWhere((date) => 
        date.year == today.year && date.month == today.month && date.day == today.day);
    
    if (todayIndex != -1) {
      // Scroll to today's position (approximate, since we don't have exact item heights)
      _scrollController.animateTo(
        todayIndex * 200.0, // Approximate height per day section
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search items...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textMuted),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              )
            : const Text('Week Timeline'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'jump_to_date') {
                // TODO: Implement date picker jump
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'jump_to_date',
                child: Text('Jump to date...'),
              ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _loadedDates.length + 1, // +1 for "Show previous days" control
        itemBuilder: (context, index) {
          if (index == 0) {
            // "Show previous days" control (hide when searching)
            if (_isSearching) return const SizedBox.shrink();
            
            return InkWell(
              onTap: _loadPreviousDays,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _previousDaysLoaded == 0 
                          ? 'Show previous days' 
                          : 'Show more previous days',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final dateIndex = index - 1;
          final date = _loadedDates[dateIndex];
          final items = ref.watch(todayItemsProvider(date));

          // Filter items by search query
          final filteredItems = _isSearching && _searchQuery.isNotEmpty
              ? items.where((item) => item.title.toLowerCase().contains(_searchQuery)).toList()
              : items;

          // Hide empty days when searching
          if (_isSearching && filteredItems.isEmpty) return const SizedBox.shrink();

          return _buildDaySection(date, today, filteredItems);
        },
      ),
      floatingActionButton: _showTodayButton && !_isSearching
          ? FloatingActionButton.small(
              onPressed: _scrollToToday,
              child: const Text('Today'),
            )
          : null,
    );
  }

  Widget _buildDaySection(DateTime date, DateTime today, List items) {
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final isYesterday = date == today.subtract(const Duration(days: 1));
    final isTomorrow = date == today.add(const Duration(days: 1));

    String relativeLabel = '';
    if (isToday) {
      relativeLabel = 'Today';
    } else if (isYesterday) {
      relativeLabel = 'Yesterday';
    } else if (isTomorrow) {
      relativeLabel = 'Tomorrow';
    }

    final weekday = DateFormat('EEEE', 'en_US').format(date);
    final dateStr = DateFormat('d MMM.').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isToday ? AppTheme.accentColor(context) : null,
                ),
              ),
              if (relativeLabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  '·',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  relativeLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday ? AppTheme.accentColor(context) : null,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                weekday,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Divider
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1),
        ),
        // Items
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Text(
              'Nothing scheduled',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...items.map((item) => _buildItemRow(item)),
      ],
    );
  }

  Widget _buildItemRow(TodayItem item) {
    return InkWell(
      onTap: () => navigateToObject(context, item.source),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            // Checkbox (only if completable)
            if (item.isCompletable)
              SizedBox(
                width: 24,
                child: Checkbox(
                  value: item.isCompleted,
                  onChanged: (value) => _toggleCompletion(item),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else
              const SizedBox(width: 24),
            const SizedBox(width: 8),
            // Emoji
            SizedBox(
              width: 20,
              child: Text(item.emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
            // Time (only if not midnight/untimed)
            if (item.timestamp.hour != 0 || item.timestamp.minute != 0)
              SizedBox(
                width: 44,
                child: Text(
                  DateFormat('HH:mm').format(item.timestamp),
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              )
            else
              const SizedBox(width: 44),
            const SizedBox(width: 8),
            // Title
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                  color: item.isCompleted 
                      ? AppColors.textMuted.withValues(alpha: 0.5)
                      : item.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Play button (only if playable)
            if (item.isPlayable)
              IconButton(
                icon: Icon(
                  Icons.play_arrow_rounded,
                  color: AppTheme.accentColor(context),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _startPomodoro(item),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleCompletion(TodayItem item) {
    HapticFeedback.lightImpact();
    
    if (item.kind == TodayItemKind.task && item.source is Task) {
      final task = item.source as Task;
      final newStage = task.stage == TaskStage.finalized 
          ? TaskStage.todo 
          : TaskStage.finalized;
      ref.read(vaultProvider.notifier).updateObject(task.copyWith(stage: newStage));
    } else if (item.kind == TodayItemKind.habitSlot && item.source is Habit) {
      final habit = item.source as Habit;
      final date = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
      ref.read(habitsProvider.notifier).toggleHabit(habit, date);
    }
  }

  void _startPomodoro(TodayItem item) {
    ref.read(pomodoroProvider.notifier).setCurrentItem(item.source.id, item.source.title);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PomodoroScreen()),
    );
  }
}
