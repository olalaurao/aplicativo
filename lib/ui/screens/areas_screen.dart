// lib/ui/screens/areas_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/organizer_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../forms/create_organizer_form.dart';
import 'organizer_detail_screen.dart';

class AreasScreen extends ConsumerStatefulWidget {
  const AreasScreen({super.key});

  @override
  ConsumerState<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends ConsumerState<AreasScreen> {
  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final areas = allObjects
        .whereType<Organizer>()
        .where((o) => o.organizerType == OrganizerType.area)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Areas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Áreas',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${areas.length} área${areas.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: areas.isEmpty
                  ? _buildEmptyState(context)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      children: areas
                          .map((area) => _AreaCard(
                                key: ValueKey(area.id),
                                area: area,
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CreateOrganizerForm(
              initialType: OrganizerType.area,
            ),
          ),
        ),
        backgroundColor: AppTheme.accentColor(context),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.category_rounded,
      headline: 'Define your areas',
      subtext:
          'Organize your life into key areas. Start by creating your first area.',
      ctaLabel: 'Create Area',
      onCta: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CreateOrganizerForm(
            initialType: OrganizerType.area,
          ),
        ),
      ),
    );
  }
}

class _AreaCard extends ConsumerWidget {
  final Organizer area;

  const _AreaCard({super.key, required this.area});

  Color _areaColor(String? rawColor) {
    if (rawColor == null || rawColor.trim().isEmpty) {
      return AppTheme.accentColor(context);
    }
    try {
      final normalized = rawColor.trim().replaceFirst('#', '0xFF');
      final parsed = int.tryParse(normalized);
      if (parsed == null) return AppTheme.accentColor(context);
      return Color(parsed);
    } catch (_) {
      return AppTheme.accentColor(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _areaColor(area.color);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrganizerDetailScreen(organizer: area),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: AppTheme.cardDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (area.icon != null) ...[
                                Text(
                                  area.icon!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  area.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
