import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/organizer_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../widgets/organizer_selector_field.dart';
import '../theme.dart';

class CreateOrganizerForm extends ConsumerStatefulWidget {
  final OrganizerType? initialType;
  final Organizer? organizer;
  const CreateOrganizerForm({super.key, this.initialType, this.organizer});

  @override
  ConsumerState<CreateOrganizerForm> createState() =>
      _CreateOrganizerFormState();
}

class _CreateOrganizerFormState extends ConsumerState<CreateOrganizerForm> {
  final _titleController = TextEditingController();
  OrganizerType _type = OrganizerType.area;
  String _selectedColor = '#3B82F6';
  String? _parentId;
  List<OrganizerReference> _organizers = [];

  static const _colors = [
    '#DC2626',
    '#F97316',
    '#F59E0B',
    '#10B981',
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
    if (widget.initialType != null) _type = widget.initialType!;
    final organizer = widget.organizer;
    if (organizer != null) {
      _titleController.text = organizer.title;
      _type = organizer.organizerType;
      _selectedColor = organizer.color ?? _selectedColor;
      _parentId = organizer.parentId;
      _organizers = organizer.organizers != null ? List.from(organizer.organizers) : [];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = _titleController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.organizer == null
                  ? 'Novo Organizador'
                  : 'Edit Organizador',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: hasTitle ? _saveOrganizer : null,
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: hasTitle ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Organizer Title',
                      hintStyle: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Tipo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: OrganizerType.values.map((t) {
                      final selected = _type == t;
                      return ChoiceChip(
                        label: Text(
                          t.name[0].toUpperCase() + t.name.substring(1),
                        ),
                        selected: selected,
                        onSelected: (v) => setState(() => _type = t),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceVariant,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                  const SizedBox(height: 24),
                  const Text(
                    'Cor',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final hex = _colors[index];
                        final color = _parseColor(hex);
                        final selected = _selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: selected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Parente (Família)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final allOrganizers = ref.watch(organizersProvider);
                      // Avoid self-reference if editing
                      final availableParents = allOrganizers
                          .where((o) => widget.organizer == null || o.id != widget.organizer!.id)
                          .toList();

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _parentId,
                            isExpanded: true,
                            hint: const Text('Sem Parente'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Sem Parente (Raiz)'),
                              ),
                              ...availableParents.map(
                                (o) => DropdownMenuItem<String?>(
                                  value: o.id,
                                  child: Text(o.title),
                                ),
                              ),
                            ],
                            onChanged: (val) => setState(() => _parentId = val),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Vincular Organizadores',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: OrganizerSelectorField(
                      selectedOrganizers: _organizers,
                      onChanged: (val) => setState(() => _organizers = val),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveOrganizer() {
    final existing = widget.organizer;
    final organizer = Organizer(
      id: existing?.id,
      title: _titleController.text.trim(),
      organizerType: _type,
      color: _selectedColor,
      parentId: _parentId,
      startDate: existing?.startDate,
      endDate: existing?.endDate,
      icon: existing?.icon,
      organizers: _organizers,
      categories: existing?.categories,
      moc: existing?.moc,
      createdAt: existing?.createdAt,
      obsidianPath: existing?.obsidianPath ?? '',
    );

    if (existing == null) {
      ref.read(organizersProvider.notifier).addOrganizer(organizer);
    } else {
      ref.read(organizersProvider.notifier).updateOrganizer(organizer);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Organizador "${organizer.title}" salvo com sucesso!'),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
