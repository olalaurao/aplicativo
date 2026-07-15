// lib/ui/screens/values_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/organizer_model.dart';
import '../theme.dart';
import '../forms/create_organizer_form.dart';
import 'universal_detail_view.dart';
import '../widgets/object_action_wrapper.dart';

class ValuesScreen extends ConsumerStatefulWidget {
  const ValuesScreen({super.key});

  @override
  ConsumerState<ValuesScreen> createState() => _ValuesScreenState();
}

class _ValuesScreenState extends ConsumerState<ValuesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allOrganizers = ref.watch(organizersProvider);
    final values = allOrganizers
        .where((o) => o.organizerType == OrganizerType.value)
        .where((o) => o.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Values'),
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
                  builder: (_) => const CreateOrganizerForm(
                    initialType: OrganizerType.value,
                  ),
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
                hintText: 'Search values...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: AppTheme.surfaceVariantColor(context),
              ),
            ),
          ),
          Expanded(
            child: values.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: values.length,
                    itemBuilder: (context, index) {
                      final value = values[index];
                      return _buildValueTile(context, value);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueTile(BuildContext context, Organizer value) {
    return ObjectActionWrapper(
      object: value,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration(context),
        child: ListTile(
          title: Text(
            value.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: value.statement != null
              ? Text(
                  value.statement!,
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
              builder: (_) => UniversalDetailView(object: value),
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
            Icons.star_outline_rounded,
            size: 64,
            color: AppTheme.accentColor(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No values yet' : 'No results found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (_searchQuery.isEmpty)
            Text(
              'Create value organizers to define your core principles',
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
