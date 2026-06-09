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
import '../theme.dart';
import '../widgets/citrine_chart.dart';
import '../widgets/analysis_calendar.dart';

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
          _loadedSavedAnalysis = true;
        });
      });
    } else {
      _loadedSavedAnalysis = true;
    }

    // Prepare data for the chart (last 14 days)
    final List<List<ChartDataPoint>> chartSeries = _activeSources
        .map((s) => _getMetricData(s, 14))
        .toList();
    final List<Color> chartColors = _activeSources
        .map((s) => s.color ?? AppColors.primary)
        .toList();

    // Prepare data for the calendar
    final calendarData = _getCalendarData();

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
            icon: const Icon(Icons.add_chart_rounded, color: AppColors.primary),
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
                        height: 300,
                        decoration: AppTheme.cardDecoration(context),
                        padding: const EdgeInsets.all(20),
                        child: chartSeries.isEmpty || chartSeries.first.isEmpty
                            ? const Center(
                                child: Text(
                                  'Adicione ou selecione métricas para visualizar o gráfico.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            : CitrineChart(
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

                      const SizedBox(height: 32),

                      // Monthly Calendar
                      Text(
                        'Visualização Mensal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            tooltip: 'Mês anterior',
                            onPressed: () => setState(() {
                              _currentMonth = DateTime(
                                _currentMonth.year,
                                _currentMonth.month - 1,
                              );
                            }),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Text(
                            DateFormat(
                              'MMMM yyyy',
                              'pt_BR',
                            ).format(_currentMonth),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Próximo mês',
                            onPressed: () => setState(() {
                              _currentMonth = DateTime(
                                _currentMonth.year,
                                _currentMonth.month + 1,
                              );
                            }),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AnalysisCalendar(
                        month: _currentMonth,
                        sources: _activeSources,
                        data: calendarData,
                      ),

                      const SizedBox(height: 32),

                      Text(
                        'Correlações e Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildInsightCard(
                        'Padrão de Coexistência',
                        _generateInsightText(chartSeries),
                        Icons.auto_awesome_rounded,
                        AppColors.habitPurple,
                      ),
                      const SizedBox(height: 12),
                      _buildInsightCard(
                        'Dica Citrine',
                        'A correlação entre sono, humor e foco (Pomodoro) é frequentemente a mais reveladora. Tente manter o registro diário para análises perfeitas.',
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
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bubble_chart_rounded,
              color: AppColors.primary,
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
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_outlined,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma Análise Ativa',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie uma análise multi-fonte para comparar simultaneamente seus hábitos, trackers, humor diário e sessões de Pomodoro.',
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
              style: AppTheme.primaryButtonStyle.copyWith(
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
            textColor: AppColors.accent,
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
          });
        },
      ),
    );
  }

  Widget _buildMetricChip(MetricSource source) {
    return Chip(
      avatar: Icon(
        Icons.circle,
        color: source.color ?? AppColors.primary,
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
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final entries = ref.read(allEntriesProvider);
    final moods = ref.read(moodsProvider);

    final dayEntries = entries
        .where(
          (e) =>
              e.date.year == date.year &&
              e.date.month == date.month &&
              e.date.day == date.day &&
              e.moodSlug != null,
        )
        .toList();

    if (dayEntries.isEmpty) return null;

    // Pegar o mood mais frequente no dia
    final moodCounts = <String, int>{};
    for (final entry in dayEntries) {
      final slug = entry.moodSlug!;
      moodCounts[slug] = (moodCounts[slug] ?? 0) + 1;
    }
    final dominantSlug = moodCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return moods
        .where((m) => m.id == dominantSlug || m.slug == dominantSlug)
        .firstOrNull
        ?.emoji;
  }


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

    final dayEntries = entries
        .where(
          (e) =>
              e.date.year == date.year &&
              e.date.month == date.month &&
              e.date.day == date.day,
        )
        .where((e) => e.moodSlug != null)
        .toList();

    if (dayEntries.isNotEmpty) {
      final values = dayEntries
          .map(
            (entry) => moods.where((m) => m.id == entry.moodSlug).firstOrNull,
          )
          .whereType<MoodDefinition>()
          .map((mood) => mood.numericValue.toDouble())
          .toList();
      if (values.isNotEmpty) {
        return values.reduce((a, b) => a + b) / values.length;
      }
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
            s.startTime.year == date.year &&
            s.startTime.month == date.month &&
            s.startTime.day == date.day &&
            s.completed,
      );
      if (sessions.isEmpty) return null;
      return sessions.fold<double>(0, (sum, s) => sum + s.duration.inMinutes);
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

  final List<Color> _colorPresets = [
    AppColors.primary,
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
          color: AppColors.primary,
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
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.3),
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
                style: AppTheme.primaryButtonStyle,
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
                        color: (source.color ?? AppColors.primary).withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForType(source.type),
                        color: source.color ?? AppColors.primary,
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
                    );
                  },
                ),
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
                color: AppColors.primary,
                title: 'Média de Humor',
                subtitle: 'Humor diário baseado no Journal',
                onTap: () {
                  _onSourceSelected(
                    MetricSource(
                      type: MetricType.mood,
                      id: 'mood',
                      label: 'Humor',
                      color: AppColors.primary,
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
                title: 'Minutos de Foco (Pomodoro)',
                subtitle: 'Tempo diário focado no Pomodoro',
                onTap: () {
                  _onSourceSelected(
                    MetricSource(
                      type: MetricType.pomodoro,
                      id: 'pomodoro',
                      label: 'Foco (Pomodoro)',
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
                    subtitle: 'Quantidade de registros diários',
                    onTap: () {
                      _onSourceSelected(
                        MetricSource(
                          type: MetricType.trackerScore,
                          id: t.id,
                          label: 'Registros: ${t.title}',
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
    if (colorStr == null || colorStr.isEmpty) return AppColors.primary;
    try {
      return Color(int.parse(colorStr.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
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
