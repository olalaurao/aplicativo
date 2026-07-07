// lib/ui/widgets/highlight_picker_sheet.dart
import 'package:flutter/material.dart';
import '../../services/markdown_parser.dart' show HighlightItem;
import '../theme.dart';

class HighlightPickerSheet extends StatelessWidget {
  final String objectTitle;
  final List<HighlightItem> highlights;
  const HighlightPickerSheet({
    super.key,
    required this.objectTitle,
    required this.highlights,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Trechos de "$objectTitle"',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: highlights.length,
              separatorBuilder: (context, sep) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final hl = highlights[i];
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, hl),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor(context).withValues(alpha: 0.07),
                      border: Border(
                        left: BorderSide(color: AppTheme.accentColor(context), width: 2),
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hl.tag != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '#${hl.tag}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentColor(context),
                              ),
                            ),
                          ),
                        Text(
                          '"${hl.text}"',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor(context),
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
