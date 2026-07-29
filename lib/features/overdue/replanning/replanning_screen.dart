// lib/features/overdue/replanning/replanning_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../ui/theme.dart';
import '../../../providers/overdue_provider.dart';
import 'replanning_actions.dart';

class ReplanningScreen extends ConsumerStatefulWidget {
  const ReplanningScreen({super.key});

  @override
  ConsumerState<ReplanningScreen> createState() => _ReplanningScreenState();
}

class _ReplanningScreenState extends ConsumerState<ReplanningScreen> {
  Set<String> selectedItems = {};

  @override
  Widget build(BuildContext context) {
    final overdueItems = ref.watch(overdueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Replan Overdue Items'),
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        elevation: 0,
        actions: [
          if (selectedItems.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showBatchActions(context, ref),
              icon: const Icon(Icons.check_circle),
              label: const Text('Apply to all'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
        ],
      ),
      body: overdueItems.isEmpty
          ? _buildEmptyState()
          : _buildOverdueList(overdueItems),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No overdue items.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueList(List<OverdueItem> overdueItems) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: overdueItems.length,
      itemBuilder: (context, index) {
        final overdueItem = overdueItems[index];
        final isSelected = selectedItems.contains(overdueItem.object.id);

        return _OverdueItemCard(
          item: overdueItem,
          isSelected: isSelected,
          onSelect: () {
            setState(() {
              if (isSelected) {
                selectedItems.remove(overdueItem.object.id);
              } else {
                selectedItems.add(overdueItem.object.id);
              }
            });
          },
          onAction: (action) {
            ReplanningActions.executeAction(
              context,
              ref,
              overdueItem,
              action,
            );
          },
        );
      },
    );
  }

  void _showBatchActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Apply to ${selectedItems.length} items',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _BatchActionButton(
              icon: Icons.add_circle_outline,
              label: 'Defer 1 day',
              color: AppColors.info,
              onTap: () {
                ReplanningActions.executeBatchAction(
                  context,
                  ref,
(_) => selectedItems,
                  ReplanningAction.deferOneDay,
                );
                Navigator.pop(context);
                setState(() => selectedItems.clear());
              },
            ),
            const SizedBox(height: 8),
            _BatchActionButton(
              icon: Icons.calendar_today,
              label: 'Defer 1 week',
              color: AppColors.info,
              onTap: () {
                ReplanningActions.executeBatchAction(
                  context,
                  ref,
(_) => selectedItems,
                  ReplanningAction.deferOneWeek,
                );
                Navigator.pop(context);
                setState(() => selectedItems.clear());
              },
            ),
            const SizedBox(height: 8),
            _BatchActionButton(
              icon: Icons.check_circle,
              label: 'Mark as done',
              color: AppColors.success,
              onTap: () {
                ReplanningActions.executeBatchAction(
                  context,
                  ref,
(_) => selectedItems,
                  ReplanningAction.complete,
                );
                Navigator.pop(context);
                setState(() => selectedItems.clear());
              },
            ),
            const SizedBox(height: 8),
            _BatchActionButton(
              icon: Icons.delete_outline,
              label: 'Discard',
              color: AppColors.error,
              onTap: () {
                ReplanningActions.executeBatchAction(
                  context,
                  ref,
(_) => selectedItems,
                  ReplanningAction.discard,
                );
                Navigator.pop(context);
                setState(() => selectedItems.clear());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OverdueItemCard extends StatelessWidget {
  final OverdueItem item;
  final bool isSelected;
  final VoidCallback onSelect;
  final Function(ReplanningAction) onAction;

  const _OverdueItemCard({
    required this.item,
    required this.isSelected,
    required this.onSelect,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = severityColor(item.severity);
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardFillColor(context),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: isSelected ? color : AppTheme.dividerColor(context),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onSelect,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.object.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              item.itemType,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.daysLate} days overdue',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelect(),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.add_circle_outline,
                    label: '+1 day',
                    onTap: () => onAction(ReplanningAction.deferOneDay),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.calendar_today,
                    label: '+1 wk',
                    onTap: () => onAction(ReplanningAction.deferOneWeek),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.check_circle,
                    label: 'Complete',
                    onTap: () => onAction(ReplanningAction.complete),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.delete_outline,
                    label: 'Discard',
                    onTap: () => onAction(ReplanningAction.discard),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BatchActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
