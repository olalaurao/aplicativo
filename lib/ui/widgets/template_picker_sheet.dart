import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/template_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';

class TemplatePickerSheet extends ConsumerWidget {
  final String objectType; // e.g. 'task', 'habit', 'goal'
  final void Function(TemplateDefinition) onTemplateSelected;

  const TemplatePickerSheet({
    super.key,
    required this.objectType,
    required this.onTemplateSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(allObjectsProvider).value?.whereType<TemplateDefinition>().where((t) => t.templateType == objectType).toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Templates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          if (templates.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No templates available',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (_, i) {
                  final t = templates[i];
                  return ListTile(
                    leading: Icon(
                      Icons.copy_all_rounded,
                      color: AppTheme.accentColor(context),
                    ),
                    title: Text(
                      t.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Tipo: ${t.templateType.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      onTemplateSelected(t);
                      Navigator.pop(context);
                    },
                  );
                },
                separatorBuilder: (_, __) => const Divider(),
                itemCount: templates.length,
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String objectType,
    required void Function(TemplateDefinition) onTemplateSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TemplatePickerSheet(
        objectType: objectType,
        onTemplateSelected: onTemplateSelected,
      ),
    );
  }
}
