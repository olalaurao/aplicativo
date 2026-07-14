// lib/ui/screens/detail_views/note_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/note_model.dart';
import '../../../models/content_object.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../../widgets/object_action_wrapper.dart';
import '../universal_detail_view.dart';
import '../../widgets/rich_text_editor.dart';
import '../../widgets/outline_editor.dart';
import '../../widgets/collection_view.dart';
import '../../widgets/checklist_view.dart';
import '../../widgets/markdown_body_view.dart';

/// Note-specific content section for universal detail view
List<Widget> buildNoteContentSection(
  BuildContext context,
  WidgetRef ref,
  Note note,
  bool isEditing,
  Widget Function(BuildContext, Note) buildNoteEditor,
  Widget Function(BuildContext, Note) buildNoteViewer,
  Widget Function(BuildContext, Note) buildNoteListItem,
) {
  final childNotes = ref.watch(notesProvider.select((notes) => notes.where((n) => n.parentNoteId == note.id).toList()));

  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: isEditing
              ? buildNoteEditor(context, note)
              : buildNoteViewer(context, note),
        ),
      ),
    ),
    if (childNotes.isNotEmpty) ...[
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
          child: Text(
            'Nested Notes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => buildNoteListItem(context, childNotes[index]),
            childCount: childNotes.length,
          ),
        ),
      ),
    ],
  ];
}

/// Build note editor based on subtype
Widget buildNoteEditor(BuildContext context, WidgetRef ref, Note note) {
  switch (note.subtype) {
    case NoteSubtype.text:
      return RichTextEditor(
        content: note.body,
        expands: false,
        onChanged: (v) {
          final updated = note.copyWith(body: v);
          ref.read(vaultProvider.notifier).updateObject(updated);
        },
      );
    case NoteSubtype.outline:
      return OutlineEditor(
        initialContent: note.body,
        onChanged: (v) {
          final updated = note.copyWith(body: v);
          ref.read(vaultProvider.notifier).updateObject(updated);
        },
      );
    case NoteSubtype.collection:
      return CollectionView(
        content: note.body,
        onChanged: (v) {
          final updated = note.copyWith(body: v);
          ref.read(vaultProvider.notifier).updateObject(updated);
        },
      );
  }
}

/// Build note viewer based on subtype
Widget buildNoteViewer(BuildContext context, WidgetRef ref, Note note) {
  if (note.isChecklist && note.subtype == NoteSubtype.text) {
    return ChecklistView(note: note);
  }
  switch (note.subtype) {
    case NoteSubtype.outline:
      return OutlineEditor(
        initialContent: note.body,
        onWikiLinkTap: (slug) => _navigateToSlug(context, ref, slug),
        onChanged: (v) {
          final updated = note.copyWith(body: v);
          ref.read(vaultProvider.notifier).updateObject(updated);
        },
      );
    case NoteSubtype.collection:
      return CollectionView(content: note.body);
    case NoteSubtype.text:
      return MarkdownBodyView(content: note.body);
  }
}

/// Build note list item for nested notes
Widget buildNoteListItem(BuildContext context, Note note) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
    ),
    child: ObjectActionWrapper(
      object: note,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UniversalDetailView(object: note),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 18,
              color: AppColors.info,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                note.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

void _navigateToSlug(BuildContext context, WidgetRef ref, String slug) {
  final all = ref.read(allObjectsProvider).valueOrNull ?? [];
  ContentObject? target;
  try {
    target = all.whereType<ContentObject>().firstWhere(
      (o) => o.slug == slug || o.title.toLowerCase() == slug.toLowerCase(),
    );
  } catch (_) {
    target = null;
  }
  if (target != null) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UniversalDetailView(object: target!)),
    );
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Objeto "$slug" não encontrado')));
  }
}
