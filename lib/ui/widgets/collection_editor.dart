// lib/ui/widgets/collection_editor.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import '../theme.dart';

enum PropertyType {
  text,
  richText,
  quantity,
  date,
  time,
  duration,
  selection,
  multiSelection,
  checkbox,
  url,
  email,
  phone,
  rating,
  relation,
  media,
}

class PropertyDefinition {
  String id;
  String name;
  PropertyType type;
  List<String>? options; // for selection types

  PropertyDefinition({
    required this.id,
    required this.name,
    required this.type,
    this.options,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'options': options,
  };

  factory PropertyDefinition.fromMap(Map<String, dynamic> map) =>
      PropertyDefinition(
        id: map['id'],
        name: map['name'],
        type: PropertyType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => PropertyType.text,
        ),
        options: map['options'] != null
            ? List<String>.from(map['options'])
            : null,
      );
}

class CollectionEditor extends StatefulWidget {
  final String initialContent;
  final Function(String) onChanged;

  const CollectionEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
  });

  @override
  State<CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<CollectionEditor> {
  List<PropertyDefinition> _schema = [];
  List<Map<String, dynamic>> _items = [];
  bool _isConfiguringSchema = true;

  // Controller cache to prevent text being lost on rebuild
  final Map<String, TextEditingController> _cellControllers = {};

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  @override
  void dispose() {
    for (final c in _cellControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _cellController(String itemId, String propId, String value) {
    final key = '${itemId}_$propId';
    if (!_cellControllers.containsKey(key)) {
      _cellControllers[key] = TextEditingController(text: value);
    }
    return _cellControllers[key]!;
  }

  void _parseContent() {
    if (widget.initialContent.isEmpty) return;
    try {
      final data = jsonDecode(widget.initialContent);
      final schemaData = data is Map ? data['schema'] : null;
      final itemData = data is Map ? data['items'] : null;
      if (schemaData is List) {
        _schema = schemaData
            .whereType<Map>()
            .map((e) => PropertyDefinition.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (itemData is List) {
        _items = itemData
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (_schema.isNotEmpty) _isConfiguringSchema = false;
    } catch (e) {
      debugPrint('CollectionEditor parse error: $e');
    }
  }

  void _save() {
    final data = {
      'schema': _schema.map((e) => e.toMap()).toList(),
      'items': _items,
    };
    widget.onChanged(jsonEncode(data));
  }

  void _addProperty() {
    setState(() {
      _schema.add(
        PropertyDefinition(
          id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
          name: '',
          type: PropertyType.text,
        ),
      );
    });
    _save();
  }

  void _addItem() {
    if (_schema.isEmpty) return;
    setState(() {
      final newItem = <String, dynamic>{
        'id': 'item_${DateTime.now().microsecondsSinceEpoch}',
      };
      for (var p in _schema) {
        newItem[p.id] = '';
      }
      _items.add(newItem);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isConfiguringSchema
              ? _buildSchemaEditor()
              : _buildDataView(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final canShowItems = _schema.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isConfiguringSchema ? 'Properties' : 'Items (${_items.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isConfiguringSchema && canShowItems)
            TextButton.icon(
              onPressed: () => setState(() => _isConfiguringSchema = false),
              icon: const Icon(Icons.table_chart_outlined, size: 16),
              label: const Text('Ver itens'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor(context)),
            ),
          if (!_isConfiguringSchema) ...[
            IconButton(
              tooltip: 'Editar estrutura',
              icon: const Icon(Icons.settings_outlined, size: 20),
              color: AppColors.textSecondary,
              onPressed: () => setState(() => _isConfiguringSchema = true),
            ),
            FilledButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('+ Linha'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentColor(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSchemaEditor() {
    return Padding(
      key: const ValueKey('schema'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._schema.asMap().entries.map(
            (entry) => _buildPropertyRow(entry.key, entry.value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _addProperty,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Property'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor(context)),
              ),
              if (_schema.isNotEmpty) ...[
                const Spacer(),
                FilledButton(
                  onPressed: () => setState(() => _isConfiguringSchema = false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentColor(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Confirmar →'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(int index, PropertyDefinition prop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: prop.name,
              decoration: const InputDecoration(
                hintText: 'Property name',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              onChanged: (v) {
                prop.name = v;
                _save();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PropertyType>(
                value: prop.type,
                isExpanded: true,
                isDense: true,
                items: PropertyType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name, style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => prop.type = v);
                  _save();
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.priorityHigh),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              setState(() => _schema.removeAt(index));
              _save();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataView() {
    if (_schema.isEmpty) {
      return const Padding(
        key: ValueKey('data-empty'),
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Defina ao menos uma propriedade primeiro.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        key: const ValueKey('data-no-items'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Center(
                child: Text(
                  'Nenhum item ainda.\nToque em "+ Linha" para adicionar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      key: const ValueKey('data-list'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final itemId = item['id']?.toString() ?? 'item_$idx';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with delete button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                  child: Row(
                    children: [
                      Text(
                        'Item ${idx + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: AppColors.error),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          // Clean up controllers for this item
                          for (final p in _schema) {
                            _cellControllers.remove('${itemId}_${p.id}');
                          }
                          setState(() => _items.removeAt(idx));
                          _save();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),
                // Fields
                ..._schema.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          p.name.isEmpty ? p.type.name : p.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _buildCellEditor(p, item, itemId)),
                    ],
                  ),
                )),
                const SizedBox(height: 4),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCellEditor(PropertyDefinition p, Map<String, dynamic> item, String itemId) {
    if (p.type == PropertyType.checkbox) {
      final value = item[p.id] == true || item[p.id] == 'true';
      return Checkbox(
        value: value,
        activeColor: AppTheme.accentColor(context),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onChanged: (v) {
          setState(() => item[p.id] = v);
          _save();
        },
      );
    }

    if (p.type == PropertyType.rating) {
      final value = int.tryParse(item[p.id]?.toString() ?? '0') ?? 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          return InkWell(
            onTap: () {
              setState(() => item[p.id] = i + 1);
              _save();
            },
            child: Icon(
              i < value ? Icons.star_rounded : Icons.star_border_rounded,
              color: AppColors.warning,
              size: 18,
            ),
          );
        }),
      );
    }

    // Default: text field with cached controller
    final ctrl = _cellController(itemId, p.id, item[p.id]?.toString() ?? '');
    return TextField(
      controller: ctrl,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 4),
        hintText: '—',
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
      style: const TextStyle(fontSize: 14),
      onChanged: (v) {
        item[p.id] = v;
        _save();
      },
    );
  }
}
