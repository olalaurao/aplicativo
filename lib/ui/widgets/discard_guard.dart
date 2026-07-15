import 'package:flutter/material.dart';

class DiscardGuard extends StatelessWidget {
  final bool isDirty;
  final Widget child;

  const DiscardGuard({
    super.key,
    required this.isDirty,
    required this.child,
  });

  Future<bool> _onWillPop() async {
    if (!isDirty) return true;

    final confirmed = await showDialog<bool>(
      context: child.key as BuildContext,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('Você tem alterações não salvas. Deseja sair sem salvar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (isDirty) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: child,
    );
  }
}
