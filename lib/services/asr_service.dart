import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../providers/chat_api_provider.dart';

import '../utils/http_utils.dart';

// ============================================================================
// Helpers
// ============================================================================

/// Map audio format extension to its MIME type label for display purposes.
/// If the format is unknown, returns `octet-stream` as fallback.
String _audioFormatLabel(String format) {
  switch (format.toLowerCase()) {
    case 'mp3':
    case 'mpga':
      return 'mpeg';
    case 'wav':
      return 'wav';
    case 'ogg':
    case 'opus':
      return 'ogg';
    case 'flac':
      return 'flac';
    case 'm4a':
    case 'mp4':
      return 'mp4';
    case 'webm':
      return 'webm';
    case 'wma':
      return 'x-ms-wma';
    default:
      return 'octet-stream';
  }
}

// ============================================================================
// ASR Config
// ============================================================================

/// Configuration for an OpenAI-compatible Automatic Speech Recognition (ASR)
/// service using the Whisper API.
///
/// The user provides the full endpoint URL (e.g. https://api.openai.com/v1/audio/transcriptions),
/// which is used directly without appending any path. The request is sent as:
///   POST {host}
///   Content-Type: application/json
///   Body: { "model": "...", "input_audio": { "data": "<base64>", "format": "..." } }
///
/// The JSON format (with `input_audio`) follows the OpenRouter STT convention
/// and avoids multipart Content-Type issues. The raw base64 data is also
/// visible in diagnostic capturer for easier debugging.
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
  /// The user provides the full endpoint URL including the path,
  /// so normalizedHost is used directly without appending /audio/transcriptions.
  String get transcribeUrl => normalizedHost;

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

  const AsrResult({required this.text, this.processingTimeMs = 0});
}

// ============================================================================
// ASR Service
// ============================================================================

/// An ASR service that uses an OpenAI-compatible audio/transcriptions API
/// to transcribe audio into text.
///
/// The API is called with a JSON POST request (OpenRouter STT convention):
///   POST {host}
///   Content-Type: application/json
///   Body: { "model": "...", "input_audio": { "data": "<base64>", "format": "..." } }
///
/// The response follows the standard OpenAI transcription format:
/// `{ "text": "transcribed text" }`.
class AsrService {
  final AsrConfig config;
  final Dio _dio;

  // ── Diagnostic capture (mirrors chat_api_provider pattern) ───────────
  /// The last request body sent to the API.
  Map<String, dynamic>? lastRequestBody;

  /// The last response data received from the API (or null on error).
  Map<String, dynamic>? lastResponseData;

  /// The last request headers sent.
  Map<String, String>? lastRequestHeaders;

  /// The last response headers received.
  Map<String, List<String>>? lastResponseHeaders;

  /// The last request URL.
  String? lastRequestUrl;

  /// The last HTTP response status code.
  int? lastResponseStatusCode;

  /// Mask API key for display, showing only first 8 chars and last 4 chars.
  static String _maskApiKey(String key) {
    if (key.isEmpty) return '****';
    if (key.length <= 4) return '${key.substring(0, 1)}***';
    if (key.length <= 16) return '${key.substring(0, 4)}****';
    return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
  }

  AsrService({required this.config, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                headers: {
                  if (config.apiKey.isNotEmpty)
                    'Authorization': 'Bearer ${config.apiKey}',
                  ...openRouterAppHeaders,
                },
                // No timeouts — ASR transcription may take a long time
              ),
            );

  /// Dio default headers, exposed for testing.
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// Dio send timeout, exposed for diagnostic and testing.
  Duration? get sendTimeout => _dio.options.sendTimeout;

  /// Dio connect timeout, exposed for diagnostic and testing.
  Duration? get connectTimeout => _dio.options.connectTimeout;

  /// Dio receive timeout, exposed for diagnostic and testing.
  Duration? get receiveTimeout => _dio.options.receiveTimeout;

  /// Transcribe audio bytes into text.
  ///
  /// [audioBytes] - The raw audio data (e.g., WAV, MP3, M4A, etc.).
  /// [audioFormat] - The audio file extension/format (e.g., 'wav', 'mp3', 'm4a').
  /// Returns [AsrResult] with the transcribed text.
  ///
  /// The request is sent as JSON (OpenRouter STT convention) with the audio
  /// data base64-encoded inside `input_audio.data`. This avoids multipart
  /// Content-Type issues and makes the actual file content visible in the
  /// diagnostic capture (`lastRequestBody`).
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

    // Encode audio as base64 for the JSON request body (OpenRouter STT format)
    final b64 = base64Encode(audioBytes);

    final body = <String, dynamic>{
      'model': config.model,
      'input_audio': {
        'data': b64,
        'format': audioFormat.toLowerCase(),
      },
      'response_format': 'json',
    };
    if (config.language != null && config.language!.isNotEmpty) {
      body['language'] = config.language;
    }

    // Capture request diagnostics — shows truncated base64 data
    // Use json decode/encode to deep-copy, so modifications don't affect
    // the actual request body sent via _dio.post().
    final reqBody = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(body)) as Map,
    );
    final inputAudio = reqBody['input_audio'] as Map<String, dynamic>;
    final data = inputAudio['data'] as String;
    inputAudio['data'] =
        '${data.substring(0, math.min(80, data.length))}... (${audioBytes.length} bytes)';
    lastRequestBody = reqBody;
    lastRequestUrl = config.transcribeUrl;
    lastRequestHeaders = {
      if (config.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${_maskApiKey(config.apiKey)}',
    };
    lastResponseData = null;
    lastResponseStatusCode = null;
    lastResponseHeaders = null;

    try {
      final response = await _dio.post(
        config.transcribeUrl,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      stopwatch.stop();

      // Capture response diagnostics
      lastResponseStatusCode = response.statusCode;
      lastResponseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'raw': '$response.data'};
      lastResponseHeaders = response.headers.map;

      final text = _extractText(response.data);

      return AsrResult(
        text: text,
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on DioException catch (e) {
      // Capture response diagnostics from exception
      _captureDioExceptionDiagnostics(e);
      throwWrappedDioException(e);
    }
  }

  /// Capture response-level diagnostic fields from a [DioException].
  void _captureDioExceptionDiagnostics(DioException e) {
    if (e.response?.data is Map) {
      lastResponseData = Map<String, dynamic>.from(e.response!.data as Map);
    } else if (e.response?.data is String) {
      lastResponseData = <String, dynamic>{'raw': e.response!.data as String};
    } else {
      lastResponseData = null;
    }
    lastResponseStatusCode = e.response?.statusCode;
    lastResponseHeaders = e.response?.headers.map;
  }

  /// Extract text from the standard OpenAI transcription response.
  String _extractText(dynamic responseData) {
    try {
      if (responseData is! Map<String, dynamic>) {
        throw Exception('API 返回格式异常');
      }
      final text = responseData['text'];
      if (text is! String || text.trim().isEmpty) {
        throw Exception('音频转写返回了空的文本');
      }
      return text;
    } catch (e) {
      throw Exception('解析音频转写结果失败: $e');
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
