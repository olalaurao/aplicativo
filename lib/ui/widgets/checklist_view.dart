import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/note_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/widget_service.dart';
import '../theme.dart';

class ChecklistView extends ConsumerStatefulWidget {
  final Note note;

  const ChecklistView({super.key, required this.note});

  @override
  ConsumerState<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends ConsumerState<ChecklistView> {
  late List<_ChecklistItem> _items;

  @override
  void initState() {
    super.initState();
    _parseBody();
  }

  @override
  void didUpdateWidget(ChecklistView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.body != widget.note.body) {
      _parseBody();
    }
  }

  void _parseBody() {
    _items = [];
    final lines = widget.note.body.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final match = RegExp(r'^- \[(x| )\] (.*)').firstMatch(line);
      if (match != null) {
        _items.add(_ChecklistItem(
          index: i,
          isCompleted: match.group(1) == 'x' || match.group(1) == 'X',
          text: match.group(2) ?? '',
        ));
      }
    }
  }

  Future<void> _toggleItem(int index, bool? value) async {
    final itemIndex = _items.indexWhere((item) => item.index == index);
    if (itemIndex == -1) return;

    setState(() {
      _items[itemIndex].isCompleted = value ?? false;
    });

    final lines = widget.note.body.split('\n');
    final item = _items[itemIndex];
    lines[item.index] = '- [${item.isCompleted ? 'x' : ' '}] ${item.text}';
    
    final newBody = lines.join('\n');
    final updated = widget.note.copyWith(body: newBody);
    
    await ref.read(vaultProvider.notifier).updateObject(updated);
    
    // Refresh widget directly. WidgetId is not directly known, passing 0 as a fallback
    // WidgetService will update citrine_note and citrine_note_0
    await WidgetService.updateNote(
      widgetId: 0,
      title: updated.title,
      content: newBody,
      slug: updated.slug,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Nenhum item na checklist.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, idx) {
        final item = _items[idx];
        return CheckboxListTile(
          value: item.isCompleted,
          onChanged: (val) => _toggleItem(item.index, val),
          title: Text(
            item.text,
            style: TextStyle(
              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
              color: item.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          activeColor: AppColors.primary,
        );
      },
    );
  }
}

class _ChecklistItem {
  final int index;
  bool isCompleted;
  final String text;

  _ChecklistItem({required this.index, required this.isCompleted, required this.text});
}
