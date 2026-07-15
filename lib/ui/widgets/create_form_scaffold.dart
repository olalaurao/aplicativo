import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import 'discard_guard.dart';
import 'template_picker_sheet.dart';
import '../../models/template_model.dart';
import '../../providers/vault_provider.dart';

class CreateFormScaffold extends ConsumerStatefulWidget {
  final String title;
  final Widget child;
  final VoidCallback onSave;
  final bool canSave;
  final VoidCallback? onTemplatePick;
  final String? templateObjectType;
  final bool showTemplateButton;
  final Widget? floatingActionButton;
  final Widget? bottomSheet;

  const CreateFormScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    required this.canSave,
    this.onTemplatePick,
    this.templateObjectType,
    this.showTemplateButton = false,
    this.floatingActionButton,
    this.bottomSheet,
  });

  @override
  ConsumerState<CreateFormScaffold> createState() => _CreateFormScaffoldState();
}

class _CreateFormScaffoldState extends ConsumerState<CreateFormScaffold> {
  bool _isDirty = false;

  @override
  Widget build(BuildContext context) {
    return DiscardGuard(
      isDirty: _isDirty,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
              actions: [
                if (widget.showTemplateButton && widget.templateObjectType != null)
                  IconButton(
                    icon: const Icon(Icons.copy_all_rounded),
                    onPressed: _pickTemplate,
                    tooltip: 'Use Template',
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    setState(() => _isDirty = true);
                  }
                  return false;
                },
                child: widget.child,
              ),
            ),
          ],
        ),
        floatingActionButton: widget.floatingActionButton,
        bottomSheet: widget.bottomSheet ??
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.divider,
                      width: 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: widget.canSave ? widget.onSave : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentColor(context),
                      disabledBackgroundColor: AppColors.textMuted.withValues(
                        alpha: 0.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _pickTemplate() async {
    if (widget.templateObjectType == null) return;

    await TemplatePickerSheet.show(
      context,
      objectType: widget.templateObjectType!,
      onTemplateSelected: (template) {
        if (widget.onTemplatePick != null) {
          widget.onTemplatePick!();
        }
      },
    );
  }
}
