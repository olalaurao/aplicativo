import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

enum OcrSectionState { loading, loaded, empty, error }

class OcrTextSection extends StatefulWidget {
  final OcrSectionState state;
  final String? text;
  final String sourceImageLabel;
  final bool initiallyExpanded;
  final ValueChanged<String> onTextChanged;
  final VoidCallback? onRetry;

  const OcrTextSection({
    super.key,
    required this.state,
    this.text,
    required this.sourceImageLabel,
    this.initiallyExpanded = true,
    required this.onTextChanged,
    this.onRetry,
  });

  @override
  State<OcrTextSection> createState() => _OcrTextSectionState();
}

class _OcrTextSectionState extends State<OcrTextSection> {
  late bool _expanded;
  late TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = TextEditingController(text: widget.text ?? '');
  }

  @override
  void didUpdateWidget(covariant OcrTextSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && widget.text != _controller.text) {
      _controller.text = widget.text ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      widget.onTextChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.text_snippet_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Texto extraído',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.state == OcrSectionState.loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildBody(context),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.state) {
      case OcrSectionState.loading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor(context),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              width: 200,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor(context),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Lendo texto da imagem...',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMutedColor(context),
              ),
            ),
          ],
        );
      case OcrSectionState.loaded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLines: null,
              minLines: 3,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Texto reconhecido...',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Re-extrair texto?'),
                      content: const Text(
                        'Isso vai substituir o texto atual. Continuar?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Continuar'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) widget.onRetry?.call();
                },
                child: const Text('🔄 Re-extrair texto'),
              ),
            ),
          ],
        );
      case OcrSectionState.empty:
        return Column(
          children: [
            Text(
              'Nenhum texto encontrado nesta imagem',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMutedColor(context)),
            ),
            const SizedBox(height: 8),
            _retryRow(context, allowManual: true),
          ],
        );
      case OcrSectionState.error:
        return Column(
          children: [
            const Text(
              'Could not read text from this image',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 8),
            _retryRow(context, allowManual: true),
          ],
        );
    }
  }

  Widget _retryRow(BuildContext context, {required bool allowManual}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: widget.onRetry,
          child: const Text('🔄 Tentar novamente'),
        ),
        if (allowManual)
          TextButton(
            onPressed: () => setState(() {
              _controller.clear();
              widget.onTextChanged('');
            }),
            child: const Text('✏️ Digitar manualmente'),
          ),
      ],
    );
  }
}
