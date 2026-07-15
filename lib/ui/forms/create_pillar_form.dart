// lib/ui/forms/create_pillar_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/pillar_model.dart';
import '../../models/shared_types.dart';
import '../../models/action_menu_item_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';
import '../widgets/universal_search_picker.dart';
import '../widgets/icon_picker.dart';
import '../widgets/form_section_card.dart';
import '../utils/material_icon_set.dart';

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
  String? _selectedIcon;
  List<OrganizerReference> _organizers = [];
  List<ActionMenuItem> _linkedActions = [];

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
    _selectedIcon = widget.existingPillar?.icon;
    _organizers = widget.existingPillar?.organizers ?? widget.initialOrganizers ?? [];
    
    // Load linked actions by filtering all actions that reference this pillar
    if (widget.existingPillar != null) {
      final allActions = ref.read(actionMenuItemsProvider);
      _linkedActions = allActions.where((action) => 
        action.organizers.any((org) => 
          org.type == 'pillar' && org.slug == widget.existingPillar!.slug
        )
      ).toList();
    }
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
      icon: _selectedIcon,
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
            FormSectionCard(
              title: 'Basic Info',
              children: [
                _buildTitleField(),
                const SizedBox(height: 16),
                _buildWhyField(),
              ],
            ),
            const SizedBox(height: 16),
            FormSectionCard(
              title: 'Appearance',
              children: [
                _buildColorPicker(),
                const SizedBox(height: 16),
                _buildIconPicker(),
              ],
            ),
            const SizedBox(height: 16),
            _buildActionMenuSection(),
            const SizedBox(height: 16),
            FormSectionCard(
              title: 'Organizers',
              children: [
                OrganizerSelectorField(
                  selectedOrganizers: _organizers,
                  onChanged: (value) => setState(() => _organizers = value),
                ),
              ],
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

  Widget _buildIconPicker() {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => IconPicker(
            selectedIconName: _selectedIcon,
            onIconSelected: (iconName) {
              setState(() => _selectedIcon = iconName);
              Navigator.pop(context);
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (_selectedIcon != null)
              Icon(
                MaterialIconSet.getIcon(_selectedIcon!),
                size: 24,
                color: AppTheme.accentColor(context),
              )
            else
              Icon(
                Icons.account_balance,
                size: 24,
                color: AppColors.textMuted,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedIcon ?? 'Select icon',
                style: TextStyle(
                  color: _selectedIcon != null
                      ? AppTheme.textPrimaryColor(context)
                      : AppColors.textMuted,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
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

  Widget _buildActionMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Action Menu',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Link actions to this pillar for quick access',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _buildEnergyLevelGroup(EnergyLevel.low, 'Low Energy'),
        const SizedBox(height: 8),
        _buildEnergyLevelGroup(EnergyLevel.medium, 'Medium Energy'),
        const SizedBox(height: 8),
        _buildEnergyLevelGroup(EnergyLevel.high, 'High Energy'),
      ],
    );
  }

  Widget _buildEnergyLevelGroup(EnergyLevel level, String label) {
    final levelActions = _linkedActions.where((a) => a.energyLevel == level).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        if (levelActions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No actions linked',
              style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context)),
            ),
          )
        else
          ...levelActions.map((action) => ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            leading: const Icon(Icons.bolt, size: 16),
            title: Text(action.title, style: const TextStyle(fontSize: 13)),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _linkedActions.remove(action)),
            ),
          )),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => _showActionPicker(level),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add action', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }

  Future<void> _showActionPicker(EnergyLevel level) async {
    final pillarSlug = _titleController.text.trim().toLowerCase().replaceAll(' ', '-');
    
    final selected = await showModalBottomSheet<ContentObject>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UniversalSearchPickerSheet(
        title: 'Select Action',
        initialFilter: 'action',
        onSelected: (obj) => Navigator.pop(context, obj),
      ),
    );

    if (selected != null && selected is ActionMenuItem) {
      // Link the action to this pillar
      final updatedAction = selected.copyWith(
        organizers: [
          ...selected.organizers,
          OrganizerReference(type: 'pillar', slug: pillarSlug, title: _titleController.text.trim()),
        ],
      );
      
      await ref.read(actionMenuItemsProvider.notifier).updateActionMenuItem(updatedAction);
      
      setState(() {
        if (!_linkedActions.any((a) => a.id == updatedAction.id)) {
          _linkedActions.add(updatedAction);
        }
      });
    }
  }
}
