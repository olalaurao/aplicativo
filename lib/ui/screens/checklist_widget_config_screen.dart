import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../services/widget_service.dart';
import '../theme.dart';

class ChecklistWidgetConfigScreen extends ConsumerStatefulWidget {
  final int? widgetId;

  const ChecklistWidgetConfigScreen({super.key, this.widgetId});

  @override
  ConsumerState<ChecklistWidgetConfigScreen> createState() => _ChecklistWidgetConfigScreenState();
}

class _ChecklistWidgetConfigScreenState extends ConsumerState<ChecklistWidgetConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final allNotes = ref.watch(notesProvider);
    final checklists = allNotes.where((n) => n.isChecklist).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Checklist'),
        backgroundColor: AppColors.surface,
      ),
      backgroundColor: AppColors.surface,
      body: checklists.isEmpty
          ? const Center(
              child: Text(
                'Nenhuma checklist encontrada.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.builder(
              itemCount: checklists.length,
              itemBuilder: (context, index) {
                final note = checklists[index];
                return ListTile(
                  title: Text(
                    note.title.isNotEmpty ? note.title : 'Sem Título',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    note.slug,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  onTap: () async {
                    if (widget.widgetId != null) {
                      await WidgetService.updateNote(
                        widgetId: widget.widgetId!,
                        title: note.title,
                        content: note.body,
                        slug: note.slug,
                      );
                    } else {
                      // Fallback case if widgetId is not provided
                      await WidgetService.updateNote(
                        widgetId: 0,
                        title: note.title,
                        content: note.body,
                        slug: note.slug,
                      );
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                );
              },
            ),
    );
  }
}
