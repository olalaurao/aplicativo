import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String text;
  final bool hasText;
  final int blockCount;

  const OcrResult({
    required this.text,
    required this.hasText,
    required this.blockCount,
  });
}

class OcrService {
  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  static Future<OcrResult> extractText(File imageFile) async {
    final recognized =
        await _recognizer.processImage(InputImage.fromFile(imageFile));
    final text = recognized.text.trim();
    return OcrResult(
      text: text,
      hasText: text.isNotEmpty,
      blockCount: recognized.blocks.length,
    );
  }

  static Future<void> dispose() => _recognizer.close();
}
