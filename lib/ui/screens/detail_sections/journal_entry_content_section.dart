// lib/ui/screens/detail_sections/journal_entry_content_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/journal_entry.dart';
import '../../../models/mood_model.dart';
import '../../../services/markdown_parser.dart';
import '../../widgets/journal_body_view.dart';
import '../../widgets/rich_text_editor.dart';
import '../../theme.dart';

/// Journal Entry-specific content section for universal detail view
List<Widget> buildJournalEntryContentSection(
  BuildContext context,
  WidgetRef ref,
  JournalEntry entry,
  MoodDefinition? mood,
  bool isEditing,
  Function(String) onBodyChanged,
  VoidCallback onSetEditing,
) {
  final plainBody = MarkdownParser.getPlainTextFromBody(entry.body).trim();
  
  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Container(
          decoration: AppTheme.cardDecoration(context),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      mood?.emoji ??
                          (entry.moodSlug != null
                              ? _fallbackMoodEmoji(entry.moodSlug!)
                              : '📝'),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'EEE, d MMM yyyy • HH:mm',
                          ).format(entry.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                        if (mood != null)
                          Text(
                            mood.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentColor(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (entry.title.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (isEditing)
                SizedBox(
                  height: 360,
                  child: RichTextEditor(
                    content: entry.body,
                    onChanged: onBodyChanged,
                  ),
                )
              else if (plainBody.isEmpty)
                Text(
                  'Sem texto nesta entry.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppTheme.textMutedColor(context),
                  ),
                )
              else
                JournalBodyView(
                  body: entry.body,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
            ],
          ),
        ),
      ),
    ),
  ];
}

String _fallbackMoodEmoji(String moodSlug) {
  // Simple fallback emoji mapping based on slug
  if (moodSlug.contains('good') || moodSlug.contains('happy') || moodSlug.contains('great')) return '😊';
  if (moodSlug.contains('bad') || moodSlug.contains('sad') || moodSlug.contains('down')) return '😢';
  if (moodSlug.contains('energetic') || moodSlug.contains('excited')) return '⚡';
  if (moodSlug.contains('calm') || moodSlug.contains('peaceful')) return '😌';
  if (moodSlug.contains('tired') || moodSlug.contains('exhausted')) return '😴';
  if (moodSlug.contains('anxious') || moodSlug.contains('worried')) return '😰';
  return '📝';
}
