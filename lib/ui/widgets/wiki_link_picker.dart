import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';
import '../../services/search_service.dart';
import '../theme.dart';

class WikiLinkPicker extends ConsumerStatefulWidget {
  final Function(ContentObject) onSelected;
  final String initialQuery;

  const WikiLinkPicker({
    super.key,
    required this.onSelected,
    this.initialQuery = '',
  });

  @override
  ConsumerState<WikiLinkPicker> createState() => _WikiLinkPickerState();
}

class _WikiLinkPickerState extends ConsumerState<WikiLinkPicker> {
  late TextEditingController _searchController;
  final SearchService _searchService = SearchService();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allObjectsAsync = ref.watch(allObjectsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search pages...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: allObjectsAsync.when(
              data: (objects) {
                final query = _searchController.text;
                final filtered = query.isEmpty
                    ? objects.take(20).toList()
                    : _searchService.search(objects, query);

                final exactMatch = objects.any(
                  (o) => o.title.toLowerCase() == query.toLowerCase(),
                );

                return ListView.builder(
                  itemCount:
                      filtered.length +
                      (query.isNotEmpty && !exactMatch ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      return ListTile(
                        leading: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          'Criar "$query"',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text('Nova note no vault'),
                        onTap: () {
                          // Return a dummy object with the title
                          widget.onSelected(NewPagePlaceholder(title: query));
                        },
                      );
                    }

                    final obj = filtered[index];
                    return ListTile(
                      leading: _buildTypeIcon(obj.type),
                      title: Text(
                        obj.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: obj.categories.isNotEmpty
                          ? Wrap(
                              spacing: 4,
                              children: obj.categories
                                  .map(
                                    (c) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        c,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )
                          : Text(
                              obj.displayType,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                      onTap: () => widget.onSelected(obj),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'task':
        icon = Icons.check_circle_outline_rounded;
        color = AppColors.info;
        break;
      case 'habit':
        icon = Icons.repeat_rounded;
        color = AppColors.habitOrange;
        break;
      case 'project':
        icon = Icons.folder_open_rounded;
        color = AppColors.habitPurple;
        break;
      case 'person':
        icon = Icons.person_outline_rounded;
        color = AppColors.habitGreen;
        break;
      case 'resource':
        icon = Icons.bookmark_outline_rounded;
        color = AppColors.error;
        break;
      default:
        icon = Icons.description_outlined;
        color = AppColors.textMuted;
    }
    return Icon(icon, color: color, size: 20);
  }
}
