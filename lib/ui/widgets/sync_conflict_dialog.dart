// lib/ui/widgets/sync_conflict_dialog.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class SyncConflictDialog extends StatelessWidget {
  final String fileName;
  final String localContent;
  final String remoteContent;

  const SyncConflictDialog({
    super.key,
    required this.fileName,
    required this.localContent,
    required this.remoteContent,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Conflito em $fileName'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Conflicting changes were detected. Choose which version to keep:',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildVersionBox(
                      context,
                      'Local (You)',
                      localContent,
                      AppTheme.accentColor(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVersionBox(
                      context,
                      'Remoto (Cloud)',
                      remoteContent,
                      AppColors.habitPurple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
      ],
    );
  }

  Widget _buildVersionBox(
    BuildContext context,
    String title,
    String content,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Text(
                content,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, content),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            minimumSize: const Size(double.infinity, 36),
          ),
          child: const Text(
            'MANTER ESTA',
            style: TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
