import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/health_alerts_provider.dart';
import '../theme.dart';
import '../forms/create_record_form.dart';
import '../../models/tracker_model.dart';

class HealthAlertsStrip extends ConsumerWidget {
  final bool compact;
  const HealthAlertsStrip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(healthAlertsProvider);
    if (alerts.isEmpty) return const SizedBox.shrink();

    if (compact) {
      // Versão horizontal para dashboard
      return SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: alerts.length,
          separatorBuilder: (context, sep) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) => _AlertCard(alert: alerts[i], compact: true)));
    }

    // Versão expandida para HabitsScreen
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          const Text('🔔', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('SAÚDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 0.10, color: AppTheme.textMutedColor(context))),
          const Spacer(),
          Text('${alerts.length} alerta${alerts.length == 1 ? "" : "s"}',
            style: const TextStyle(fontSize: 11, color: AppColors.warning)),
        ])),
      ...alerts.map((a) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: _AlertCard(alert: a, compact: false))),
    ]);
  }
}

class _AlertCard extends ConsumerWidget {
  final HealthAlert alert;
  final bool compact;
  const _AlertCard({required this.alert, required this.compact});

  Color get _color => switch (alert.level) {
    FieldAlertLevel.critical => AppColors.error,
    FieldAlertLevel.warning  => AppColors.warning,
    FieldAlertLevel.info     => AppColors.info,
    FieldAlertLevel.none     => AppColors.textMuted,
  };

  String get _icon => switch (alert.level) {
    FieldAlertLevel.critical => '🚨',
    FieldAlertLevel.warning  => '⚠️',
    FieldAlertLevel.info     => 'ℹ️',
    FieldAlertLevel.none     => '•',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Expanded(child: Text(alert.field.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color))),
          ]),
          const SizedBox(height: 4),
          Text(alert.message, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor(context))),
        ]));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.25))),
      child: Row(children: [
        Text(_icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${alert.tracker.title} · ${alert.field.title}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _color)),
          const SizedBox(height: 2),
          Text(alert.message,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
          if (alert.field.alertNote != null) ...[
            const SizedBox(height: 3),
            Text(alert.field.alertNote!, style: TextStyle(fontSize: 10,
              color: AppTheme.textMutedColor(context), fontStyle: FontStyle.italic)),
          ],
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CreateRecordForm(tracker: alert.tracker)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
            child: Text('Registrar', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: _color)))),
      ]));
  }
}
