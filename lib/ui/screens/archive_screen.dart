// lib/ui/screens/archive_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/content_object.dart';
import '../theme.dart';
import '../widgets/object_action_wrapper.dart';
import 'universal_detail_view.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  String _filterType = 'all';

  @override
  Widget build(BuildContext context) {
    final archivedObjects = ref
        .watch(allObjectsProvider)
        .maybeWhen(
          data: (objects) => objects.where((o) => o.archived).toList(),
          orElse: () => <ContentObject>[],
        );

    final filtered = _filterType == 'all'
        ? archivedObjects
        : archivedObjects.where((o) => o.type == _filterType).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Arquivo'), centerTitle: true),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final obj = filtered[index];
                      return _buildArchiveTile(context, obj);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final types = ['all', 'task', 'habit', 'goal', 'note', 'resource'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: types
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    t.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: _filterType == t,
                  onSelected: (selected) => setState(() => _filterType = t),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _filterType == t
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildArchiveTile(BuildContext context, ContentObject obj) {
    return ObjectActionWrapper(
      object: obj,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration(context),
        child: ListTile(
          title: Text(
            obj.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            obj.type.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.unarchive_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            onPressed: () {
              // Restore logic
              obj.archived = false;
              // ref.read(vaultProvider.notifier).updateObject(obj);
            },
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UniversalDetailView(object: obj)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum item arquivado',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
