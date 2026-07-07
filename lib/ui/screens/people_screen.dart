// lib/ui/screens/people_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/vault_provider.dart';
import '../../models/people_model.dart';
import '../theme.dart';
import '../forms/create_person_form.dart';
import '../widgets/empty_state.dart';
import '../widgets/object_action_wrapper.dart';
import 'universal_detail_view.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  bool _isListView = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allPeople = ref.watch(peopleProvider);
    final filtered = allPeople.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.title.toLowerCase().contains(q) ||
          (p.email?.toLowerCase().contains(q) ?? false) ||
          (p.phone?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        final aDue = a.isDueForContact;
        final bDue = b.isDueForContact;
        if (aDue && !bDue) return -1;
        if (!aDue && bDue) return 1;
        return 0;
      });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: CustomScrollView(
        key: const PageStorageKey('people-scroll'),
        slivers: [
          SliverAppBar(
            title: const Text('Pessoas & Contatos'),
            floating: true,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(_isListView
                    ? Icons.grid_view_rounded
                    : Icons.list_rounded),
                tooltip: _isListView ? 'Grade' : 'Lista',
                onPressed: () => setState(() => _isListView = !_isListView),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_rounded),
                onPressed: () => _openCreatePerson(context),
              ),
            ],
          ),
          // Search field
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantColor(context),
                  borderRadius: BorderRadius.circular(14)),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar pessoas…',
                    hintStyle: TextStyle(color: AppTheme.textMutedColor(context)),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppTheme.textMutedColor(context)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            })
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.people_rounded,
                headline: 'Nenhum contato ainda',
                subtext: 'Adicione pessoas importantes para manter sua rede ativa.',
                ctaLabel: 'Adicionar Pessoa',
                onCta: () => _openCreatePerson(context),
              ),
            )
          else if (_isListView)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildPersonListTile(ctx, filtered[i]),
                childCount: filtered.length,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildPersonCard(ctx, filtered[i]),
                  childCount: filtered.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildPersonListTile(BuildContext context, Person person) {
    final urgencyColor = _urgencyColor(person);
    return ObjectActionWrapper(
      object: person,
      child: ListTile(
        leading: Stack(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surfaceVariant,
            backgroundImage: person.photo != null ? NetworkImage(person.photo!) : null,
            child: person.photo == null
                ? const Icon(Icons.person, size: 22, color: AppColors.textMuted)
                : null,
          ),
          if (person.isDueForContact)
            Positioned(top: 0, right: 0,
              child: Container(width: 10, height: 10,
                decoration: BoxDecoration(color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor, width: 1.5)))),
        ]),
        title: Text(person.title,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(_urgencyLabel(person),
          style: TextStyle(fontSize: 12, color: urgencyColor, fontWeight: FontWeight.w600)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _contactActionWidget(person, Icons.chat_bubble_outline_rounded,
              AppTheme.accentColor(context), _ContactType.sms),
          const SizedBox(width: 6),
          _contactActionWidget(person, Icons.call_outlined,
              AppColors.habitGreen, _ContactType.call),
        ]),
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => UniversalDetailView(object: person))),
      ),
    );
  }

  Widget _buildPersonCard(BuildContext context, Person person) {
    final urgencyColor = _urgencyColor(person);
    final urgencyLabel = _urgencyLabel(person);

    return ObjectActionWrapper(
      object: person,
      child: InkWell(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => UniversalDetailView(object: person))),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(context),
          child: Column(children: [
            Stack(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.surfaceVariant,
                backgroundImage: person.photo != null ? NetworkImage(person.photo!) : null,
                child: person.photo == null
                    ? const Icon(Icons.person, size: 30, color: AppColors.textMuted)
                    : null,
              ),
              if (person.isDueForContact)
                Positioned(top: 0, right: 0,
                  child: Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor, width: 1.5)))),
            ]),
            const SizedBox(height: 10),
            Text(person.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              textAlign: TextAlign.center,
              maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(urgencyLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: urgencyColor),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            if (person.contactFrequency != null)
              Text('A cada ${person.contactFrequency!.inDays} dias',
                style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(context)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _contactActionWidget(person, Icons.chat_bubble_outline_rounded,
                  AppTheme.accentColor(context), _ContactType.sms),
              const SizedBox(width: 8),
              _contactActionWidget(person, Icons.call_outlined,
                  AppColors.habitGreen, _ContactType.call),
            ]),
          ]),
        ),
      ),
    );
  }

  Color _urgencyColor(Person person) {
    final daysSince = person.lastContactDate != null
        ? DateTime.now().difference(person.lastContactDate!).inDays
        : null;
    final freqDays = person.contactFrequency?.inDays;
    double ratio = 0.0;
    if (freqDays != null && freqDays > 0) {
      ratio = (daysSince ?? (freqDays + 1)) / freqDays;
    } else if (daysSince != null) {
      ratio = daysSince > 30 ? 1.2 : 0.4;
    } else {
      ratio = 1.2;
    }
    if (ratio > 1.0) return AppColors.error;
    if (ratio > 0.7) return AppColors.warning;
    return AppColors.habitGreen;
  }

  String _urgencyLabel(Person person) {
    final daysSince = person.lastContactDate != null
        ? DateTime.now().difference(person.lastContactDate!).inDays
        : null;
    final freqDays = person.contactFrequency?.inDays;
    double ratio = 0.0;
    if (freqDays != null && freqDays > 0) {
      ratio = (daysSince ?? (freqDays + 1)) / freqDays;
    } else if (daysSince != null) {
      ratio = daysSince > 30 ? 1.2 : 0.4;
    } else {
      ratio = 1.2;
    }
    // F3.10: Add short word labels for Person urgency badge instead of color alone
    if (ratio > 1.0) return 'Overdue';
    if (ratio > 0.7) return 'Due soon';
    return 'On track';
  }

  Widget _contactActionWidget(
      Person person, IconData icon, Color color, _ContactType type) {
    return GestureDetector(
      onTap: () async {
        if (person.phone == null || person.phone!.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nenhum telefone cadastrado')));
          }
          return;
        }
        final uri = type == _ContactType.sms
            ? Uri.parse('sms:${person.phone}')
            : Uri.parse('tel:${person.phone}');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
    );
  }

  void _openCreatePerson(BuildContext context) {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => const CreatePersonForm()));
  }
}

enum _ContactType { sms, call }

