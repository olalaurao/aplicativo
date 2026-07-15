// lib/ui/widgets/icon_picker.dart
import 'package:flutter/material.dart';
import '../utils/material_icon_set.dart';

class IconPicker extends StatelessWidget {
  final String? selectedIconName;
  final Function(String?) onIconSelected;

  const IconPicker({
    super.key,
    this.selectedIconName,
    required this.onIconSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Icon'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 1,
          ),
          itemCount: MaterialIconSet.iconNames.length,
          itemBuilder: (context, index) {
            final iconName = MaterialIconSet.iconNames[index];
            final icon = MaterialIconSet.getIcon(iconName);
            final isSelected = selectedIconName == iconName;
            
            return InkWell(
              onTap: () => onIconSelected(iconName),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.primary)
                      : Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(icon, size: 24),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
