import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/saved_filter.dart';
import '../../providers/settings_provider.dart';
import '../theme.dart';

class FilterSortSheet extends ConsumerStatefulWidget {
  final String targetType;
  final SavedFilter? currentFilter;
  final List<FilterProperty> availableProperties;
  final ValueChanged<SavedFilter?> onApply;

  const FilterSortSheet({
    super.key,
    required this.targetType,
    required this.currentFilter,
    required this.availableProperties,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required String targetType,
    required SavedFilter? currentFilter,
    required List<FilterProperty> availableProperties,
    required ValueChanged<SavedFilter?> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: DraggableScrollableSheet(
          initialChildSize: 0.80,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => FilterSortSheet(
            targetType: targetType,
            currentFilter: currentFilter,
            availableProperties: availableProperties,
            onApply: (f) {
              Navigator.pop(ctx);
              onApply(f);
            },
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends ConsumerState<FilterSortSheet> {
  late SavedFilter _draft;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter ??
        SavedFilter(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Novo filtro',
          targetType: widget.targetType,
        );
    _nameController.text = _draft.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(settingsProvider).filtersFor(widget.targetType);
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.dividerColor(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              const Text(
                'Filtrar & Ordenar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Filtros salvos ──
                _section(
                  'MEUS FILTROS',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...saved.map(_savedChip),
                        _addSavedChip(),
                      ],
                    ),
                  ),
                ),
                // ── Regras ──
                _section(
                  'FILTRAR POR',
                  child: Column(
                    children: [
                      ..._draft.rules.asMap().entries.map(
                        (e) => _ruleCard(e.key, e.value),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _addRule,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.info.withOpacity(0.25),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                                color: AppColors.info,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Adicionar filtro',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Ordenar ──
                _section(
                  'ORDENAR POR',
                  child: Column(
                    children: [
                      _dropdownRow(
                        SortField.values.map((f) => f.name).toList(),
                        _draft.sortBy.name,
                        (val) => setState(
                          () => _draft = _draft.copyWith(
                            sortBy: SortField.values.byName(val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _directionBtn('↓ Mais recente', false),
                          const SizedBox(width: 8),
                          _directionBtn('↑ Mais antigo', true),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Agrupar ──
                _section(
                  'AGRUPAR POR',
                  child: _dropdownRow(
                    GroupField.values.map((f) => f.name).toList(),
                    _draft.groupBy.name,
                    (val) => setState(
                      () => _draft = _draft.copyWith(
                        groupBy: GroupField.values.byName(val),
                      ),
                    ),
                  ),
                ),
                // ── Visualização ──
                _section(
                  'VISUALIZAÇÃO',
                  child: Row(
                    children: [
                      _viewBtn('⊞ Grade', ViewMode.grid),
                      const SizedBox(width: 8),
                      _viewBtn('☰ Lista', ViewMode.list),
                      const SizedBox(width: 8),
                      _viewBtn('§ Grupos', ViewMode.grouped),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Footer
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            10 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Limpar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String label, {required Widget child}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.10,
            color: AppTheme.textMutedColor(context),
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 4),
      ],
    ),
  );

  Widget _savedChip(SavedFilter f) {
    final isActive = _draft.id == f.id;
    return GestureDetector(
      onTap: () => setState(() => _draft = f),
      onLongPress: () => _deleteFilter(f),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isActive
                  ? AppColors.primary.withOpacity(0.15)
                  : AppTheme.surfaceVariantColor(context),
          border:
              isActive
                  ? Border.all(color: AppColors.primary.withOpacity(0.3))
                  : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          f.name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color:
                isActive ? AppColors.primary : AppTheme.textSecondaryColor(context),
          ),
        ),
      ),
    );
  }

  Widget _addSavedChip() => GestureDetector(
    onTap: _promptSaveCurrent,
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '＋ Salvar atual',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.info,
        ),
      ),
    ),
  );

  /// Each rule is shown as a compact card with dropdowns stacked vertically
  /// to avoid Row overflow issues.
  Widget _ruleCard(int index, FilterRule rule) {
    final prop = widget.availableProperties.firstWhere(
      (p) => p.key == rule.property,
      orElse: () => widget.availableProperties.first,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Property selector
                _labelledDropdown<String>(
                  label: 'Propriedade',
                  value: widget.availableProperties.any(
                        (p) => p.key == rule.property,
                      )
                      ? rule.property
                      : widget.availableProperties.first.key,
                  items: widget.availableProperties
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.key,
                          child: Text(
                            p.label,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final rules = _draft.rules.toList();
                    rules[index] = FilterRule(
                      property: val,
                      op: FilterOperator.equals,
                      value: '',
                    );
                    setState(() => _draft = _draft.copyWith(rules: rules));
                  },
                ),
                const SizedBox(height: 6),
                // Row 2: Operator + Value side by side
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: _labelledDropdown<FilterOperator>(
                        label: 'Operador',
                        value: rule.op,
                        items: [
                          FilterOperator.equals,
                          FilterOperator.notEquals,
                          FilterOperator.contains,
                          FilterOperator.isEmpty,
                        ]
                            .map(
                              (op) => DropdownMenuItem(
                                value: op,
                                child: Text(
                                  _opLabel(op),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final rules = _draft.rules.toList();
                          rules[index] = FilterRule(
                            property: rule.property,
                            op: val,
                            value: rule.value,
                          );
                          setState(
                            () => _draft = _draft.copyWith(rules: rules),
                          );
                        },
                      ),
                    ),
                    if (rule.op != FilterOperator.isEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(child: _valueField(rule, index, prop)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            onPressed: () {
              final rules = _draft.rules.toList()..removeAt(index);
              setState(() => _draft = _draft.copyWith(rules: rules));
            },
            icon: const Icon(
              Icons.remove_circle_outline_rounded,
              size: 18,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelledDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMutedColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.dividerColor(context),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _valueField(FilterRule rule, int index, FilterProperty prop) {
    if (prop.allowedValues != null && prop.allowedValues!.isNotEmpty) {
      final currentVal = prop.allowedValues!.contains(rule.value)
          ? rule.value as String
          : null;
      return _labelledDropdown<String>(
        label: 'Valor',
        value: currentVal ?? prop.allowedValues!.first,
        items: prop.allowedValues!
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v, style: const TextStyle(fontSize: 12)),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val == null) return;
          final rules = _draft.rules.toList();
          rules[index] = FilterRule(
            property: rule.property,
            op: rule.op,
            value: val,
          );
          setState(() => _draft = _draft.copyWith(rules: rules));
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valor',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMutedColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.dividerColor(context)),
          ),
          child: TextFormField(
            initialValue: rule.value?.toString() ?? '',
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Digite o valor',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (val) {
              final rules = _draft.rules.toList();
              rules[index] = FilterRule(
                property: rule.property,
                op: rule.op,
                value: val,
              );
              setState(() => _draft = _draft.copyWith(rules: rules));
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdownRow(
    List<String> options,
    String current,
    ValueChanged<String> onChange,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceVariantColor(context),
      borderRadius: BorderRadius.circular(10),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: current,
        isExpanded: true,
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o,
                child: Text(o, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val != null) onChange(val);
        },
      ),
    ),
  );

  Widget _directionBtn(String label, bool ascending) {
    final active = _draft.sortAscending == ascending;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(
          () => _draft = _draft.copyWith(sortAscending: ascending),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color:
                active
                    ? AppColors.primary.withOpacity(0.12)
                    : AppTheme.surfaceVariantColor(context),
            border:
                active
                    ? Border.all(color: AppColors.primary.withOpacity(0.3))
                    : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    active
                        ? AppColors.primary
                        : AppTheme.textSecondaryColor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _viewBtn(String label, ViewMode mode) {
    final active = _draft.viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _draft = _draft.copyWith(viewMode: mode)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color:
                active
                    ? AppColors.primary.withOpacity(0.12)
                    : AppTheme.surfaceVariantColor(context),
            border:
                active
                    ? Border.all(color: AppColors.primary.withOpacity(0.3))
                    : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    active
                        ? AppColors.primary
                        : AppTheme.textSecondaryColor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addRule() {
    if (widget.availableProperties.isEmpty) return;
    final prop = widget.availableProperties.first;
    // Pre-fill value with the first allowed value if available
    final defaultValue =
        prop.allowedValues?.isNotEmpty == true ? prop.allowedValues!.first : '';
    setState(
      () => _draft = _draft.copyWith(
        rules: [
          ..._draft.rules,
          FilterRule(
            property: prop.key,
            op: FilterOperator.equals,
            value: defaultValue,
          ),
        ],
      ),
    );
  }

  void _clear() => setState(
    () => _draft = SavedFilter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Todos',
      targetType: widget.targetType,
    ),
  );

  void _apply() {
    // Check if this filter is one of the persisted saved filters
    final saved = ref.read(settingsProvider).filtersFor(widget.targetType);
    final isSavedFilter = saved.any((f) => f.id == _draft.id);

    final isBlank =
        !isSavedFilter &&
        _draft.rules.isEmpty &&
        _draft.groupBy == GroupField.none &&
        _draft.sortBy == SortField.modified &&
        _draft.sortAscending == false;
    widget.onApply(isBlank ? null : _draft);
  }

  void _promptSaveCurrent() async {
    _nameController.text = _draft.name == 'Todos' ? '' : _draft.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar filtro'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome do filtro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final toSave = _draft.copyWith(name: name);
    await ref.read(settingsProvider.notifier).upsertSavedFilter(toSave);
    setState(() => _draft = toSave);
  }

  void _deleteFilter(SavedFilter f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${f.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).deleteSavedFilter(f.id);
      if (_draft.id == f.id) _clear();
    }
  }

  String _opLabel(FilterOperator op) => switch (op) {
    FilterOperator.equals => '=',
    FilterOperator.notEquals => '≠',
    FilterOperator.contains => 'contém',
    FilterOperator.greaterThan => '>',
    FilterOperator.lessThan => '<',
    FilterOperator.isEmpty => 'vazio',
  };
}
