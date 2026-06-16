// lib/services/transcription_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TranscriptionService {
  static const _apiUrl =
      'https://api-inference.huggingface.co/models/openai/whisper-large-v3';

  /// Transcreve um vídeo a partir de sua URL de áudio/vídeo.
  /// Requer: HuggingFace token gratuito (configurado em Settings > Integrações).
  ///
  /// LIMITAÇÃO: HuggingFace Inference API aceita arquivos de até ~25MB.
  /// Para vídeos maiores, retorna erro e orienta o usuário.
  ///
  /// ALTERNATIVA GRATUITA ADICIONAL: Groq API tem Whisper gratuito com
  /// limite de 7200 segundos/dia — mais generoso que HuggingFace.
  /// Endpoint: https://api.groq.com/openai/v1/audio/transcriptions
  static Future<String?> transcribeFromUrl({
    required String videoUrl,
    required String hfToken, // token do HuggingFace salvo em Settings
    String language = 'pt',
  }) async {
    try {
      // 1. Baixar o áudio do vídeo (via URL direta se disponível)
      //    TikTok: a URL de oEmbed pode não dar acesso direto ao arquivo
      //    Fallback: usar videoUrl diretamente se for .mp4 acessível
      final audioResponse = await http.get(Uri.parse(videoUrl));
      if (audioResponse.statusCode != 200) return null;

      final bytes = audioResponse.bodyBytes;
      if (bytes.lengthInBytes > 25 * 1024 * 1024) {
        throw Exception(
            'Arquivo muito grande para transcrição automática (>25MB)');
      }

      // 2. Enviar para HuggingFace Whisper
      final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $hfToken',
            'Content-Type': 'application/octet-stream',
            'X-Wait-For-Model': 'true', // aguarda o modelo carregar se necessário
          },
          body: bytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] as String?;
      }

      // Modelo ainda carregando (503) → aguardar e tentar novamente
      if (response.statusCode == 503) {
        await Future.delayed(const Duration(seconds: 20));
        return transcribeFromUrl(
            videoUrl: videoUrl, hfToken: hfToken, language: language);
      }

      return null;
    } catch (e) {
      debugPrint('Transcription error: $e');
      return null;
    }
  }
}
