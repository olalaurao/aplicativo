import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/snapshot_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';

class CreateSnapshotForm extends ConsumerStatefulWidget {
  final String? initialTitle;

  const CreateSnapshotForm({super.key, this.initialTitle});

  @override
  ConsumerState<CreateSnapshotForm> createState() => _CreateSnapshotFormState();
}

class _CreateSnapshotFormState extends ConsumerState<CreateSnapshotForm> {
  late final TextEditingController _titleController;
  final TextEditingController _reflectionController = TextEditingController();
  String? _attachmentPath;
  String? _previewPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text:
          widget.initialTitle ??
          'Snapshot ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        _attachmentPath != null &&
        _titleController.text.trim().isNotEmpty &&
        !_saving;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Snapshot'),
        actions: [
          TextButton(
            onPressed: canSave ? _saveSnapshot : null,
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
              hintText: 'Snapshot title',
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickPhoto,
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: AppTheme.cardDecoration(context),
                clipBehavior: Clip.antiAlias,
                child: _previewPath == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_a_photo_rounded,
                              color: AppColors.textMuted,
                              size: 36,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add photo',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Image.file(File(_previewPath!), fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reflectionController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Reflection',
              hintText: 'What should this snapshot remember?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: canSave ? _saveSnapshot : null,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save Snapshot'),
            style: AppTheme.primaryButtonStyle(AppTheme.accentColor(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo Library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await ImagePicker().pickImage(source: source);
    if (image == null) return;

    final obsidian = ref.read(obsidianServiceProvider);
    final relativePath = await obsidian.saveAttachment(File(image.path));
    if (!mounted || relativePath == null) return;

    setState(() {
      _attachmentPath = relativePath;
      _previewPath = '${obsidian.vaultDir!.path}/$relativePath';
    });
  }

  Future<void> _saveSnapshot() async {
    if (_attachmentPath == null) return;
    setState(() => _saving = true);

    final reflection = [
      if (_reflectionController.text.trim().isNotEmpty)
        _reflectionController.text.trim(),
      '![[${_attachmentPath!}]]',
    ].join('\n\n');

    final snapshot = Snapshot(
      title: _titleController.text.trim(),
      parentId: 'inbox',
      kpiValues: const {},
      reflection: reflection,
      date: DateTime.now(),
    );

    await ref.read(snapshotsProvider.notifier).addSnapshot(snapshot);
    if (!mounted) return;
    Navigator.pop(context);
  }
}
