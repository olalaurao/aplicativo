import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/color_palette_model.dart';
import '../../providers/color_palette_provider.dart';
import '../widgets/advanced_color_picker.dart';
import '../theme.dart';

/// Screen for managing custom color palette
class ColorPaletteScreen extends ConsumerStatefulWidget {
  const ColorPaletteScreen({super.key});

  @override
  ConsumerState<ColorPaletteScreen> createState() => _ColorPaletteScreenState();
}

class _ColorPaletteScreenState extends ConsumerState<ColorPaletteScreen> {
  bool _showDarkPalette = false;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(colorPaletteProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentColors = _showDarkPalette && palette.useSeparateDarkPalette
        ? palette.darkColors
        : palette.lightColors;
    final isDarkPalette = _showDarkPalette && palette.useSeparateDarkPalette;
    final isFull = isDarkPalette ? palette.isDarkPaletteFull : palette.isLightPaletteFull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Palette'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () => _showResetDialog(context, ref),
            tooltip: 'Reset to Default',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Separate dark palette toggle
          Card(
            child: SwitchListTile(
              title: const Text('Separate Dark Palette'),
              subtitle: const Text('Use different colors for dark mode'),
              value: palette.useSeparateDarkPalette,
              onChanged: (value) {
                ref.read(colorPaletteProvider.notifier).toggleSeparateDarkPalette(value);
                setState(() {
                  _showDarkPalette = value;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Mode selector
          if (palette.useSeparateDarkPalette)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Light Mode'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Dark Mode'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {_showDarkPalette},
              onSelectionChanged: (Set<bool> selected) {
                setState(() {
                  _showDarkPalette = selected.first;
                });
              },
            ),
          if (palette.useSeparateDarkPalette) const SizedBox(height: 16),

          // Color count
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${isDarkPalette ? 'Dark' : 'Light'} Colors',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${currentColors.length}/${ColorPalette.maxColorsPerPalette}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isFull ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Color grid
          if (currentColors.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No colors yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add your first color',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: currentColors.length,
              itemBuilder: (context, index) {
                final color = currentColors[index];
                return _ColorTile(
                  color: color,
                  onTap: () => _showColorEditDialog(context, ref, color, isDarkPalette),
                  onLongPress: () => _showDeleteDialog(context, ref, color.id, isDarkPalette),
                );
              },
            ),
          const SizedBox(height: 16),

          // Add color button
          if (!isFull)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showColorPicker(context, ref, isDarkPalette),
                icon: const Icon(Icons.add),
                label: const Text('Add Color'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else
            Card(
              color: AppColors.warning.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Maximum ${ColorPalette.maxColorsPerPalette} colors reached',
                        style: TextStyle(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Clear all button
          if (currentColors.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _showClearDialog(context, ref, isDarkPalette),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear All Colors'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref, bool isDarkPalette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: AdvancedColorPicker(
          initialColor: '#F97316',
          onColorChanged: (hex) {
            // Color selected, will be saved when user confirms
          },
        ),
      ),
    ).then((hex) {
      if (hex != null && hex is String) {
        if (isDarkPalette) {
          ref.read(colorPaletteProvider.notifier).addDarkColor(hex);
        } else {
          ref.read(colorPaletteProvider.notifier).addLightColor(hex);
        }
      }
    });
  }

  void _showColorEditDialog(
    BuildContext context,
    WidgetRef ref,
    PaletteColor color,
    bool isDarkPalette,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: AdvancedColorPicker(
          initialColor: color.hex,
          onColorChanged: (hex) {
            // Color selected, will be saved when user confirms
          },
        ),
      ),
    ).then((hex) {
      if (hex != null && hex is String) {
        if (isDarkPalette) {
          ref.read(colorPaletteProvider.notifier).updateDarkColor(color.id, hex);
        } else {
          ref.read(colorPaletteProvider.notifier).updateLightColor(color.id, hex);
        }
      }
    });
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    String colorId,
    bool isDarkPalette,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Color'),
        content: const Text('Are you sure you want to delete this color?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (isDarkPalette) {
                ref.read(colorPaletteProvider.notifier).removeDarkColor(colorId);
              } else {
                ref.read(colorPaletteProvider.notifier).removeLightColor(colorId);
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref, bool isDarkPalette) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Colors'),
        content: const Text('Are you sure you want to clear all colors from this palette?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (isDarkPalette) {
                ref.read(colorPaletteProvider.notifier).clearDarkPalette();
              } else {
                ref.read(colorPaletteProvider.notifier).clearLightPalette();
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default'),
        content: const Text('This will reset your color palette to the default colors. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(colorPaletteProvider.notifier).resetToDefault();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying a single color tile
class _ColorTile extends StatelessWidget {
  final PaletteColor color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ColorTile({
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: PaletteColor.parseHex(color.hex),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Edit hint
            Positioned.fill(
              child: Center(
                child: Icon(
                  Icons.edit,
                  size: 20,
                  color: _getContrastColor(color.hex),
                ),
              ),
            ),
            // Delete hint (top right)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.close,
                size: 14,
                color: _getContrastColor(color.hex),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getContrastColor(String hex) {
    final color = PaletteColor.parseHex(hex);
    final luminance = (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
