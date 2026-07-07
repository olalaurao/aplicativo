import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/analysis_model.dart';
import '../../models/mood_model.dart';
import '../theme.dart';

class AnalysisCalendar extends StatelessWidget {
  final DateTime month;
  final List<MetricSource> sources;
  final Map<DateTime, List<MetricSource>> data;
  final Map<DateTime, Map<String, double>> values;
  final Map<DateTime, String?> moodEmojis;
  final Map<DateTime, MoodDefinition?> moodDetails;
  final ValueChanged<DateTime>? onMonthChanged;

  const AnalysisCalendar({
    super.key,
    required this.month,
    required this.sources,
    required this.data,
    required this.values,
    required this.moodEmojis,
    required this.moodDetails,
    this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = (firstDay.weekday - 1) % 7;
    final primarySource = sources
        .where((source) => source.type != MetricType.mood)
        .firstOrNull;
    final maxPrimaryValue = _maxValueForSource(primarySource);

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 10),
          _buildWeekdayHeader(context),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.86,
            ),
            itemCount: daysInMonth + firstWeekday,
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox.shrink();

              final day = index - firstWeekday + 1;
              final date = DateTime(month.year, month.month, day);
              final key = _dateKey(date);
              final dayData = data[key] ?? const [];
              final dayValues = values[key] ?? const {};

              return _CalendarDayCell(
                date: date,
                sources: dayData,
                sourceValues: dayValues,
                moodEmoji: moodEmojis[key],
                primarySource: primarySource,
                maxPrimaryValue: maxPrimaryValue,
                onTap: () => _showDaySummarySheet(
                  context,
                  date,
                  dayData,
                  dayValues,
                  moodEmojis[key],
                  moodDetails[key],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: onMonthChanged == null
              ? null
              : () => onMonthChanged!(DateTime(month.year, month.month - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: onMonthChanged == null
              ? null
              : () => onMonthChanged!(DateTime(month.year, month.month + 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMutedColor(context),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  double _maxValueForSource(MetricSource? source) {
    if (source == null) return 0;
    var maxValue = 0.0;
    for (final dayValues in values.values) {
      final value = dayValues[source.id];
      if (value != null && value > maxValue) maxValue = value;
    }
    return maxValue;
  }

  void _showDaySummarySheet(
    BuildContext context,
    DateTime date,
    List<MetricSource> daySources,
    Map<String, double> dayValues,
    String? moodEmoji,
    MoodDefinition? mood,
  ) {
    final hasData = daySources.isNotEmpty || mood != null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.45,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    DateFormat('EEEE, MMMM d').format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!hasData)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No data recorded for this day.',
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (mood != null)
                      _MoodSummaryRow(mood: mood, fallbackEmoji: moodEmoji),
                    if (mood != null && daySources.isNotEmpty)
                      const SizedBox(height: 16),
                    for (final source in daySources)
                      _MetricValueRow(
                        source: source,
                        value: dayValues[source.id],
                      ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push(
                          '/planner/day/${DateFormat('yyyy-MM-dd').format(date)}',
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('View entries for this day'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  DateTime _dateKey(DateTime date) => DateTime(date.year, date.month, date.day);
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final List<MetricSource> sources;
  final Map<String, double> sourceValues;
  final String? moodEmoji;
  final MetricSource? primarySource;
  final double maxPrimaryValue;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.date,
    required this.sources,
    required this.sourceValues,
    required this.moodEmoji,
    required this.primarySource,
    required this.maxPrimaryValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final dateKey = DateTime(date.year, date.month, date.day);
    final isToday = dateKey == todayKey;
    final isFuture = dateKey.isAfter(todayKey);
    final primaryColor = primarySource?.color ?? AppTheme.accentColor(context);
    final primaryValue = primarySource == null
        ? null
        : sourceValues[primarySource!.id];
    final heatAlpha = primaryValue == null || maxPrimaryValue <= 0
        ? 0.0
        : max(0.03, (primaryValue / maxPrimaryValue).clamp(0.0, 1.0) * 0.12);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isToday
              ? AppTheme.accentColor(context).withValues(alpha: 0.10)
              : heatAlpha > 0
              ? primaryColor.withValues(alpha: heatAlpha)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? AppTheme.accentColor(context)
                : AppTheme.dividerColor(context).withValues(alpha: 0.25),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        child: Column(
          children: [
            Text(
              '${date.day}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isToday
                    ? AppTheme.accentColor(context)
                    : isFuture
                    ? AppTheme.textMutedColor(context).withValues(alpha: 0.4)
                    : AppTheme.textSecondaryColor(context),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  moodEmoji ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            _DotsRow(sources: sources, values: sourceValues),
          ],
        ),
      ),
    );
  }
}

class _DotsRow extends StatelessWidget {
  final List<MetricSource> sources;
  final Map<String, double> values;

  const _DotsRow({required this.sources, required this.values});

  @override
  Widget build(BuildContext context) {
    final visibleSources = sources.take(4).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final source in visibleSources) ...[
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: (source.color ?? AppTheme.accentColor(context)).withValues(
                alpha: _dotAlpha(values[source.id]),
              ),
              shape: BoxShape.circle,
            ),
          ),
        ],
        if (sources.length > 4)
          Text(
            '+',
            style: TextStyle(
              color: AppTheme.textMutedColor(context),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  double _dotAlpha(double? value) {
    if (value == null) return 0.8;
    if (value <= 1) return value.clamp(0.35, 1.0);
    return (0.35 + (value.clamp(0.0, 10.0) / 10.0) * 0.65).clamp(0.35, 1.0);
  }
}

class _MoodSummaryRow extends StatelessWidget {
  final MoodDefinition mood;
  final String? fallbackEmoji;

  const _MoodSummaryRow({required this.mood, this.fallbackEmoji});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(fallbackEmoji ?? mood.emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mood.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pleasantness ${mood.pleasantness} · Energy ${mood.energy}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricValueRow extends StatelessWidget {
  final MetricSource source;
  final double? value;

  const _MetricValueRow({required this.source, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: source.color ?? AppTheme.accentColor(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatValue(value, source.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double? value, MetricType type) {
    if (value == null) return '--';
    if (type == MetricType.habit) return value > 0 ? 'Done' : 'Not done';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
