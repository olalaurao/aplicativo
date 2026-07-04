// lib/ui/screens/shopping_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/vault_provider.dart';
import '../../models/shopping_list_model.dart' as shopping_list_model;
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
  String? _selectedListId;
  final Set<String> _collapsedCategories = {};

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

  shopping_list_model.ShoppingItem _parseShoppingItemInput(String input) {
    String text = input.trim();
    String? note;
    String? category;
    String? quantity;

    // 1. Extract note starting with //
    final noteIdx = text.indexOf('//');
    if (noteIdx != -1) {
      note = text.substring(noteIdx + 2).trim();
      text = text.substring(0, noteIdx).trim();
    }

    // 2. Extract category starting with #
    final hashMatch = RegExp(r'#(\S+)').firstMatch(text);
    if (hashMatch != null) {
      category = hashMatch.group(1);
      text = text.replaceFirst(RegExp(r'#\S+'), '').trim();
    }

    // 3. Extract quantity (number followed by unit like kg, g, l, ml, u, pct, cx, etc.)
    final qtyMatch = RegExp(
      r'(\d+(?:\.\d+)?\s*(?:kg|g|l|ml|un|u|pct|cx|unid|unidades|caixa|caixas|pacote|pacotes|latas|lata|xicara|xicaras|colher|colheres|pcs|pc|unids)?)$',
      caseSensitive: false,
    ).firstMatch(text);

    if (qtyMatch != null) {
      final potentialQty = qtyMatch.group(1)!.trim();
      if (RegExp(r'\d').hasMatch(potentialQty)) {
        quantity = potentialQty;
        text = text.substring(0, text.length - potentialQty.length).trim();
      }
    }

    if (text.isEmpty) text = input.trim();

    return shopping_list_model.ShoppingItem(
      id: const Uuid().v4(),
      name: text,
      quantity: quantity,
      category: category,
      note: note,
      status: shopping_list_model.ShoppingItemStatus.active,
    );
  }

  void _submitItem(String text, shopping_list_model.ShoppingList activeList) {
    final title = text.trim();
    if (title.isEmpty) return;

    final parsedItem = _parseShoppingItemInput(title);
    final updatedItems = [...activeList.items, parsedItem];
    final updatedList = activeList.copyWith(items: updatedItems);

    ref.read(shoppingListsProvider.notifier).updateShoppingList(updatedList);
    _textController.clear();
  }

  void _createNewList() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Lista de Compras'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: 'Nome da lista (ex: Supermercado)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final name = titleController.text.trim();
              if (name.isNotEmpty) {
                final newList = shopping_list_model.ShoppingList(
                  id: const Uuid().v4(),
                  title: name,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await ref.read(shoppingListsProvider.notifier).addShoppingList(newList);
                setState(() => _selectedListId = newList.id);
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(shoppingListsProvider);

    if (lists.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor(context),
        appBar: AppBar(title: const Text('Listas de Compras')),
        body: Center(
          child: EmptyState(
            icon: Icons.shopping_bag_outlined,
            headline: 'Nenhuma lista de compras',
            subtext: 'Crie sua primeira lista para organizar os itens.',
            ctaLabel: 'Criar Lista',
            onCta: _createNewList,
          ),
        ),
      );
    }

    final activeList = lists.firstWhere(
      (l) => l.id == _selectedListId,
      orElse: () => lists.first,
    );

    // Group items by category
    final itemsToDisplay = activeList.items.where((i) => i.status != shopping_list_model.ShoppingItemStatus.archived).toList();
    final activeItems = itemsToDisplay.where((i) => i.status == shopping_list_model.ShoppingItemStatus.active).toList();
    final checkedItems = itemsToDisplay.where((i) => i.status == shopping_list_model.ShoppingItemStatus.checked).toList();

    final Map<String, List<shopping_list_model.ShoppingItem>> groupedActive = {};
    for (final item in activeItems) {
      final cat = item.category ?? 'Geral';
      groupedActive.putIfAbsent(cat, () => []).add(item);
    }

    // Sort items inside groups by order
    for (final list in groupedActive.values) {
      list.sort((a, b) => a.order.compareTo(b.order));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showListSelector(lists),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                activeList.title,
                style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.arrow_drop_down, size: 24),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              activeList.hideChecked ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            ),
            tooltip: activeList.hideChecked ? 'Mostrar Concluídos' : 'Ocultar Concluídos',
            onPressed: () {
              final updated = activeList.copyWith(hideChecked: !activeList.hideChecked);
              ref.read(shoppingListsProvider.notifier).updateShoppingList(updated);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _createNewList,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: activeList.items.isEmpty
                  ? Center(
                      child: const EmptyState(
                        icon: Icons.add_shopping_cart_rounded,
                        headline: 'Nenhum item adicionado',
                        subtext: 'Adicione itens usando o campo abaixo.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        ...groupedActive.entries.map((entry) {
                          final catName = entry.key;
                          final listItems = entry.value;
                          final isCollapsed = _collapsedCategories.contains(catName);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCategoryHeader(catName, listItems.length, isCollapsed),
                              if (!isCollapsed)
                                ...listItems.map((item) => _buildItemRow(item, activeList)),
                              const SizedBox(height: 12),
                            ],
                          );
                        }),
                        if (!activeList.hideChecked && checkedItems.isNotEmpty) ...[
                          const Divider(),
                          _buildCategoryHeader('Concluídos', checkedItems.length, false),
                          ...checkedItems.map((item) => _buildItemRow(item, activeList)),
                        ],
                      ],
                    ),
            ),
            _buildInputArea(activeList),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title, int count, bool isCollapsed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (title != 'Concluídos')
            IconButton(
              icon: Icon(
                isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  if (isCollapsed) {
                    _collapsedCategories.remove(title);
                  } else {
                    _collapsedCategories.add(title);
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(shopping_list_model.ShoppingItem item, shopping_list_model.ShoppingList activeList) {
    final isChecked = item.isChecked;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: InkWell(
          onTap: () {
            final updatedItems = activeList.items.map((i) {
              if (i.id == item.id) {
                return i.copyWith(
                  status: isChecked
                      ? shopping_list_model.ShoppingItemStatus.active
                      : shopping_list_model.ShoppingItemStatus.checked,
                );
              }
              return i;
            }).toList();
            final updatedList = activeList.copyWith(items: updatedItems);
            ref.read(shoppingListsProvider.notifier).updateShoppingList(updatedList);
          },
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isChecked ? AppColors.accent : Theme.of(context).dividerColor,
                width: 2,
              ),
              color: isChecked ? AppColors.accent : Colors.transparent,
            ),
            child: isChecked
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: TextStyle(
                fontSize: 15,
                decoration: isChecked ? TextDecoration.lineThrough : null,
                color: isChecked
                    ? AppTheme.textMutedColor(context)
                    : AppTheme.textPrimaryColor(context),
              ),
            ),
            if (item.note != null && item.note!.isNotEmpty)
              Text(
                item.note!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.quantity != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.quantity!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: AppTheme.textMutedColor(context),
                size: 20,
              ),
              onPressed: () {
                final updatedItems = activeList.items.where((i) => i.id != item.id).toList();
                final updatedList = activeList.copyWith(items: updatedItems);
                ref.read(shoppingListsProvider.notifier).updateShoppingList(updatedList);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(shopping_list_model.ShoppingList activeList) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (val) => _submitItem(val, activeList),
            decoration: InputDecoration(
              hintText: 'Adicionar item (ex: Café 500g #Geral // marca X)',
              hintStyle: TextStyle(
                color: AppTheme.textMutedColor(context),
                fontSize: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  color: AppColors.accent,
                ),
                onPressed: () => _submitItem(_textController.text, activeList),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showListSelector(List<shopping_list_model.ShoppingList> lists) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Minhas Listas de Compras',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  return ListTile(
                    leading: const Icon(Icons.shopping_cart_outlined),
                    title: Text(list.title),
                    trailing: list.id == _selectedListId
                        ? const Icon(Icons.check, color: AppColors.accent)
                        : null,
                    onTap: () {
                      setState(() => _selectedListId = list.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
