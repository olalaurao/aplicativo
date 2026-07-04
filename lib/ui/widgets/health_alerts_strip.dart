import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/health_alerts_provider.dart';
import '../../providers/wellbeing_indicator_provider.dart';
import '../../models/wellbeing_indicator_model.dart';
import '../theme.dart';
import '../forms/create_record_form.dart';
import '../../models/tracker_model.dart';

class HealthAlertsStrip extends ConsumerWidget {
  final bool compact;
  const HealthAlertsStrip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackerAlerts = ref.watch(healthAlertsProvider);
    final wellbeingAlerts = ref.watch(activeHealthAlertsProvider);
    
    // Combine both alert types
    final allAlerts = [...trackerAlerts, ...wellbeingAlerts];
    if (allAlerts.isEmpty) return const SizedBox.shrink();

    if (compact) {
      // Versão horizontal para dashboard
      return SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: allAlerts.length,
          separatorBuilder: (context, sep) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) => _buildAlertCard(allAlerts[i], compact: true)));
    }

    // Versão expandida para HabitsScreen
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          const Text('🔔', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('HEALTH ALERTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 0.10, color: AppTheme.textMutedColor(context))),
          const Spacer(),
          Text('${allAlerts.length} alert${allAlerts.length == 1 ? "" : "s"}',
            style: const TextStyle(fontSize: 11, color: AppColors.warning)),
        ])),
      ...allAlerts.map((a) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: _buildAlertCard(a, compact: false))),
    ]);
  }
  
  Widget _buildAlertCard(dynamic alert, {required bool compact}) {
    if (alert is HealthAlert) {
      return _TrackerAlertCard(alert: alert, compact: compact);
    } else if (alert is WellbeingSignalStatus) {
      return _WellbeingAlertCard(alert: alert, compact: compact);
    }
    return const SizedBox.shrink();
  }
}

class _TrackerAlertCard extends ConsumerWidget {
  final HealthAlert alert;
  final bool compact;
  const _TrackerAlertCard({required this.alert, required this.compact});

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

class _WellbeingAlertCard extends ConsumerWidget {
  final WellbeingSignalStatus alert;
  final bool compact;
  const _WellbeingAlertCard({required this.alert, required this.compact});

  Color get _color {
    if (alert.status == SignalStatus.alert) return AppColors.error;
    if (alert.status == SignalStatus.watch) return AppColors.warning;
    return AppColors.success;
  }

  String get _icon {
    if (alert.status == SignalStatus.alert) return '🚨';
    if (alert.status == SignalStatus.watch) return '⚠️';
    return '✓';
  }

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
            Expanded(child: Text(alert.sourceTitle ?? 'Signal',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color))),
          ]),
          const SizedBox(height: 4),
          Text(alert.message ?? 'Needs attention', maxLines: 2, overflow: TextOverflow.ellipsis,
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
          Text(alert.sourceTitle ?? 'Wellbeing Signal',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _color)),
          const SizedBox(height: 2),
          Text(alert.message ?? 'Needs attention',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
          if (alert.currentValue != null) ...[
            const SizedBox(height: 3),
            Text('Current: ${alert.currentValue?.toStringAsFixed(1)}', style: TextStyle(fontSize: 10,
              color: AppTheme.textMutedColor(context), fontStyle: FontStyle.italic)),
          ],
        ])),
      ]));
  }
}
