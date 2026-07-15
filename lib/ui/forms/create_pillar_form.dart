// lib/ui/forms/create_pillar_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/pillar_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';

class CreatePillarForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final Pillar? existingPillar;
  final List<OrganizerReference>? initialOrganizers;

  const CreatePillarForm({
    super.key,
    this.initialTitle,
    this.existingPillar,
    this.initialOrganizers,
  });

  @override
  ConsumerState<CreatePillarForm> createState() => _CreatePillarFormState();
}

class _CreatePillarFormState extends ConsumerState<CreatePillarForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _whyController;
  String _selectedColor = '#8B5CF6';
  List<OrganizerReference> _organizers = [];

  static const _colorSwatches = [
    '#DC2626',
    '#F97316',
    '#F59E0B',
    '#22C55E',
    '#14B8A6',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#6B7280',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = WikiLinkTextController(
      context: context,
      text: widget.existingPillar?.title ?? widget.initialTitle,
    );
    _whyController = TextEditingController(
      text: widget.existingPillar?.why ?? '',
    );
    _selectedColor = widget.existingPillar?.color ?? '#8B5CF6';
    _organizers = widget.existingPillar?.organizers ?? widget.initialOrganizers ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _whyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    final pillar = Pillar(
      id: widget.existingPillar?.id,
      title: _titleController.text.trim(),
      why: _whyController.text.trim().isEmpty ? null : _whyController.text.trim(),
      color: _selectedColor,
      organizers: _organizers,
      touchLog: widget.existingPillar?.touchLog ?? [],
      createdAt: widget.existingPillar?.createdAt,
      updatedAt: DateTime.now(),
      obsidianPath: widget.existingPillar?.obsidianPath ?? '',
    );

    try {
      if (widget.existingPillar != null) {
        await ref.read(pillarsProvider.notifier).updatePillar(pillar);
      } else {
        await ref.read(pillarsProvider.notifier).addPillar(pillar);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving pillar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPillar != null ? 'Edit Pillar' : 'New Pillar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildWhyField(),
            const SizedBox(height: 16),
            _buildColorPicker(),
            const SizedBox(height: 16),
            OrganizerSelectorField(
              selectedOrganizers: _organizers,
              onChanged: (value) => setState(() => _organizers = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Title',
        hintText: 'e.g., Health, Family, Career',
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildWhyField() {
    return TextField(
      controller: _whyController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Why (optional)',
        hintText: 'What does this pillar represent to you?',
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Color',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colorSwatches.map((color) {
            final isSelected = color == _selectedColor;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
