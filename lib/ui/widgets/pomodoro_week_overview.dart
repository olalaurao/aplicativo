import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/content_object.dart';
import '../../models/task_model.dart';
import '../../models/goal_model.dart';
import '../../models/project_model.dart';
import '../../providers/pomodoro_provider.dart';
import '../theme.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import 'package:flutter_svg/flutter_svg.dart'; // For icon parsing
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'universal_search_picker.dart';

class PomodoroWeekOverview extends ConsumerWidget {
  const PomodoroWeekOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomodoroState = ref.watch(pomodoroProvider);
    final allOrganizers = ref.watch(organizerListProvider);
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];

    // Calculate total hours this week
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final sessionsThisWeek = pomodoroState.history.where((s) => s.date.isAfter(startOfWeek)).toList();
    final totalMinutesThisWeek = sessionsThisWeek.fold<int>(0, (sum, s) => sum + s.minutesWorked);
    final totalHoursThisWeek = totalMinutesThisWeek / 60;
    final avgHoursPerDay = totalHoursThisWeek / (now.weekday); // Average up to today
    final mutedColor = AppTheme.textMutedColor(context);
    final dividerColor = AppTheme.dividerColor(context);

    // Group sessions by day
    final Map<int, double> dailyMinutes = {};
    for (var i = 0; i < 7; i++) {
      dailyMinutes[i] = 0.0;
    }
    for (final session in sessionsThisWeek) {
      final day = session.date.weekday - 1; // 0 for Monday, 6 for Sunday
      dailyMinutes[day] = (dailyMinutes[day] ?? 0.0) + session.minutesWorked;
    }

    // Group sessions by organizer
    final Map<String, double> organizerMinutes = {};
    for (final session in sessionsThisWeek) {
      String? orgSlug;
      if (session.linkedItemSlug != null) {
        final target = allObjects.firstWhere(
          (o) => o.id == session.linkedItemSlug || o.slug == session.linkedItemSlug,
          orElse: () => null as dynamic,
        ) as ContentObject?;
        if (target != null) {
          if (target is Task) {
            orgSlug = target.organizers.firstOrNull?.slug;
          } else if (target is Goal) {
            orgSlug = target.organizers.firstOrNull?.slug;
          } else if (target is Project) {
            orgSlug = target.slug;
          }
        }
        if (orgSlug == null) {
          final isOrganizer = allOrganizers.any((o) => o.slug == session.linkedItemSlug);
          if (isOrganizer) {
            orgSlug = session.linkedItemSlug;
          }
        }
      }
      if (orgSlug != null) {
        organizerMinutes[orgSlug] = (organizerMinutes[orgSlug] ?? 0.0) + session.minutesWorked;
      }
    }

    final sortedOrganizers = organizerMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor(context).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${totalHoursThisWeek.toStringAsFixed(0)}h',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.accentColor(context),
                  ),
                ),
                Text(
                  'this week',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '~${avgHoursPerDay.toStringAsFixed(0)}h per day',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _pickPomodoroObject(context, ref),
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Iniciar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor(context),
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: AppTheme.accentColor(context).withValues(alpha: 0.32),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 120,
          child: BarChart(
            BarChartData(
              barTouchData: const BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      return SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(dayNames[value.toInt()], style: TextStyle(fontSize: 10, color: mutedColor)),
                      );
                    },
                    interval: 1,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 10, color: mutedColor));
                    },
                    reservedSize: 28,
                    interval: 3,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: dailyMinutes.entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value / 60.0, // Convert minutes to hours
                      color: AppTheme.accentColor(context).withValues(alpha: 0.8),
                      width: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: dividerColor.withValues(alpha: 0.35),
                    strokeWidth: 0.5,
                    dashArray: [5, 5],
                  );
                },
              ),
              alignment: BarChartAlignment.spaceAround,
              maxY: 12, // Max hours to display on Y axis
            ),
          ),
        ),
        const SizedBox(height: 20),
        Column(
          children: sortedOrganizers.take(4).map((entry) {
            final organizer = allOrganizers.firstWhere(
              (o) => o.slug == entry.key,
              orElse: () => OrganizerReference(type: 'label', slug: entry.key, title: entry.key, icon: 'folder'), // Fallback
            );

            Widget iconWidget;
            if (organizer.icon != null && organizer.icon!.startsWith('ph-')) {
              // Icon from PhosphorIcons
              iconWidget = Icon(PhosphorIcons.folder(), color: _parseHexColor(organizer.color), size: 20);
            } else if (organizer.icon != null && organizer.icon!.endsWith('.svg')) {
              // SVG icon
              iconWidget = SvgPicture.asset(
                'assets/icons/${organizer.icon}',
                colorFilter: ColorFilter.mode(_parseHexColor(organizer.color), BlendMode.srcIn),
                width: 20,
                height: 20,
              );
            } else {
              iconWidget = Icon(Icons.folder_open, color: _parseHexColor(organizer.color), size: 20);
            }
            final hours = (entry.value / 60).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          organizer.title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalMinutesThisWeek == 0 ? 0 : entry.value / totalMinutesThisWeek,
                            backgroundColor: dividerColor.withValues(alpha: 0.35),
                            valueColor: AlwaysStoppedAnimation<Color>(_parseHexColor(organizer.color)),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${hours}h',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
      ),
    );
  }

  void _pickPomodoroObject(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => UniversalSearchPickerSheet(
        title: 'Foco do Pomodoro',
        initialFilter: 'task',
        showClear: true,
        onSelected: (ContentObject object) {
          Navigator.pop(sheetContext);
          ref.read(pomodoroProvider.notifier).setCurrentItem(
                object.id,
                object.title,
              );
          ref.read(pomodoroProvider.notifier).start();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pomodoro iniciado: ${object.title}')),
          );
        },
        onClear: () {
          Navigator.pop(sheetContext);
          ref.read(pomodoroProvider.notifier).setCurrentItem(null, null);
          ref.read(pomodoroProvider.notifier).start();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pomodoro iniciado sem objeto vinculado')),
          );
        },
      ),
    );
  }

  Color _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    final cleaned = hex.replaceFirst('#', '').replaceFirst('0x', '');
    final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(withAlpha, radix: 16) ?? AppColors.primary.toARGB32());
  }
}
