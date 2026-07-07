import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/scheduler.dart';
import '../../providers/day_theme_provider.dart';
import '../theme.dart';
import '../widgets/wiki_link_picker.dart';

class SchedulerPicker extends ConsumerStatefulWidget {
  final Scheduler? initialScheduler;

  const SchedulerPicker({super.key, this.initialScheduler});

  @override
  ConsumerState<SchedulerPicker> createState() => _SchedulerPickerState();
}

class _SchedulerPickerState extends ConsumerState<SchedulerPicker> {
  int _currentStep = 0;

  // Rule Data
  RepeatType _selectedType = RepeatType.numberOfDays;
  int _interval = 1;
  List<String> _daysOfWeek = [];
  List<int> _daysOfMonth = [];
  String? _themeId;
  String? _blockId;
  int _countPerPeriod = 1;
  String _period = 'month';
  int _startingDayOffset = 0;
  int _intervalBetweenDays = 1;
  String? _linkedItemId;
  String? _targetType;
  String? _fieldName;

  // Scheduler Data
  List<SchedulerRule> _exclusions = [];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int? _maxOccurrences;
  OverduePolicy _overduePolicy = OverduePolicy.keep;

  @override
  void initState() {
    super.initState();
    if (widget.initialScheduler != null) {
      final s = widget.initialScheduler!;
      _startDate = s.startDate;
      _endDate = s.endDate;
      _maxOccurrences = s.maxOccurrences;
      _overduePolicy = s.overduePolicy;
      _exclusions = List.from(s.exclusions);

      if (s.rules.isNotEmpty) {
        final firstRule = s.rules.first;
        _selectedType = firstRule.repeatType;
        _interval = firstRule.interval ?? 1;
        _daysOfWeek = List<String>.from(firstRule.daysOfWeek ?? []);
        _daysOfMonth = List<int>.from(firstRule.daysOfMonth ?? []);
        _themeId = firstRule.themeId;
        _blockId = firstRule.blockId;
        _countPerPeriod = firstRule.countPerPeriod ?? 1;
        _period = firstRule.period ?? 'month';
        _startingDayOffset = firstRule.startingDayOffset ?? 0;
        _intervalBetweenDays = firstRule.intervalBetweenDays ?? 1;
        _linkedItemId = firstRule.linkedItemId;
        _targetType = firstRule.targetType;
        _fieldName = firstRule.fieldName;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _stepTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildStepTypeSelection(),
                _buildStepConfiguration(),
                _buildStepScopeAndExclusions(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'Repeat';
      case 1:
        return 'Configure';
      case 2:
        return 'Rules & Scope';
      default:
        return 'Scheduler';
    }
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.accentColor(context) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepTypeSelection() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'WHAT FREQUENCY?',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        _typeOption(
          RepeatType.numberOfDays,
          'Daily / Interval',
          Icons.calendar_today_rounded,
        ),
        _typeOption(
          RepeatType.daysOfWeek,
          'Days of Week',
          Icons.view_week_rounded,
        ),
        _typeOption(
          RepeatType.numberOfWeeks,
          'Weekly',
          Icons.date_range_rounded,
        ),
        _typeOption(
          RepeatType.numberOfMonths,
          'Monthly',
          Icons.calendar_month_rounded,
        ),
        _typeOption(
          RepeatType.numberOfHours,
          'Hourly / Intraday',
          Icons.access_time_rounded,
        ),
        _typeOption(
          RepeatType.daysAfterLastEnd,
          'Relative (post-completion)',
          Icons.history_rounded,
        ),
        _typeOption(
          RepeatType.numberOfDaysPerPeriod,
          'Periodic Goal (ex: 3x/week)',
          Icons.flag_rounded,
        ),
        _typeOption(
          RepeatType.linkedItemAppears,
          'Linked to Item (same day)',
          Icons.link_rounded,
        ),
        _typeOption(
          RepeatType.nDaysAfterLinkedItem,
          'N Days after Linked Item',
          Icons.timeline_rounded,
        ),
        _typeOption(
          RepeatType.firstBusinessDayOfMonth,
          'Business Rules',
          Icons.business_center_rounded,
        ),
        _typeOption(
          RepeatType.daysAfterReferenceField,
          'Days After Reference Field',
          Icons.calendar_view_day_rounded,
        ),
        _typeOption(
          RepeatType.daysOfTheme,
          'Day Theme',
          Icons.dashboard_customize_rounded,
        ),
        _typeOption(
          RepeatType.daysWithBlock,
          'Time Block Presence',
          Icons.view_day_rounded,
        ),
      ],
    );
  }

