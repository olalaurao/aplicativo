import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import 'settings/sections/profile_section.dart';
import 'settings/sections/vault_import_section.dart';
import 'settings/sections/appearance_section.dart';
import 'settings/sections/google_account_section.dart';
import 'settings/sections/mood_schedules_section.dart';
import 'settings/sections/third_party_api_section.dart';
import 'settings/sections/sync_backup_section.dart';
import 'settings/sections/notifications_section.dart';
import 'settings/sections/planner_tasks_section.dart';
import 'settings/sections/object_structure_section.dart';
import 'settings/sections/obsidian_tools_section.dart';
import 'settings/sections/diagnostics_maintenance_section.dart';
import 'settings/sections/about_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            title: Text(
              'Settings',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            floating: true,
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _section('Profile'),
                const SizedBox(height: 12),
                const ProfileSection(),
                const SizedBox(height: 24),
                _section('Vault & Import'),
                const SizedBox(height: 12),
                const VaultImportSection(),
                const SizedBox(height: 24),
                _section('Appearance'),
                const SizedBox(height: 12),
                const AppearanceSection(),
                const SizedBox(height: 24),
                _section('Google Account'),
                const SizedBox(height: 12),
                const GoogleAccountSection(),
                const SizedBox(height: 24),
                _section('Mood & Schedules'),
                const SizedBox(height: 12),
                const MoodSchedulesSection(),
                const SizedBox(height: 24),
                _section('Third-Party & API Keys'),
                const SizedBox(height: 12),
                const ThirdPartyApiSection(),
                const SizedBox(height: 24),
                _section('Sync & Backup'),
                const SizedBox(height: 12),
                const SyncBackupSection(),
                const SizedBox(height: 24),
                _section('Notifications'),
                const SizedBox(height: 12),
                const NotificationsSection(),
                const SizedBox(height: 24),
                _section('Planner & Tasks'),
                const SizedBox(height: 12),
                const PlannerTasksSection(),
                const SizedBox(height: 24),
                _section('Object Structure'),
                const SizedBox(height: 12),
                const ObjectStructureSection(),
                const SizedBox(height: 24),
                _section('Obsidian Tools'),
                const SizedBox(height: 12),
                const ObsidianToolsSection(),
                const SizedBox(height: 24),
                _section('Diagnostics & Maintenance'),
                const SizedBox(height: 12),
                const DiagnosticsMaintenanceSection(),
                const SizedBox(height: 24),
                _section('About'),
                const SizedBox(height: 12),
                const AboutSection(),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}
