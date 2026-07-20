import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/color_palette_model.dart';
import '../../providers/color_palette_provider.dart';
import '../widgets/advanced_color_picker.dart';
import '../theme.dart';

/// Screen for managing background color palette
class BackgroundColorScreen extends ConsumerStatefulWidget {
  const BackgroundColorScreen({super.key});

  @override
  ConsumerState<BackgroundColorScreen> createState() => _BackgroundColorScreenState();
}

class _BackgroundColorScreenState extends ConsumerState<BackgroundColorScreen> {
  bool _showDarkPalette = false;

  @override
  Widget build(BuildContext context) {
    final bgPalette = ref.watch(backgroundColorPaletteProvider);
    final currentColors = _showDarkPalette
        ? bgPalette.darkBackgrounds
        : bgPalette.lightBackgrounds;
    final isDarkPalette = _showDarkPalette;
    final isFull = isDarkPalette ? bgPalette.isDarkPaletteFull : bgPalette.isLightPaletteFull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Colors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () => _showResetDialog(context, ref),
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mode selector
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
          const SizedBox(height: 24),

          // Color count
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${isDarkPalette ? 'Dark' : 'Light'} Backgrounds',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${currentColors.length}/${BackgroundColorPalette.maxBackgroundColors}',
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

          // Info card
          Card(
            color: AppColors.info.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Save up to ${BackgroundColorPalette.maxBackgroundColors} background colors for quick access in Appearance settings.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.info,
                      ),
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
                      Icons.wallpaper_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No background colors saved',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add your first background color',
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
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: currentColors.length,
              itemBuilder: (context, index) {
                final color = currentColors[index];
                return _BackgroundColorTile(
                  color: color,
                  onTap: () => _showColorEditDialog(context, ref, index, isDarkPalette),
                  onLongPress: () => _showDeleteDialog(context, ref, index, isDarkPalette),
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
                label: const Text('Add Background Color'),
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
                        'Maximum ${BackgroundColorPalette.maxBackgroundColors} colors reached',
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
              label: const Text('Clear All Backgrounds'),
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
          initialColor: '#F8F9FB',
          onColorChanged: (hex) {
            // Color selected, will be saved when user confirms
          },
        ),
      ),
    ).then((hex) {
      if (hex != null && hex is String) {
        if (isDarkPalette) {
          ref.read(backgroundColorPaletteProvider.notifier).addDarkBackground(hex);
        } else {
          ref.read(backgroundColorPaletteProvider.notifier).addLightBackground(hex);
        }
      }
    });
  }

  void _showColorEditDialog(
    BuildContext context,
    WidgetRef ref,
    int index,
    bool isDarkPalette,
  ) {
    final bgPalette = ref.read(backgroundColorPaletteProvider);
    final currentColor = isDarkPalette
        ? bgPalette.darkBackgrounds[index]
        : bgPalette.lightBackgrounds[index];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: AdvancedColorPicker(
          initialColor: currentColor,
          onColorChanged: (hex) {
            // Color selected, will be saved when user confirms
          },
        ),
      ),
    ).then((hex) {
      if (hex != null && hex is String) {
        if (isDarkPalette) {
          ref.read(backgroundColorPaletteProvider.notifier).updateDarkBackground(index, hex);
        } else {
          ref.read(backgroundColorPaletteProvider.notifier).updateLightBackground(index, hex);
        }
      }
    });
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    int index,
    bool isDarkPalette,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Background Color'),
        content: const Text('Are you sure you want to delete this background color?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (isDarkPalette) {
                ref.read(backgroundColorPaletteProvider.notifier).removeDarkBackground(index);
              } else {
                ref.read(backgroundColorPaletteProvider.notifier).removeLightBackground(index);
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
        title: const Text('Clear All Backgrounds'),
        content: const Text('Are you sure you want to clear all background colors?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (isDarkPalette) {
                ref.read(backgroundColorPaletteProvider.notifier).clearDarkBackgrounds();
              } else {
                ref.read(backgroundColorPaletteProvider.notifier).clearLightBackgrounds();
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
        title: const Text('Clear All Backgrounds'),
        content: const Text('This will clear all background colors from both light and dark modes. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(backgroundColorPaletteProvider.notifier).resetToEmpty();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying a single background color tile
class _BackgroundColorTile extends StatelessWidget {
  final String color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BackgroundColorTile({
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
        height: 80,
        decoration: BoxDecoration(
          color: PaletteColor.parseHex(color),
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
                  color: _getContrastColor(color),
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
                color: _getContrastColor(color),
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
