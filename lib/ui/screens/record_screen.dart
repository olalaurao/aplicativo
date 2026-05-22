// lib/ui/screens/record_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../widgets/create_menu_sheet.dart';
import '../forms/create_record_form.dart';
import 'trackers_screen.dart';

class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackers = ref.watch(trackersProvider);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Header ───
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trackers',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'record_fab',
                      onPressed: () => showCreateMenu(context),
                      child: const Icon(Icons.add, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── This Week Summary Card ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _summaryMetric('24', 'Records'),
                        const SizedBox(width: 28),
                        _summaryMetric(
                          '${trackers.isEmpty ? 6 : trackers.length}',
                          'Trackers',
                        ),
                        const SizedBox(width: 28),
                        _summaryMetric('86%', 'Consistency'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Recent Activity Section ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrackersScreen()),
                    ),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Featured Tracker Cards ───
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (trackers.isNotEmpty)
                  ...trackers
                      .take(3)
                      .map(
                        (t) => _buildTrackerActivityCard(
                          context,
                          title: t.title,
                          value: '0',
                          unit: '',
                          emoji: '📊',
                          color: _parseColor(t.color),
                          records: 0,
                          lastDate: 'Today',
                        ),
                      )
                else ...[
                  _buildTrackerActivityCard(
                    context,
                    title: 'Sleep Quality',
                    value: '7.2',
                    unit: 'hours',
                    emoji: '😴',
                    color: AppColors.habitPurple,
                    records: 28,
                    lastDate: 'May 6',
                    trendUp: true,
                  ),
                  _buildTrackerActivityCard(
                    context,
                    title: 'Workout Stats',
                    value: '65',
                    unit: 'min',
                    emoji: '💪',
                    color: AppColors.habitGreen,
                    records: 45,
                    lastDate: 'May 6',
                    trendUp: false,
                  ),
                  _buildTrackerActivityCard(
                    context,
                    title: 'Water Intake',
                    value: '2.1',
                    unit: 'L',
                    emoji: '💧',
                    color: AppColors.info,
                    records: 28,
                    lastDate: 'May 6',
                    trendUp: false,
                  ),
                ],
              ],
            ),
          ),

          // ─── All Trackers Grid ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'All Trackers',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrackersScreen()),
                    ),
                    child: const Text(
                      '+ New Tracker',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              delegate: SliverChildListDelegate(
                trackers.isNotEmpty
                    ? trackers
                          .map(
                            (t) => _buildTrackerGridCard(
                              context,
                              title: t.title,
                              emoji: '📊',
                              value: '0',
                              unit: '',
                              records: 0,
                              color: _parseColor(t.color),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateRecordForm(tracker: t),
                                ),
                              ),
                            ),
                          )
                          .toList()
                    : [
                        _buildTrackerGridCard(
                          context,
                          title: 'Weight',
                          emoji: '⚖️',
                          value: '72.5',
                          unit: 'kg',
                          records: 52,
                          color: AppColors.habitOrange,
                        ),
                        _buildTrackerGridCard(
                          context,
                          title: 'Reading Progress',
                          emoji: '📖',
                          value: '25',
                          unit: 'pages',
                          records: 18,
                          color: AppColors.habitGreen,
                        ),
                        _buildTrackerGridCard(
                          context,
                          title: 'Mood',
                          emoji: '😊',
                          value: '',
                          unit: '',
                          records: 30,
                          color: AppColors.habitPink,
                        ),
                        _buildTrackerGridCard(
                          context,
                          title: 'Expenses',
                          emoji: '💰',
                          value: '',
                          unit: '',
                          records: 15,
                          color: AppColors.success,
                        ),
                      ],
              ),
            ),
          ),

          // ─── Quick Stats Card ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Stats',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickStatRow(
                      '😴',
                      'Avg Sleep',
                      '7.2 hrs',
                      '+0.5 from last week',
                      AppColors.habitPurple,
                    ),
                    const Divider(height: 24),
                    _buildQuickStatRow(
                      '💪',
                      'Workout Time',
                      '455 min',
                      'This week',
                      AppColors.habitGreen,
                    ),
                    const Divider(height: 24),
                    _buildQuickStatRow(
                      '🔥',
                      'Streak',
                      '14 days',
                      'Personal best!',
                      AppColors.habitOrange,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ─── Summary Metric ───
  Widget _summaryMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  // ─── Tracker Activity Card (Featured) ───
  Widget _buildTrackerActivityCard(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required String emoji,
    required Color color,
    required int records,
    required String lastDate,
    bool trendUp = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: InkWell(
        onTap: () {
          // Find the actual tracker object from title if possible, or just open generic
          // For now, navigate to detail or show log
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: AppTheme.cardDecoration(context),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '$value $unit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              trendUp
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 16,
                              color: color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add, size: 16, color: color),
                    ),
                    onPressed: () {
                      // Open log form
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Mini sparkline
              SizedBox(
                height: 48,
                child: CustomPaint(
                  size: const Size(double.infinity, 48),
                  painter: _SparklinePainter(color: color),
                ),
              ),

              const SizedBox(height: 10),

              // Footer
              Row(
                children: [
                  Text(
                    '$records records',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Last: $lastDate',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tracker Grid Card ───
  Widget _buildTrackerGridCard(
    BuildContext context, {
    required String title,
    required String emoji,
    required String value,
    required String unit,
    required int records,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap:
          onTap ??
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TrackersScreen()),
          ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            if (value.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.trending_down_rounded, size: 14, color: color),
                  const SizedBox(width: 3),
                  Text(
                    '$value $unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            Text(
              '$records records',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick Stat Row ───
  Widget _buildQuickStatRow(
    String emoji,
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

// ─── Sparkline Painter ───
class _SparklinePainter extends CustomPainter {
  final Color color;
  _SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Yesulated sparkline data
    final points = [
      0.4,
      0.3,
      0.5,
      0.45,
      0.6,
      0.55,
      0.7,
      0.65,
      0.75,
      0.8,
      0.7,
      0.85,
    ];
    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (points[i - 1] * size.height);
        final cx = (prevX + x) / 2;
        path.cubicTo(cx, prevY, cx, y, x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Fill gradient below line
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
