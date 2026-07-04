import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/note_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/markdown_parser.dart';
import '../../services/ocr_service.dart';
import '../theme.dart';
import '../widgets/ocr_text_section.dart';

class CreateScanDocumentForm extends ConsumerStatefulWidget {
  final String? initialTitle;

  const CreateScanDocumentForm({super.key, this.initialTitle});

  @override
  ConsumerState<CreateScanDocumentForm> createState() =>
      _CreateScanDocumentFormState();
}

class _CreateScanDocumentFormState
    extends ConsumerState<CreateScanDocumentForm> {
  late final TextEditingController _titleController;
  final TextEditingController _notesController = TextEditingController();
  final List<_DocumentAttachment> _attachments = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialTitle ?? 'Scanned Document',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        _attachments.isNotEmpty &&
        _titleController.text.trim().isNotEmpty &&
        !_saving;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Scan Document'),
        actions: [
          TextButton(
            onPressed: canSave ? _saveDocumentNote : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Document title',
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addCameraImage(ImageSource.camera),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Import'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_attachments.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration(context),
              child: const Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 40,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add a photo, PDF, or document file.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ..._attachments.map(_attachmentTile),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Add context, OCR text, or follow-up notes.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: canSave ? _saveDocumentNote : null,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save Document Note'),
            style: AppTheme.primaryButtonStyle,
          ),
        ],
      ),
    );
  }

  Widget _attachmentTile(_DocumentAttachment attachment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: AppTheme.cardDecoration(context),
          child: ListTile(
            leading: Icon(
              attachment.isImage
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              attachment.relativePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _attachments.remove(attachment)),
            ),
          ),
        ),
        if (attachment.isImage)
          OcrTextSection(
            state: attachment.ocrState,
            text: attachment.ocrText,
            sourceImageLabel: attachment.name,
            initiallyExpanded: attachment.ocrState == OcrSectionState.loaded &&
                attachment.ocrText.isNotEmpty,
            onTextChanged: (text) {
              final idx = _attachments.indexOf(attachment);
              if (idx >= 0) {
                setState(() {
                  _attachments[idx] = attachment.copyWith(ocrText: text);
                });
              }
            },
            onRetry: () => _retryOcr(attachment),
          ),
      ],
    );
  }

  Future<void> _addCameraImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source);
    if (image == null) return;
    await _saveAttachment(File(image.path), image.name, isImage: true);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'heic',
        'pdf',
        'doc',
        'docx',
        'txt',
        'md',
      ],
    );
    if (result == null) return;

    for (final file in result.files) {
      if (file.path == null) continue;
      final ext = file.extension?.toLowerCase();
      await _saveAttachment(
        File(file.path!),
        file.name,
        isImage: ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'heic',
      );
    }
  }

  Future<void> _saveAttachment(
    File file,
    String name, {
    required bool isImage,
  }) async {
    final obsidian = ref.read(obsidianServiceProvider);
    final relativePath = await obsidian.saveAttachment(file);
    if (!mounted || relativePath == null) return;

    OcrSectionState ocrState = OcrSectionState.empty;
    String ocrText = '';
    Future<OcrResult>? ocrFuture;
    if (isImage) {
      ocrState = OcrSectionState.loading;
      ocrFuture = OcrService.extractText(file);
    }

    setState(() {
      _attachments.add(
        _DocumentAttachment(
          name: name,
          relativePath: relativePath,
          isImage: isImage,
          ocrState: ocrState,
          ocrText: ocrText,
        ),
      );
    });

    if (ocrFuture != null) {
      try {
        final result = await ocrFuture;
        if (!mounted) return;
        setState(() {
          final idx = _attachments.indexWhere((a) => a.relativePath == relativePath);
          if (idx < 0) return;
          final att = _attachments[idx];
          _attachments[idx] = att.copyWith(
            ocrText: result.text,
            ocrState: result.hasText
                ? OcrSectionState.loaded
                : OcrSectionState.empty,
          );
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          final idx = _attachments.indexWhere((a) => a.relativePath == relativePath);
          if (idx >= 0) {
            _attachments[idx] =
                _attachments[idx].copyWith(ocrState: OcrSectionState.error);
          }
        });
      }
    }
  }

  Future<void> _retryOcr(_DocumentAttachment attachment) async {
    final idx = _attachments.indexOf(attachment);
    if (idx < 0) return;
    setState(() => _attachments[idx] = attachment.copyWith(
          ocrState: OcrSectionState.loading,
        ));
    try {
      final vaultPath = ref.read(obsidianServiceProvider).vaultPath;
      final file = File('$vaultPath/_attachments/${attachment.relativePath}');
      final result = await OcrService.extractText(file);
      if (!mounted) return;
      setState(() {
        _attachments[idx] = attachment.copyWith(
          ocrText: result.text,
          ocrState: result.hasText
              ? OcrSectionState.loaded
              : OcrSectionState.empty,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _attachments[idx] =
            attachment.copyWith(ocrState: OcrSectionState.error);
      });
    }
  }

  Future<void> _saveDocumentNote() async {
    setState(() => _saving = true);
    final body = StringBuffer();
    if (_notesController.text.trim().isNotEmpty) {
      body.writeln(_notesController.text.trim());
      body.writeln();
    }
    body.writeln('## Attachments');
    for (final attachment in _attachments) {
      body.writeln('- ![[${attachment.relativePath}]]');
    }

    var finalBody = body.toString().trim();
    for (final attachment in _attachments) {
      if (attachment.isImage && attachment.ocrText.trim().isNotEmpty) {
        finalBody = MarkdownParser.upsertOcrSection(
          finalBody,
          attachment.relativePath,
          attachment.ocrText.trim(),
        );
      }
    }

    final note = Note(
      title: _titleController.text.trim(),
      subtype: NoteSubtype.text,
      body: finalBody,
      categories: const ['[[notes]]', '[[documents]]'],
    );
    await ref.read(notesProvider.notifier).addNote(note);
    if (!mounted) return;
    Navigator.pop(context);
  }
}

class _DocumentAttachment {
  final String name;
  final String relativePath;
  final bool isImage;
  final OcrSectionState ocrState;
  final String ocrText;

  const _DocumentAttachment({
    required this.name,
    required this.relativePath,
    required this.isImage,
    this.ocrState = OcrSectionState.empty,
    this.ocrText = '',
  });

  _DocumentAttachment copyWith({
    OcrSectionState? ocrState,
    String? ocrText,
  }) {
    return _DocumentAttachment(
      name: name,
      relativePath: relativePath,
      isImage: isImage,
      ocrState: ocrState ?? this.ocrState,
      ocrText: ocrText ?? this.ocrText,
    );
  }
}
