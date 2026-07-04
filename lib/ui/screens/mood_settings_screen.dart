// lib/ui/screens/mood_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mood_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/app_color_picker.dart';

class MoodSettingsScreen extends ConsumerWidget {
  const MoodSettingsScreen({super.key});

  static const int _maxUserMoods = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(moodsProvider);
    final userMoodCount = moods
        .where((mood) => mood.source == MoodSource.user)
        .length;
    final canAdd = userMoodCount < _maxUserMoods;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Settings'),
        actions: [
          TextButton.icon(
            onPressed: canAdd
                ? () => _openMoodForm(context, ref, null)
                : () => _showMaxMoodsMessage(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ],
      ),
      body: SafeArea(
        child: moods.isEmpty
            ? _MoodEmptyState(onAdd: () => _openMoodForm(context, ref, null))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _MoodHeader(configured: userMoodCount, max: _maxUserMoods),
                  const SizedBox(height: 12),
                  for (final quadrant in MoodQuadrant.values)
                    _MoodQuadrantSection(
                      quadrant: quadrant,
                      moods: _moodsForQuadrant(moods, quadrant),
                      onToggleHidden: (mood) => ref
                          .read(moodsProvider.notifier)
                          .updateMood(mood.copyWith(hidden: !mood.hidden)),
                      onOpen: (mood) => _showMoodDetails(context, ref, mood),
                    ),
                ],
              ),
      ),
      floatingActionButton: moods.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: canAdd
                  ? () => _openMoodForm(context, ref, null)
                  : () => _showMaxMoodsMessage(context),
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  List<MoodDefinition> _moodsForQuadrant(
    List<MoodDefinition> moods,
    MoodQuadrant quadrant,
  ) {
    return moods.where((mood) => mood.quadrant == quadrant).toList()
      ..sort((a, b) {
        final bySource = a.source.index.compareTo(b.source.index);
        if (bySource != 0) return bySource;
        final byOrder = (a.order ?? a.pleasantness).compareTo(
          b.order ?? b.pleasantness,
        );
        if (byOrder != 0) return byOrder;
        return a.title.compareTo(b.title);
      });
  }

  void _openMoodForm(
    BuildContext context,
    WidgetRef ref,
    MoodDefinition? mood,
  ) {
    if (mood == null) {
      final userMoodCount = ref
          .read(moodsProvider)
          .where((m) => m.source == MoodSource.user)
          .length;
      if (userMoodCount >= _maxUserMoods) {
        _showMaxMoodsMessage(context);
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MoodFormScreen(mood: mood),
      ),
    );
  }

  void _showMoodDetails(
    BuildContext context,
    WidgetRef ref,
    MoodDefinition mood,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _MoodDetailSheet(
        mood: mood,
        onUpdate: (updated) =>
            ref.read(moodsProvider.notifier).updateMood(updated),
        onEdit: mood.source == MoodSource.user
            ? () {
                Navigator.pop(sheetContext);
                _openMoodForm(context, ref, mood);
              }
            : null,
        onEditCoordinates: mood.source == MoodSource.system
            ? () {
                Navigator.pop(sheetContext);
                _openMoodForm(context, ref, mood);
              }
            : null,
        onDelete: mood.source == MoodSource.user
            ? () async {
                final confirmed = await _confirmDeleteMood(sheetContext, mood);
                if (confirmed != true) return;
                await ref.read(moodsProvider.notifier).deleteMood(mood);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              }
            : null,
      ),
    );
  }

  Future<bool?> _confirmDeleteMood(BuildContext context, MoodDefinition mood) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${mood.label}?'),
        content: const Text(
          "Historical records are preserved, but this mood won't appear in the picker.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMaxMoodsMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You already have 20 custom moods.')),
    );
  }
}

class _MoodQuadrantSection extends StatelessWidget {
  final MoodQuadrant quadrant;
  final List<MoodDefinition> moods;
  final ValueChanged<MoodDefinition> onToggleHidden;
  final ValueChanged<MoodDefinition> onOpen;

