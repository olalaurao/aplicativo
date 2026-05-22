// lib/ui/components/conflict_resolution_dialog.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class ConflictResolutionDialog extends StatelessWidget {
  final String fileName;
  final String localContent;
  final String remoteContent;

  const ConflictResolutionDialog({
    super.key,
    required this.fileName,
    required this.localContent,
    required this.remoteContent,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sync Conflict: $fileName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The file has changed on Google Drive and locally. Which version do you want to keep?',
          ),
          const SizedBox(height: 16),
          _buildVersionCard(
            context,
            'Local Version',
            localContent,
            AppColors.info,
          ),
          const SizedBox(height: 8),
          _buildVersionCard(
            context,
            'Remote Version',
            remoteContent,
            AppColors.success,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'local'),
          child: const Text('Keep Local'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'remote'),
          child: const Text('Keep Remote'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'merge'),
          child: const Text('Merge (Manual)'),
        ),
      ],
    );
  }

  Widget _buildVersionCard(
    BuildContext context,
    String title,
    String content,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            content.length > 100 ? '${content.substring(0, 100)}...' : content,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