  Widget _typeOption(RepeatType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentColor(context).withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentColor(context) : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accentColor(context) : AppColors.textMuted,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppTheme.accentColor(context),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConfiguration() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _getRepeatLabel(_selectedType).toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 24),
        _buildConfigFields(_selectedType),
      ],
    );
  }

  Widget _buildConfigFields(RepeatType type) {
    switch (type) {
      case RepeatType.numberOfDays:
        return _intervalInput('Repeat every', 'days');
      case RepeatType.daysOfWeek:
        return _buildDaysOfWeekSelector();
      case RepeatType.numberOfWeeks:
        return Column(
          children: [
            _intervalInput('Repeat every', 'weeks'),
            const SizedBox(height: 20),
            _buildDaysOfWeekSelector(),
          ],
        );
      case RepeatType.numberOfMonths:
        return _buildMonthlySelector();
      case RepeatType.numberOfHours:
        return _intervalInput('Repeat every', 'hours');
      case RepeatType.daysAfterLastStart:
        return _intervalInput('Recur', 'days after last start');
      case RepeatType.daysAfterLastEnd:
        return _intervalInput('Recur', 'days after last completion');
      case RepeatType.numberOfDaysPerPeriod:
        return _buildPeriodSelector();
      case RepeatType.linkedItemAppears:
      case RepeatType.nDaysAfterLinkedItem:
        return _buildLinkedItemSelector(type);
      case RepeatType.daysOfTheme:
        return _buildThemeSelector();
      case RepeatType.daysWithBlock:
        return _buildBlockSelector();
      case RepeatType.firstBusinessDayOfMonth:
        return const Text(
          'Scheduled for the first business day of each month.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        );
      case RepeatType.daysAfterReferenceField:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _intervalInput('Repeat every', 'days after date'),
            const SizedBox(height: 20),
            const Text('Target Object Type', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'e.g. person, project',
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              controller: TextEditingController(text: _targetType),
              onChanged: (v) => _targetType = v,
            ),
            const SizedBox(height: 20),
            const Text('Date Field Name', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'e.g. last_contact_date',
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              controller: TextEditingController(text: _fieldName),
              onChanged: (v) => _fieldName = v,
            ),
          ],
        );
    }
  }

  Widget _intervalInput(String prefix, String suffix) {
    return Row(
      children: [
        Text(prefix, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 16),
        SizedBox(
          width: 80,
          child: TextField(
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            controller: TextEditingController(text: _interval.toString()),
            onChanged: (v) => _interval = int.tryParse(v) ?? 1,
          ),
        ),
        const SizedBox(width: 16),
        Text(suffix, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildDaysOfWeekSelector() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: days.map((day) {
        final selected = _daysOfWeek.contains(day);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _daysOfWeek.remove(day);
              } else {
                _daysOfWeek.add(day);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accentColor(context).withValues(alpha: 0.1)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.accentColor(context) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: selected ? AppTheme.accentColor(context) : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  day,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthlySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _intervalInput('Repeat every', 'months'),
        const SizedBox(height: 32),
        const Text(
          'ON DAYS:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._daysOfMonth.map(
              (day) => Chip(
                label: Text('Day $day'),
                onDeleted: () => setState(() => _daysOfMonth.remove(day)),
                backgroundColor: AppColors.surfaceVariant,
                side: BorderSide.none,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add Day'),
              onPressed: () async {
                final day = await showDialog<int>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Choose day'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 7,
                        children: List.generate(
                          31,
                          (i) => InkWell(
                            onTap: () => Navigator.pop(ctx, i + 1),
                            child: Center(child: Text('${i + 1}')),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                if (day != null && !_daysOfMonth.contains(day)) {
                  setState(() => _daysOfMonth.add(day));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 50,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                controller: TextEditingController(
                  text: _countPerPeriod.toString(),
                ),
                decoration: const InputDecoration(isDense: true),
                onChanged: (v) => _countPerPeriod = int.tryParse(v) ?? 1,
              ),
            ),
            const Text(' days per '),
            DropdownButton<String>(
              value: _period,
              items: [
                'week',
                'month',
                'year',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _period = v!),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _numericRow(
          'Starting Day Offset',
          _startingDayOffset,
          (v) => _startingDayOffset = v,
        ),
        _numericRow(
          'Interval between days',
          _intervalBetweenDays,
          (v) => _intervalBetweenDays = v,
        ),
      ],
    );
  }

  Widget _numericRow(String label, int val, ValueChanged<int> onVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          SizedBox(
            width: 50,
            child: TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              controller: TextEditingController(text: val.toString()),
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) => onVal(int.tryParse(v) ?? 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedItemSelector(RepeatType type) {
    return Column(
      children: [
        ListTile(
          title: const Text('Linked Item'),
          subtitle: Text(_linkedItemId ?? 'Select item...'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => WikiLinkPicker(
                onSelected: (obj) {
                  setState(() => _linkedItemId = '[[${obj.slug}]]');
                  Navigator.pop(context);
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (type == RepeatType.nDaysAfterLinkedItem)
          _intervalInput('Occurs', 'days after'),
      ],
    );
  }

  Widget _buildStepScopeAndExclusions() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'DATE & POLICY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Start Date'),
          subtitle: Text(DateFormat('MMM d, yyyy').format(_startDate)),
          trailing: const Icon(Icons.calendar_today_rounded, size: 20),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) setState(() => _startDate = date);
          },
        ),
        ListTile(
          title: const Text('End Date'),
          subtitle: Text(
            _endDate != null
                ? DateFormat('MMM d, yyyy').format(_endDate!)
                : 'None (Infinite)',
          ),
          trailing: const Icon(Icons.event_busy_rounded, size: 20),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _endDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            setState(() => _endDate = date);
          },
        ),
        _numericRow(
          'Occurrence Limit',
          _maxOccurrences ?? 0,
          (v) => _maxOccurrences = v > 0 ? v : null,
        ),
        const SizedBox(height: 24),
        const Text(
          'OVERDUE POLICY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _overdueOption(
          OverduePolicy.keep,
          'Keep Date',
          'Preserves the original schedule.',
        ),
        _overdueOption(
          OverduePolicy.skip,
          'Skip',
          'Advances to the next valid occurrence.',
        ),
        _overdueOption(
          OverduePolicy.prompt,
          'Prompt',
          'Decide at completion time.',
        ),

        const SizedBox(height: 32),
        Row(
          children: [
            const Text(
              'EXCLUSIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addExclusion,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        ..._exclusions.map(
          (e) => Card(
            child: ListTile(
              title: Text(_getRepeatLabel(e.repeatType)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () => setState(() => _exclusions.remove(e)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _overdueOption(OverduePolicy policy, String label, String sub) {
    final selected = _overduePolicy == policy;
    return ListTile(
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppTheme.accentColor(context) : AppColors.textMuted,
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      onTap: () => setState(() => _overduePolicy = policy),
    );
  }

  void _addExclusion() {
    setState(() {
      _exclusions.add(
        SchedulerRule(
          repeatType: RepeatType.daysOfWeek,
          daysOfWeek: ['Sat', 'Sun'],
        ),
      );
    });
  }

  Widget _buildFooter() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _onNext,
            child: Text(
              _currentStep < 2 ? 'Next' : 'Finish',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    final themes = ref.watch(dayThemesProvider);
    if (themes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text(
          'No Day Themes configured.\nCreate themes in Settings → Day Themes.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fire on active Day Theme:',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ...themes.map((theme) {
          final isSelected = _themeId == theme.id;
          return GestureDetector(
            onTap: () => setState(() => _themeId = theme.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentColor(context).withValues(alpha: 0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor(context) : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      theme.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.accentColor(context),
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBlockSelector() {
    final blocks = ref.watch(timeBlocksProvider);
    if (blocks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text(
          'No Time Blocks configured.\nCreate blocks in Settings → Day Themes.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fire when Time Block is active:',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ...blocks.map((block) {
          final isSelected = _blockId == block.id;
          final rangeLabel = block.timeRanges.isNotEmpty
              ? '${block.timeRanges.first.startHour.toString().padLeft(2, '0')}:${block.timeRanges.first.startMinute.toString().padLeft(2, '0')} – ${block.timeRanges.first.endHour.toString().padLeft(2, '0')}:${block.timeRanges.first.endMinute.toString().padLeft(2, '0')}'
              : '';
          return GestureDetector(
            onTap: () => setState(() => _blockId = block.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentColor(context).withValues(alpha: 0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor(context) : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.view_day_rounded, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (rangeLabel.isNotEmpty)
                          Text(
                            rangeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.accentColor(context),
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _onNext() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      final scheduler = Scheduler(
        rules: [
          SchedulerRule(
            repeatType: _selectedType,
            interval: _interval,
            daysOfWeek: _daysOfWeek,
            daysOfMonth: _daysOfMonth,
            themeId: _themeId,
            blockId: _blockId,
            countPerPeriod: _countPerPeriod,
            period: _period,
            startingDayOffset: _startingDayOffset,
            intervalBetweenDays: _intervalBetweenDays,
            linkedItemId: _linkedItemId,
            targetType: _targetType,
            fieldName: _fieldName,
          ),
        ],
        exclusions: _exclusions,
        startDate: _startDate,
        endDate: _endDate,
        maxOccurrences: _maxOccurrences,
        overduePolicy: _overduePolicy,
      );
      Navigator.pop(context, scheduler);
    }
  }

  String _getRepeatLabel(RepeatType type) {
    switch (type) {
      case RepeatType.numberOfDays:
        return 'Every N days';
      case RepeatType.daysOfWeek:
        return 'Days of week';
      case RepeatType.numberOfWeeks:
        return 'Every N weeks';
      case RepeatType.numberOfMonths:
        return 'Every N months';
      case RepeatType.daysOfTheme:
        return 'Themes';
      case RepeatType.daysWithBlock:
        return 'Blocks';
      case RepeatType.daysAfterLastStart:
        return 'Post-start';
      case RepeatType.daysAfterLastEnd:
        return 'Post-completion';
      case RepeatType.numberOfDaysPerPeriod:
        return 'Periodic goal';
      case RepeatType.numberOfHours:
        return 'Every N hours';
      case RepeatType.linkedItemAppears:
        return 'Linked item';
      case RepeatType.nDaysAfterLinkedItem:
        return 'N days post-linked';
      case RepeatType.firstBusinessDayOfMonth:
        return '1st business day';
      case RepeatType.daysAfterReferenceField:
        return 'Days after reference field';
    }
  }
}
