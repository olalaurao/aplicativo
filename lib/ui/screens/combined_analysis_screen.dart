// lib/ui/screens/combined_analysis_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../providers/vault_provider.dart';
import '../../providers/pomodoro_provider.dart';
import '../../providers/google_calendar_provider.dart';
import '../../models/tracker_model.dart';
import '../../models/mood_model.dart';
import '../../models/analysis_model.dart';
import '../../models/pomodoro_session.dart';
import '../../models/journal_entry.dart';
import '../../models/goal_model.dart';
import '../../models/kpi_model.dart';
import '../../services/kpi_engine.dart';
import '../theme.dart';
import '../widgets/quartzo_chart.dart';
import '../widgets/analysis_calendar.dart';
import '../widgets/mood_emoji_timeline.dart';

class CombinedAnalysisScreen extends ConsumerStatefulWidget {
  const CombinedAnalysisScreen({super.key});

  @override
  ConsumerState<CombinedAnalysisScreen> createState() =>
      _CombinedAnalysisScreenState();
}

class _CombinedAnalysisScreenState
    extends ConsumerState<CombinedAnalysisScreen> {
  DateTime _currentMonth = DateTime.now();
  CombinedAnalysis? _currentAnalysis;
  bool _loadedSavedAnalysis = false;
  final List<MetricSource> _activeSources = [];
  final Set<String> _hiddenSourceIds = {};

  @override
  Widget build(BuildContext context) {
    final analyses = ref.watch(combinedAnalysisProvider);

    if (!_loadedSavedAnalysis && analyses.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final saved = analyses.first;
        setState(() {
          _currentAnalysis = saved;
          _activeSources
            ..clear()
            ..addAll(_sourcesForAnalysis(saved));
          _hiddenSourceIds.clear();
          _loadedSavedAnalysis = true;
        });
      });
    } else {
      _loadedSavedAnalysis = true;
    }

    // Prepare data for the chart (last 14 days)
    final visibleSources = _activeSources
        .where((source) => !_hiddenSourceIds.contains(source.id))
        .toList();
    MetricSource? visibleMoodSource;
    for (final source in visibleSources) {
      if (source.type == MetricType.mood) {
        visibleMoodSource = source;
        break;
      }
    }
    final moodTimelinePoints = visibleMoodSource == null
        ? <ChartDataPoint>[]
        : _getMetricData(visibleMoodSource, 14);

    final List<List<ChartDataPoint>> chartSeries = visibleSources
        .map((s) => _getMetricData(s, 14))
        .toList();
    final List<Color> chartColors = visibleSources
        .map((s) => s.color ?? AppTheme.accentColor(context))
        .toList();

    // Prepare data for the calendar
    final calendarData = _getCalendarData();
    final calendarValues = _getCalendarValues();
    final calendarMoodEmojis = _getCalendarMoodEmojis();
    final calendarMoodDetails = _getCalendarMoodDetails();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Correlação Multi-Fonte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_chart_rounded, color: AppTheme.accentColor(context)),
            tooltip: 'Nova Análise',
            onPressed: () => _showAnalysisFormSheet(context, null),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análise de Correlação',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Correlacione múltiplos trackers, hábitos, humor e produtividade para identificar padrões.',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Analysis Profile Selector Card
                    _buildAnalysisSelector(context, analyses),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            if (_currentAnalysis == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Metrics Chips
                      if (_activeSources.isNotEmpty) ...[
                        Text(
                          'Métricas Ativas',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondaryColor(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _activeSources
                              .map((s) => _buildMetricChip(s))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Main Chart
                      Container(
                        height: visibleMoodSource == null ? 300 : 360,
                        decoration: AppTheme.cardDecoration(context),
                        padding: const EdgeInsets.all(20),
                        child: chartSeries.isEmpty || chartSeries.first.isEmpty
                            ? const Center(
                                child: Text(
                                  'Adicione ou selecione métricas para visualizar o gráfico.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            : Column(
                                children: [
                                  Expanded(
                                    child: QuartzoChart(
                                      type:
                                          _currentAnalysis
                                              ?.charts
                                              .firstOrNull
                                              ?.type ??
                                          ChartType.line,
                                      title: 'Tendência (Últimos 14 dias)',
                                      data: chartSeries.first,
                                      multiData: chartSeries,
                                      colors: chartColors,
                                    ),
                                  ),
                                  if (visibleMoodSource != null) ...[
                                    const SizedBox(height: 8),
                                    MoodEmojiTimeline(
                                      points: moodTimelinePoints,
                                      days: 14,
                                    ),
                                  ],
                                ],
                              ),
                      ),

                      const SizedBox(height: 32),

                      Text(
                        'Visualização Mensal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnalysisCalendar(
                        month: _currentMonth,
                        sources: _activeSources,
                        data: calendarData,
                        values: calendarValues,
                        moodEmojis: calendarMoodEmojis,
                        moodDetails: calendarMoodDetails,
                        onMonthChanged: (month) {
                          setState(() => _currentMonth = month);
                        },
                      ),

                      const SizedBox(height: 32),

                      Text(
                        'Correlations and Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildInsightCard(
                        'Coexistence Pattern',
                        _generateInsightText(chartSeries),
                        Icons.auto_awesome_rounded,
                        AppColors.habitPurple,
                      ),
                      const SizedBox(height: 12),
                      _buildInsightCard(
                        'Citrine Tip',
                        'The correlation between sleep, mood, and focus (Pomodoro) is often the most revealing. Try to keep a daily log for perfect analyses.',
                        Icons.lightbulb_outline_rounded,
                        AppColors.warning,
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSelector(
    BuildContext context,
    List<CombinedAnalysis> analyses,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentColor(context).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bubble_chart_rounded,
              color: AppTheme.accentColor(context),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuração de Análise',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                if (analyses.isEmpty)
                  Text(
                    'Nenhuma análise salva',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  )
                else
                  DropdownButtonHideUnderline(
                    child: DropdownButton<CombinedAnalysis>(
                      value:
                          _currentAnalysis != null &&
                              analyses.any((a) => a.id == _currentAnalysis!.id)
                          ? analyses.firstWhere(
                              (a) => a.id == _currentAnalysis!.id,
                            )
                          : null,
                      isDense: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                      ),
                      dropdownColor: AppTheme.surfaceColor(context),
                      hint: Text(
                        'Selecione uma análise...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      items: analyses.map((a) {
                        return DropdownMenuItem<CombinedAnalysis>(
                          value: a,
                          child: Text(
                            a.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _currentAnalysis = val;
                            _activeSources
                              ..clear()
                              ..addAll(_sourcesForAnalysis(val));
                          });
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_currentAnalysis != null) ...[
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 20),
              tooltip: 'Editar Configuração',
              onPressed: () =>
                  _showAnalysisFormSheet(context, _currentAnalysis),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
              tooltip: 'Excluir Análise',
              onPressed: () =>
                  _confirmDeleteAnalysis(context, _currentAnalysis!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentColor(context).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 60,
                color: AppTheme.accentColor(context),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Analysis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a multi-source analysis to compare your habits, trackers, daily mood, and Pomodoro sessions simultaneously.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova Análise Personalizada'),
              style: AppTheme.primaryButtonStyle(AppTheme.accentColor(context)).copyWith(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              onPressed: () => _showAnalysisFormSheet(context, null),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAnalysis(
    BuildContext context,
    CombinedAnalysis analysis,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir análise?'),
        content: Text(
          'Deseja realmente excluir a configuração "${analysis.title}"? Esta ação pode ser desfeita em até 30 dias.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final originalPath = analysis.obsidianPath;
      await ref
          .read(combinedAnalysisProvider.notifier)
          .deleteAnalysis(analysis);
      if (!context.mounted) return;

      setState(() {
        _currentAnalysis = null;
        _activeSources.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Análise "${analysis.title}" excluída'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Desfazer',
            textColor: AppTheme.accentColor(context),
            onPressed: () async {
              await ref
                  .read(vaultProvider.notifier)
                  .restoreObject(analysis, originalPath);
            },
          ),
        ),
      );
    }
  }

  void _showAnalysisFormSheet(
    BuildContext context,
    CombinedAnalysis? analysis,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AnalysisFormSheet(
        analysis: analysis,
        onSaved: (savedAnalysis) {
          setState(() {
            _currentAnalysis = savedAnalysis;
            _activeSources
              ..clear()
              ..addAll(_sourcesForAnalysis(savedAnalysis));
            _hiddenSourceIds.clear();
          });
        },
      ),
    );
  }

  Widget _buildMetricChip(MetricSource source) {
    final selected = !_hiddenSourceIds.contains(source.id);
    return Opacity(
      opacity: selected ? 1 : 0.4,
      child: FilterChip(
        selected: selected,
        onSelected: (value) {
          setState(() {
            if (value) {
              _hiddenSourceIds.remove(source.id);
            } else {
              _hiddenSourceIds.add(source.id);
            }
          });
        },
        avatar: source.type == MetricType.mood
            ? const Text('😊', style: TextStyle(fontSize: 14))
            : Icon(
                Icons.circle,
                color: source.color ?? AppTheme.accentColor(context),
                size: 12,
              ),
        label: Text(
          source.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceVariantColor(context),
        selectedColor: (source.color ?? AppTheme.accentColor(context)).withValues(
          alpha: 0.14,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  List<MetricSource> _sourcesForAnalysis(CombinedAnalysis analysis) {
    return analysis.dataSources.isNotEmpty
        ? analysis.dataSources
        : analysis.charts.expand((chart) => chart.sources).toList();
  }

  String _generateInsightText(List<List<ChartDataPoint>> series) {
    if (series.isEmpty) return 'Adicione métricas para ver os insights.';
    if (series.length < 2) {
      return 'Adicione mais uma métrica para calcularmos a correlação de comportamento entre elas.';
    }
    final a = series[0]
        .where((p) => p.value != null)
        .map((p) => p.value!)
        .toList();
    final b = series[1]
        .where((p) => p.value != null)
        .map((p) => p.value!)
        .toList();
    final correlation = _correlation(a, b);

    if (correlation.abs() < 0.25) {
      return 'Até o momento, não há uma correlação forte detectada entre as duas primeiras métricas configuradas. Continue registrando mais dias para análises precisas.';
    }

    final direction = correlation > 0
        ? 'tendem a subir juntas'
        : 'se movem em direções opostas';
    return 'Padrão Identificado: As duas primeiras métricas $direction (grau de correlação: ${correlation.toStringAsFixed(2)}). Isso sugere uma interdependência direta entre elas.';
  }

  double _correlation(List<double> a, List<double> b) {
    final length = a.length < b.length ? a.length : b.length;
    if (length < 2) return 0;
    final ax = a.take(length).toList();
    final bx = b.take(length).toList();
    final meanA = ax.reduce((x, y) => x + y) / length;
    final meanB = bx.reduce((x, y) => x + y) / length;
    double numerator = 0;
    double denomA = 0;
    double denomB = 0;
    for (var i = 0; i < length; i++) {
      final da = ax[i] - meanA;
      final db = bx[i] - meanB;
      numerator += da * db;
      denomA += da * da;
      denomB += db * db;
    }
    if (denomA == 0 || denomB == 0) return 0;
    return numerator / sqrt(denomA * denomB);
  }

  Map<DateTime, List<MetricSource>> _getCalendarData() {
    final Map<DateTime, List<MetricSource>> calendarData = {};
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final List<MetricSource> daySources = [];

      for (var source in _activeSources) {
        final value = _getValueForDate(source, date);
        if (value != null) {
          daySources.add(source);
        }
      }

      if (daySources.isNotEmpty) {
        calendarData[DateTime(date.year, date.month, date.day)] = daySources;
      }
    }
    return calendarData;
  }

  Map<DateTime, Map<String, double>> _getCalendarValues() {
    final values = <DateTime, Map<String, double>>{};
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dayValues = <String, double>{};

      for (final source in _activeSources) {
        final value = _getValueForDate(source, date);
        if (value != null) dayValues[source.id] = value;
      }

      if (dayValues.isNotEmpty) {
        values[_dateKey(date)] = dayValues;
      }
    }

    return values;
  }

  Map<DateTime, String?> _getCalendarMoodEmojis() {
    final emojis = <DateTime, String?>{};
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final emoji = _getMoodEmojiForDate(date);
      if (emoji != null) emojis[_dateKey(date)] = emoji;
    }

    return emojis;
  }

  Map<DateTime, MoodDefinition?> _getCalendarMoodDetails() {
    final moods = <DateTime, MoodDefinition?>{};
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final mood = _getMoodForDate(date);
      if (mood != null) moods[_dateKey(date)] = mood;
    }

    return moods;
  }

  List<ChartDataPoint> _getMetricData(MetricSource source, int days) {
    final today = DateTime.now();
    final List<ChartDataPoint> points = [];

    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: (days - 1) - i));
      final dateStr = DateFormat('dd/MM').format(date);
      final value = _getValueForDate(source, date);
      // Para fontes de mood, incluir o emoji do humor dominante no ponto
      String? emoji;
      if (source.type == MetricType.mood && value != null) {
        emoji = _getMoodEmojiForDate(date);
      }
      points.add(ChartDataPoint(label: dateStr, value: value, emoji: emoji));
    }
    return points;
  }

  /// Retorna o emoji do mood mais frequente (ou único) numa data
  String? _getMoodEmojiForDate(DateTime date) {
    return _getMoodForDate(date)?.emoji;
  }

  MoodDefinition? _getMoodForDate(DateTime date) {
    final entries = ref.read(allEntriesProvider);
    final moods = ref.read(moodsProvider);

    // F2.14: Collect all mood entries for the day from moodEntries array
    final allMoodEntries = <MoodEntry>[];
    for (final entry in entries) {
      if (entry.date.year == date.year &&
          entry.date.month == date.month &&
          entry.date.day == date.day) {
        // Prefer moodEntries array over legacy moodSlug
        if (entry.moodEntries.isNotEmpty) {
          allMoodEntries.addAll(entry.moodEntries);
        } else if (entry.moodSlug != null) {
          // Legacy fallback: convert moodSlug to MoodEntry
          allMoodEntries.add(MoodEntry(
            moodSlug: entry.moodSlug!,
            timestamp: entry.date,
          ));
        }
      }
    }

    if (allMoodEntries.isEmpty) return null;

    // Get the most recent mood entry for the day
    allMoodEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recentEntry = allMoodEntries.first;
    
    return moods
        .where((m) => m.id == recentEntry.moodSlug || m.slug == recentEntry.moodSlug)
        .firstOrNull;
  }

  DateTime _dateKey(DateTime date) => DateTime(date.year, date.month, date.day);

  double? _getValueForDate(MetricSource source, DateTime date) {
    switch (source.type) {
      case MetricType.mood:
        return _getMoodValueForDate(date);
      case MetricType.habit:
        return _getHabitValueForDate(source.id, date);
      case MetricType.trackerField:
        return _getTrackerValueForDate(source.id, source.fieldId!, date);
      case MetricType.trackerScore:
        return _getTrackerScoreForDate(source.id, date);
      case MetricType.googleCalendar:
        return _getGoogleEventValueForDate(date);
      case MetricType.pomodoro:
        return _getPomodoroValueForDate(date);
      case MetricType.kpi:
        return _getKPIValueForDate(source.id, date);
    }
  }

  double? _getTrackerScoreForDate(String trackerId, DateTime date) {
    final records = ref.read(trackingRecordsProvider);
    final count = records
        .where(
          (r) =>
              _recordBelongsToTracker(r, trackerId) &&
              r.date.year == date.year &&
              r.date.month == date.month &&
              r.date.day == date.day,
        )
        .length
        .toDouble();
    return count == 0 ? null : count;
  }

  double? _getMoodValueForDate(DateTime date) {
    final entries = ref.read(allEntriesProvider);
    final moods = ref.read(moodsProvider);

    // F2.14: Collect all mood entries for the day from moodEntries array
    final allMoodEntries = <MoodEntry>[];
    for (final entry in entries) {
      if (entry.date.year == date.year &&
          entry.date.month == date.month &&
          entry.date.day == date.day) {
        // Prefer moodEntries array over legacy moodSlug
        if (entry.moodEntries.isNotEmpty) {
          allMoodEntries.addAll(entry.moodEntries);
        } else if (entry.moodSlug != null) {
          // Legacy fallback: convert moodSlug to MoodEntry
          allMoodEntries.add(MoodEntry(
            moodSlug: entry.moodSlug!,
            timestamp: entry.date,
          ));
        }
      }
    }

    if (allMoodEntries.isEmpty) return null;

    // Average all mood values for the day
    final values = allMoodEntries
        .map((moodEntry) {
          final mood = moods
              .where((m) => m.id == moodEntry.moodSlug || m.slug == moodEntry.moodSlug)
              .firstOrNull;
          return mood?.numericValue.toDouble();
        })
        .whereType<double>()
        .toList();

    if (values.isNotEmpty) {
      return values.reduce((a, b) => a + b) / values.length;
    }
    return null;
  }

  double? _getHabitValueForDate(String habitId, DateTime date) {
    final habits = ref.read(habitsProvider);
    final habit = habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) return null;

    final record = habit.completionHistory
        .where(
          (c) =>
              c.date.year == date.year &&
              c.date.month == date.month &&
              c.date.day == date.day,
        )
        .firstOrNull;
    if (record == null) return null;
    return record.successful || record.completions > 0 ? 1.0 : 0.0;
  }

  double? _getTrackerValueForDate(
    String trackerId,
    String fieldId,
    DateTime date,
  ) {
    final records = ref.read(trackingRecordsProvider);
    final dayRecords = records
        .where(
          (r) =>
              _recordBelongsToTracker(r, trackerId) &&
              r.date.year == date.year &&
              r.date.month == date.month &&
              r.date.day == date.day,
        )
        .toList();
    if (dayRecords.isEmpty) return null;

    var total = 0.0;
    var foundValue = false;
    for (final record in dayRecords) {
      final val = record.fieldValues[fieldId];
      if (val is num) {
        total += val.toDouble();
        foundValue = true;
      } else if (val is bool) {
        total += val ? 1.0 : 0.0;
        foundValue = true;
      } else if (val is List) {
        total += val.length.toDouble();
        foundValue = true;
      } else if (val is String) {
        final parsed = double.tryParse(val);
        if (parsed != null) {
          total += parsed;
          foundValue = true;
        }
      }
    }
    return foundValue ? total : null;
  }

  bool _recordBelongsToTracker(TrackingRecord record, String trackerId) {
    if (record.trackerId == trackerId) return true;
    final tracker = ref
        .read(trackersProvider)
        .where((t) => t.id == trackerId || t.slug == trackerId)
        .firstOrNull;
    if (tracker == null) return false;
    return record.trackerId == tracker.slug ||
        record.trackerId == tracker.title ||
        record.trackerId == tracker.id;
  }

  double _getGoogleEventValueForDate(DateTime date) {
    final events = ref.watch(googleCalendarEventsProvider(date));
    return events.maybeWhen(
      data: (list) => list.length.toDouble(),
      orElse: () => 0,
    );
  }

  double? _getPomodoroValueForDate(DateTime date) {
    try {
      final pState = ref.read(pomodoroProvider);
      final sessions = pState.history.where(
        (s) =>
            s.date.year == date.year &&
            s.date.month == date.month &&
            s.date.day == date.day &&
            s.state == PomodoroSessionState.completed,
      );
      if (sessions.isEmpty) return null;
      return sessions.fold<double>(0, (sum, s) => sum + s.minutesWorked);
    } catch (_) {
      return null;
    }
  }

  double? _getKPIValueForDate(String kpiId, DateTime date) {
    try {
      final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
      final goals = allObjects.whereType<Goal>().toList();
      
      for (final goal in goals) {
        final kpi = goal.kpis.cast<KPI?>().firstWhere(
          (k) => k != null && k.id == kpiId,
          orElse: () => null,
        );
        if (kpi != null) {
          // Calculate KPI value for the specific date
          // Since KPIEngine calculates over a range, we'll use the date as both start and end
          final value = KPIEngine.calculateKPIValue(
            kpi: kpi,
            habits: ref.read(habitsProvider),
            trackerRecords: ref.read(trackingRecordsProvider),
            entries: ref.read(allEntriesProvider),
            moods: ref.read(moodsProvider),
            notes: ref.read(notesProvider),
            tasks: ref.read(tasksProvider),
          );
          return value;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildInsightCard(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisFormSheet extends ConsumerStatefulWidget {
  final CombinedAnalysis? analysis;
  final Function(CombinedAnalysis) onSaved;

  const _AnalysisFormSheet({this.analysis, required this.onSaved});

  @override
  ConsumerState<_AnalysisFormSheet> createState() => _AnalysisFormSheetState();
}

class _AnalysisFormSheetState extends ConsumerState<_AnalysisFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final List<MetricSource> _tempSources = [];
  late ChartType _selectedChartType;

  List<Color> get _colorPresets => [
    AppTheme.accentColor(context),
    AppColors.secondary,
    AppColors.success,
    AppColors.warning,
    AppColors.info,
    AppColors.habitPurple,
    AppColors.habitPink,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.analysis?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.analysis?.description ?? '',
    );
    _selectedChartType =
        widget.analysis?.charts.firstOrNull?.type ?? ChartType.line;
    if (widget.analysis != null &&
        (widget.analysis!.dataSources.isNotEmpty ||
            widget.analysis!.charts.isNotEmpty)) {
      _tempSources.addAll(
        widget.analysis!.dataSources.isNotEmpty
            ? widget.analysis!.dataSources
            : widget.analysis!.charts.expand((chart) => chart.sources),
      );
    } else {
      // Default initial source
      _tempSources.add(
        MetricSource(
          type: MetricType.mood,
          id: 'mood',
          label: 'Meu Humor',
          color: AppTheme.accentColor(context),
          dimension: 'pleasantness',
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: AppTheme.sheetDecoration(context),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.analysis == null ? 'Nova Análise' : 'Editar Análise',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Form inputs
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Título da Análise',
                        hintText: 'Ex: Humor vs Foco',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira um título';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText:
                            'Ex: Entenda como sessões de Pomodoro impactam seu humor',
                      ),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<ChartType>(
                      initialValue: _selectedChartType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de gráfico',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ChartType.line,
                          child: Text('Linha multi-série'),
                        ),
                        DropdownMenuItem(
                          value: ChartType.bar,
                          child: Text('Barras'),
                        ),
                        DropdownMenuItem(
                          value: ChartType.pie,
                          child: Text('Pizza/donut'),
                        ),
                        DropdownMenuItem(
                          value: ChartType.heatmap,
                          child: Text('Calendar heatmap'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedChartType = value);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Active Sources Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Métricas Selecionadas',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        Text(
                          'Arraste para reordenar',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_tempSources.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Nenhuma métrica adicionada.',
                            style: TextStyle(
                              color: AppTheme.textMutedColor(context),
                            ),
                          ),
                        ),
                      )
                    else
                      Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tempSources.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              final item = _tempSources.removeAt(oldIndex);
                              _tempSources.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final source = _tempSources[index];
                            final uniqueKey =
                                '${source.id}_${source.fieldId ?? ''}_$index';
                            return _buildSourceCard(source, index, uniqueKey);
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Add Metric Trigger button
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Adicionar Fonte de Dados'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accentColor(context),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: AppTheme.accentColor(context).withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        onPressed: () => _showPicker(context),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppTheme.primaryButtonStyle(AppTheme.accentColor(context)),
                onPressed: _saveForm,
                child: const Text('Salvar Configuração'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(MetricSource source, int index, String uniqueKey) {
    return Container(
      key: ValueKey(uniqueKey),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          const Padding(
            padding: EdgeInsets.only(top: 8, right: 8),
            child: Icon(Icons.drag_handle_rounded, color: AppColors.textMuted),
          ),

          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (source.color ?? AppTheme.accentColor(context)).withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForType(source.type),
                        color: source.color ?? AppTheme.accentColor(context),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTypeLabel(source.type),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Editable Display Name Label input
                TextFormField(
                  initialValue: source.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Rótulo de Exibição',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (val) {
                    _tempSources[index] = MetricSource(
                      type: source.type,
                      id: source.id,
                      label: val,
                      fieldId: source.fieldId,
                      color: source.color,
                      dimension: source.dimension,
                      axis: source.axis,
                      showEmojiMarkers: source.showEmojiMarkers,
                      valueMapping: source.valueMapping,
                    );
                  },
                ),
                if (source.type == MetricType.mood) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: source.dimension,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Dimensão do Humor (Requerido)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    dropdownColor: AppTheme.surfaceColor(context),
                    items: const [
                      DropdownMenuItem(
                        value: 'pleasantness',
                        child: Text('Agradabilidade (Pleasantness)'),
                      ),
                      DropdownMenuItem(
                        value: 'energy',
                        child: Text('Energia (Energy)'),
                      ),
                    ],
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Por favor, selecione a dimensão do humor';
                      }
                      return null;
                    },
                    onChanged: (val) {
                      setState(() {
                        _tempSources[index] = MetricSource(
                          type: source.type,
                          id: source.id,
                          label: source.label,
                          fieldId: source.fieldId,
                          color: source.color,
                          dimension: val,
                          axis: source.axis,
                          showEmojiMarkers: source.showEmojiMarkers,
                          valueMapping: source.valueMapping,
                        );
                      });
                    },
                  ),
                ],
                const SizedBox(height: 10),

                // Color Selection Strip
                Text(
                  'Cor da métrica',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: _colorPresets.map((color) {
                    final isSelected =
                        source.color?.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _tempSources[index] = MetricSource(
                            type: source.type,
                            id: source.id,
                            label: source.label,
                            fieldId: source.fieldId,
                            color: color,
                            dimension: source.dimension,
                            axis: source.axis,
                            showEmojiMarkers: source.showEmojiMarkers,
                            valueMapping: source.valueMapping,
                          );
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.textPrimaryColor(context)
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Delete Button
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _tempSources.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final habits = ref.read(habitsProvider);
    final trackers = ref.read(trackersProvider);
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final goals = allObjects.whereType<Goal>().toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: AppTheme.sheetDecoration(ctx),
        padding: const EdgeInsets.all(20),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Adicionar Métrica',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryColor(ctx),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mood
              _buildPickerItem(
                ctx,
                icon: Icons.face_rounded,
                color: AppTheme.accentColor(context),
                title: 'Average Mood',
                subtitle: 'Daily mood based on Journal',
                onTap: () {
                  _onSourceSelected(
                    MetricSource(
                      type: MetricType.mood,
                      id: 'mood',
                      label: 'Mood',
                      color: AppTheme.accentColor(context),
                      dimension: 'pleasantness',
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),

              // Pomodoro
              _buildPickerItem(
                ctx,
                icon: Icons.timer_outlined,
                color: AppColors.habitPurple,
                title: 'Focus Minutes (Pomodoro)',
                subtitle: 'Daily focused time on Pomodoro',
                onTap: () {
                  _onSourceSelected(
                    MetricSource(
                      type: MetricType.pomodoro,
                      id: 'pomodoro',
                      label: 'Focus (Pomodoro)',
                      color: AppColors.habitPurple,
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),

              // Habits Header
              if (habits.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'HÁBITOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                ...habits.map(
                  (h) => _buildPickerItem(
                    ctx,
                    icon: Icons.repeat_rounded,
                    color: AppColors.habitGreen,
                    title: h.displayTitle,
                    subtitle: 'Frequência de conclusão do hábito',
                    onTap: () {
                      _onSourceSelected(
                        MetricSource(
                          type: MetricType.habit,
                          id: h.id,
                          label: h.displayTitle,
                          color: AppColors.habitGreen,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],

              // Trackers Header
              if (trackers.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'TRACKERS (SCORE TOTAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                ...trackers.map((t) {
                  final trackerColor = _parseColor(t.color);
                  return _buildPickerItem(
                    ctx,
                    icon: Icons.analytics_rounded,
                    color: trackerColor,
                    title: 'Total: ${t.title}',
                    subtitle: 'Number of daily records',
                    onTap: () {
                      _onSourceSelected(
                        MetricSource(
                          type: MetricType.trackerScore,
                          id: t.id,
                          label: 'Records: ${t.title}',
                          color: trackerColor,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'CAMPOS DE TRACKERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                ...trackers.expand((t) {
                  final trackerColor = _parseColor(t.color);
                  return t.sections.expand(
                    (s) => s.inputFields
                        .where(
                          (f) =>
                              f.type == InputFieldType.quantity ||
                              f.type == InputFieldType.range ||
                              f.type == InputFieldType.mood ||
                              f.type == InputFieldType.duration ||
                              f.type == InputFieldType.checkbox ||
                              f.type == InputFieldType.checklist,
                        )
                        .map(
                          (f) => _buildPickerItem(
                            ctx,
                            icon: _getIconForField(f.type),
                            color: trackerColor,
                            title: '${t.title}: ${f.title}',
                            subtitle: 'Valores numéricos de ${f.title}',
                            onTap: () {
                              _onSourceSelected(
                                MetricSource(
                                  type: MetricType.trackerField,
                                  id: t.id,
                                  label: '${t.title}: ${f.title}',
                                  fieldId: f.id,
                                  color: trackerColor,
                                ),
                              );
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                  );
                }),
              ],

              // Google Calendar
              _buildPickerItem(
                ctx,
                icon: Icons.calendar_today_rounded,
                color: AppColors.info,
                title: 'Eventos (Google Calendar)',
                subtitle: 'Quantidade de compromissos externos',
                onTap: () {
                  _onSourceSelected(
                    MetricSource(
                      type: MetricType.googleCalendar,
                      id: 'google',
                      label: 'Compromissos',
                      color: AppColors.info,
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),

              // KPIs Header
              if (goals.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'KPIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                ...goals.expand((g) => g.kpis.map(
                  (kpi) => _buildPickerItem(
                    ctx,
                    icon: Icons.show_chart_rounded,
                    color: AppColors.warning,
                    title: kpi.title,
                    subtitle: 'KPI de ${g.title}',
                    onTap: () {
                      _onSourceSelected(
                        MetricSource(
                          type: MetricType.kpi,
                          id: kpi.id,
                          label: kpi.title,
                          color: AppColors.warning,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onSourceSelected(MetricSource source) {
    setState(() {
      _tempSources.add(source);
    });
  }

  Widget _buildPickerItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppTheme.textPrimaryColor(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context)),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tempSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos uma métrica')),
      );
      return;
    }

    final analysis = CombinedAnalysis(
      id: widget.analysis?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : 'Análise de métricas combinadas',
      createdAt: widget.analysis?.createdAt,
      updatedAt: DateTime.now(),
      obsidianPath: widget.analysis?.obsidianPath ?? '',
      dataSources: List.from(_tempSources),
      categories: const ['[[analyses]]'],
      charts: [
        AnalysisChart(
          title: 'Gráfico Comparativo',
          type: _selectedChartType,
          sources: List.from(_tempSources),
        ),
      ],
    );

    try {
      if (widget.analysis == null) {
        await ref.read(combinedAnalysisProvider.notifier).addAnalysis(analysis);
      } else {
        await ref
            .read(combinedAnalysisProvider.notifier)
            .updateAnalysis(analysis);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar análise: $e')));
      return;
    }

    widget.onSaved(analysis);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuração de análise salva com sucesso'),
      ),
    );
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return AppTheme.accentColor(context);
    try {
      return Color(int.parse(colorStr.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppTheme.accentColor(context);
    }
  }

  IconData _getIconForType(MetricType type) {
    switch (type) {
      case MetricType.mood:
        return Icons.face_rounded;
      case MetricType.habit:
        return Icons.repeat_rounded;
      case MetricType.trackerField:
        return Icons.tune_rounded;
      case MetricType.trackerScore:
        return Icons.analytics_outlined;
      case MetricType.googleCalendar:
        return Icons.calendar_today_rounded;
      case MetricType.pomodoro:
        return Icons.timer_outlined;
      case MetricType.kpi:
        return Icons.show_chart_rounded;
    }
  }

  String _getTypeLabel(MetricType type) {
    switch (type) {
      case MetricType.mood:
        return 'Humor';
      case MetricType.habit:
        return 'Hábito';
      case MetricType.trackerField:
        return 'Campo de Tracker';
      case MetricType.trackerScore:
        return 'Score de Tracker';
      case MetricType.googleCalendar:
        return 'Google Calendar';
      case MetricType.pomodoro:
        return 'Foco (Pomodoro)';
      case MetricType.kpi:
        return 'KPI';
    }
  }

  IconData _getIconForField(InputFieldType type) {
    switch (type) {
      case InputFieldType.mood:
        return Icons.face_rounded;
      case InputFieldType.duration:
        return Icons.timer_outlined;
      case InputFieldType.range:
        return Icons.linear_scale_rounded;
      case InputFieldType.quantity:
        return Icons.analytics_outlined;
      case InputFieldType.checkbox:
        return Icons.check_box_rounded;
      case InputFieldType.checklist:
        return Icons.checklist_rounded;
      default:
        return Icons.short_text_rounded;
    }
  }
}
