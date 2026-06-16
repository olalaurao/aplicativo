import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/shopping_item.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isOutros = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitItem(String text) {
    final title = text.trim();
    if (title.isEmpty) return;

    final items = ref.read(shoppingItemsProvider);
    final existing = items
        .where((item) => item.title.toLowerCase() == title.toLowerCase())
        .firstOrNull;

    if (existing != null) {
      if (existing.isCompleted) {
        final updated = existing.copyWith(
          isCompleted: false,
          categories: _isOutros ? ['outros'] : [],
        );
        ref.read(shoppingItemsProvider.notifier).updateShoppingItem(updated);
      }
    } else {
      final newItem = ShoppingItem(
        title: title,
        categories: _isOutros ? ['outros'] : [],
      );
      ref.read(shoppingItemsProvider.notifier).addShoppingItem(newItem);
    }

    _textController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(shoppingItemsProvider);

    final pendingMercado =
        items
            .where(
              (item) =>
                  !item.isCompleted &&
                  !item.archived &&
                  !item.categories.contains('outros'),
            )
            .toList()
          ..sort((a, b) {
            if (a.order != null || b.order != null) {
              return (a.order ?? 9999).compareTo(b.order ?? 9999);
            }
            return b.updatedAt.compareTo(a.updatedAt);
          });

    final pendingOutros =
        items
            .where(
              (item) =>
                  !item.isCompleted &&
                  !item.archived &&
                  item.categories.contains('outros'),
            )
            .toList()
          ..sort((a, b) {
            if (a.order != null || b.order != null) {
              return (a.order ?? 9999).compareTo(b.order ?? 9999);
            }
            return b.updatedAt.compareTo(a.updatedAt);
          });

    final completed =
        items.where((item) => item.isCompleted && !item.archived).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Lista de Mercado',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.shopping_cart_rounded,
                      headline: 'Lista vazia',
                      subtext: 'Adicione itens abaixo para começar sua lista.',
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      children: [
                        if (pendingMercado.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Mercado',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppTheme.textMutedColor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final list = List<ShoppingItem>.from(
                                pendingMercado,
                              );
                              final item = list.removeAt(oldIndex);
                              list.insert(newIndex, item);
                              for (int i = 0; i < list.length; i++) {
                                if (list[i].order != i) {
                                  ref
                                      .read(shoppingItemsProvider.notifier)
                                      .updateShoppingItem(
                                        list[i].copyWith(order: i),
                                      );
                                }
                              }
                            },
                            children: pendingMercado
                                .map(
                                  (item) => _buildItemRow(
                                    item,
                                    key: ValueKey(item.id),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (pendingOutros.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(
                              'Outros',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppTheme.textMutedColor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final list = List<ShoppingItem>.from(
                                pendingOutros,
                              );
                              final item = list.removeAt(oldIndex);
                              list.insert(newIndex, item);
                              for (int i = 0; i < list.length; i++) {
                                if (list[i].order != i) {
                                  ref
                                      .read(shoppingItemsProvider.notifier)
                                      .updateShoppingItem(
                                        list[i].copyWith(order: i),
                                      );
                                }
                              }
                            },
                            children: pendingOutros
                                .map(
                                  (item) => _buildItemRow(
                                    item,
                                    key: ValueKey(item.id),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (completed.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 8),
                            child: Text(
                              'Concluídos',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppTheme.textMutedColor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          ...completed.map((item) => _buildItemRow(item)),
                        ],
                      ],
                    ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(ShoppingItem item, {Key? key}) {
    final isOutros = item.categories.contains('outros');
    final activeColor = isOutros ? AppColors.secondary : AppColors.accent;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: InkWell(
          onTap: () {
            ref
                .read(shoppingItemsProvider.notifier)
                .updateShoppingItem(
                  item.copyWith(isCompleted: !item.isCompleted),
                );
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: item.isCompleted
                    ? activeColor
                    : Theme.of(context).dividerColor,
                width: 2,
              ),
              color: item.isCompleted ? activeColor : Colors.transparent,
            ),
            child: item.isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 16,
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
            color: item.isCompleted
                ? AppTheme.textMutedColor(context)
                : AppTheme.textPrimaryColor(context),
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: AppTheme.textMutedColor(context),
          ),
          onPressed: () {
            ref.read(shoppingItemsProvider.notifier).deleteShoppingItem(item);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.title} excluído'),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Desfazer',
                  textColor: activeColor,
                  onPressed: () {
                    final originalPath = item.obsidianPath.isNotEmpty
                        ? item.obsidianPath
                        : 'shopping/${item.slug}.md';
                    ref
                        .read(vaultProvider.notifier)
                        .restoreObject(item, originalPath);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('🛒 Mercado'),
                selected: !_isOutros,
                selectedColor: AppColors.accent.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: !_isOutros
                      ? AppColors.accent
                      : AppTheme.textMutedColor(context),
                  fontWeight: !_isOutros ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() => _isOutros = false);
                    _focusNode.requestFocus();
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('🏷️ Outros'),
                selected: _isOutros,
                selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _isOutros
                      ? AppColors.secondary
                      : AppTheme.textMutedColor(context),
                  fontWeight: _isOutros ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() => _isOutros = true);
                    _focusNode.requestFocus();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: _submitItem,
            decoration: InputDecoration(
              hintText: _isOutros
                  ? 'Adicionar a Outros...'
                  : 'Adicionar ao Mercado...',
              hintStyle: TextStyle(color: AppTheme.textMutedColor(context)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  color: _isOutros ? AppColors.secondary : AppColors.accent,
                ),
                onPressed: () => _submitItem(_textController.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
