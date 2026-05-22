// lib/ui/components/outline_editor.dart
import 'package:flutter/material.dart';

class OutlineNode {
  String text;
  int indent;
  bool isCompleted;

  OutlineNode({required this.text, this.indent = 0, this.isCompleted = false});
}

class OutlineEditor extends StatefulWidget {
  final List<OutlineNode> initialNodes;
  final Function(List<OutlineNode>) onChanged;

  const OutlineEditor({
    super.key,
    required this.initialNodes,
    required this.onChanged,
  });

  @override
  State<OutlineEditor> createState() => _OutlineEditorState();
}

class _OutlineEditorState extends State<OutlineEditor> {
  late List<OutlineNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = List.from(widget.initialNodes);
    if (_nodes.isEmpty) _nodes.add(OutlineNode(text: ''));
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _nodes.length,
      itemBuilder: (context, index) {
        final node = _nodes[index];
        return Padding(
          padding: EdgeInsets.only(left: node.indent * 20.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  node.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => node.isCompleted = !node.isCompleted);
                  widget.onChanged(_nodes);
                },
              ),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: node.text)
                    ..selection = TextSelection.collapsed(
                      offset: node.text.length,
                    ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Start typing...',
                  ),
                  onChanged: (v) {
                    node.text = v;
                    widget.onChanged(_nodes);
                  },
                  onSubmitted: (v) {
                    setState(() {
                      _nodes.insert(
                        index + 1,
                        OutlineNode(text: '', indent: node.indent),
                      );
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.format_indent_increase, size: 18),
                onPressed: () {
                  setState(() => node.indent++);
                  widget.onChanged(_nodes);
                },
              ),
              IconButton(
                icon: const Icon(Icons.format_indent_decrease, size: 18),
                onPressed: () {
                  setState(() => node.indent = (node.indent - 1).clamp(0, 5));
                  widget.onChanged(_nodes);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
