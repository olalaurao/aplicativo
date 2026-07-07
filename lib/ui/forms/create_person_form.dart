// lib/ui/forms/create_person_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/people_model.dart';
import '../../models/task_model.dart';
import '../theme.dart';
import '../widgets/wiki_link_controller.dart';
import '../../providers/vault_provider.dart';

class CreatePersonForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final Person? existingPerson;
  const CreatePersonForm({super.key, this.initialTitle, this.existingPerson});

  @override
  ConsumerState<CreatePersonForm> createState() => _CreatePersonFormState();
}

class _CreatePersonFormState extends ConsumerState<CreatePersonForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _photoUrlController;
  late final TextEditingController _frequencyController;
  int _contactFrequencyDays = 14;
  TaskPriority _priority = TaskPriority.none;

  @override
  void initState() {
    super.initState();
    _nameController = WikiLinkTextController(
      context: context,
      text: widget.existingPerson?.title ?? widget.initialTitle ?? '',
    );
    _photoUrlController = WikiLinkTextController(
      context: context,
      text: widget.existingPerson?.photo ?? '',
    );
    _frequencyController = TextEditingController(text: '14');

    if (widget.existingPerson != null) {
      final person = widget.existingPerson!;
      _contactFrequencyDays = person.contactFrequency?.inDays ?? 14;
      _frequencyController.text = _contactFrequencyDays.toString();
      _priority = person.contactPriority;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoUrlController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasName = _nameController.text.trim().isNotEmpty;

    final isDirty = _nameController.text.trim().isNotEmpty;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text('Você possui alterações não salvas. Deseja sair mesmo assim?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if ((discard ?? false) && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child:  Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'New Person',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Full Name',
                      hintStyle: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildFieldRow(
                          'Photo URL',
                          _photoUrlController,
                          'https://...',
                        ),
                        const Divider(height: 32),
                        _buildFrequencyRow(),
                        const Divider(height: 32),
                        _buildPriorityRow(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: hasName ? _savePerson : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Add Person',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildFieldRow(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentColor(context),
            ),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyRow() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Frequency',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 148,
          child: TextField(
            controller: _frequencyController,
            textAlign: TextAlign.end,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentColor(context),
            ),
            decoration: const InputDecoration(
              prefixText: 'Every ',
              suffixText: ' days',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed > 0) {
                _contactFrequencyDays = parsed;
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityRow() {
    return Row(
      children: [
        const Text(
          'Contact Priority',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        DropdownButton<TaskPriority>(
          value: _priority,
          underline: const SizedBox(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.accentColor(context),
          ),
          onChanged: (val) => setState(() => _priority = val!),
          items: TaskPriority.values
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name.toUpperCase()),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  void _savePerson() {
    final parsedFrequency = int.tryParse(_frequencyController.text.trim());
    if (parsedFrequency != null && parsedFrequency > 0) {
      _contactFrequencyDays = parsedFrequency;
    }

    final person = Person(
      id:
          widget.existingPerson?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: widget.existingPerson?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      title: _nameController.text.trim(),
      photo: _photoUrlController.text.trim().isEmpty
          ? null
          : _photoUrlController.text.trim(),
      contactFrequency: Duration(days: _contactFrequencyDays),
      contactPriority: _priority,
      lastContactDate: widget.existingPerson?.lastContactDate ?? DateTime.now(),
      phone: widget.existingPerson?.phone,
      email: widget.existingPerson?.email,
      organizers: widget.existingPerson?.organizers,
      obsidianPath: widget.existingPerson?.obsidianPath ?? '',
    );

    if (widget.existingPerson != null) {
      ref.read(vaultProvider.notifier).updateObject(person);
    } else {
      ref.read(peopleProvider.notifier).addPerson(person);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Person "${person.title}" ${widget.existingPerson != null ? 'updated' : 'added'} successfully!',
        ),
      ),
    );
  }
}
