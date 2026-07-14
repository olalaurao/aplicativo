import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/markdown_parser.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../screens/universal_detail_view.dart';
import 'markdown_body_view.dart';

class JournalBodyView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final ops = MarkdownParser.tryParseDeltaOps(body);
    final defaultStyle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkTextSecondary
          : AppColors.textSecondary,
      height: 1.4,
    );
    final effectiveStyle = defaultStyle.merge(style);

    if (ops == null) {
      if (_hasObsidianEmbeds(body)) {
        return _EmbeddedMarkdownPreview(
          content: body,
          maxLines: maxLines,
          style: effectiveStyle,
        );
      }
      if (maxLines != null) {
        return Text(
          MarkdownParser.getPlainTextFromBody(body),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: effectiveStyle,
        );
      }
      return MarkdownBodyView(content: body, shrinkWrap: true);
    }

    if (_needsMarkdownLayout(ops)) {
      return _EmbeddedMarkdownPreview(
        content: _deltaToMarkdown(ops),
        maxLines: maxLines,
        style: effectiveStyle,
      );
    }

    final spans = <InlineSpan>[];
    for (final op in ops) {
      final insert = op['insert'];
      final attributes = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : <String, dynamic>{};

      if (insert is String) {
        spans.addAll(
          _spansForText(
            context,
            ref,
            insert,
            _styleFor(effectiveStyle, attributes),
          ),
        );
      } else if (insert is Map) {
        spans.add(_mediaSpan(context, ref, insert));
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

  bool _needsMarkdownLayout(List<Map<String, dynamic>> ops) {
    return ops.any((op) {
      final insert = op['insert'];
      final attributes = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : const <String, dynamic>{};
      return insert is Map ||
          (insert is String && _hasObsidianEmbeds(insert)) ||
          attributes['list'] != null ||
          attributes['blockquote'] == true ||
          attributes['header'] != null;
    });
  }

  String _deltaToMarkdown(List<Map<String, dynamic>> ops) {
    final lines = <String>[];
    final line = StringBuffer();
    var orderedIndex = 1;

    void flushLine(Map<String, dynamic> attributes) {
      final text = line.toString();
      line.clear();
      final listType = attributes['list']?.toString();
      if (listType == 'bullet') {
        lines.add('- $text');
      } else if (listType == 'ordered') {
        lines.add('${orderedIndex++}. $text');
      } else if (listType == 'checked' || listType == 'unchecked') {
        lines.add('- [${listType == 'checked' ? 'x' : ' '}] $text');
      } else if (attributes['blockquote'] == true) {
        lines.add('> $text');
      } else if (attributes['header'] != null) {
        final level = attributes['header'].toString() == '1' ? '#' : '##';
        lines.add('$level $text');
      } else {
        orderedIndex = 1;
        lines.add(text);
      }
    }

    for (final op in ops) {
      final insert = op['insert'];
      final attributes = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : <String, dynamic>{};

      if (insert is Map) {
        final image = insert['image']?.toString();
        if (image != null && image.isNotEmpty) {
          if (line.isNotEmpty) flushLine(const {});
          lines.add('![[$image]]');
        }
        continue;
      }

      if (insert is! String) continue;
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        var text = parts[i];
        if (text.isNotEmpty) {
          if (attributes['bold'] == true) text = '**$text**';
          if (attributes['italic'] == true) text = '*$text*';
          line.write(text);
        }
        if (i < parts.length - 1) {
          flushLine(attributes);
        }
      }
    }

    if (line.isNotEmpty) flushLine(const {});
    return lines.join('\n');
  }

  bool _hasObsidianEmbeds(String text) =>
      RegExp(r'!\[\[([^\]]+)\]\]').hasMatch(text);

  List<InlineSpan> _spansForText(
    BuildContext context,
    WidgetRef ref,
    String text,
    TextStyle style,
  ) {
    final spans = <InlineSpan>[];
    final tokenRegex = RegExp(r'!\[\[([^\]]+)\]\]|\[\[([^\]]+)\]\]');
    var cursor = 0;

    for (final match in tokenRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: style),
        );
      }
      final embedPath = match.group(1);
      final linkText = match.group(2);
      if (embedPath != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: _EmbeddedMedia(path: embedPath.trim()),
            ),
          ),
        );
      } else if (linkText != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _openWikiLink(context, ref, linkText),
              child: Text(
                linkText,
                style: style.copyWith(
                  color: AppTheme.accentColor(context),
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }

    return spans;
  }

  void _openWikiLink(BuildContext context, WidgetRef ref, String linkText) {
    final lookup = linkText
        .split('#')
        .first
        .split('/')
        .last
        .replaceAll('.md', '')
        .trim()
        .toLowerCase();
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final target = allObjects.where((o) {
      final title = o.title.trim().toLowerCase();
      final slug = o.slug.trim().toLowerCase();
      final fileName = o.obsidianFileName.trim().toLowerCase();
      final aliases = o.aliases.map((a) => a.trim().toLowerCase());
      return title == lookup ||
          slug == lookup ||
          fileName == lookup ||
          aliases.contains(lookup);
    }).firstOrNull;
    if (target == null) return;
    context.push('/detail/${target.id}', extra: target);
  }

  InlineSpan _mediaSpan(
    BuildContext context,
    WidgetRef ref,
    Map<dynamic, dynamic> insert,
  ) {
    final image = insert['image']?.toString();
    if (image != null && image.isNotEmpty) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: _EmbeddedMedia(path: image),
        ),
      );
    }

    final mediaInfo = _getMediaInfo(insert);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: _MediaPill(
          label: mediaInfo.label,
          icon: mediaInfo.icon,
          color: mediaInfo.color,
        ),
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
        'Vídeo',
        Icons.play_circle_fill_rounded,
        AppColors.error,
      );
    }
    if (insert['formula'] != null) {
      return _MediaInfo(
        'Fórmula',
        Icons.functions_rounded,
        AppColors.habitPurple,
      );
    }
    return _MediaInfo('Mídia', Icons.attachment_rounded, AppColors.primary);
  }
}

