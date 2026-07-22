import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../providers/chat_api_provider.dart';
import '../providers/provider_config.dart';
import '../utils/audio_utils.dart';
import 'app_log_service.dart';
import '../utils/http_utils.dart';

// Formati supportati dal Whisper API (OpenAI-compatible).
const _asrSupportedFormats = {
  'flac',
  'mp3',
  'mp4',
  'mpeg',
  'mpga',
  'm4a',
  'ogg',
  'opus',
  'wav',
  'webm',
};

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

  /// Type-specific config (language, responseFormat, temperature, etc.)
  final Map<String, dynamic> typeConfig;

  /// Custom parameters that the user defined
  final List<CustomParam> customParams;

  const AsrConfig({
    this.model = 'whisper-1',
    required this.apiKey,
    required this.host,
    this.language,
    this.typeConfig = const {},
    this.customParams = const [],
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
  String get transcribeUrl => normalizedHost;

  /// Get the effective language from typeConfig, falling back to the
  /// legacy `language` field for backward compatibility.
  String? get effectiveLanguage {
    if (typeConfig['enableLanguage'] == true &&
        typeConfig.containsKey('language')) {
      final lang = typeConfig['language'] as String?;
      if (lang != null && lang.isNotEmpty) return lang;
    }
    return language;
  }

  AsrConfig copyWith({
    String? model,
    String? apiKey,
    String? host,
    String? language,
    Map<String, dynamic>? typeConfig,
    List<CustomParam>? customParams,
  }) =>
      AsrConfig(
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        host: host ?? this.host,
        language: language ?? this.language,
        typeConfig: typeConfig ?? this.typeConfig,
        customParams: customParams ?? this.customParams,
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
  /// with the audio file as a binary part. The labeled [audioFormat] is used
  /// directly for the filename and MIME type — no auto-detection or conversion
  /// is performed.
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

    final fmt = audioFormat.toLowerCase();
    if (!_asrSupportedFormats.contains(fmt)) {
      throw Exception(
        '不支持的音频格式: $fmt。'
        'Whisper API 支持的格式: ${_asrSupportedFormats.join(", ")}。'
        '请将音频转换为 WAV/MP3 格式后重试。',
      );
    }

    final stopwatch = Stopwatch()..start();

    final fileName = 'audio.$fmt';
    final mimeTypeString = getMimeType(fmt);
    final mimeType = mimeTypeString.contains('/')
        ? DioMediaType.parse(mimeTypeString)
        : null;

    final extraFormFields = <String, dynamic>{};
    final diagnosticFields = <String, dynamic>{
      'file': '$fileName (${audioBytes.length} bytes, $mimeTypeString)',
      'model': config.model,
    };

    final tc = config.typeConfig;

    // response_format
    if (tc['enableResponseFormat'] == true &&
        tc.containsKey('responseFormat')) {
      final rf = tc['responseFormat'] as String;
      extraFormFields['response_format'] = rf;
      diagnosticFields['response_format'] = rf;
    } else {
      extraFormFields['response_format'] = 'json';
      diagnosticFields['response_format'] = 'json';
    }

    // language
    final effectiveLang = config.effectiveLanguage;
    if (effectiveLang != null && effectiveLang.isNotEmpty) {
      extraFormFields['language'] = effectiveLang;
      diagnosticFields['language'] = effectiveLang;
    }

    // temperature
    if (tc['enableTemperature'] == true && tc.containsKey('temperature')) {
      final temp = (tc['temperature'] as num).toDouble();
      extraFormFields['temperature'] = temp.toString();
      diagnosticFields['temperature'] = temp;
    }

    // timestamp_granularities (only for verbose_json)
    if (tc['enableTimestampGranularities'] == true &&
        tc.containsKey('timestampGranularities')) {
      final tg = tc['timestampGranularities'] as String;
      extraFormFields['timestamp_granularities'] = tg;
      diagnosticFields['timestamp_granularities'] = tg;
    }

    // prompt
    if (tc['enablePrompt'] == true && tc.containsKey('prompt')) {
      final prompt = tc['prompt'] as String;
      if (prompt.trim().isNotEmpty) {
        extraFormFields['prompt'] = prompt;
        diagnosticFields['prompt'] = prompt;
      }
    }

    // Custom parameters
    for (final param in config.customParams) {
      final name = param.paramName.trim();
      if (name.isEmpty) continue;
      final value = param.defaultValue.trim();
      if (value.isEmpty) continue;
      final parsed = _parseParamValue(value, param.type);
      extraFormFields[name] = parsed is String ? parsed : parsed.toString();
      diagnosticFields[name] = parsed;
    }

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        audioBytes,
        filename: fileName,
        contentType: mimeType,
      ),
      'model': config.model,
      ...extraFormFields,
    });

    // Capture request diagnostics (for error details dialog).
    lastRequestBody = diagnosticFields;
    lastRequestUrl = config.transcribeUrl;
    lastRequestHeaders = {
      if (config.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${_maskApiKey(config.apiKey)}',
    };
    lastResponseData = null;
    lastResponseStatusCode = null;
    lastResponseHeaders = null;

    try {
      // ⚠️  Do NOT set contentType manually — Dio auto-generates the proper
      //     Content-Type with boundary when sending FormData. Setting it
      //     explicitly (e.g., contentType: 'multipart/form-data') strips the
      //     boundary parameter, which all OpenAI-compatible servers reject.
      final response = await _dio.post(
        config.transcribeUrl,
        data: formData,
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

  /// Parse a parameter value string into its proper type.
  static dynamic _parseParamValue(String value, String type) {
    switch (type) {
      case 'number':
        final numVal = num.tryParse(value);
        return numVal ?? value;
      case 'boolean':
        if (value.toLowerCase() == 'true') return true;
        if (value.toLowerCase() == 'false') return false;
        return value;
      case 'json':
        try {
          return jsonDecode(value);
        } catch (_) {
          return value;
        }
      case 'string':
      default:
        return value;
    }
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
  Map<String, dynamic> typeConfig = const {},
  List<CustomParam> customParams = const [],
}) {
  return AsrService(
    config: AsrConfig(
      host: host,
      apiKey: apiKey,
      model: model,
      language: language,
      typeConfig: typeConfig,
      customParams: customParams,
    ),
  );
}
