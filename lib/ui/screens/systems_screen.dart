// lib/ui/screens/systems_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/systems_provider.dart';
import '../../models/system_model.dart';
import '../theme.dart';
import '../forms/create_system_form.dart';
import 'system_detail_screen.dart';
import '../widgets/object_action_wrapper.dart';

class SystemsScreen extends ConsumerStatefulWidget {
  const SystemsScreen({super.key});

  @override
  ConsumerState<SystemsScreen> createState() => _SystemsScreenState();
}

class _SystemsScreenState extends ConsumerState<SystemsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final systems = ref.watch(systemsProvider);
    final filteredSystems = systems
        .where((s) => s.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Systems'),
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
                  builder: (_) => const CreateSystemForm(),
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
                hintText: 'Search systems...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: AppTheme.surfaceVariantColor(context),
              ),
            ),
          ),
          Expanded(
            child: filteredSystems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredSystems.length,
                    itemBuilder: (context, index) {
                      final system = filteredSystems[index];
                      return _buildSystemTile(context, system);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemTile(BuildContext context, SystemDefinition system) {
    return ObjectActionWrapper(
      object: system,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration(context),
        child: ListTile(
          title: Text(
            system.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: system.description != null
              ? Text(
                  system.description!,
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
              builder: (_) => SystemDetailScreen(system: system),
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
            Icons.settings_suggest_outlined,
            size: 64,
            color: AppTheme.accentColor(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No systems yet' : 'No results found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (_searchQuery.isEmpty)
            Text(
              'Create systems to structure your recurring workflows',
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
