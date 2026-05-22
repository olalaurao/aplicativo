// lib/ui/widgets/moc_picker_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/moc_model.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';
import '../forms/create_moc_form.dart';
import '../theme.dart';

Future<void> showMocPickerModal(
  BuildContext context,
  WidgetRef ref,
  ContentObject object,
) async {
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final mocs = ref.watch(mocsProvider);
          final objectSlugLink = '[[${object.slug}]]';

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'MOC',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Adicione "${object.title}" a um ou mais MOCs para organizá-lo no seu vault.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: mocs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.layers_clear_outlined, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              const Text(
                                'Nenhum MOC criado ainda',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CreateMocForm()),
                                  );
                                },
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Criar Novo MOC'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: mocs.length,
                          itemBuilder: (context, index) {
                            final moc = mocs[index];
                            final isLinked = moc.children.contains(objectSlugLink) || object.moc.contains('[[${moc.slug}]]');

                            return Card(
                              color: AppColors.surfaceVariant,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.layers_outlined, size: 18, color: AppColors.primary),
                                ),
                                title: Text(
                                  moc.title,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                subtitle: Text(
                                  moc.description.isNotEmpty ? moc.description : 'Sem descrição',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Checkbox(
                                  value: isLinked,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) async {
                                    final updatedMocChildren = List<String>.from(moc.children);
                                    final updatedObjectMocs = List<String>.from(object.moc);
                                    final mocLink = '[[${moc.slug}]]';

                                    if (val == true) {
                                      if (!updatedMocChildren.contains(objectSlugLink)) {
                                        updatedMocChildren.add(objectSlugLink);
                                      }
                                      if (!updatedObjectMocs.contains(mocLink)) {
                                        updatedObjectMocs.add(mocLink);
                                      }
                                    } else {
                                      updatedMocChildren.remove(objectSlugLink);
                                      updatedObjectMocs.remove(mocLink);
                                    }

                                    final updatedMoc = moc.copyWith(children: updatedMocChildren);
                                    final updatedObject = _copyWithMoc(object, updatedObjectMocs);

                                    // Persist both updates in the vault
                                    await ref.read(vaultProvider.notifier).updateObject(updatedMoc);
                                    await ref.read(vaultProvider.notifier).updateObject(updatedObject);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (mocs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateMocForm()),
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Criar Novo MOC'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

// Helper to support copyWith(moc: ...) for any ContentObject subclass dynamically
ContentObject _copyWithMoc(ContentObject obj, List<String> newMocs) {
  // Use dynamic or cast to copyWith supporting new MOCs
  try {
    return (obj as dynamic).copyWith(moc: newMocs) as ContentObject;
  } catch (e) {
    // Fallback if copyWith fails/isn't overridden: modify in-place (since some objects might not implement copyWith properly)
    obj.moc = newMocs;
    return obj;
  }
}
