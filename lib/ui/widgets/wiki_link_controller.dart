import 'package:flutter/material.dart';
import 'wiki_link_picker.dart';

class WikiLinkTextController extends TextEditingController {
  final BuildContext context;

  WikiLinkTextController({required this.context, super.text}) {
    addListener(_onChanged);
  }

  void _onChanged() {
    final val = text;
    final selection = this.selection;
    if (selection.baseOffset < 2) return;

    final lastTwo = val.substring(
      selection.baseOffset - 2,
      selection.baseOffset,
    );
    if (lastTwo == '[[') {
      _showPicker(selection.baseOffset);
    }
  }

  void _showPicker(int offset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WikiLinkPicker(
        onSelected: (obj) {
          final currentText = text;
          final before = currentText.substring(0, offset);
          final after = currentText.substring(offset);

          // Replace [[ with [[title]]
          // Note: we already have [[ typed, so we just append title and ]]
          text = '$before${obj.title}]] $after';
          selection = TextSelection.fromPosition(
            TextPosition(offset: before.length + obj.title.length + 3),
          );
          Navigator.pop(context);
        },
      ),
    );
  }
}
