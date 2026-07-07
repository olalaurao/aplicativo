// lib/ui/widgets/outline_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../theme.dart';
import '../../models/content_object.dart';
import '../../services/markdown_parser.dart';
import 'universal_search_picker.dart';
import 'highlight_picker_sheet.dart';


class OutlineNode {
  String id;
  String text;
  int level;
  bool isCompleted;
  bool isCollapsed;
  List<OutlineNode> children;

  OutlineNode({
    required this.id,
    required this.text,
    this.level = 0,
    this.isCompleted = false,
    this.isCollapsed = false,
    this.children = const [],
  });
}

class OutlineEditor extends StatefulWidget {
  final String initialContent;
  final Function(String) onChanged;
  final Function(String)? onWikiLinkTap;

  const OutlineEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
    this.onWikiLinkTap,
  });

  @override
  State<OutlineEditor> createState() => _OutlineEditorState();
}

class _OutlineEditorState extends State<OutlineEditor> {
  late List<OutlineItem> _items;
  int? _focusIndex; // For focus mode
  int? _editingIndex; // The currently focused textfield

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  void _parseContent() {
    if (widget.initialContent.isEmpty) {
      _items = [
        OutlineItem(
          text: '',
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      ];
      return;
    }

    final lines = widget.initialContent.split('\n');
    _items = lines.where((l) => l.trim().isNotEmpty).map((line) {
      final indentMatch = RegExp(r'^(\s*)').firstMatch(line);
      final indent = indentMatch?.group(1)?.length ?? 0;
      final level = indent ~/ 2;

      final content = line.trim();
      bool completed = false;
      String text = content;

      if (content.startsWith('- [x]')) {
        completed = true;
        text = content.replaceFirst('- [x]', '').trim();
      } else if (content.startsWith('- [ ]')) {
        text = content.replaceFirst('- [ ]', '').trim();
      } else if (content.startsWith('- ')) {
        text = content.replaceFirst('- ', '').trim();
      }

      return OutlineItem(
        text: text,
        level: level,
        isCompleted: completed,
        id: '${DateTime.now().millisecondsSinceEpoch}_${line.hashCode}',
      );
    }).toList();

    if (_items.isEmpty) _items = [OutlineItem(text: '', id: 'initial')];
  }

  void _updateContent() {
    final content = _items
        .map((item) {
          final indent = '  ' * item.level;
          final prefix = item.isCompleted ? '- [x] ' : '- [ ] ';
          return '$indent$prefix${item.text}';
        })
        .join('\n');
    widget.onChanged(content);
  }

  @override
  Widget build(BuildContext context) {
    List<int> visibleIndices = [];
    if (_focusIndex == null) {
      visibleIndices = List.generate(_items.length, (i) => i);
    } else {
      // Focus Mode: Show only the focused item and its descendants
      final focusedLevel = _items[_focusIndex!].level;
      visibleIndices.add(_focusIndex!);
      for (int i = _focusIndex! + 1; i < _items.length; i++) {
        if (_items[i].level > focusedLevel) {
          visibleIndices.add(i);
        } else {
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_focusIndex != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextButton.icon(
              onPressed: () => setState(() => _focusIndex = null),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Sair do Modo Focus'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor(context)),
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleIndices.length,
          onReorder: (oldIdx, newIdx) {
            setState(() {
              final actualOld = visibleIndices[oldIdx];
              int actualNew =
                  visibleIndices[newIdx == visibleIndices.length
                      ? visibleIndices.length - 1
                      : newIdx];

              final item = _items.removeAt(actualOld);
              _items.insert(newIdx > oldIdx ? actualNew : actualNew, item);
            });
            _updateContent();
          },
          itemBuilder: (context, idx) {
            final actualIndex = visibleIndices[idx];
            final item = _items[actualIndex];
            return _buildItem(actualIndex, item);
          },
        ),
      ],
    );
  }

  Widget _buildItem(int index, OutlineItem item) {
    final isEditingItem = _editingIndex == index;
    final wikiRegex = RegExp(r'\[\[([^\]]+)\]\]');
    final hasWikiLink = wikiRegex.hasMatch(item.text);

    return Container(
      key: ValueKey(item.id),
      padding: EdgeInsets.only(left: item.level * 20.0 + 8, right: 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 16,
                color: AppTheme.textMutedColor(context),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Checkbox(
              value: item.isCompleted,
              onChanged: (v) {
                setState(() => item.isCompleted = v ?? false);
                _updateContent();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              activeColor: AppTheme.accentColor(context),
            ),
          ),
          Expanded(
            child: (!isEditingItem && hasWikiLink)
                ? InkWell(
                    onTap: () => setState(() => _editingIndex = index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _buildWikiText(item.text, item),
                    ),
                  )
                : KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) => _handleKeyEvent(event, index, item),
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          setState(() => _editingIndex = index);
                        } else if (_editingIndex == index) {
                          setState(() => _editingIndex = null);
                        }
                      },
                      child: TextField(
                        onChanged: (v) {
                          item.text = v;
                          _updateContent();
                        },
                        controller: TextEditingController(text: item.text)
                          ..selection = TextSelection.fromPosition(
                            TextPosition(offset: item.text.length),
                          ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: item.level == 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: item.isCompleted
                              ? AppTheme.textMutedColor(context)
                              : AppTheme.textPrimaryColor(context),
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        onSubmitted: (_) => _addItemAfter(index),
                      ),
                    ),
                  ),
          ),
          if (isEditingItem) ...[
            IconButton(
              icon: const Icon(Icons.link_rounded, size: 16),
              onPressed: () => _insertWikiLink(index),
              tooltip: 'Inserir Link',
            ),
            IconButton(
              icon: const Icon(Icons.format_quote_rounded, size: 16),
              onPressed: () => _insertHighlight(index),
              tooltip: 'Citar Trecho',
            ),
          ],
          if (_focusIndex == null)
            IconButton(
              icon: Icon(
                Icons.center_focus_weak_rounded,
                size: 16,
                color: AppTheme.textMutedColor(context),
              ),
              onPressed: () => setState(() => _focusIndex = index),
              tooltip: 'Focus',
            ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppTheme.textMutedColor(context),
            ),
            onPressed: () => _removeItem(index),
            tooltip: 'Remover',
          ),
        ],
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event, int index, OutlineItem item) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        if (item.level > 0) setState(() => item.level--);
      } else {
        if (item.level < 8) setState(() => item.level++);
      }
      _updateContent();
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        item.text.isEmpty &&
        _items.length > 1) {
      _removeItem(index);
    }
  }

  void _addItemAfter(int index) {
    setState(() {
      _items.insert(
        index + 1,
        OutlineItem(
          text: '',
          level: _items[index].level,
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );
    });
    _updateContent();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      if (_items.isEmpty) _items = [OutlineItem(text: '', id: 'initial')];
      if (_focusIndex == index) _focusIndex = null;
    });
    _updateContent();
  }

  Widget _buildWikiText(String text, OutlineItem item) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in RegExp(r'\[\[([^\]]+)\]\]').allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final slug = match.group(1)!;
      spans.add(TextSpan(
        text: slug,
        style: const TextStyle(
            color: AppColors.info, decoration: TextDecoration.underline),
        // We use tap recognizer directly on TextSpan
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    
    // Convert tap gesture to inline spans
    final tapSpans = spans.map((span) {
      if (span is TextSpan && span.style?.color == AppColors.info) {
        return TextSpan(
          text: span.text,
          style: span.style,
          recognizer: _TapGestureRecognizer()
            ..onTap = () {
              if (widget.onWikiLinkTap != null) {
                widget.onWikiLinkTap!(span.text!);
              }
            },
        );
      }
      return span;
    }).toList();

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 15,
          fontWeight: item.level == 0 ? FontWeight.w600 : FontWeight.w400,
          color: item.isCompleted
              ? AppTheme.textMutedColor(context)
              : AppTheme.textPrimaryColor(context),
          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
        ),
        children: tapSpans,
      ),
    );
  }

  Future<void> _insertWikiLink(int index) async {
    ContentObject? selected;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => UniversalSearchPickerSheet(
        title: 'Vincular objeto',
        showClear: false,
        onSelected: (object) {
          selected = object;
          Navigator.pop(sheetContext);
        },
      ),
    );
    if (selected == null) return;
    setState(() {
      _items[index].text += ' [[${selected!.slug}]]';
    });
    _updateContent();
  }

  Future<void> _insertHighlight(int index) async {
    ContentObject? selected;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => UniversalSearchPickerSheet(
        title: 'Escolher objeto para citar',
        showClear: false,
        onSelected: (object) {
          selected = object;
          Navigator.pop(sheetContext);
        },
      ),
    );
    if (selected == null) return;

    final body = (selected as dynamic).body ?? (selected as dynamic).synopsis ?? '';
    final highlights = MarkdownParser.extractHighlights(body);
    if (highlights.isEmpty) {
      setState(() {
        _items[index].text += ' [[${selected!.slug}]]';
      });
      _updateContent();
      return;
    }

    if (!mounted) return;
    final hlSelected = await showModalBottomSheet<HighlightItem>(
      context: context, // ignore: use_build_context_synchronously
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => HighlightPickerSheet(
          objectTitle: selected!.title,
          highlights: highlights,
        ),
      ),
    );
    if (hlSelected == null) return;

    setState(() {
      _items[index].text += ' > "${hlSelected.text}" — [[${selected!.slug}]]';
    });
    _updateContent();
  }
}

class _TapGestureRecognizer extends TapGestureRecognizer {}

class OutlineItem {
  String id;
  String text;
  int level;
  bool isCompleted;

  OutlineItem({
    required this.id,
    required this.text,
    this.level = 0,
    this.isCompleted = false,
  });
}
