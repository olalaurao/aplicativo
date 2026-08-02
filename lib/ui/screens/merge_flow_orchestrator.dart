// lib/ui/screens/merge_flow_orchestrator.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import 'merge_type_selection_screen.dart';
import 'merge_reconciliation_screen.dart';
import 'merge_body_screen.dart';
import 'merge_confirmation_screen.dart';
import '../../providers/merge_provider.dart';
import '../../services/merge_service.dart';

/// Orchestrates the complete merge flow by connecting all merge screens
class MergeFlowOrchestrator {
  static Future<void> startMergeFlow(
    BuildContext context,
    WidgetRef ref,
    List<ContentObject> selectedObjects,
  ) async {
    if (!context.mounted) return;

    // Step 1: Select target type (skips if all same type)
    final targetType = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MergeTypeSelectionScreen(
          selectedObjects: selectedObjects,
        ),
      ),
    );

    if (targetType == null || !context.mounted) return; // User cancelled or context invalid

    // Step 2: Reconcile properties
    final reconciledProperties = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MergeReconciliationScreen(
          selectedObjects: selectedObjects,
          targetType: targetType,
        ),
      ),
    );

    if (reconciledProperties == null || !context.mounted) return; // User cancelled or context invalid

    // Step 3: Reconcile body (only if objects have body content)
    final objectsWithBody = selectedObjects.where((obj) {
      return obj.title.isNotEmpty; // Simplified check
    }).toList();

    String? mergedBody;
    String? bodyMergeMode;

    if (objectsWithBody.isNotEmpty && context.mounted) {
      final bodyResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => MergeBodyScreen(
            selectedObjects: selectedObjects,
          ),
        ),
      );

      if (bodyResult == null || !context.mounted) return; // User cancelled or context invalid

      mergedBody = bodyResult['body'] as String?;
      bodyMergeMode = bodyResult['mode'] as String?;
    }

    if (!context.mounted) return;

    // Step 4: Select survivor (default to latest updatedAt)
    final survivor = selectedObjects.reduce((a, b) =>
        a.updatedAt.isAfter(b.updatedAt) ? a : b);

    // Step 5: Show confirmation
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MergeConfirmationScreen(
          selectedObjects: selectedObjects,
          survivor: survivor,
          targetType: targetType,
          reconciledProperties: reconciledProperties,
          mergedBody: mergedBody,
          bodyMergeMode: bodyMergeMode,
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return; // User cancelled or context invalid

    // Step 6: Execute merge
    print('[MergeFlowOrchestrator] Step 6: Starting merge execution');
    final losingObjects = selectedObjects.where((obj) => obj.id != survivor.id).toList();
    print('[MergeFlowOrchestrator] Survivor: ${survivor.slug}, Losing: ${losingObjects.map((o) => o.slug).join(', ')}');
    
    try {
      print('[MergeFlowOrchestrator] Getting merge service');
      final mergeService = ref.read(mergeServiceProvider);
      
      // Apply reconciled properties to survivor
      // Note: This is a simplified version - a full implementation would
      // properly reconstruct the object with the new properties
      print('[MergeFlowOrchestrator] Calling performMerge');
      await mergeService.performMerge(
        survivor: survivor,
        losingObjects: losingObjects,
        reconciledProperties: reconciledProperties,
        reconciledBody: mergedBody,
      );
      print('[MergeFlowOrchestrator] performMerge completed');

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully merged ${losingObjects.length} objects'),
            backgroundColor: Colors.green,
          ),
        );
      }
      print('[MergeFlowOrchestrator] Merge flow completed successfully');
    } catch (e) {
      print('[MergeFlowOrchestrator] Merge failed with error: $e');
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merge failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}