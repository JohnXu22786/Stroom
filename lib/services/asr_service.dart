import 'dart:typed_data';

import 'package:dio/dio.dart';

// ============================================================================
// ASR Config
// ============================================================================

/// Configuration for an OpenAI-compatible Automatic Speech Recognition (ASR)
/// service using the Whisper API.
///
/// The API follows the OpenAI audio/transcriptions format:
///   POST {host}/audio/transcriptions
///   Content-Type: multipart/form-data
///   Body: file, model, language (optional), response_format=json
class AsrConfig {
  final String model;
  final String apiKey;
  final String host;
  final String? language;

  const AsrConfig({
    this.model = 'whisper-1',
    required this.apiKey,
    required this.host,
    this.language,
  });

  /// Returns the host without a trailing slash.
  String get normalizedHost {
    var h = host.trim();
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  /// The full transcription endpoint URL.
  String get transcribeUrl =>
      '${normalizedHost}/audio/transcriptions';

  AsrConfig copyWith({
    String? model,
    String? apiKey,
    String? host,
    String? language,
  }) =>
      AsrConfig(
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        host: host ?? this.host,
        language: language ?? this.language,
      );
}

// ============================================================================
// ASR Result
// ============================================================================

/// The result of an ASR transcription operation.
class AsrResult {
  final String text;
  final int processingTimeMs;

  const AsrResult({
    required this.text,
    this.processingTimeMs = 0,
  });
}

// ============================================================================
// ASR Service
// ============================================================================

/// An ASR service that uses an OpenAI-compatible audio/transcriptions API
/// to transcribe audio into text.
///
/// The API is called with a multipart/form-data POST request containing:
/// - `file`: the audio file data
/// - `model`: the Whisper model ID (default: whisper-1)
/// - `language` (optional): ISO language code
/// - `response_format`: json (default)
///
/// The response follows the standard OpenAI transcription format:
/// `{ "text": "transcribed text" }`.
class AsrService {
  final AsrConfig config;
  final Dio _dio;

  AsrService({
    required this.config,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              headers: {
                if (config.apiKey.isNotEmpty)
                  'Authorization': 'Bearer ${config.apiKey}',
              },
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 120),
            ));

  /// Transcribe audio bytes into text.
  ///
  /// [audioBytes] - The raw audio data (e.g., WAV, MP3, M4A, etc.).
  /// [audioFormat] - The audio file extension/format (e.g., 'wav', 'mp3', 'm4a').
  /// Returns [AsrResult] with the transcribed text.
  Future<AsrResult> transcribe({
    required Uint8List audioBytes,
    String audioFormat = 'wav',
  }) async {
    if (config.host.isEmpty) {
      throw Exception('API 地址未配置');
    }
    if (audioBytes.isEmpty) {
      throw Exception('音频数据为空');
    }

    final stopwatch = Stopwatch()..start();

    final fileName = 'audio.$audioFormat';
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(audioBytes, filename: fileName),
      'model': config.model,
      'response_format': 'json',
      if (config.language != null && config.language!.isNotEmpty)
        'language': config.language,
    });

    final response = await _dio.post(
      config.transcribeUrl,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    stopwatch.stop();

    final text = _extractText(response.data);

    return AsrResult(
      text: text,
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Extract text from the standard OpenAI transcription response.
  String _extractText(dynamic responseData) {
    try {
      if (responseData is! Map<String, dynamic>) {
        throw Exception('API 返回格式异常');
      }
      final text = responseData['text'];
      if (text is! String || text.trim().isEmpty) {
        throw Exception('语音识别返回了空的文本');
      }
      return text;
    } catch (e) {
      throw Exception('解析语音识别结果失败: $e');
    }
  }
}

// ============================================================================
// Factory Functions
// ============================================================================

/// Create an [AsrService] from provider configuration fields.
AsrService createAsrServiceFromConfig({
  required String host,
  required String apiKey,
  String model = 'whisper-1',
  String? language,
}) {
  return AsrService(
    config: AsrConfig(
      host: host,
      apiKey: apiKey,
      model: model,
      language: language,
    ),
  );
}
