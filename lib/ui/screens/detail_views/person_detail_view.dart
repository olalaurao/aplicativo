// lib/ui/screens/detail_views/person_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/people_model.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../universal_detail_view.dart';

/// Person-specific content section for universal detail view
List<Widget> buildPersonContentSection(
  BuildContext context,
  WidgetRef ref,
  Person person,
  Widget Function(BuildContext, WidgetRef, IconData, String, Color) contactActionButton,
  Widget Function(BuildContext, WidgetRef, Person) personGoogleEventBanner,
  Widget Function(String, {Color? color}) badge,
  Color Function(String) typeColorForMention,
  IconData Function(String) typeIconForMention,
) {
  final daysSince = person.lastContactDate != null
      ? DateTime.now().difference(person.lastContactDate!).inDays
      : null;
  final isOverdue = person.isDueForContact;
  final frequencyDays = person.contactFrequency?.inDays ?? 0;
  final progress = (daysSince != null && frequencyDays > 0)
      ? (daysSince / frequencyDays).clamp(0.0, 1.0)
      : 0.0;

  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration(context),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: person.photo != null
                        ? NetworkImage(person.photo!)
                        : null,
                    child: person.photo == null
                        ? Text(
                            person.title.isNotEmpty
                                ? person.title.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentColor(context),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      contactActionButton(
                        context,
                        ref,
                        Icons.chat_bubble_outline_rounded,
                        'WhatsApp',
                        const Color(0xFF25D366),
                      ),
                      contactActionButton(
                        context,
                        ref,
                        Icons.message_outlined,
                        'Message',
                        AppTheme.accentColor(context),
                      ),
                      contactActionButton(
                        context,
                        ref,
                        Icons.call_outlined,
                        'Call',
                        AppColors.habitGreen,
                      ),
                      contactActionButton(
                        context,
                        ref,
                        Icons.mail_outline_rounded,
                        'Email',
                        AppColors.info,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            personGoogleEventBanner(context, ref, person),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CONTACT FREQUENCY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (isOverdue)
                        badge('OVERDUE', color: AppColors.error)
                      else if (frequencyDays > 0)
                        Text(
                          '${frequencyDays - (daysSince ?? 0)} days left',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverdue ? AppColors.error : AppTheme.accentColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    person.lastContactDate != null
                        ? 'Last contact: ${DateFormat('MMMM d, yyyy').format(person.lastContactDate!)}'
                        : 'Never contacted through Citrine',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ─── Contact History ───
            const Text(
              'CONTACT HISTORY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (ctx) {
                final historyAsync = ref.watch(
                  backlinksProvider(person.id),
                );
                return historyAsync.when(
                  data: (mentions) {
                    if (mentions.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.cardDecoration(ctx),
                        child: const Text(
                          'No contact entries yet.\nMention this person in journal entries or tasks to build the history.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final sorted = mentions.toList()
                      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                    final display = sorted.take(10).toList();
                    return Container(
                      decoration: AppTheme.cardDecoration(ctx),
                      child: Column(
                        children: display.asMap().entries.map((e) {
                          final item = e.value;
                          final isLast = e.key == display.length - 1;
                          return Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: typeColorForMention(
                                    item.type,
                                  ).withValues(alpha: 0.1),
                                  child: Icon(
                                    typeIconForMention(item.type),
                                    size: 16,
                                    color: typeColorForMention(item.type),
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  DateFormat(
                                    'd MMM yyyy',
                                  ).format(item.updatedAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                trailing: badge(
                                  item.type,
                                  color: typeColorForMention(item.type),
                                ),
                                dense: true,
                                onTap: () => Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        UniversalDetailView(object: item),
                                  ),
                                ),
                              ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  indent: 56,
                                  color: AppColors.divider,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    ),
  ];
}
