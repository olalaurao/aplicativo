import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../../providers/settings_provider.dart' show AppSettings, SettingsNotifier, AutoCategoryRule, settingsProvider;
import '../../../../providers/vault_provider.dart' show templatesProvider, allObjectsProvider;
import '../../../../models/template_model.dart' show TemplateDefinition;
import '../../type_signatures_screen.dart';
import '../../category_management_screen.dart';

class ObjectStructureSection extends ConsumerWidget {
  const ObjectStructureSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Object Identification',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Configure how tasks, habits and projects are recognized in your Vault.',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TypeSignaturesScreen(),
              ),
            ),
          ),
          const Divider(height: 1, indent: 16),
          _buildDailyReviewTemplateTile(context, ref),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Ideas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Configure capture strategy',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showIdeaSettingsDialog(
              context,
              ref,
              settings,
              notifier,
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Manage Categories',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CategoryManagementScreen(),
              ),
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Categorization Rules',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '${settings.autoCategoryRules.length} active rules',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: AppColors.info,
            ),
            onTap: () => _showAutoCategoryRulesDialog(
              context,
              ref,
              settings,
              notifier,
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text(
              'Category Colors',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '${settings.categoryColors.length} custom colors',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(
              Icons.color_lens_outlined,
              size: 20,
              color: AppColors.warning,
            ),
            onTap: () => _showCategoryColorsDialog(
              context,
              ref,
              settings,
              notifier,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReviewTemplateTile(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final templates = ref.watch(templatesProvider);
    final entryTemplates = templates
        .where((t) => t.templateType == 'entry')
        .toList();

    final selectedTemplate = entryTemplates
        .cast<TemplateDefinition?>()
        .firstWhere(
          (t) => t?.id == settings.reviewDailyTemplateId,
          orElse: () => null,
        );

    return ListTile(
      title: const Text(
        'Template de Daily Review',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        selectedTemplate != null
            ? 'Ativo: ${selectedTemplate.title}'
            : 'Nenhum template selecionado',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Icon(
        Icons.rate_review_outlined,
        size: 20,
        color: AppTheme.accentColor(context),
      ),
      onTap: () => _showDailyReviewTemplatePicker(
        context,
        ref,
        entryTemplates,
        settings.reviewDailyTemplateId,
      ),
    );
  }

  void _showDailyReviewTemplatePicker(
    BuildContext context,
    WidgetRef ref,
    List<TemplateDefinition> entryTemplates,
    String currentId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Select Daily Review Template',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: entryTemplates.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              'Nenhum template de Entry encontrado.\nCrie um template em Templates primeiro.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: entryTemplates.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              final isSelected = currentId.isEmpty;
                              return ListTile(
                                title: const Text(
                                  'Nenhum',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: AppTheme.accentColor(context),
                                      )
                                    : null,
                                onTap: () {
                                  ref
                                      .read(settingsProvider.notifier)
                                      .updateReviewDailyTemplateId('');
                                  Navigator.pop(ctx);
                                },
                              );
                            }
                            final template = entryTemplates[index - 1];
                            final isSelected = template.id == currentId;
                            return ListTile(
                              title: Text(
                                template.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: const Text(
                                'Daily review prompt',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: AppTheme.accentColor(context),
                                    )
                                  : null,
                              onTap: () {
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateReviewDailyTemplateId(template.id);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showIdeaSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    String currentStrategy = settings.ideaStrategy;
    final tagController = TextEditingController(text: settings.ideaTag);
    final folderController = TextEditingController(text: settings.ideaFolder);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Idea Configuration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How should the system recognize an idea?'),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: currentStrategy,
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => currentStrategy = v);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RadioListTile<String>(
                        title: Text('By Tag'),
                        value: 'tag',
                      ),
                      if (currentStrategy == 'tag')
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 32,
                            right: 16,
                            bottom: 8,
                          ),
                          child: TextField(
                            controller: tagController,
                            decoration: const InputDecoration(
                              labelText: 'Tag (without #)',
                            ),
                          ),
                        ),
                      const RadioListTile<String>(
                        title: Text('By Folder'),
                        value: 'folder',
                      ),
                      if (currentStrategy == 'folder')
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 32,
                            right: 16,
                            bottom: 8,
                          ),
                          child: TextField(
                            controller: folderController,
                            decoration: const InputDecoration(
                              labelText: 'Folder Path',
                            ),
                          ),
                        ),
                      const RadioListTile<String>(
                        title: Text('Any Note'),
                        value: 'any_note',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final strategy = currentStrategy;
                final tag = tagController.text.trim();
                final folder = folderController.text.trim();
                Navigator.pop(ctx);
                await notifier.setIdeaStrategy(
                  strategy: strategy,
                  tag: tag,
                  folder: folder,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoCategoryRulesDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    final patternController = TextEditingController();
    final categoryController = TextEditingController();
    String targetType = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            children: [
              const Text(
                'Auto-Categorization Rules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: settings.autoCategoryRules.isEmpty
                    ? const Center(
                        child: Text(
                          'No rules created.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: settings.autoCategoryRules.length,
                        itemBuilder: (c, i) {
                          final rule = settings.autoCategoryRules[i];
                          return ListTile(
                            title: Text(rule.pattern),
                            subtitle: Text(
                              '${rule.targetType} -> ${rule.category}',
                            ),
                          );
                        },
                      ),
              ),
              const Divider(),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Pattern',
                  hintText: 'Example: #work or project',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: '[[work]]',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: targetType,
                decoration: const InputDecoration(labelText: 'Target type'),
                items:
                    const [
                          'all',
                          'task',
                          'habit',
                          'note',
                          'entry',
                          'project',
                          'resource',
                        ]
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                onChanged: (value) =>
                    setModalState(() => targetType = value ?? 'all'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final pattern = patternController.text.trim();
                    final category = categoryController.text.trim();
                    if (pattern.isEmpty || category.isEmpty) return;
                    await notifier.addAutoCategoryRule(
                      AutoCategoryRule(
                        pattern: pattern,
                        category: category,
                        targetType: targetType,
                      ),
                    );
                    patternController.clear();
                    categoryController.clear();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('ADD RULE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryColorsDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    final categoryController = TextEditingController();
    String selectedColor = '#8B5CF6';
    const swatches = [
      '#EF4444',
      '#F97316',
      '#F59E0B',
      '#10B981',
      '#06B6D4',
      '#3B82F6',
      '#8B5CF6',
      '#EC4899',
      '#6B7280',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Category Colors',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (settings.categoryColors.isNotEmpty)
                ...settings.categoryColors.entries
                    .where((entry) => !entry.key.startsWith('notif_') && !entry.key.startsWith('btn_'))
                    .map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Color(
                        int.parse(entry.value.replaceAll('#', '0xFF')),
                      ),
                    ),
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                  ),
                ),
              const Divider(),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: '[[work]]',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: swatches.map((hex) {
                  final selected = selectedColor == hex;
                  final color = Color(int.parse(hex.replaceAll('#', '0xFF')));
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final category = categoryController.text.trim();
                    if (category.isEmpty) return;
                    await notifier.updateCategoryColor(category, selectedColor);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('SAVE COLOR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
