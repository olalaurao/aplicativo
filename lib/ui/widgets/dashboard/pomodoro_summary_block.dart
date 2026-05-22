import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme.dart';
import '../../../providers/pomodoro_provider.dart';

class PomodoroSummaryBlock extends ConsumerWidget {
  const PomodoroSummaryBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroProvider);
    
    // Dados simulados para o gráfico (7 dias)
    final spots = List.generate(7, (index) => BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: (index + 1) * 1.5,
          color: AppColors.primary,
          width: 12,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    ));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pomodoros da Semana',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '55h esta semana',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text('~8h por dia', style: TextStyle(color: AppTheme.textMutedColor(context))),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                barGroups: spots,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
                        return Text(days[value.toInt()], style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}