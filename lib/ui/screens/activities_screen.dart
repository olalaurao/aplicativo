// lib/ui/screens/activities_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/organizer_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../forms/create_organizer_form.dart';
import 'organizer_detail_screen.dart';

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final activities = allObjects
        .whereType<Organizer>()
        .where((o) => o.organizerType == OrganizerType.activity)
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
                      'Activities',
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
                    'Atividades',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${activities.length} atividade${activities.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: activities.isEmpty
                  ? _buildEmptyState(context)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      children: activities
                          .map((activity) => _ActivityCard(
                                key: ValueKey(activity.id),
                                activity: activity,
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
              initialType: OrganizerType.activity,
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
      icon: Icons.local_activity_rounded,
      headline: 'Track your activities',
      subtext:
          'Record recurring activities and hobbies. Start by creating your first activity.',
      ctaLabel: 'Create Activity',
      onCta: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CreateOrganizerForm(
            initialType: OrganizerType.activity,
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  final Organizer activity;

  const _ActivityCard({super.key, required this.activity});

  Color _activityColor(String? rawColor) {
    if (rawColor == null || rawColor.trim().isEmpty) {
      return AppColors.habitGreen;
    }
    try {
      final normalized = rawColor.trim().replaceFirst('#', '0xFF');
      final parsed = int.tryParse(normalized);
      if (parsed == null) return AppColors.habitGreen;
      return Color(parsed);
    } catch (_) {
      return AppColors.habitGreen;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _activityColor(activity.color);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrganizerDetailScreen(organizer: activity),
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
                              if (activity.icon != null) ...[
                                Text(
                                  activity.icon!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  activity.title,
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
