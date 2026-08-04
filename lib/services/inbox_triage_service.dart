import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inbox_model.dart';
import '../../providers/vault_provider.dart';

Future<void> triageInboxItem(
  BuildContext context,
  WidgetRef ref,
  InboxItem item,
  Widget form,
) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final inboxNotifier = ref.read(inboxProvider.notifier);

  try {
    final saved = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => form),
    );
    if (saved == true) {
      await inboxNotifier.triageItem(item);
    }
  } catch (e) {
    debugPrint('Inbox triage failed: $e');
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not triage this item.')),
    );
  }
}
