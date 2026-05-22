// lib/ui/components/universal_detail_view.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class UniversalDetailView extends StatelessWidget {
  final String title;
  final String objectType; // Task, Habit, Entry, etc.
  final Widget customProperties;

  const UniversalDetailView({
    super.key,
    required this.title,
    required this.objectType,
    required this.customProperties,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(objectType),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$value action selected')));
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Edit', child: Text('Edit')),
              PopupMenuItem(value: 'Archive', child: Text('Archive')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Standard Title Header
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Tags / Categories section
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: const Text('Productivity'),
                  backgroundColor: AppColors.info.withValues(alpha: 0.1),
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                ),
                Chip(
                  label: const Text('Work'),
                  backgroundColor: AppColors.habitOrange.withValues(alpha: 0.1),
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                ),
              ],
            ),
            const Divider(height: 32),

            // Custom properties specific to the object type
            customProperties,

            const Divider(height: 32),

            // Standard Mentions / Backlinks Footer
            const Text(
              'Mentions & Backlinks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildBacklinkCard(
              'Journal Entry',
              'Reflected on this today.',
              'Yesterday',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$title saved')));
        },
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
    );
  }

  Widget _buildBacklinkCard(
    String objectType,
    String contextText,
    String time,
  ) {
    return Card(
      elevation: 0,
      color: AppColors.textMuted.withValues(alpha: 0.05),
      child: ListTile(
        leading: const Icon(Icons.link, color: AppColors.textMuted),
        title: Text(objectType),
        subtitle: Text(contextText),
        trailing: Text(
          time,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}
