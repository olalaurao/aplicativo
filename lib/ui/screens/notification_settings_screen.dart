// lib/ui/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/color_palette_provider.dart';
import '../../models/color_palette_model.dart';

/// Settings screen for customizing notification appearance (popup colors, alarm colors, buttons).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  // Default colors per notification sub-type
  late Map<String, Color> _typeColors;
  late Map<String, bool> _buttonVisibility;

  static const _defaultColors = <String, Color>{
    'alarm_alarm': Color(0xFFEF4444),
    'alarm_task': Color(0xFF3B82F6),
    'alarm_event': Color(0xFF8B5CF6),
    'alarm_reminder': Color(0xFFF97316),
    'popup_task': Color(0xFF3B82F6),
    'popup_event': Color(0xFF8B5CF6),
    'popup_habit': Color(0xFF22C55E),
    'popup_reminder': Color(0xFF9CA3AF),
  };

  static const _defaultButtons = <String, bool>{
    'alarm_done': true,
    'alarm_snooze_5': true,
    'alarm_snooze_10': true,
    'alarm_snooze_15': true,
    'alarm_dismiss': true,
    'popup_done': true,
    'popup_snooze': true,
    'popup_dismiss': true,
  };

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _typeColors = _loadColors(settings);
    _buttonVisibility = _loadButtons(settings);
  }

  Map<String, Color> _loadColors(AppSettings settings) {
    final saved = settings.notificationAppearanceConfig;
    return Map.fromEntries(_defaultColors.entries.map((e) {
      final hex = saved['notif_${e.key}'];
      return MapEntry(
        e.key,
        hex != null ? _parseColor(hex) : e.value,
      );
    }));
  }

  Map<String, bool> _loadButtons(AppSettings settings) {
    final saved = settings.notificationAppearanceConfig;
    return Map.fromEntries(_defaultButtons.entries.map((e) {
      final val = saved['btn_${e.key}'];
      return MapEntry(e.key, val == 'false' ? false : e.value);
    }));
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
    } catch (_) {
      return AppTheme.accentColor(context);
    }
  }

  Future<void> _saveColor(String key, Color color) async {
    _typeColors[key] = color;
    final notifier = ref.read(settingsProvider.notifier);
    final hex = '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
    await notifier.updateNotificationAppearanceConfig('notif_$key', hex);
    if (mounted) setState(() {});
  }

  Future<void> _saveButton(String key, bool value) async {
    _buttonVisibility[key] = value;
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.updateNotificationAppearanceConfig('btn_$key', value.toString());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            title: Text(
              'Notification Appearance',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            floating: true,
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Alarm Colors ──
                _sectionHeader('Alarm Screen Colors'),
                const SizedBox(height: 12),
                _buildColorGrid('alarm', {
                  'alarm_alarm': 'Alarm',
                  'alarm_task': 'Task',
                  'alarm_event': 'Event',
                  'alarm_reminder': 'Reminder',
                }),

                const SizedBox(height: 28),

                // ── Popup Colors ──
                _sectionHeader('Popup Banner Colors'),
                const SizedBox(height: 12),
                _buildColorGrid('popup', {
                  'popup_task': 'Task',
                  'popup_event': 'Event',
                  'popup_habit': 'Habit',
                  'popup_reminder': 'Reminder',
                }),

                const SizedBox(height: 28),

                // ── Alarm Buttons ──
                _sectionHeader('Alarm Screen Buttons'),
                const SizedBox(height: 12),
                _buildButtonToggles({
                  'alarm_done': 'Mark as Done',
                  'alarm_snooze_5': 'Snooze 5 min',
                  'alarm_snooze_10': 'Snooze 10 min',
                  'alarm_snooze_15': 'Snooze 15 min',
                  'alarm_dismiss': 'Dismiss',
                }),

                const SizedBox(height: 28),

                // ── Popup Buttons ──
                _sectionHeader('Popup Banner Buttons'),
                const SizedBox(height: 12),
                _buildButtonToggles({
                  'popup_done': 'Mark as Done',
                  'popup_snooze': 'Snooze 10 min',
                  'popup_dismiss': 'Dismiss / OK',
                }),

                const SizedBox(height: 28),

                // Reset button
                Center(
                  child: TextButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('Reset to Defaults'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
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

  Widget _buildColorGrid(String prefix, Map<String, String> items) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: items.entries.map((entry) {
          final color = _typeColors[entry.key] ?? AppTheme.accentColor(context);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // Color swatch
                GestureDetector(
                  onTap: () => _showColorPicker(entry.key, color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Label
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                // Edit button
                GestureDetector(
                  onTap: () => _showColorPicker(entry.key, color),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariantColor(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButtonToggles(Map<String, String> items) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: items.entries.map((entry) {
          final visible = _buttonVisibility[entry.key] ?? true;
          return Column(
            children: [
              ListTile(
                title: Text(
                  entry.value,
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: Switch.adaptive(
                  value: visible,
                  onChanged: (v) => _saveButton(entry.key, v),
                  activeThumbColor: AppTheme.accentColor(context),
                ),
              ),
              if (entry.key != items.keys.last)
                const Divider(height: 1, indent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showColorPicker(String key, Color current) {
    final palette = ref.read(colorPaletteProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Use custom palette colors, or fall back to default
    final colorHexes = isDarkMode && palette.useSeparateDarkPalette
        ? palette.darkHexes
        : palette.lightHexes;
    
    final presets = colorHexes.isNotEmpty
        ? colorHexes.map((hex) => PaletteColor.parseHex(hex)).toList()
        : [
            const Color(0xFFEF4444), // Red
            const Color(0xFFF97316), // Orange
            const Color(0xFFF59E0B), // Amber
            const Color(0xFF22C55E), // Green
            const Color(0xFF14B8A6), // Teal
            const Color(0xFF3B82F6), // Blue
            const Color(0xFF6366F1), // Indigo
            const Color(0xFF8B5CF6), // Purple
            const Color(0xFFEC4899), // Pink
            const Color(0xFF9CA3AF), // Gray
            const Color(0xFF1E293B), // Dark
            const Color(0xFFFFB000), // Gold (brand)
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Color',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presets.map((color) {
                  final isSelected = color.toARGB32() == current.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      _saveColor(key, color);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 24)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Colors & Buttons?'),
        content: const Text(
            'This will restore all notification colors and button visibility to their default values.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notifier = ref.read(settingsProvider.notifier);
    for (final entry in _defaultColors.entries) {
      final hex = '#${(entry.value.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
      await notifier.updateNotificationAppearanceConfig('notif_${entry.key}', hex);
    }
    for (final entry in _defaultButtons.entries) {
      await notifier.updateNotificationAppearanceConfig('btn_${entry.key}', entry.value.toString());
    }
    setState(() {
      _typeColors = Map.from(_defaultColors);
      _buttonVisibility = Map.from(_defaultButtons);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings reset.')),
      );
    }
  }
}
