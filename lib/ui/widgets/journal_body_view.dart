import 'package:flutter/material.dart';
import '../../services/markdown_parser.dart';
import '../theme.dart';
import 'markdown_body_view.dart';

class JournalBodyView extends StatelessWidget {
  final String body;
  final int? maxLines;
  final TextStyle? style;

  const JournalBodyView({
    super.key,
    required this.body,
    this.maxLines,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final ops = MarkdownParser.tryParseDeltaOps(body);
    final effectiveStyle =
        style ??
        TextStyle(
          fontSize: 14,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
          height: 1.4,
        );

    if (ops == null) {
      return MarkdownBodyView(
        content: body,
        shrinkWrap: true,
      );
    }

    final spans = <InlineSpan>[];
    for (final op in ops) {
      final insert = op['insert'];
      final attributes = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : <String, dynamic>{};

      if (insert is String) {
        spans.add(
          TextSpan(text: insert, style: _styleFor(effectiveStyle, attributes)),
        );
      } else if (insert is Map) {
        final mediaInfo = _getMediaInfo(insert);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: _MediaPill(
                label: mediaInfo.label,
                icon: mediaInfo.icon,
                color: mediaInfo.color,
              ),
            ),
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: RichText(
        maxLines: maxLines,
        overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
        text: TextSpan(style: effectiveStyle, children: spans),
        textAlign: _getAlignment(ops),
      ),
    );
  }

  TextAlign _getAlignment(List<Map<String, dynamic>> ops) {
    for (final op in ops) {
      if (op['attributes'] is Map && op['attributes']['align'] != null) {
        switch (op['attributes']['align']) {
          case 'center':
            return TextAlign.center;
          case 'right':
            return TextAlign.right;
          case 'justify':
            return TextAlign.justify;
        }
      }
    }
    return TextAlign.start;
  }

  TextStyle _styleFor(TextStyle base, Map<String, dynamic> attributes) {
    var result = base;
    if (attributes['bold'] == true) {
      result = result.copyWith(fontWeight: FontWeight.w800);
    }
    if (attributes['italic'] == true) {
      result = result.copyWith(fontStyle: FontStyle.italic);
    }
    final decorations = <TextDecoration>[];
    if (attributes['underline'] == true) {
      decorations.add(TextDecoration.underline);
    }
    if (attributes['strike'] == true) {
      decorations.add(TextDecoration.lineThrough);
    }
    if (decorations.isNotEmpty) {
      result = result.copyWith(decoration: TextDecoration.combine(decorations));
    }

    if (attributes['color'] != null) {
      final colorStr = attributes['color'].toString();
      if (colorStr.startsWith('#')) {
        result = result.copyWith(
          color: Color(int.parse(colorStr.replaceFirst('#', '0xFF'))),
        );
      }
    }

    if (attributes['size'] != null) {
      if (attributes['size'] == 'small') result = result.copyWith(fontSize: 12);
      if (attributes['size'] == 'large') result = result.copyWith(fontSize: 18);
      if (attributes['size'] == 'huge') result = result.copyWith(fontSize: 22);
    }

    return result;
  }

  _MediaInfo _getMediaInfo(Map<dynamic, dynamic> insert) {
    if (insert['image'] != null) {
      return _MediaInfo('Imagem', Icons.image_rounded, AppColors.habitGreen);
    }
    if (insert['video'] != null) {
      return _MediaInfo(
        'Video',
        Icons.play_circle_fill_rounded,
        AppColors.error,
      );
    }
    if (insert['formula'] != null) {
      return _MediaInfo(
        'Formula',
        Icons.functions_rounded,
        AppColors.habitPurple,
      );
    }
    return _MediaInfo('Media', Icons.attachment_rounded, AppColors.primary);
  }
}

class _MediaInfo {
  final String label;
  final IconData icon;
  final Color color;
  _MediaInfo(this.label, this.icon, this.color);
}

class _MediaPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MediaPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
