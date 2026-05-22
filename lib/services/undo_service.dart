import 'dart:async';
import 'package:flutter/material.dart';

class UndoService {
  static void showUndoSnackbar({
    required BuildContext context,
    required String message,
    required FutureOr<void> Function() onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: SnackBarAction(label: 'UNDO', onPressed: onUndo),
      ),
    );
  }
}
