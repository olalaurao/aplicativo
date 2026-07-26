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
import 'settings/sections/quick_capture_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<String, bool> _expandedSections = {
    'Profile': false,
    'Vault & Import': false,
    'Appearance': false,
    'Google Account': false,
    'Mood & Schedules': false,
    'Third-Party & API Keys': false,
    'Sync & Backup': false,
    'Notifications': false,
    'Quick Capture': false,
    'Planner & Tasks': false,
    'Object Structure': false,
    'Obsidian Tools': false,
    'Diagnostics & Maintenance': false,
    'About': false,
  };

  void _toggleSection(String title) {
    setState(() {
      _expandedSections[title] = !(_expandedSections[title] ?? false);
    });
  }

  Widget _buildSectionHeader(String title, {bool isExpanded = false, VoidCallback? onToggle}) {
    final text = Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );

    if (onToggle != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 8),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                text,
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: text,
    );
  }

  Widget _buildExpandableSection(String title, Widget content) {
    final isExpanded = _expandedSections[title] ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title,
          isExpanded: isExpanded,
          onToggle: () => _toggleSection(title),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 12),
          content,
        ],
        const SizedBox(height: 16),
      ],
    );
  }

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
                _buildExpandableSection('Profile', const ProfileSection()),
                _buildExpandableSection('Vault & Import', const VaultImportSection()),
                _buildExpandableSection('Appearance', const AppearanceSection()),
                _buildExpandableSection('Google Account', const GoogleAccountSection()),
                _buildExpandableSection('Mood & Schedules', const MoodSchedulesSection()),
                _buildExpandableSection('Third-Party & API Keys', const ThirdPartyApiSection()),
                _buildExpandableSection('Sync & Backup', const SyncBackupSection()),
                _buildExpandableSection('Notifications', const NotificationsSection()),
                _buildExpandableSection('Quick Capture', const QuickCaptureSection()),
                _buildExpandableSection('Planner & Tasks', const PlannerTasksSection()),
                _buildExpandableSection('Object Structure', const ObjectStructureSection()),
                _buildExpandableSection('Obsidian Tools', const ObsidianToolsSection()),
                _buildExpandableSection('Diagnostics & Maintenance', const DiagnosticsMaintenanceSection()),
                _buildExpandableSection('About', const AboutSection()),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
