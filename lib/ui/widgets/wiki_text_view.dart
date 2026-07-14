import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../screens/universal_detail_view.dart';
import '../widgets/create_menu_sheet.dart';
import 'object_action_wrapper.dart';

class WikiTextView extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  const WikiTextView({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref
        .watch(allObjectsProvider)
        .maybeWhen(data: (data) => data, orElse: () => []);

    final List<InlineSpan> spans = [];
    final RegExp linkRegex = RegExp(r'\[\[(.*?)\]\]');

    int lastIndex = 0;
    for (final match in linkRegex.allMatches(text)) {
      // Text before the match
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      final linkText = match.group(1) ?? '';
      final lookup = linkText
          .split('#')
          .first
          .split('/')
          .last
          .replaceAll('.md', '')
          .trim()
          .toLowerCase();
      final matchingObject = allObjects
          .where((o) {
            final title = o.title.trim().toLowerCase();
            final slug = o.slug.trim().toLowerCase();
            final fileName = o.obsidianFileName.trim().toLowerCase();
            final aliases = o.aliases.map((a) => a.trim().toLowerCase());
            return title == lookup ||
                slug == lookup ||
                fileName == lookup ||
                aliases.contains(lookup);
          })
          .firstOrNull;

      if (matchingObject != null) {
        // Valid link
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () {
                context.push('/detail/${matchingObject.id}', extra: matchingObject);
              },
              onLongPress: () =>
                  showObjectActionSheet(context, ref, matchingObject),
              child: Text(
                linkText,
                style: (style ?? const TextStyle()).copyWith(
                  color: AppTheme.accentColor(context),
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
      } else {
        // Broken link
        spans.add(
          TextSpan(
            text: linkText,
            style: (style ?? const TextStyle()).copyWith(
              color: AppColors.error.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dashed,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _showCreateBrokenLinkDialog(context, linkText);
              },
          ),
        );
      }

      lastIndex = match.end;
    }

    // Remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(
        style: style ?? Theme.of(context).textTheme.bodyMedium,
        children: spans,
      ),
    );
  }

  void _showCreateBrokenLinkDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Page not found'),
        content: Text(
          'The page "[[$title]]" does not exist yet. Do you want to create it now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CreateMenuSheet(initialTitle: title),
              );
            },
            child: const Text('CRIAR'),
          ),
        ],
      ),
    );
  }
}
