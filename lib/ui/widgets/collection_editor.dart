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
        type: PropertyType.values.firstWhere((e) => e.name == map['type']),
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

  @override
  void initState() {
    super.initState();
    _parseContent();
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
            .map(
              (e) => PropertyDefinition.fromMap(Map<String, dynamic>.from(e)),
            )
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
      // Not JSON or invalid
    }
  }

  void _save() {
    final data = {
      'schema': _schema.map((e) => e.toMap()).toList(),
      'items': _items,
    };
    widget.onChanged(jsonEncode(data));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCollectionToolbar(),
        const SizedBox(height: 16),
        _isConfiguringSchema ? _buildSchemaEditor() : _buildDataView(),
      ],
    );
  }

  Widget _buildCollectionToolbar() {
    final canShowItems = _schema.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isConfiguringSchema ? 'Properties' : 'Items',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isConfiguringSchema && canShowItems)
            TextButton.icon(
              onPressed: () => setState(() => _isConfiguringSchema = false),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Items'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          if (!_isConfiguringSchema) ...[
            IconButton(
              tooltip: 'Configure properties',
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.textSecondary,
              onPressed: () => setState(() => _isConfiguringSchema = true),
            ),
            FilledButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New row'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSchemaEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._schema.asMap().entries.map(
            (entry) => _buildPropertyRow(entry.key, entry.value),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _addProperty,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Property'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(int index, PropertyDefinition prop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Property Name',
                border: InputBorder.none,
              ),
              onChanged: (v) {
                prop.name = v;
                _save();
              },
              controller: TextEditingController(text: prop.name)
                ..selection = TextSelection.collapsed(offset: prop.name.length),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: DropdownButton<PropertyType>(
              value: prop.type,
              isExpanded: true,
              underline: const SizedBox(),
              items: PropertyType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => prop.type = v);
                _save();
              },
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppColors.priorityHigh,
            ),
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
      return const Center(child: Text('Add properties first.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          ..._schema.map((p) => DataColumn(label: Text(p.name))),
          const DataColumn(label: Text('')),
        ],
        rows: [
          ..._items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return DataRow(
              cells: [
                ..._schema.map((p) => DataCell(_buildCellEditor(p, item))),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: () {
                      setState(() => _items.removeAt(idx));
                      _save();
                    },
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
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

  Widget _buildCellEditor(PropertyDefinition p, Map<String, dynamic> item) {
    if (p.type == PropertyType.checkbox) {
      final value = item[p.id] == true || item[p.id] == 'true';
      return Checkbox(
        value: value,
        activeColor: AppColors.primary,
        onChanged: (v) {
          setState(() {
            item[p.id] = v;
          });
          _save();
        },
      );
    } else if (p.type == PropertyType.rating) {
      final value = int.tryParse(item[p.id]?.toString() ?? '0') ?? 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          return InkWell(
            onTap: () {
              setState(() {
                item[p.id] = index + 1;
              });
              _save();
            },
            child: Icon(
              index < value ? Icons.star_rounded : Icons.star_border_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          );
        }),
      );
    } else {
      return TextField(
        decoration: const InputDecoration(border: InputBorder.none),
        onChanged: (v) {
          item[p.id] = v;
          _save();
        },
        controller: TextEditingController(text: item[p.id]?.toString() ?? '')
          ..selection = TextSelection.collapsed(
            offset: (item[p.id]?.toString() ?? '').length,
          ),
      );
    }
  }
}
