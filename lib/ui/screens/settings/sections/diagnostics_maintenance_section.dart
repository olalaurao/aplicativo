import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../diagnostic_reports_screen.dart';
import '../../widgets_management_screen.dart';

class DiagnosticsMaintenanceSection extends StatelessWidget {
  const DiagnosticsMaintenanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            leading: Icon(
              Icons.assessment_rounded,
              color: AppTheme.accentColor(context),
            ),
            title: const Text(
              'Diagnostic Reports',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'View system health and performance metrics',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DiagnosticReportsScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            leading: Icon(
              Icons.widgets_rounded,
              color: AppTheme.accentColor(context),
            ),
            title: const Text(
              'Widgets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Manage home screen widgets',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WidgetsManagementScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
