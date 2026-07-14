// lib/ui/screens/detail_sections/idea_content_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/content_object.dart';
import '../../../models/idea_model.dart';
import '../../../providers/vault_provider.dart';
import '../../widgets/wiki_text_view.dart';
import '../../theme.dart';
import '../universal_detail_view.dart';

/// Idea-specific content section for universal detail view
List<Widget> buildIdeaContentSection(
  BuildContext context,
  WidgetRef ref,
  IdeaDefinition idea,
  IconData Function(String) typeIcon,
) {
  final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
  
  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conteúdo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(context),
              child: idea.body.trim().isEmpty
                  ? Text(
                      'Sem conteúdo',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                    )
                  : WikiTextView(
                      text: idea.body,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
            ),
            if (idea.linkedSlugs.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Vínculos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...idea.linkedSlugs.map((slug) {
                final linked = allObjects.cast<ContentObject?>().firstWhere(
                  (o) =>
                      o != null &&
                      (o.slug == slug ||
                          o.id == slug ||
                          o.title == slug),
                  orElse: () => null,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: AppTheme.surfaceColor(context),
                    leading: Icon(
                      linked != null
                          ? typeIcon(linked.type)
                          : Icons.link_rounded,
                      color: AppTheme.accentColor(context),
                    ),
                    title: Text(
                      linked?.title ?? slug,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      linked?.type.toUpperCase() ?? 'LINK',
                      style: const TextStyle(fontSize: 10),
                    ),
                    onTap: linked != null
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UniversalDetailView(object: linked),
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    ),
  ];
}
