// lib/ui/screens/inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../providers/vault_provider.dart';
import '../../models/inbox_model.dart';
import '../theme.dart';
import '../forms/create_task_form.dart';
import '../forms/create_note_form.dart';
import '../forms/create_entry_form.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final TextEditingController _captureController = TextEditingController();
  final FocusNode _captureFocus = FocusNode();
  bool _isCapturing = false;

  @override
  void dispose() {
    _captureController.dispose();
    _captureFocus.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final text = _captureController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    await ref.read(inboxProvider.notifier).addItem(text);
    _captureController.clear();
    setState(() => _isCapturing = false);
    _captureFocus.unfocus();
  }

  void _showTriageSheet(BuildContext ctx, InboxItem item) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _TriageSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(inboxProvider, (prev, next) {
      if (next.hasValue) {
        final notifier = ref.read(inboxProvider.notifier);
        if (notifier.autoArchivedTitles.isNotEmpty) {
          final titles = List<String>.from(notifier.autoArchivedTitles);
          notifier.clearAutoArchived();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${titles.length} item(s) antigo(s) do Inbox arquivado(s) automaticamente: ${titles.join(", ")}',
                ),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 6),
              ),
            );
          });
        }
      }
    });

    final inboxAsync = ref.watch(inboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Capturar'),
            onPressed: () {
              setState(() => _isCapturing = true);
              Future.delayed(
                const Duration(milliseconds: 100),
                () => _captureFocus.requestFocus(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick capture bar
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isCapturing
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardFillColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _captureController,
                        focusNode: _captureFocus,
                        decoration: const InputDecoration(
                          hintText: 'O que está na sua cabeça?',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _capture(),
                      ),
                    ),
                    IconButton(
                      onPressed: _capture,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() => _isCapturing = false);
                        _captureFocus.unfocus();
                      },
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),

          // List
          Expanded(
            child: inboxAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyInboxState(
                    onCapture: () {
                      setState(() => _isCapturing = true);
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _captureFocus.requestFocus(),
                      );
                    },
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return _InboxItemCard(
                      item: item,
                      onTriage: () => _showTriageSheet(ctx, item),
                      onDelete: () async {
                        HapticFeedback.mediumImpact();
                        await ref
                            .read(inboxProvider.notifier)
                            .deleteItem(item);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: const Text('Item removido do Inbox'),
                              action: SnackBarAction(
                                label: 'OK',
                                textColor: AppColors.primary,
                                onPressed: () {},
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyInboxState extends StatelessWidget {
  final VoidCallback onCapture;
  const _EmptyInboxState({required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 72,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            const Text(
              'Inbox vazio',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Capture qualquer ideia, tarefa ou pensamento\nsem precisar categorizar agora.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Capturar agora'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item Card ────────────────────────────────────────────────────────────────
class _InboxItemCard extends StatelessWidget {
  final InboxItem item;
  final VoidCallback onTriage;
  final VoidCallback onDelete;

  const _InboxItemCard({
    required this.item,
    required this.onTriage,
    required this.onDelete,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTriage,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inbox_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(item.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onTriage,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Triar',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Triage Sheet ─────────────────────────────────────────────────────────────
class _TriageSheet extends ConsumerWidget {
  final InboxItem item;
  const _TriageSheet({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'O que é isso?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _TriageOption(
            icon: Icons.check_box_outlined,
            color: AppColors.info,
            label: 'Virou uma task',
            subtitle: 'Criar tarefa com este título',
            onTap: () async {
              await ref.read(inboxProvider.notifier).triageItem(item);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateTaskForm(initialTitle: item.title),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          _TriageOption(
            icon: Icons.description_outlined,
            color: AppColors.habitPink,
            label: 'Era uma ideia (nota)',
            subtitle: 'Criar nota com este conteúdo',
            onTap: () async {
              await ref.read(inboxProvider.notifier).triageItem(item);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateNoteForm(initialTitle: item.title),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          _TriageOption(
            icon: Icons.menu_book_rounded,
            color: AppColors.primary,
            label: 'É uma entrada do journal',
            subtitle: 'Adicionar ao diário de hoje',
            onTap: () async {
              await ref.read(inboxProvider.notifier).triageItem(item);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEntryForm(initialBody: item.title),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          _TriageOption(
            icon: Icons.delete_outline_rounded,
            color: AppColors.error,
            label: 'Deletar',
            subtitle: 'Não era importante',
            onTap: () async {
              await ref.read(inboxProvider.notifier).deleteItem(item);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TriageOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _TriageOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
