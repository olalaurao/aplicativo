// lib/ui/screens/merge_type_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import '../theme.dart';
import '../utils/object_icons.dart';

class MergeTypeSelectionScreen extends ConsumerWidget {
  final List<ContentObject> selectedObjects;

  const MergeTypeSelectionScreen({
    super.key,
    required this.selectedObjects,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get distinct types from selected objects
    final typeCounts = <String, int>{};
    for (final obj in selectedObjects) {
      typeCounts[obj.type] = (typeCounts[obj.type] ?? 0) + 1;
    }

    final distinctTypes = typeCounts.keys.toList();

    // If all objects share the same type, skip this screen and return immediately
    if (distinctTypes.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context, distinctTypes.first);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Select Target Type'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose the type for the merged object',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selected objects contain ${distinctTypes.length} different type${distinctTypes.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: distinctTypes.length,
                  itemBuilder: (context, index) {
                    final type = distinctTypes[index];
                    final count = typeCounts[type]!;
                    return _buildTypeCard(context, ref, type, count);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(
    BuildContext context,
    WidgetRef ref,
    String type,
    int count,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context, type);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ObjectIcons.iconDataForType(type, ref),
                  size: 24,
                  color: AppTheme.accentColor(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTypeDisplayName(type),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count object${count == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeDisplayName(String type) {
    // Convert type to display name
    return type.split('_').map((word) {
      final first = word[0].toUpperCase();
      final rest = word.substring(1);
      return '$first$rest';
    }).join(' ');
  }
}