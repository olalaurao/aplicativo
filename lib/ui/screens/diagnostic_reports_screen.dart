import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../../services/crash_report_service.dart';

class DiagnosticReportsScreen extends StatefulWidget {
  const DiagnosticReportsScreen({super.key});

  @override
  State<DiagnosticReportsScreen> createState() =>
      _DiagnosticReportsScreenState();
}

class _DiagnosticReportsScreenState extends State<DiagnosticReportsScreen> {
  List<File> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });
    final reports = await CrashReportService.instance.getInternalReports();
    setState(() {
      _reports = reports;
      _isLoading = false;
    });
  }

  Future<void> _clearReports() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Reports?'),
        content: const Text(
          'All local diagnostic reports will be deleted. The Vault copy will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CrashReportService.instance.clearInternalReports();
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reports cleared.')));
      }
    }
  }

  Future<void> _shareReport(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: file.path.split('/').last.split('\\').last,
    );
  }

  Future<void> _shareAllReports() async {
    if (_reports.isEmpty) return;
    await Share.shareXFiles(
      _reports.map((file) => XFile(file.path)).toList(),
      subject: 'Citrine diagnostic reports',
    );
  }

  Future<void> _exportAllReports() async {
    if (_reports.isEmpty) return;

    try {
      final buffer = StringBuffer();
      for (var i = 0; i < _reports.length; i++) {
        final file = _reports[i];
        final fileName = file.path.split('/').last.split('\\').last;
        final content = await file.readAsString();
        if (i > 0) buffer.writeln('\n\n');
        buffer.writeln('===== $fileName =====');
        buffer.writeln(content.trim());
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_reports.length} report(s) copied to clipboard.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting reports: $e')),
      );
    }
  }

  void _viewReport(File file) async {
    try {
      final content = await file.readAsString();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            file.path.split('/').last.split('\\').last,
            style: const TextStyle(fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => _shareReport(file),
              child: const Text('Share'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error reading report: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Diagnostic Reports',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share all',
            onPressed: _reports.isEmpty ? null : _shareAllReports,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy all',
            onPressed: _reports.isEmpty ? null : _exportAllReports,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: AppColors.error,
            ),
            onPressed: _reports.isEmpty ? null : _clearReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? const Center(
              child: Text(
                'No reports found.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.separated(
              itemCount: _reports.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final file = _reports[index];
                final fileName = file.path.split('/').last.split('\\').last;
                final size = file.lengthSync();
                final kb = (size / 1024).toStringAsFixed(1);
                return ListTile(
                  leading: const Icon(
                    Icons.bug_report_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '$kb KB · Internal storage',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share_rounded),
                        tooltip: 'Share',
                        onPressed: () => _shareReport(file),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'View',
                        onPressed: () => _viewReport(file),
                      ),
                    ],
                  ),
                  onTap: () => _viewReport(file),
                );
              },
            ),
    );
  }
}
