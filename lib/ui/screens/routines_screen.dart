// lib/ui/screens/routines_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/organizer_model.dart';
import '../theme.dart';
import '../forms/create_organizer_form.dart';
import 'universal_detail_view.dart';
import '../widgets/object_action_wrapper.dart';
import '../../providers/settings_provider.dart';
import '../../models/saved_filter.dart';
import '../widgets/filter_sort_sheet.dart';
import '../widgets/filterable_list_header.dart';
import '../utils/filter_sort_utils.dart';

class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  String _searchQuery = '';
  SavedFilter? _activeFilter;
  List<SavedFilter> _savedFilters = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(
        () => _savedFilters = ref.read(settingsProvider).filtersFor('routine'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final rawRoutines = allObjects
        .whereType<Organizer>()
        .where((o) => o.organizerType == OrganizerType.routine)
        .toList();
    final routines = FilterSortUtils.applyFilterAndSort(rawRoutines, _searchQuery, _activeFilter).cast<Organizer>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: FilterableListHeader(
              targetType: 'routine',
              searchQuery: _searchQuery,
              activeFilter: _activeFilter,
              savedFilters: _savedFilters,
              availableProperties: OrganizerFilterProperties.all,
              onSearchChanged: (v) => setState(() => _searchQuery = v),
              onFilterChanged: (f) => setState(() {
                _activeFilter = f;
                _savedFilters = ref.read(settingsProvider).filtersFor('routine');
              }),
              onAddPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateOrganizerForm(
                      initialType: OrganizerType.routine,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: routines.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: routines.length,
                    itemBuilder: (context, index) {
                      final routine = routines[index];
                      return _buildRoutineTile(context, routine);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineTile(BuildContext context, Organizer routine) {
    return ObjectActionWrapper(
      object: routine,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration(context),
        child: ListTile(
          title: Text(
            routine.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppTheme.textMutedColor(context),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: routine),
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
            Icons.sync_outlined,
            size: 64,
            color: AppTheme.accentColor(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No routines yet' : 'No results found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (_searchQuery.isEmpty)
            Text(
              'Create routine organizers to structure your recurring activities',
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
