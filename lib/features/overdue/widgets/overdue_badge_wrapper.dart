// lib/features/overdue/widgets/overdue_badge_wrapper.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../providers/overdue_provider.dart';

class OverdueBadgeWrapper extends StatelessWidget {
  final Widget child;
  final DateTime? dueDate;
  final OverdueSeverity severity;
  final String? customDateText;

  const OverdueBadgeWrapper({
    super.key,
    required this.child,
    required this.dueDate,
    required this.severity,
    this.customDateText,
  });

  String _getOverdueText() {
    if (customDateText != null) return customDateText!;
    if (dueDate == null || severity == OverdueSeverity.none) return '';
    
    final now = DateTime.now();
    final daysLate = now.difference(dueDate!).inDays;
    
    if (daysLate == 1) return 'atrasado há 1 dia';
    return 'atrasado há $daysLate dias';
  }

  @override
  Widget build(BuildContext context) {
    if (severity == OverdueSeverity.none) {
      return child;
    }

    final color = severityColor(severity);
    final overdueText = _getOverdueText();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: color,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          if (overdueText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    overdueText,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
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
}