class _EmbeddedMarkdownPreview extends ConsumerWidget {
  final String content;
  final int? maxLines;
  final TextStyle style;

  const _EmbeddedMarkdownPreview({
    required this.content,
    required this.maxLines,
    required this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = content.split('\n');
    final visibleLines = maxLines == null
        ? lines
        : lines.take(maxLines!).toList();
    final children = <Widget>[];
    final embedRegex = RegExp(r'!\[\[([^\]]+)\]\]');

    for (final line in visibleLines) {
      final matches = embedRegex.allMatches(line).toList();
      if (matches.isEmpty) {
        if (line.trim().isEmpty) continue;
        children.add(MarkdownBodyView(content: line, shrinkWrap: true));
        continue;
      }

      var textOnly = line;
      for (final match in matches) {
        final path = match.group(1)!.trim();
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _EmbeddedMedia(path: path),
          ),
        );
      }
      textOnly = textOnly.replaceAll(embedRegex, '').trim();
      if (textOnly.isNotEmpty) {
        children.add(MarkdownBodyView(content: textOnly, shrinkWrap: true));
      }
    }

    if (children.isEmpty) {
      return MarkdownBodyView(content: content, shrinkWrap: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _EmbeddedMedia extends ConsumerWidget {
  final String path;

  const _EmbeddedMedia({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalized = path.replaceAll('\\', '/');
    final ext = normalized.split('.').last.toLowerCase();
    final isImage = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'}.contains(ext);
    if (!isImage) {
      return _MediaPill(
        label: 'Anexo',
        icon: Icons.attachment_rounded,
        color: AppTheme.accentColor(context),
      );
    }

    final obsidian = ref.watch(obsidianServiceProvider);
    final file =
        normalized.startsWith('/') ||
            RegExp(r'^[A-Za-z]:/').hasMatch(normalized)
        ? File(normalized)
        : File('${obsidian.vaultDir?.path ?? ''}/$normalized');

    if (!file.existsSync()) {
      return const _MediaPill(
        label: 'Imagem',
        icon: Icons.broken_image_rounded,
        color: AppColors.warning,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180, minWidth: 96),
        child: Image.file(file, fit: BoxFit.cover),
      ),
    );
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
