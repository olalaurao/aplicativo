import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/habit_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../../services/automation_service.dart';
import 'vault_link_picker_sheet.dart';

/// Handles habit checkbox tap including optional [link_item] action flow.
Future<void> handleHabitCheckTap(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  DateTime date, {
  int? slotIndex,
  required bool Function() wasAlreadyDone,
  VoidCallback? onProcessingChanged,
}) async {
  onProcessingChanged?.call();
  try {
    final alreadyDone = wasAlreadyDone();
    if (!alreadyDone) {
      final linkAction = habit.actions.firstWhereOrNull(
        (a) =>
            a.type == 'link_item' &&
            (a.trigger == 'slot_complete' || a.trigger == 'day_complete'),
      );
      if (linkAction != null) {
        final selected = await showModalBottomSheet<List<VaultLinkRef>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => VaultLinkPickerSheet(
            promptTitle: linkAction.params?['prompt_title'] as String? ??
                'O que você quer vincular a esse check?',
            allowMultiple:
                linkAction.params?['allow_multiple'] as bool? ?? true,
          ),
        );
        if (selected != null && selected.isNotEmpty) {
          await AutomationService.persistLinkedRefsPublic(
            ref,
            habit,
            date,
            selected,
          );
        }
      }
    }
    await ref.read(habitsProvider.notifier).toggleHabit(
          habit,
          date,
          slotIndex: slotIndex,
        );
  } finally {
    onProcessingChanged?.call();
  }
}