  const _MoodQuadrantSection({
    required this.quadrant,
    required this.moods,
    required this.onToggleHidden,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = MoodDefinition.quadrantColor(quadrant);
    final visible = moods.where((mood) => !mood.hidden).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: color,
        collapsedIconColor: color,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _quadrantTitle(quadrant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$visible of ${moods.length} visible',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        subtitle: Text(
          _quadrantDescription(quadrant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        children: moods.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No moods in this quadrant yet.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              ]
            : moods
                  .map(
                    (mood) => _MoodRow(
                      mood: mood,
                      color: color,
                      onToggleHidden: () => onToggleHidden(mood),
                      onTap: () => onOpen(mood),
                    ),
                  )
                  .toList(),
      ),
    );
  }

  String _quadrantTitle(MoodQuadrant quadrant) => switch (quadrant) {
    MoodQuadrant.red => 'Red',
    MoodQuadrant.yellow => 'Yellow',
    MoodQuadrant.green => 'Green',
    MoodQuadrant.blue => 'Blue',
  };

  String _quadrantDescription(MoodQuadrant quadrant) => switch (quadrant) {
    MoodQuadrant.red => 'High energy · Unpleasant',
    MoodQuadrant.yellow => 'High energy · Pleasant',
    MoodQuadrant.green => 'Low energy · Pleasant',
    MoodQuadrant.blue => 'Low energy · Unpleasant',
  };
}

class _MoodRow extends StatelessWidget {
  final MoodDefinition mood;
  final Color color;
  final VoidCallback onToggleHidden;
  final VoidCallback onTap;

  const _MoodRow({
    required this.mood,
    required this.color,
    required this.onToggleHidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Text(mood.emoji, style: const TextStyle(fontSize: 22)),
      title: Text(
        mood.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        mood.description?.trim().isNotEmpty == true
            ? mood.description!.trim()
            : 'Pleasantness ${mood.pleasantness}/10 · Energy ${mood.energy}/10',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mood.source == MoodSource.system)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'System',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          if (mood.source == MoodSource.user)
            const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted),
          Switch.adaptive(
            value: !mood.hidden,
            activeThumbColor: color,
            onChanged: (_) => onToggleHidden(),
          ),
        ],
      ),
    );
  }
}

class _MoodDetailSheet extends StatefulWidget {
  final MoodDefinition mood;
  final ValueChanged<MoodDefinition> onUpdate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onEditCoordinates;

  const _MoodDetailSheet({
    required this.mood,
    required this.onUpdate,
    this.onEdit,
    this.onDelete,
    this.onEditCoordinates,
  });

  @override
  State<_MoodDetailSheet> createState() => _MoodDetailSheetState();
}

class _MoodDetailSheetState extends State<_MoodDetailSheet> {
  late MoodDefinition _mood;

  @override
  void initState() {
    super.initState();
    _mood = widget.mood;
  }

