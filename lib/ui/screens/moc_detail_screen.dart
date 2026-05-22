// lib/ui/screens/moc_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/moc_model.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';
import '../forms/create_moc_form.dart';
import '../theme.dart';
import 'universal_detail_view.dart';

class MocDetailScreen extends ConsumerStatefulWidget {
  final MocDefinition moc;
  const MocDetailScreen({super.key, required this.moc});

  @override
  ConsumerState<MocDetailScreen> createState() => _MocDetailScreenState();
}

class _MocDetailScreenState extends ConsumerState<MocDetailScreen> {
  late MocDefinition moc;
  final Set<String> _expandedSubMocs = {};

  @override
  void initState() {
    super.initState();
    moc = widget.moc;
  }

  @override
  Widget build(BuildContext context) {
    // Keep moc reactively updated in case of edits
    final allMocs = ref.watch(mocsProvider);
    final activeMoc = allMocs.firstWhere(
      (m) => m.id == moc.id,
      orElse: () => moc,
    );
    moc = activeMoc;

    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'MOC',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateMocForm(existingMoc: moc),
                    ),
                  );
                },
                tooltip: 'Editar MOC',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    moc.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (moc.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      moc.description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),
                  const Text(
                    'Estrutura e Elementos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (moc.children.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.account_tree_outlined, size: 40, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhum item conectado a este MOC.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateMocForm(existingMoc: moc),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Adicionar Elementos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: moc.children.length,
                      itemBuilder: (context, index) {
                        final link = moc.children[index];
                        return _buildNestedItem(link, allObjects, allMocs, 0);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNestedItem(
    String link,
    List<ContentObject> allObjects,
    List<MocDefinition> allMocs,
    double depth,
  ) {
    final slug = link.replaceAll('[[', '').replaceAll(']]', '').trim();

    // Check if this is a sub-MOC
    final subMoc = allMocs.firstWhere(
      (m) => m.slug == slug || m.title.toLowerCase() == slug.toLowerCase(),
      orElse: () => MocDefinition(
        id: 'dummy',
        title: '',
        description: '',
        children: [],
        createdAt: DateTime.now(),
        obsidianPath: '',
      ),
    );

    final isSubMoc = subMoc.id != 'dummy';

    // Check if general content object
    final obj = allObjects.firstWhere(
      (o) => o.slug == slug || o.title.toLowerCase() == slug.toLowerCase(),
      orElse: () => NewPagePlaceholder(title: slug),
    );

    final title = isSubMoc ? subMoc.title : obj.title;
    final type = isSubMoc ? 'moc' : obj.type;
    final isExpanded = _expandedSubMocs.contains(slug);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 20),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isSubMoc 
                ? AppColors.primary.withValues(alpha: 0.03)
                : AppColors.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSubMoc
                  ? BorderSide(color: AppColors.primary.withValues(alpha: 0.1), width: 1)
                  : BorderSide.none,
            ),
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _buildTypeIcon(type),
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: isSubMoc ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                isSubMoc ? 'MOC Subjacente' : _getTypeLabel(obj).toUpperCase(),
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5),
              ),
              trailing: isSubMoc
                  ? IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedSubMocs.remove(slug);
                          } else {
                            _expandedSubMocs.add(slug);
                          }
                        });
                      },
                    )
                  : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
              onTap: () {
                if (isSubMoc) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MocDetailScreen(moc: subMoc),
                    ),
                  );
                } else if (obj is! NewPagePlaceholder) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UniversalDetailView(object: obj),
                    ),
                  );
                }
              },
            ),
          ),
        ),
        if (isSubMoc && isExpanded && subMoc.children.isNotEmpty) ...[
          ...subMoc.children.map((subLink) {
            return _buildNestedItem(subLink, allObjects, allMocs, depth + 1);
          }),
        ],
      ],
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'moc':
        icon = Icons.layers_outlined;
        color = AppColors.primary;
        break;
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

  String _getTypeLabel(ContentObject obj) {
    switch (obj.type) {
      case 'task':
        return 'Tarefa';
      case 'habit':
        return 'Hábito';
      case 'goal':
        return 'Objetivo';
      case 'note':
        return 'Nota';
      case 'resource':
        return 'Recurso';
      case 'person':
        return 'Pessoa';
      default:
        return obj.type;
    }
  }
}
