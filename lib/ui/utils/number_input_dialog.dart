import 'package:flutter/material.dart';
import '../theme.dart';

Future<int?> showNumberInputDialog(
  BuildContext context, {
  required String title,
  required int initialValue,
  int? min,
  int? max,
  String? labelText,
}) async {
  final controller = TextEditingController(text: initialValue.toString());
  
  final result = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: labelText ?? 'Value',
          border: const OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(controller.text);
            if (value != null) {
              if (min != null && value < min) return;
              if (max != null && value > max) return;
              Navigator.pop(context, value);
            }
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
  
  controller.dispose();
  return result;
}
