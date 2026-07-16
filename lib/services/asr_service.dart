import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../providers/chat_api_provider.dart';
import '../utils/audio_utils.dart';
import 'app_log_service.dart';
import '../utils/http_utils.dart';

// ============================================================================
// ASR Config
// ============================================================================

/// Configuration for an OpenAI-compatible Automatic Speech Recognition (ASR)
/// service using the Whisper API.
///
/// The user provides the full endpoint URL (e.g. https://api.openai.com/v1/audio/transcriptions),
/// which is used directly without appending any path. The request is sent as:
///   POST {host}
///   Content-Type: multipart/form-data (with boundary)
///   Body: file (binary), model, language (optional), response_format=json
///
/// This follows the standard OpenAI STT multipart/form-data convention,
/// which is compatible with OpenAI, OpenRouter, aihubmix, and other
/// OpenAI-compatible providers.
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
/// The API is called with a multipart/form-data POST request (standard OpenAI
/// STT convention) containing:
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
  /// The request is sent as multipart/form-data (standard OpenAI STT convention)
  /// with the audio file as a binary part. This is compatible with OpenAI,
  /// OpenRouter, aihubmix, and other OpenAI-compatible providers.
  Future<AsrResult> transcribe({
    required Uint8List audioBytes,
    String audioFormat = 'wav',
  }) async {
    await AppLogService.info(
        'AsrService', '开始转写: 格式=$audioFormat, 大小=${audioBytes.length} 字节');
    if (config.host.isEmpty) {
      throw Exception('API 地址未配置');
    }
    if (audioBytes.isEmpty) {
      throw Exception('音频数据为空');
    }

    final stopwatch = Stopwatch()..start();

    final fileName = 'audio.$audioFormat';
    final mimeTypeString = getMimeType(audioFormat);
    final mimeType = mimeTypeString.contains('/')
        ? DioMediaType.parse(mimeTypeString)
        : null;
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        audioBytes,
        filename: fileName,
        contentType: mimeType,
      ),
      'model': config.model,
      'response_format': 'json',
      if (config.language != null && config.language!.isNotEmpty)
        'language': config.language,
    });

    // Capture request diagnostics (for error details dialog).
    // This is a summary only — the actual binary data is sent via FormData.
    lastRequestBody = {
      'file': '$fileName (${audioBytes.length} bytes, $mimeTypeString)',
      'model': config.model,
      'response_format': 'json',
      if (config.language != null && config.language!.isNotEmpty)
        'language': config.language,
    };
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
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
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

      await AppLogService.info('AsrService',
          '转写完成: ${stopwatch.elapsedMilliseconds}ms, 文本长度=${text.length}');
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
