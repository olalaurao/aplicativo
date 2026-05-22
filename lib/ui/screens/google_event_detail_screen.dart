import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

class GoogleEventDetailScreen extends StatelessWidget {
  final google_calendar.Event event;

  const GoogleEventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final start = event.start?.dateTime ?? event.start?.date;
    final end = event.end?.dateTime ?? event.end?.date;
    final isAllDay = event.start?.date != null;

    final startTime = start?.toLocal();
    final endTime = end?.toLocal();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Evento do Google'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => _openInGoogleCalendar(context),
            tooltip: 'Abrir no Google Agenda',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.summary ?? '(Untitled)',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Importado do Google Calendar',
                        style: TextStyle(
                          color: AppTheme.textMutedColor(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              context,
              icon: Icons.access_time_rounded,
              title: 'Quando',
              content: isAllDay
                  ? '${DateFormat('EEEE, d MMMM').format(startTime!)} (Dia inteiro)'
                  : '${DateFormat('EEEE, d MMMM').format(startTime!)}\n'
                        '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime!)}',
            ),
            if (event.location != null && event.location!.isNotEmpty)
              _buildSection(
                context,
                icon: Icons.location_on_outlined,
                title: 'Local',
                content: event.location!,
              ),
            if (event.description != null && event.description!.isNotEmpty)
              _buildSection(
                context,
                icon: Icons.notes_rounded,
                title: 'Description',
                content: event.description!,
                isMarkdown: true,
              ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openInGoogleCalendar(context),
                icon: const Icon(Icons.calendar_today_rounded),
                label: const Text('Ver no Google Agenda'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.info,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    bool isMarkdown = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.info),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.info,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInGoogleCalendar(BuildContext context) async {
    final htmlLink = event.htmlLink;
    if (htmlLink != null) {
      final uri = Uri.parse(htmlLink);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the Google Calendar link.'),
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This event does not have an associated link.'),
          ),
        );
      }
    }
  }
}
