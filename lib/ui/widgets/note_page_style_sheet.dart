import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/note_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/app_color_picker.dart';

class NotePageStyleSheet extends ConsumerStatefulWidget {
  final Note note;

  const NotePageStyleSheet({super.key, required this.note});

  @override
  ConsumerState<NotePageStyleSheet> createState() => _NotePageStyleSheetState();
}

class _NotePageStyleSheetState extends ConsumerState<NotePageStyleSheet> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickCoverImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      final obsidianService = ref.read(obsidianServiceProvider);
      final relativePath = await obsidianService.saveAttachment(
        File(image.path),
      );

      if (relativePath != null && mounted) {
        ref.read(vaultProvider.notifier).updateObject(
          widget.note.copyWith(coverImagePath: relativePath),
        );
        Navigator.pop(context);
      }
    }
  }

  void _clearCoverImage() {
    ref.read(vaultProvider.notifier).updateObject(
      widget.note.copyWith(coverImagePath: null),
    );
    Navigator.pop(context);
  }

  void _openColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AppColorPicker(
        value: widget.note.color ?? '',
        onChanged: (color) {
          ref.read(vaultProvider.notifier).updateObject(
            widget.note.copyWith(color: color),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.sheetDecoration(context),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Page Style',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Cover Image Section
          const Text(
            'Cover Image',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCoverImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Choose Image'),
                ),
              ),
              if (widget.note.coverImagePath != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _clearCoverImage,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Remove'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Accent Color Section
          const Text(
            'Accent Color',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _openColorPicker,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.note.color != null
                          ? _parseColor(widget.note.color!)
                          : AppTheme.accentColor(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.note.color ?? 'Default accent',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceAll('#', '0xFF')));
    } catch (e) {
      return AppColors.primary;
    }
  }
}
