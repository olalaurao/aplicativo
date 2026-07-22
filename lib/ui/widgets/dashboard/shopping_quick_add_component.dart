import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/shopping_list_model.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../../navigation/object_navigation.dart';

class ShoppingQuickAddComponent extends ConsumerStatefulWidget {
  final DashboardBlock block;

  const ShoppingQuickAddComponent({super.key, required this.block});

  @override
  ConsumerState<ShoppingQuickAddComponent> createState() => _ShoppingQuickAddComponentState();
}

class _ShoppingQuickAddComponentState extends ConsumerState<ShoppingQuickAddComponent> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ShoppingList? _resolveList(List<ShoppingList> allLists) {
    final configuredId = widget.block.metadata['shoppingListId'] as String?;
    if (configuredId != null) {
      final list = allLists.where((l) => l.id == configuredId || l.slug == configuredId).firstOrNull;
      if (list != null && !list.archived) return list;
    }

    final activeLists = allLists.where((l) => !l.archived).toList();
    if (activeLists.isNotEmpty) {
      activeLists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return activeLists.first;
    }
    return null;
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    
    try {
      final allLists = (ref.read(allObjectsProvider).valueOrNull ?? []).whereType<ShoppingList>().toList();
      var targetList = _resolveList(allLists);

      if (targetList == null) {
        targetList = ShoppingList(
          id: const Uuid().v4(),
          title: 'Shopping List',
          createdAt: DateTime.now(),
        );
        // We will create it on the fly by updating it.
        // Wait, does updateObject create if it doesn't exist? Yes, it uses the ObsidianService write logic.
      }

      final newItem = ShoppingItem(
        id: const Uuid().v4(),
        name: text,
        status: ShoppingItemStatus.active,
      );

      final updatedList = targetList.copyWith(
        items: [...targetList.items, newItem],
      );

      await ref.read(vaultProvider.notifier).updateObject(updatedList);
      _controller.clear();
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allLists = (ref.watch(allObjectsProvider).valueOrNull ?? []).whereType<ShoppingList>().toList();
    final targetList = _resolveList(allLists);

    final previewCount = widget.block.metadata['previewCount'] as int? ?? 3;
    final activeItems = targetList?.items.where((i) => i.status == ShoppingItemStatus.active).toList() ?? [];
    final visibleItems = activeItems.take(previewCount).toList();

    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Icon(Icons.add_shopping_cart_rounded, color: AppColors.textMuted, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.block.title.isNotEmpty ? widget.block.title : 'Quick Add — Shopping',
                          style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (targetList != null)
                  InkWell(
                    onTap: () => navigateToObject(context, targetList),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'View',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.accent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: Theme.of(context).textTheme.bodyMedium!,
                    decoration: InputDecoration(
                      hintText: targetList == null ? 'Add an item...' : 'Add item...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _submit(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                if (_isSubmitting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.accent),
                    onPressed: _submit,
                  ),
              ],
            ),
          ),
          if (targetList != null && targetList.items.isNotEmpty && activeItems.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('All items checked off.', style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.textMuted)),
            )
          else if (targetList == null || targetList.items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('No items yet.', style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.textMuted)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: visibleItems.map((item) {
                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final updatedItems = targetList.items.map((i) {
                        if (i.id == item.id) {
                          return ShoppingItem(
                            id: i.id,
                            name: i.name,
                            quantity: i.quantity,
                            category: i.category,
                            note: i.note,
                            status: ShoppingItemStatus.checked,
                            order: i.order,
                          );
                        }
                        return i;
                      }).toList();
                      ref.read(vaultProvider.notifier).updateObject(targetList.copyWith(items: updatedItems));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.radio_button_unchecked_rounded, size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${item.name}${item.quantity != null ? ' (${item.quantity})' : ''}',
                              style: Theme.of(context).textTheme.bodyMedium!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
