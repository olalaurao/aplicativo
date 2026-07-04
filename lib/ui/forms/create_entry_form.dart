import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../models/journal_entry.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../../models/template_model.dart';
import '../../providers/settings_provider.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/rich_text_editor.dart';
import '../theme.dart';
import '../widgets/organizer_picker_modal.dart';
import 'package:go_router/go_router.dart';
import '../../models/mood_model.dart';
import '../widgets/mood_picker_sheet.dart';

class CreateEntryForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final JournalEntry? existingEntry;
  final DateTime? initialDate;
  final String? initialBody;
  const CreateEntryForm({
    super.key,
    this.initialTitle,
    this.existingEntry,
    this.initialDate,
    this.initialBody,
  });

  @override
  ConsumerState<CreateEntryForm> createState() => _CreateEntryFormState();
}

class _CreateEntryFormState extends ConsumerState<CreateEntryForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _feelingsController;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  String _content = '';
  DateTime _entryDate = DateTime.now();
  String? _moodSlug;
  String? _location;
  String? _templateId;
  List<OrganizerReference> _organizers = [];

  final GlobalKey<RichTextEditorState> _editorKey =
      GlobalKey<RichTextEditorState>();

  static const _feelingChips = [
    'Ansioso',
    'Grato',
    'Cansado',
    'Inspirado',
    'Produtivo',
    'Calmo',
    'Estressado',
  ];
  final List<String> _selectedFeelings = [];
  final List<String> _photoPaths = [];

  @override
  void initState() {
    super.initState();
    // #region agent log
    _appendDebugLog(
      runId: 'run3',
      hypothesisId: 'H8',
      location: 'create_entry_form.dart:initState',
      message: 'entry_form_initialized',
      data: {'hasExistingEntry': widget.existingEntry != null},
    );
    // #endregion
    _titleController = WikiLinkTextController(
      context: context,
      text: widget.existingEntry?.title ?? widget.initialTitle,
    );
    _feelingsController = TextEditingController(
      text: widget.existingEntry?.feelings ?? '',
    );

    if (widget.existingEntry != null) {
      final entry = widget.existingEntry!;
      _content = entry.body;
      _entryDate = entry.date;
      _moodSlug = entry.moodSlug;
      _location = entry.location;
      _templateId = entry.templateId;
      _organizers = List.of(entry.organizers);
    } else {
      final now = DateTime.now();
      final initialDate = widget.initialDate;
      _entryDate = initialDate == null
          ? now
          : DateTime(
              initialDate.year,
              initialDate.month,
              initialDate.day,
              now.hour,
              now.minute,
            );
      if (widget.initialBody != null) {
        _content = widget.initialBody!;
      } else {
        // Apply Daily Review Template if configured
        final settings = ref.read(settingsProvider);
        if (settings.reviewDailyTemplateId.isNotEmpty) {
          final templates = ref.read(templatesProvider);
          final reviewTemplate = templates
              .cast<TemplateDefinition?>()
              .firstWhere(
                (t) =>
                    t?.id == settings.reviewDailyTemplateId &&
                    t?.templateType == 'entry',
                orElse: () => null,
              );
          if (reviewTemplate != null) {
            String body = reviewTemplate.body;
            body = body.replaceAll(
              '{{date}}',
              DateFormat('dd/MM/yyyy').format(_entryDate),
            );
            body = body.replaceAll(
              '{{time}}',
              DateFormat('HH:mm').format(_entryDate),
            );
            body = body.replaceAll(
              '{{weekday}}',
              DateFormat('EEEE').format(_entryDate),
            );
            body = body.replaceAll(
              '{{title}}',
              widget.initialTitle ?? 'Nova Entry',
            );
            _content = body;
            _templateId = reviewTemplate.id;

            if (reviewTemplate.frontmatterDefaults.containsKey('mood')) {
              _moodSlug = reviewTemplate.frontmatterDefaults['mood'] as String?;
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _feelingsController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDirty = _titleController.text.trim().isNotEmpty ||
        _content.trim().isNotEmpty;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text(
              'Você possui alterações não salvas. Deseja sair mesmo assim?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if ((discard ?? false) && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ─── Top Bar ───
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'New Entry',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _content.isEmpty ? null : _saveEntry,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Title Field ───
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Entry title (optional)',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),

                  // ─── Body Rich Text Editor ───
                  SizedBox(
                    height: 300,
                    child: RichTextEditor(
                      key: _editorKey,
                      content: _content,
                      onChanged: (val) {
                        setState(() {
                          _content = val;
                        });
                      },
                      placeholder: 'What is on your mind?',
                      expands: true,
                    ),
                  ),

                  // ─── Photo Strip Placeholder ───
                  const SizedBox(height: 24),
                  _buildPhotoStrip(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // ─── Metadata Row & Toolbar ───
          _buildBottomControls(),
        ],
      ),
    ),
  );
  }

  Widget _buildBottomControls() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Metadata Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _metadataChip(
                    icon: Icons.event_outlined,
                    label: DateFormat('MMM d, HH:mm').format(_entryDate),
                    onTap: _pickDateTime,
                  ),
                  const SizedBox(width: 8),
                  Consumer(
                    builder: (context, ref, child) {
                      final moods = ref.watch(moodsProvider);
                      final selectedMood = moods
                          .where(
                            (m) => m.id == _moodSlug || m.slug == _moodSlug,
                          )
                          .firstOrNull;
                      return _metadataChip(
                        icon: Icons.mood_rounded,
                        label: selectedMood != null
                            ? selectedMood.emoji
                            : 'Mood',
                        onTap: () => _pickMood(moods),
                        isActive: _moodSlug != null,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _metadataChip(
                    icon: Icons.location_on_outlined,
                    label: _location ?? 'Location',
                    onTap: _showLocationPicker,
                    isActive: _location != null,
                  ),
                  const SizedBox(width: 8),
                  _metadataChip(
                    icon: Icons.layers_outlined,
                    label: _organizers.isEmpty
                        ? 'Organizadores'
                        : '${_organizers.length} selecionados',
                    onTap: _pickOrganizers,
                    isActive: _organizers.isNotEmpty,
                  ),
                  const SizedBox(width: 8),
                  _metadataChip(
                    icon: Icons.copy_all_rounded,
                    label: 'Modelos',
                    onTap: _showTemplatePicker,
                  ),
                ],
              ),
            ),
            // RichTextEditor already has a toolbar, so we don't need one here.
          ],
        ),
      ),
    );
  }

  Widget _metadataChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_entryDate),
      );
      if (time != null) {
        setState(() {
          _entryDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _pickMood(List<dynamic> moods) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return MoodPickerSheet(
          onMoodSelected: (moodSlug) {
            setState(() {
              _moodSlug = moodSlug;
            });
          },
        );
      },
    );
  }

  Future<void> _pickOrganizers() async {
    final res = await showOrganizerPickerModal(context, ref, _organizers);
    if (res != null && mounted) {
      setState(() {
        _organizers.clear();
        _organizers.addAll(res);
      });
    }
  }

  Widget _buildPhotoStrip() {
    if (_photoPaths.isEmpty) {
      return GestureDetector(
        onTap: _addPhoto,
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider,
              style: BorderStyle.solid,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_rounded, color: AppColors.textMuted),
              SizedBox(width: 8),
              Text(
                'Add photos',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotos',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._photoPaths.map(
                (path) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(path),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _addPhoto,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.divider,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final file = File(image.path);
      final obsidian = ref.read(obsidianServiceProvider);
      final relPath = await obsidian.saveAttachment(file);
      if (relPath != null && mounted) {
        setState(() {
          _photoPaths.add('${obsidian.vaultDir!.path}/$relPath');
          _content = _appendInlineEmbed(_content, relPath);
        });
      }
    }
  }

  String _appendInlineEmbed(String content, String relPath) {
    final embed = '![[${relPath.replaceAll('\\', '/')}]]';
    if (content.trim().isEmpty) return embed;
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        decoded.add({'insert': '\n$embed\n'});
        return jsonEncode(decoded);
      }
      if (decoded is Map && decoded['ops'] is List) {
        (decoded['ops'] as List).add({'insert': '\n$embed\n'});
        return jsonEncode(decoded);
      }
    } catch (_) {
      // Keep plain markdown fallback below.
    }
    return '$content\n$embed';
  }

  void _showLocationPicker() {
    // #region agent log
    _appendDebugLog(
      runId: 'run3',
      hypothesisId: 'H8',
      location: 'create_entry_form.dart:_showLocationPicker',
      message: 'location_picker_opened',
      data: {'currentLocation': _location},
    );
    // #endregion
    final controller = TextEditingController(text: _location);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Where are you?'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _location = controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showTemplatePicker() async {
    final templates = ref
        .read(templatesProvider)
        .where((t) => t.templateType == 'entry')
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Templates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/create/template',
                      extra: {'initialType': 'entry'},
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (templates.isEmpty)
              const Text(
                'Nenhum template encontrado.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ...templates.map(
              (t) => ListTile(
                title: Text(t.title),
                onTap: () {
                  String body = t.body;
                  body = body.replaceAll(
                    '{{date}}',
                    DateFormat('dd/MM/yyyy').format(_entryDate),
                  );
                  body = body.replaceAll(
                    '{{time}}',
                    DateFormat('HH:mm').format(_entryDate),
                  );
                  body = body.replaceAll(
                    '{{weekday}}',
                    DateFormat('EEEE').format(_entryDate),
                  );
                  body = body.replaceAll(
                    '{{title}}',
                    _titleController.text.isNotEmpty
                        ? _titleController.text
                        : 'Nova Entry',
                  );

                  setState(() {
                    if (_content.trim().isEmpty) {
                      _content = body;
                    } else {
                      _content += '\n$body';
                    }
                    _editorKey.currentState?.appendText(body);
                    _templateId = t.id;

                    if (t.frontmatterDefaults.containsKey('mood')) {
                      _moodSlug = t.frontmatterDefaults['mood'] as String?;
                    }
                    // Handle organizers if needed
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _appendDebugLog({
    required String runId,
    required String hypothesisId,
    required String location,
    required String message,
    required Map<String, dynamic> data,
  }) async {
    debugPrint('[$runId][$hypothesisId] $location: $message $data');
  }

  Future<void> _saveEntry() async {
    final entry = JournalEntry(
      id: widget.existingEntry?.id,
      createdAt: widget.existingEntry?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      title: _titleController.text.trim(),
      body: _content, // Storing as JSON string
      date: _entryDate,
      moodSlug: _moodSlug,
      feelings: _feelingsController.text.trim().isNotEmpty
          ? _feelingsController.text.trim()
          : null,
      location: _location,
      templateId: _templateId,
      organizers: _organizers,
    );
    try {
      if (widget.existingEntry != null) {
        await ref
            .read(todayJournalProvider.notifier)
            .updateEntry(entry, originalEntry: widget.existingEntry);
      } else {
        await ref.read(todayJournalProvider.notifier).addEntry(entry);
      }
    } catch (e) {
      debugPrint('Failed to save journal entry: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar entrada: $e')));
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
