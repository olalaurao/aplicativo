// lib/ui/screens/detail_views/resource_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/resource_model.dart';
import '../../../providers/vault_provider.dart';
import '../../../services/markdown_parser.dart';
import '../../theme.dart';
import '../../widgets/linked_objects_section.dart';

/// Resource-specific content section for universal detail view
List<Widget> buildResourceContentSection(
  BuildContext context,
  WidgetRef ref,
  Resource resource,
  Color Function(ResourceStatus) resourceStatusColor,
  String Function(ResourceStatus) resourceStatusLabel,
  Widget Function(BuildContext, {required IconData icon, required String label, required String value, bool isEmpty}) miniPropCard,
  Widget Function(BuildContext, WidgetRef, Resource, List<HighlightItem>) buildHighlightsSection,
  Widget Function(BuildContext, WidgetRef, Resource) buildSynopsisSection,
  VoidCallback startFocusSession,
) {
  final readDateStr = resource.readDate != null
      ? DateFormat('d MMM yyyy').format(resource.readDate!)
      : 'N/A';
  final statusColor = resourceStatusColor(resource.status);
  final highlights = MarkdownParser.extractHighlights(resource.synopsis ?? '');

  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          children: [
            if (resource.coverImage != null)
              Center(
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      resource.coverImage!,
                      height: 220,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              resource.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Resource · ${resource.mediaType}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () =>
                  _showResourceStatusPicker(context, ref, resource),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      resourceStatusLabel(resource.status).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                miniPropCard(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: 'Created',
                  value: DateFormat('d MMM').format(resource.createdAt),
                ),
                miniPropCard(
                  context,
                  icon: Icons.update_rounded,
                  label: 'Modified',
                  value: DateFormat('d MMM').format(resource.updatedAt),
                ),
                miniPropCard(
                  context,
                  icon: Icons.person_outline_rounded,
                  label: 'Author',
                  value: resource.author ?? 'N/A',
                  isEmpty: resource.author == null,
                ),
                miniPropCard(
                  context,
                  icon: Icons.date_range_outlined,
                  label: 'Year',
                  value: resource.year?.toString() ?? 'N/A',
                  isEmpty: resource.year == null,
                ),
                miniPropCard(
                  context,
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: resource.category ?? 'No category',
                  isEmpty: resource.category == null,
                ),
                miniPropCard(
                  context,
                  icon: Icons.menu_book_outlined,
                  label: 'Read Date',
                  value: readDateStr,
                  isEmpty: resource.readDate == null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            buildHighlightsSection(context, ref, resource, highlights),
          ],
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.timer_outlined, size: 18),
          label: const Text('Start Pomodoro Session'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: startFocusSession,
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: LinkedObjectsSection(
        owner: resource,
        links: resource.links,
        onAdd: (selected) async {
          final linkRef = '[[${selected.slug}]]';
          if (resource.links.contains(linkRef)) return;
          final updated = resource.copyWith(
            links: [...resource.links, linkRef],
            updatedAt: DateTime.now(),
          );
          await ref
              .read(vaultProvider.notifier)
              .updateObject(updated);
        },
        onRemove: (slug) async {
          final updated = resource.copyWith(
            links: resource.links
                .where((r) => r != slug)
                .toList(),
            updatedAt: DateTime.now(),
          );
          await ref
              .read(vaultProvider.notifier)
              .updateObject(updated);
        },
      ),
    ),
  ];
}

void _showResourceStatusPicker(BuildContext context, WidgetRef ref, Resource resource) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Resource Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: ResourceStatus.values.map((status) {
          return ListTile(
            title: Text(_resourceStatusLabel(status)),
            onTap: () async {
              final updated = resource.copyWith(status: status);
              await ref.read(vaultProvider.notifier).updateObject(updated);
              if (context.mounted) Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    ),
  );
}

String _resourceStatusLabel(ResourceStatus status) {
  switch (status) {
    case ResourceStatus.toConsume:
      return 'To Consume';
    case ResourceStatus.inProgress:
      return 'In Progress';
    case ResourceStatus.completed:
      return 'Completed';
    case ResourceStatus.dropped:
      return 'Dropped';
  }
}
