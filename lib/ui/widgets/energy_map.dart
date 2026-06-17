// lib/ui/widgets/energy_map.dart
//
// Exibe um mapa de energia diária gerado a partir de JournalEntries e Notes
// com `category: energy`. Calcula o nível médio de humor/energia por hora
// do dia (últimos 30 dias) e renderiza uma visualização horizontal de blocos
// coloridos 6h–23h.
//
// Uso:
//   EnergyMap()  — widget standalone, lê dados via Riverpod
//   EnergyMap(compact: true) — versão compacta para o dashboard

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/journal_entry.dart';
import '../../models/note_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';

// ─── Provider derivado ────────────────────────────────────────────────────────

/// Retorna [_HourEnergy] para cada hora de 6 a 23, calculado dos últimos 30 dias
final energyMapProvider = Provider<List<_HourEnergy>>((ref) {
  final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
  final moods = ref.watch(moodsProvider);

  // Field Notes com category: energy contêm anotações livres sobre energia
  // — extraímos o horário de criação e usamos o mood como proxy numérico.
  final energyNotes = allObjects
      .whereType<Note>()
      .where((n) => n.categories.any((c) => c.toLowerCase() == 'energy'))
      .toList();

  // Journal entries dos últimos 30 dias com moodSlug preenchido
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final entries = allObjects
      .whereType<JournalEntry>()
      .where((e) => e.date.isAfter(cutoff) && e.moodSlug != null)
      .toList();

  // Mapeia moodSlug → numericValue
  double? _moodValue(String? slug) {
    if (slug == null) return null;
    return moods
        .where((m) => m.id == slug || m.slug == slug)
        .firstOrNull
        ?.numericValue
        .toDouble();
  }

  // Acumular somas por hora (0–23)
  final Map<int, List<double>> hourValues = {};

  // De journal entries
  for (final entry in entries) {
    final hour = entry.date.hour;
    final value = _moodValue(entry.moodSlug);
    if (value != null) {
      hourValues.putIfAbsent(hour, () => []).add(value);
    }
  }

  // De field notes de energia (hora da criação = hora da anotação)
  for (final note in energyNotes) {
    final hour = note.createdAt.hour;
    // Tenta extrair nível numérico do título ("Energia: 4", "energy: 3", etc.)
    final match = RegExp(
      r'(?:energia|energy)[:\s]+(\d)',
      caseSensitive: false,
    ).firstMatch(note.title + ' ' + note.body);
    final value = match != null
        ? double.tryParse(match.group(1) ?? '')
        : null;
    if (value != null) {
      hourValues.putIfAbsent(hour, () => []).add(value);
    }
  }

  // Gera resultado para horas 6–23
  return List.generate(18, (i) {
    final hour = i + 6;
    final values = hourValues[hour] ?? [];
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    return _HourEnergy(hour: hour, avgEnergy: avg, sampleCount: values.length);
  });
});

// ─── Modelo interno ───────────────────────────────────────────────────────────

class _HourEnergy {
  final int hour;
  final double? avgEnergy; // 1–5 (escala do mood)
  final int sampleCount;

  const _HourEnergy({
    required this.hour,
    required this.avgEnergy,
    required this.sampleCount,
  });

  /// 0.0–1.0 normalizado para a escala 1–5
  double get normalized => avgEnergy == null ? 0 : ((avgEnergy! - 1) / 4).clamp(0.0, 1.0);
}

// ─── Widget principal ─────────────────────────────────────────────────────────

class EnergyMap extends ConsumerWidget {
  final bool compact;

  const EnergyMap({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hourData = ref.watch(energyMapProvider);
    final hasData = hourData.any((h) => h.avgEnergy != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Energy Map',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Últimos 30 dias',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        if (!hasData)
          _buildEmptyState(context)
        else
          _buildMap(context, hourData),
        if (!compact && hasData)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildPeakHintRow(hourData),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(
            Icons.bolt_outlined,
            size: 20,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Adicione notas com category: energy ou registre seu humor diário para ver seu mapa de energia.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, List<_HourEnergy> data) {
    return SizedBox(
      height: compact ? 48 : 72,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth =
              (constraints.maxWidth - (data.length - 1) * 3) / data.length;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < data.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                _EnergyBar(
                  hourEnergy: data[i],
                  width: barWidth.clamp(4.0, 40.0),
                  maxHeight: compact ? 48 : 72,
                  showLabel: !compact && i % 3 == 0,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeakHintRow(List<_HourEnergy> data) {
    // Encontrar horários de pico (top 3 com dados)
    final withData = data.where((h) => h.avgEnergy != null).toList()
      ..sort((a, b) => (b.avgEnergy!).compareTo(a.avgEnergy!));

    if (withData.isEmpty) return const SizedBox.shrink();

    final peaks = withData.take(3).toList();
    return Wrap(
      spacing: 8,
      children: peaks.map((h) {
        final label = DateFormat('HH:mm').format(
          DateTime(2000, 1, 1, h.hour),
        );
        return Chip(
          avatar: const Icon(Icons.bolt_rounded, size: 14, color: AppColors.warning),
          label: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.warning.withValues(alpha: 0.1),
          side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

// ─── Barra individual ─────────────────────────────────────────────────────────

class _EnergyBar extends StatelessWidget {
  final _HourEnergy hourEnergy;
  final double width;
  final double maxHeight;
  final bool showLabel;

  const _EnergyBar({
    required this.hourEnergy,
    required this.width,
    required this.maxHeight,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = hourEnergy.normalized;
    final hasData = hourEnergy.avgEnergy != null;
    final barHeight = hasData
        ? (normalized * (maxHeight - 16)).clamp(6.0, maxHeight - 16)
        : 4.0;

    final color = _energyColor(normalized, hasData);

    return Tooltip(
      message: hasData
          ? '${_hourLabel(hourEnergy.hour)}: ${hourEnergy.avgEnergy!.toStringAsFixed(1)} / 5 (${hourEnergy.sampleCount} amostras)'
          : '${_hourLabel(hourEnergy.hour)}: sem dados',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showLabel)
            Text(
              _hourLabel(hourEnergy.hour),
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textMuted,
              ),
            )
          else
            const SizedBox(height: 12),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            width: width,
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Color _energyColor(double normalized, bool hasData) {
    if (!hasData) return AppColors.surfaceVariant;
    if (normalized >= 0.7) return AppColors.habitGreen;
    if (normalized >= 0.45) return AppColors.warning;
    return AppColors.error.withValues(alpha: 0.7);
  }

  String _hourLabel(int hour) =>
      DateFormat('HH').format(DateTime(2000, 1, 1, hour));
}
