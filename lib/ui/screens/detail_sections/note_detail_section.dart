// lib/ui/screens/detail_sections/note_detail_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/note_model.dart';
import '../../../providers/vault_provider.dart';
import '../../widgets/property_grid.dart';

/// Note-specific property cards for universal detail view
List<Widget> buildNotePropertyCards(
  BuildContext context,
  WidgetRef ref,
  Note note,
) {
  final allObjects = ref.watch(allObjectsProvider).value ?? [];
  final allNotes = allObjects.whereType<Note>().where((n) => n.parentNoteId == note.id).toList();
  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _buildNotePropertiesGrid(context, note, allNotes),
      ),
    ),
  ];
}

Widget _buildNotePropertiesGrid(BuildContext context, Note note, List<Note> childNotes) {
  final cards = <PropertyCard>[];
  
  cards.add(PropertyCard(
    icon: Icons.description,
    label: 'Tipo',
    value: note.subtype.name.toUpperCase(),
  ));
  cards.add(PropertyCard(
    icon: Icons.folder,
    label: 'Sub-notas',
    value: childNotes.length.toString(),
    state: childNotes.isEmpty ? PropertyCardState.empty : PropertyCardState.normal,
  ));
  if (note.parentNoteId != null) {
    cards.add(PropertyCard(
      icon: Icons.supervisor_account,
      label: 'Nota pai',
      value: note.parentNoteId!,
    ));
  }
  
  return PropertyGrid(cards: cards);
}
