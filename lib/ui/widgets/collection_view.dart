// lib/ui/widgets/collection_view.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import '../theme.dart';
import 'collection_editor.dart';

class CollectionView extends StatelessWidget {
  final String content;
  final Function(String)? onChanged;

  const CollectionView({super.key, required this.content, this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Empty Collection. Use "Edit" to define schema.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    try {
      final data = jsonDecode(content);
      final List<dynamic> schemaRaw = data['schema'] ?? [];
      final List<dynamic> itemsRaw = data['items'] ?? [];

      final schema = schemaRaw
          .map((e) => PropertyDefinition.fromMap(e))
          .toList();
      final items = List<Map<String, dynamic>>.from(itemsRaw);

      if (schema.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'No properties defined. Use "Edit" to add fields.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: AppTheme.cardDecoration(context),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppColors.surfaceVariant.withValues(alpha: 0.5),
            ),
            columnSpacing: 32,
            columns: schema
                .map(
                  (p) => DataColumn(
                    label: Text(
                      p.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                )
                .toList(),
            rows: items
                .map(
                  (item) => DataRow(
                    cells: schema
                        .map(
                          (p) => DataCell(
                            Text(
                              item[p.id]?.toString() ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      );
    } catch (e) {
      return Center(
        child: Text(
          'Error rendering collection: $e',
          style: const TextStyle(color: AppColors.error),
        ),
      );
    }
  }
}
