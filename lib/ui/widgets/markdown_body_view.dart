import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../screens/universal_detail_view.dart';
import '../theme.dart';

import 'package:url_launcher/url_launcher.dart';

class MarkdownBodyView extends ConsumerWidget {
  final String content;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final EdgeInsets? padding;

  const MarkdownBodyView({
    super.key,
    required this.content,
    this.scrollController,
    this.shrinkWrap = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref
        .watch(allObjectsProvider)
        .maybeWhen(data: (data) => data, orElse: () => []);

    // Pre-process content to handle [[WikiLinks]] for Markdown
    // We convert [[Title]] to [Title](citrine://object/Title)
    // We must encode the URL part so flutter_markdown parses it correctly
    var processedContent = content.replaceAllMapped(RegExp(r'\[\[(.*?)\]\]'), (
      match,
    ) {
      final title = match.group(1) ?? '';
      return '[$title](citrine://object/${Uri.encodeComponent(title)})';
    });

    // Also fix any existing [title](citrine://object/title with spaces)
    processedContent = processedContent.replaceAllMapped(
      RegExp(r'\[(.*?)\]\(citrine://object/(.*?)\)'),
      (match) {
        final text = match.group(1) ?? '';
        final unencodedTitle = match.group(2) ?? '';
        // If it's already encoded, decoding and re-encoding is safe
        final decoded = Uri.decodeComponent(unencodedTitle);
        return '[$text](citrine://object/${Uri.encodeComponent(decoded)})';
      },
    );

    return MarkdownBody(
      data: processedContent,
      selectable: true,
      shrinkWrap: shrinkWrap,
      onTapLink: (text, href, title) async {
        if (href != null) {
          if (href.startsWith('citrine://object/')) {
            final objectTitle = Uri.decodeComponent(
              href.replaceFirst('citrine://object/', ''),
            );
            final lookup = objectTitle
                .split('/')
                .last
                .replaceAll('.md', '')
                .trim()
                .toLowerCase();
            final matchingObject = allObjects.where((o) {
              final title = o.title.trim().toLowerCase();
              final slug = o.slug.trim().toLowerCase();
              final fileName = o.obsidianFileName.trim().toLowerCase();
              return title == lookup || slug == lookup || fileName == lookup;
            }).firstOrNull;

            if (matchingObject != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversalDetailView(object: matchingObject),
                ),
              );
            } else {
              // Handle broken link
              _showCreateBrokenLinkDialog(context, objectTitle);
            }
          } else {
            // Handle regular http/https URLs
            final uri = Uri.tryParse(href);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: AppTheme.textPrimaryColor(context),
        ),
        h1: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppTheme.textPrimaryColor(context),
          letterSpacing: -0.5,
        ),
        h2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimaryColor(context),
        ),
        h3: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor(context),
        ),
        code: TextStyle(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        blockquote: TextStyle(
          color: AppTheme.textMutedColor(context),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
        ),
        listBullet: const TextStyle(color: AppColors.primary),
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
              // We'll need access to ref here or just use a generic way to show the sheet
              // For now, let's just use the Navigator to a form
            },
            child: const Text('CRIAR'),
          ),
        ],
      ),
    );
  }
}