  @override
  Widget build(BuildContext context) {
    final color = MoodDefinition.quadrantColor(_mood.quadrant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(_mood.emoji, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _mood.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_mood.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _mood.description!.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _InfoRow(
              title: 'Quadrant',
              child: Chip(
                label: Text(_mood.quadrant.name.toUpperCase()),
                backgroundColor: color.withValues(alpha: 0.14),
                labelStyle: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _InfoRow(
              title: 'Values',
              child: Text(
                'Pleasantness: ${_mood.pleasantness}/10 · Energy: ${_mood.energy}/10',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aliases',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final alias in _mood.aliases)
                  InputChip(
                    label: Text(alias),
                    onDeleted: () => _updateAliases(
                      _mood.aliases.where((item) => item != alias).toList(),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add alias'),
                  onPressed: _addAlias,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: !_mood.hidden,
              activeThumbColor: color,
              title: const Text('Show in picker'),
              subtitle: const Text('Hiding preserves all historical records.'),
              onChanged: (_) => _update(_mood.copyWith(hidden: !_mood.hidden)),
            ),
            if (widget.onEdit != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit mood'),
                ),
              ),
            ],
            if (widget.onEditCoordinates != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmEditCoordinates,
                  icon: const Icon(Icons.tune_outlined),
                  label: const Text('Edit coordinates'),
                ),
              ),
            ],
            if (widget.onDelete != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete mood'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Center(
              child: Text(
                _mood.source == MoodSource.system
                    ? 'System moods cannot be fully edited. You can add aliases and hide.'
                    : 'Custom moods can be edited or hidden at any time.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAlias() async {
    final controller = TextEditingController();
    final alias = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add alias'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search alias'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = alias?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    _updateAliases({..._mood.aliases, trimmed}.toList());
  }

  void _updateAliases(List<String> aliases) {
    _update(_mood.copyWith(aliases: aliases));
  }

  void _update(MoodDefinition mood) {
    setState(() => _mood = mood);
    widget.onUpdate(mood);
  }

  Future<void> _confirmEditCoordinates() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit coordinates?'),
        content: const Text(
          'This changes how this mood appears from now on. Past check-ins and charts won\'t change retroactively.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed == true && widget.onEditCoordinates != null) {
      widget.onEditCoordinates!();
    }
  }
}

class _MoodFormScreen extends ConsumerStatefulWidget {
  final MoodDefinition? mood;

  const _MoodFormScreen({this.mood});

  @override
  ConsumerState<_MoodFormScreen> createState() => _MoodFormScreenState();
}

class _MoodFormScreenState extends ConsumerState<_MoodFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _aliasController;
  String _emoji = '😐';
  MoodQuadrant _quadrant = MoodQuadrant.green;
  int _pleasantness = 4;
  int _energy = 2;
  String _color = '#66BB6A';
  final List<String> _aliases = [];

  @override
  void initState() {
    super.initState();
    final mood = widget.mood;
    _nameController = TextEditingController(text: mood?.label ?? '');
    _descriptionController = TextEditingController(
      text: mood?.description ?? '',
    );
    _aliasController = TextEditingController();
    if (mood != null) {
      _emoji = mood.emoji;
      _quadrant = mood.quadrant;
      _pleasantness = mood.pleasantness;
      _energy = mood.energy;
      _color = mood.color;
      _aliases.addAll(mood.aliases);
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.mood == null;
    final canSave = _nameController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isNew ? 'New mood' : 'Edit mood'),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            const _SectionLabel(
              title: 'What do you call this feeling?',
              helper: 'This name will appear in the picker.',
            ),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Flow, Nostalgic, Focused',
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel(title: 'Emoji'),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _showEmojiPicker,
                  child: const Text('Choose emoji'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel(title: 'How do you feel?'),
            _QuadrantGrid(
              selected: _quadrant,
              onSelected: (quadrant) {
                setState(() {
                  _quadrant = quadrant;
                  _color = _hexForColor(MoodDefinition.quadrantColor(quadrant));
                  final pleasantRange = _pleasantRange(quadrant);
                  final energyRange = _energyRange(quadrant);
                  _pleasantness = pleasantRange.start;
                  _energy = energyRange.start;
                });
              },
            ),
            const SizedBox(height: 24),
            const _SectionLabel(title: 'Fine-tune'),
            _MoodSlider(
              label: 'Pleasantness',
              value: _pleasantness,
              range: _pleasantRange(_quadrant),
              minLabel: 'Less pleasant',
              maxLabel: 'More pleasant',
              onChanged: (value) => setState(() => _pleasantness = value),
            ),
            _MoodSlider(
              label: 'Energy',
              value: _energy,
              range: _energyRange(_quadrant),
              minLabel: 'Less energy',
              maxLabel: 'More energy',
              onChanged: (value) => setState(() => _energy = value),
            ),
            const SizedBox(height: 24),
            const _SectionLabel(title: 'Description'),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "How do you usually feel when you're like this?",
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel(
              title: 'Aliases',
              helper: 'You can search this mood by any of these names.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final alias in _aliases)
                  InputChip(
                    label: Text(alias),
                    onDeleted: () => setState(() => _aliases.remove(alias)),
                  ),
              ],
            ),
            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                hintText: 'Type and press Enter',
              ),
              onSubmitted: _addAlias,
            ),
            const SizedBox(height: 24),
            const _SectionLabel(title: 'Color'),
            AppColorPicker(
              value: _color,
              onChanged: (value) => setState(() => _color = value),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: canSave ? _save : null,
            style: AppTheme.primaryButtonStyle,
            child: const Text('Save'),
          ),
        ),
      ),
    );
  }

  void _addAlias(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      if (!_aliases.contains(trimmed)) _aliases.add(trimmed);
      _aliasController.clear();
    });
  }

  Future<void> _showEmojiPicker() async {
    const emojis = [
      '😁',
      '😀',
      '🙂',
      '😐',
      '🙁',
      '😢',
      '😭',
      '😡',
      '🤬',
      '😴',
      '🥱',
      '🤔',
      '🥰',
      '😍',
      '🤩',
      '😌',
      '😤',
      '😰',
      '😎',
      '✨',
      '🔥',
      '🌊',
      '🌱',
      '🧘',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 6,
        children: [
          for (final emoji in emojis)
            InkWell(
              onTap: () => Navigator.pop(context, emoji),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
        ],
      ),
    );
    if (selected != null) setState(() => _emoji = selected);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final existing = widget.mood;
    final id = existing?.id ?? _uniqueMoodId(ref, name);
    final mood = MoodDefinition(
      id: id,
      title: name,
      label: name,
      emoji: _emoji,
      color: _color,
      source: MoodSource.user,
      hidden: existing?.hidden ?? false,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      quadrant: _quadrant,
      pleasantness: _pleasantness,
      energy: _energy,
      aliases: _aliases,
      order: existing?.order,
      obsidianPath: existing?.obsidianPath ?? 'moods/$id.md',
    );
    if (existing == null) {
      await ref.read(moodsProvider.notifier).addMood(mood);
    } else {
      await ref.read(moodsProvider.notifier).updateMood(mood);
    }
    if (mounted) Navigator.pop(context);
  }

  String _uniqueMoodId(WidgetRef ref, String title) {
    final existing = ref.read(moodsProvider).map((m) => m.id).toSet();
    final base = _slugFromTitle(title);
    if (!existing.contains(base)) return base;
    var index = 2;
    while (existing.contains('$base-$index')) {
      index++;
    }
    return '$base-$index';
  }

  String _slugFromTitle(String title) {
    return title
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  ({int start, int end}) _pleasantRange(MoodQuadrant quadrant) =>
      switch (quadrant) {
        MoodQuadrant.red => (start: 0, end: 4),
        MoodQuadrant.blue => (start: 0, end: 4),
        MoodQuadrant.green => (start: 5, end: 10),
        MoodQuadrant.yellow => (start: 5, end: 10),
      };

  ({int start, int end}) _energyRange(MoodQuadrant quadrant) =>
      switch (quadrant) {
        MoodQuadrant.red => (start: 5, end: 10),
        MoodQuadrant.yellow => (start: 5, end: 10),
        MoodQuadrant.green => (start: 0, end: 4),
        MoodQuadrant.blue => (start: 0, end: 4),
      };

  String _hexForColor(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class _MoodSlider extends StatelessWidget {
  final String label;
  final int value;
  final ({int start, int end}) range;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<int> onChanged;

  const _MoodSlider({
    required this.label,
    required this.value,
    required this.range,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '$value/10',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Slider(
          min: range.start.toDouble(),
          max: range.end.toDouble(),
          divisions: range.end - range.start,
          value: value.clamp(range.start, range.end).toDouble(),
          onChanged: (next) => onChanged(next.round()),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                minLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Text(
              maxLabel,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _QuadrantGrid extends StatelessWidget {
  final MoodQuadrant selected;
  final ValueChanged<MoodQuadrant> onSelected;

  const _QuadrantGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        for (final quadrant in MoodQuadrant.values)
          _QuadrantButton(
            quadrant: quadrant,
            selected: selected == quadrant,
            onTap: () => onSelected(quadrant),
          ),
      ],
    );
  }
}

class _QuadrantButton extends StatelessWidget {
  final MoodQuadrant quadrant;
  final bool selected;
  final VoidCallback onTap;

  const _QuadrantButton({
    required this.quadrant,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = MoodDefinition.quadrantColor(quadrant);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Icon(
              _quadrantIcon(quadrant),
              color: selected ? AppColors.textOnPrimary : color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                quadrant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.textOnPrimary : color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _quadrantIcon(MoodQuadrant quadrant) => switch (quadrant) {
    MoodQuadrant.red => Icons.bolt_rounded,
    MoodQuadrant.yellow => Icons.wb_sunny_rounded,
    MoodQuadrant.green => Icons.spa_rounded,
    MoodQuadrant.blue => Icons.water_drop_rounded,
  };
}

class _InfoRow extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoRow({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? helper;

  const _SectionLabel({required this.title, this.helper});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(
              helper!,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodHeader extends StatelessWidget {
  final int configured;
  final int max;

  const _MoodHeader({required this.configured, required this.max});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$configured/$max custom moods configured',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
    );
  }
}

class _MoodEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _MoodEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mood_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No moods yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a custom mood to use in journal entries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              style: AppTheme.primaryButtonStyle,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add mood'),
            ),
          ],
        ),
      ),
    );
  }
}
