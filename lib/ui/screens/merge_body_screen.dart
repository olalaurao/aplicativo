// lib/ui/screens/merge_body_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import '../../models/note_model.dart';
import '../../models/journal_entry.dart';
import '../theme.dart';

enum BodyMergeMode { pickOne, concatenate }

class MergeBodyScreen extends ConsumerStatefulWidget {
  final List<ContentObject> selectedObjects;

  const MergeBodyScreen({
    super.key,
    required this.selectedObjects,
  });

  @override
  ConsumerState<MergeBodyScreen> createState() => _MergeBodyScreenState();
}

class _MergeBodyScreenState extends ConsumerState<MergeBodyScreen> {
  BodyMergeMode _selectedMode = BodyMergeMode.pickOne;
  String? _selectedObjectId;
  int _concatenateOrder = 0; // 0 = selection order, 1 = alphabetical, 2 = date

  @override
  Widget build(BuildContext context) {
    final objectsWithBody = widget.selectedObjects.where(_hasBody).toList();

    if (objectsWithBody.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Body Content'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No body content found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'None of the selected objects have body content to merge',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Skip Body Merge'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Body Content'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: _canProceed() ? () => Navigator.pop(context, _getMergedBody()) : null,
            child: Text(
              'Continue',
              style: TextStyle(
                color: _canProceed() ? AppTheme.accentColor(context) : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode selection
            _buildModeSelector(),
            const Divider(height: 1),
            Expanded(
              child: _buildModeContent(objectsWithBody),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merge Mode',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  BodyMergeMode.pickOne,
                  'Pick One',
                  'Use one object\'s body verbatim',
                  Icons.radio_button_unchecked_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeOption(
                  BodyMergeMode.concatenate,
                  'Concatenate',
                  'Join all bodies with headers',
                  Icons.view_list_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
    BodyMergeMode mode,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _selectedObjectId = null; // Reset selection when mode changes
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentColor(context).withValues(alpha: 0.1)
              : AppColors.surfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentColor(context)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.accentColor(context)
                  : AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.accentColor(context)
                    : AppTheme.textPrimaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeContent(List<ContentObject> objectsWithBody) {
    if (_selectedMode == BodyMergeMode.pickOne) {
      return _buildPickOneContent(objectsWithBody);
    } else {
      return _buildConcatenateContent(objectsWithBody);
    }
  }

  Widget _buildPickOneContent(List<ContentObject> objectsWithBody) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Select which body to use',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        ...objectsWithBody.map((obj) => _buildBodyOption(obj)),
        const SizedBox(height: 24),
        if (_selectedObjectId != null)
          _buildBodyPreview(
            objectsWithBody.firstWhere((obj) => obj.id == _selectedObjectId),
          ),
      ],
    );
  }

  Widget _buildBodyOption(ContentObject obj) {
    final isSelected = _selectedObjectId == obj.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedObjectId = obj.id;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentColor(context)
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? AppTheme.accentColor(context)
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obj.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getBodyPreview(obj),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConcatenateContent(List<ContentObject> objectsWithBody) {
    return Column(
      children: [
        // Order selection
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('Selection'),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('Alphabetical'),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text('Date'),
                  ),
                ],
                selected: {_concatenateOrder},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _concatenateOrder = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _buildBodyPreview(
                null, // null indicates concatenated preview
                objectsWithBody: objectsWithBody,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBodyPreview(
    ContentObject? obj, {
    List<ContentObject>? objectsWithBody,
  }) {
    String previewBody;

    if (obj != null) {
      previewBody = _getBodyContent(obj);
    } else if (objectsWithBody != null) {
      previewBody = _getConcatenatedBody(objectsWithBody);
    } else {
      previewBody = '';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '${previewBody.length} characters',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(
                previewBody,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasBody(ContentObject obj) {
    return _getBodyContent(obj).isNotEmpty;
  }

  String _getBodyContent(ContentObject obj) {
    if (obj is Note) {
      return obj.body;
    } else if (obj is JournalEntry) {
      return obj.body; // Use body instead of entryText
    }
    // Add other types with body content as needed
    return '';
  }

  String _getBodyPreview(ContentObject obj) {
    final content = _getBodyContent(obj);
    if (content.length > 100) {
      return '${content.substring(0, 100)}...';
    }
    return content;
  }

  String _getConcatenatedBody(List<ContentObject> objectsWithBody) {
    List<ContentObject> orderedObjects;

    switch (_concatenateOrder) {
      case 0: // Selection order (default)
        orderedObjects = objectsWithBody;
        break;
      case 1: // Alphabetical
        orderedObjects = List.from(objectsWithBody)..sort((a, b) => a.title.compareTo(b.title));
        break;
      case 2: // Date
        orderedObjects = List.from(objectsWithBody)..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      default:
        orderedObjects = objectsWithBody;
    }

    final buffer = StringBuffer();
    for (final obj in orderedObjects) {
      buffer.writeln('## From: ${obj.title}');
      buffer.writeln();
      buffer.writeln(_getBodyContent(obj));
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  Map<String, dynamic>? _getMergedBody() {
    final objectsWithBody = widget.selectedObjects.where(_hasBody).toList();
    if (objectsWithBody.isEmpty) return null;

    String? body;
    if (_selectedMode == BodyMergeMode.pickOne) {
      if (_selectedObjectId == null) return null;
      body = _getBodyContent(objectsWithBody.firstWhere((obj) => obj.id == _selectedObjectId));
    } else {
      body = _getConcatenatedBody(objectsWithBody);
    }
    
    if (body == null || body.isEmpty) return null;
    
    return {
      'body': body,
      'mode': _selectedMode.name,
    };
  }

  bool _canProceed() {
    if (_selectedMode == BodyMergeMode.pickOne) {
      return _selectedObjectId != null;
    } else {
      // Concatenate mode always has a valid result
      return true;
    }
  }
}