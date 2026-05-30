// lib/ui/widgets/rich_text_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wiki_link_picker.dart';
import '../theme.dart';
import '../../providers/vault_provider.dart';
import 'dart:async';

class RichTextEditor extends ConsumerStatefulWidget {
  final String content;
  final Function(String) onChanged;
  final String placeholder;
  final bool expands;

  const RichTextEditor({
    super.key,
    required this.content,
    required this.onChanged,
    this.placeholder = 'Write your thoughts...',
    this.expands = true,
  });

  @override
  ConsumerState<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends ConsumerState<RichTextEditor>
    with WidgetsBindingObserver {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  OverlayEntry? _toolbarOverlay;
  bool _wikiPickerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(() {
      if (mounted) setState(() {});
      _syncToolbarOverlay();
    });
    _loadContent();
  }

  @override
  void didChangeMetrics() {
    _toolbarOverlay?.markNeedsBuild();
  }

  void _loadContent() {
    try {
      if (widget.content.trim().startsWith('[') ||
          widget.content.trim().startsWith('{')) {
        final doc = Document.fromJson(jsonDecode(widget.content));
        _controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        // Fallback to plain text if not JSON
        _controller = QuillController(
          document: Document()..insert(0, widget.content),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (e) {
      _controller = QuillController.basic();
    }

    _controller.addListener(() {
      final json = jsonEncode(_controller.document.toDelta().toJson());

      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          widget.onChanged(json);
        }
      });

      // Check if user just typed '[['
      final selection = _controller.selection;
      if (selection.isCollapsed && selection.baseOffset >= 2) {
        final text = _controller.document.toPlainText();
        if (selection.baseOffset <= text.length) {
          final lastTwoChars = text.substring(
            selection.baseOffset - 2,
            selection.baseOffset,
          );
          if (lastTwoChars == '[[') {
            _onAddWikiLink(
              isEmbed: false,
              replaceStart: selection.baseOffset - 2,
              replaceLength: 2,
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeToolbarOverlay();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncToolbarOverlay() {
    if (_focusNode.hasFocus) {
      if (_toolbarOverlay != null) {
        _toolbarOverlay!.markNeedsBuild();
        return;
      }

      _toolbarOverlay = OverlayEntry(
        builder: (overlayContext) {
          final bottomInset = MediaQuery.of(overlayContext).viewInsets.bottom;
          final isDark = Theme.of(overlayContext).brightness == Brightness.dark;

          return Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: Material(
              color: Colors.transparent,
              child: _buildToolbar(isDark),
            ),
          );
        },
      );

      Overlay.of(context, rootOverlay: true).insert(_toolbarOverlay!);
    } else {
      _removeToolbarOverlay();
    }
  }

  void _removeToolbarOverlay() {
    _toolbarOverlay?.remove();
    _toolbarOverlay = null;
  }

  Future<void> _onAddPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final file = File(image.path);
      final obsidian = ref.read(obsidianServiceProvider);
      final relPath = await obsidian.saveAttachment(file);

      if (relPath != null) {
        final index = _controller.selection.baseOffset;
        final length = _controller.selection.extentOffset - index;
        // Obsidian syntax for inline image
        _controller.replaceText(index, length, '![[$relPath]]\n', null);
      }
    }
  }

  void _onAddWikiLink({
    bool isEmbed = false,
    int? replaceStart,
    int? replaceLength,
  }) {
    if (_wikiPickerOpen) return;
    _wikiPickerOpen = true;
    final selection = _controller.selection;
    final start = replaceStart ?? selection.baseOffset;
    final length =
        replaceLength ?? (selection.extentOffset - selection.baseOffset);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WikiLinkPicker(
        onSelected: (obj) {
          final prefix = isEmbed ? '!' : '';
          final insert = '$prefix[[${obj.title}]]';
          _controller.replaceText(
            start.clamp(0, _controller.document.length),
            length,
            insert,
            TextSelection.collapsed(offset: start + insert.length),
          );
          Navigator.pop(context);
        },
      ),
    ).whenComplete(() => _wikiPickerOpen = false);
  }

  void _onAddMention() {
    _onAddWikiLink(
      isEmbed: false,
    ); // Mentions are just @WikiLinks or [[WikiLinks]] in our system
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.expands) Expanded(child: _buildEditor()) else _buildEditor(),
      ],
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      key: const ValueKey('rich-text-toolbar'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.divider,
          ),
        ),
      ),
      child: QuillSimpleToolbar(
        controller: _controller,
        config: QuillSimpleToolbarConfig(
          multiRowsDisplay: false,
          toolbarSize: 44,
          showFontFamily: false,
          showFontSize: false,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: false,
          showColorButton: true,
          showBackgroundColorButton: false,
          showListBullets: true,
          showListNumbers: true,
          showListCheck: true,
          showCodeBlock: false,
          showQuote: true,
          showIndent: false,
          showLink: true,
          showSearchButton: false,
          showAlignmentButtons: false,
          showDirection: false,
          showUndo: true,
          showRedo: true,
          showClearFormat: true,
          showDividers: true,
          showHeaderStyle: true,
          customButtons: [
            QuillToolbarCustomButtonOptions(
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
              onPressed: _onAddPhoto,
              tooltip: 'Anexar Foto',
            ),
            QuillToolbarCustomButtonOptions(
              icon: const Icon(Icons.alternate_email_rounded, size: 20),
              onPressed: _onAddMention,
              tooltip: 'Mencionar (@)',
            ),
            QuillToolbarCustomButtonOptions(
              icon: const Icon(Icons.note_add_outlined, size: 20),
              onPressed: () => _onAddWikiLink(isEmbed: true),
              tooltip: 'Incorporar Nota (![[ ]])',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return QuillEditor.basic(
      controller: _controller,
      focusNode: _focusNode,
      config: QuillEditorConfig(
        placeholder: widget.placeholder,
        padding: const EdgeInsets.all(20),
        autoFocus: false,
        expands: widget.expands,
      ),
    );
  }
}
