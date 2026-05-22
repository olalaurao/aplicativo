// lib/ui/screens/people_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/people_model.dart';
import '../theme.dart';
import '../forms/create_person_form.dart';
import '../widgets/empty_state.dart';
import '../widgets/object_action_wrapper.dart';
import 'universal_detail_view.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPeople = ref.watch(peopleProvider);
    final sortedPeople = allPeople.toList()
      ..sort((a, b) {
        final aDue = a.isDueForContact;
        final bDue = b.isDueForContact;
        if (aDue && !bDue) return -1;
        if (!aDue && bDue) return 1;
        return 0;
      });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('People & Contacts'),
            floating: true,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_rounded),
                onPressed: () => _openCreatePerson(context),
              ),
            ],
          ),
          if (sortedPeople.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.people_rounded,
                headline: 'No contacts yet',
                subtext:
                    'Add important people to keep your network active and healthy.',
                ctaLabel: 'Add Person',
                onCta: () => _openCreatePerson(context),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildPersonCard(context, ref, sortedPeople[index]),
                  childCount: sortedPeople.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonCard(BuildContext context, WidgetRef ref, Person person) {
    final daysSince = person.lastContactDate != null
        ? DateTime.now().difference(person.lastContactDate!).inDays
        : null;

    final isOverdue = person.isDueForContact;

    return ObjectActionWrapper(
      object: person,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UniversalDetailView(object: person),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: person.photo != null
                        ? NetworkImage(person.photo!)
                        : null,
                    child: person.photo == null
                        ? const Icon(
                            Icons.person,
                            size: 36,
                            color: AppColors.textMuted,
                          )
                        : null,
                  ),
                  if (isOverdue)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.priority_high_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                person.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                isOverdue
                    ? 'Overdue'
                    : (daysSince != null ? '$daysSince days ago' : 'Never'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isOverdue ? AppColors.error : AppColors.textMuted,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _contactAction(
                    Icons.chat_bubble_outline_rounded,
                    AppColors.primary,
                    () {},
                  ),
                  const SizedBox(width: 8),
                  _contactAction(
                    Icons.call_outlined,
                    AppColors.habitGreen,
                    () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactAction(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  void _openCreatePerson(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePersonForm()),
    );
  }
}
