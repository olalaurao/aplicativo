// lib/ui/screens/pillars_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/pillar_model.dart';
import '../theme.dart';
import '../forms/create_pillar_form.dart';
import 'universal_detail_view.dart';
import '../widgets/object_action_wrapper.dart';
import '../utils/object_icons.dart';

class PillarsScreen extends ConsumerStatefulWidget {
  const PillarsScreen({super.key});

  @override
  ConsumerState<PillarsScreen> createState() => _PillarsScreenState();
}

class _PillarsScreenState extends ConsumerState<PillarsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allPillars = ref.watch(pillarsProvider);
    final pillars = allPillars
        .where((o) => o.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pillars'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 20,
                color: AppTheme.accentColor(context),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreatePillarForm(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search pillars...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: AppTheme.surfaceVariantColor(context),
              ),
            ),
          ),
          Expanded(
            child: pillars.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: pillars.length,
                    itemBuilder: (context, index) {
                      final pillar = pillars[index];
                      return _buildPillarTile(context, pillar);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarTile(BuildContext context, Pillar pillar) {
    return ObjectActionWrapper(
      object: pillar,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration(context),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(int.parse(pillar.color.replaceFirst('#', '0xFF'))).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              ObjectIcons.iconDataForType('pillar', ref) ?? Icons.account_balance,
              color: Color(int.parse(pillar.color.replaceFirst('#', '0xFF'))),
              size: 20,
            ),
          ),
          title: Text(
            pillar.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: pillar.why != null
              ? Text(
                  pillar.why!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedColor(context),
                  ),
                )
              : null,
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppTheme.textMutedColor(context),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: pillar),
            ),
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
            ObjectIcons.iconDataForType('pillar', ref) ?? Icons.account_balance,
            size: 64,
            color: AppTheme.accentColor(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No pillars yet' : 'No results found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (_searchQuery.isEmpty)
            Text(
              'Create pillars to track your life areas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMutedColor(context),
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }
}
