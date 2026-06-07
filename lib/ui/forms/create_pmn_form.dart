import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/journal_entry.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

class CreatePmnForm extends ConsumerStatefulWidget {
  final JournalEntry? existingPmn;
  const CreatePmnForm({super.key, this.existingPmn});

  @override
  ConsumerState<CreatePmnForm> createState() => _CreatePmnFormState();
}

class _CreatePmnFormState extends ConsumerState<CreatePmnForm> {
  final TextEditingController _plusController = TextEditingController();
  final TextEditingController _minusController = TextEditingController();
  final TextEditingController _nextController = TextEditingController();

  DateTime _startDate = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  DateTime _endDate = DateTime.now().add(Duration(days: 7 - DateTime.now().weekday));
  
  @override
  void initState() {
    super.initState();
    if (widget.existingPmn != null) {
      final pmn = widget.existingPmn!;
      _plusController.text = pmn.plus.join('\n');
      _minusController.text = pmn.minus.join('\n');
      _nextController.text = pmn.next.join('\n');
      if (pmn.dateRangeStart != null) _startDate = pmn.dateRangeStart!;
      if (pmn.dateRangeEnd != null) _endDate = pmn.dateRangeEnd!;
    }
  }

  @override
  void dispose() {
    _plusController.dispose();
    _minusController.dispose();
    _nextController.dispose();
    super.dispose();
  }

  String _getWeekString() {
    // Basic week string format YYYY-WNN
    int dayOfYear = int.parse(DateFormat('D').format(_startDate));
    int woy =  ((dayOfYear - _startDate.weekday + 10) / 7).floor();
    return '${_startDate.year}-W${woy.toString().padLeft(2, '0')}';
  }

  Future<void> _savePmn() async {
    final plusList = _plusController.text.split('\n').where((s) => s.trim().isNotEmpty).map((e) => e.startsWith('- ') ? e.substring(2) : e).toList();
    final minusList = _minusController.text.split('\n').where((s) => s.trim().isNotEmpty).map((e) => e.startsWith('- ') ? e.substring(2) : e).toList();
    final nextList = _nextController.text.split('\n').where((s) => s.trim().isNotEmpty).map((e) => e.startsWith('- ') ? e.substring(2) : e).toList();

    final weekStr = _getWeekString();
    
    final pmn = widget.existingPmn?.copyWith(
      plus: plusList,
      minus: minusList,
      next: nextList,
      week: weekStr,
      dateRangeStart: _startDate,
      dateRangeEnd: _endDate,
      referencedDates: [_startDate, _endDate],
    ) ?? JournalEntry(
      id: const Uuid().v4(),
      title: 'PMN $weekStr',
      body: '',
      date: DateTime.now(),
      entryType: JournalEntryType.pmn,
      week: weekStr,
      dateRangeStart: _startDate,
      dateRangeEnd: _endDate,
      referencedDates: [_startDate, _endDate],
      plus: plusList,
      minus: minusList,
      next: nextList,
    );

    await ref.read(vaultProvider.notifier).createObject(pmn);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('PMN Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _savePmn,
            child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Week: ${_getWeekString()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection('Plus (+)', _plusController, 'What went well?'),
            const SizedBox(height: 16),
            _buildSection('Minus (-)', _minusController, 'What could be improved?'),
            const SizedBox(height: 16),
            _buildSection('Next (->)', _nextController, 'What are the next actions?'),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
