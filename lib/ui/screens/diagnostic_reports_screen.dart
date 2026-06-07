import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../../services/crash_report_service.dart';

class DiagnosticReportsScreen extends StatefulWidget {
  const DiagnosticReportsScreen({super.key});

  @override
  State<DiagnosticReportsScreen> createState() => _DiagnosticReportsScreenState();
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
        title: const Text('Limpar Relatórios?'),
        content: const Text('Todos os relatórios de diagnóstico locais serão apagados. A cópia no Vault não será afetada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CrashReportService.instance.clearInternalReports();
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Relatórios apagados.')),
        );
      }
    }
  }

  void _viewReport(File file) async {
    try {
      final content = await file.readAsString();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(file.path.split('/').last.split('\\').last, style: const TextStyle(fontSize: 14)),
          content: SingleChildScrollView(
            child: Text(content, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copiado para a área de transferência')),
                  );
                }
              },
              child: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao ler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Relatórios de Diagnóstico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
            onPressed: _reports.isEmpty ? null : _clearReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum relatório encontrado.',
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
                      leading: const Icon(Icons.bug_report_outlined, color: AppColors.primary),
                      title: Text(fileName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: Text('$kb KB · Caminho interno', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _viewReport(file),
                    );
                  },
                ),
    );
  }
}
