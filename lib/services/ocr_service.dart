import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../providers/chat_api_provider.dart';
import '../providers/provider_config.dart';

import '../utils/http_utils.dart';
import 'app_log_service.dart';

// ============================================================================
// OCR Config
// ============================================================================

/// Configuration for an OpenAI-compatible OCR service.
class OcrConfig {
  final String model;
  final String apiKey;
  final String host;
  final String? systemPrompt;

  /// Type-specific config (temperature, topP, detail, maxTokens, etc.)
  final Map<String, dynamic> typeConfig;

  /// Custom parameters that the user defined
  final List<CustomParam> customParams;

  const OcrConfig({
    this.model = 'gpt-4o',
    required this.apiKey,
    required this.host,
    this.systemPrompt,
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

  /// The default system prompt used to guide OCR extraction.
  String get effectiveSystemPrompt =>
      systemPrompt ?? '请提取图片中的所有文字内容，保持原始格式和排版。只返回提取的文字，不要添加额外说明。';

  /// Get the image detail level from typeConfig (default: 'high').
  String get effectiveDetail =>
      (typeConfig['detail'] as String?) ?? 'high';

  /// Get max_tokens from typeConfig, or default 4096.
  int get effectiveMaxTokens {
    final value = typeConfig['maxTokens'];
    if (value is num) return value.toInt();
    return 4096;
  }

  /// Get temperature from typeConfig, or default 0.0.
  double get effectiveTemperature =>
      (typeConfig['temperature'] as num?)?.toDouble() ?? 0.0;

  OcrConfig copyWith({
    String? model,
    String? apiKey,
    String? host,
    String? systemPrompt,
    Map<String, dynamic>? typeConfig,
    List<CustomParam>? customParams,
  }) =>
      OcrConfig(
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        host: host ?? this.host,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        typeConfig: typeConfig ?? this.typeConfig,
        customParams: customParams ?? this.customParams,
      );
}

// ============================================================================
// OCR Result
// ============================================================================

/// The result of an OCR operation.
class OcrResult {
  final String text;
  final int processingTimeMs;
  final int imageCount;

  const OcrResult({
    required this.text,
    this.processingTimeMs = 0,
    this.imageCount = 1,
  });
}

// ============================================================================
// OCR Service
// ============================================================================

/// An OCR service that uses an OpenAI-compatible Chat Completions API
/// with vision support to extract text from images.
///
/// The API is called with a chat message containing:
/// - A system prompt instructing the model to extract text
/// - A user message with the image(s) encoded as base64 data URIs
///
/// The response follows the standard OpenAI chat completion format.
class OcrService {
  final OcrConfig config;
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

  OcrService({
    required this.config,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              headers: {
                'Content-Type': 'application/json',
                if (config.apiKey.isNotEmpty)
                  'Authorization': 'Bearer ${config.apiKey}',
                ...openRouterAppHeaders,
              },
              // No timeouts — OCR tasks may take a long time
            ));

  /// Dio default headers, exposed for testing.
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// Dio send timeout, exposed for diagnostic and testing.
  Duration? get sendTimeout => _dio.options.sendTimeout;

  /// Dio connect timeout, exposed for diagnostic and testing.
  Duration? get connectTimeout => _dio.options.connectTimeout;

  /// Dio receive timeout, exposed for diagnostic and testing.
  Duration? get receiveTimeout => _dio.options.receiveTimeout;

  /// The chat completions endpoint URL.
  /// The user provides the full endpoint URL including the path,
  /// so normalizedHost is used directly without appending /chat/completions.
  String get _chatUrl => config.normalizedHost;

  /// Perform OCR on a single image.
  ///
  /// [imageBytes] - The raw image data.
  /// [imageFormat] - The image format (e.g., 'jpeg', 'png').
  /// Returns [OcrResult] with the extracted text.
  Future<OcrResult> recognize({
    required Uint8List imageBytes,
    String imageFormat = 'jpeg',
  }) async {
    await AppLogService.info(
        'OcrService', '开始 OCR 识别: 格式=$imageFormat, 大小=${imageBytes.length} 字节');
    final stopwatch = Stopwatch()..start();

    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:image/$imageFormat;base64,$base64Image';

    final body = _buildRequestBody([
      _buildImageContent(dataUri),
    ]);

    // Capture request diagnostics
    lastRequestBody = body;
    lastRequestUrl = _chatUrl;
    lastRequestHeaders = {
      'Content-Type': 'application/json',
      if (config.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${_maskApiKey(config.apiKey)}',
    };
    lastResponseData = null;
    lastResponseStatusCode = null;
    lastResponseHeaders = null;

    try {
      final response = await _dio.post(
        _chatUrl,
        data: body,
      );

      stopwatch.stop();

      // Capture response diagnostics
      lastResponseStatusCode = response.statusCode;
      lastResponseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'raw': '$response.data'};
      lastResponseHeaders = response.headers.map;

      final text = _extractText(response.data);

      await AppLogService.info('OcrService',
          'OCR 识别完成: ${stopwatch.elapsedMilliseconds}ms, 文本长度=${text.length}');
      return OcrResult(
        text: text,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        imageCount: 1,
      );
    } on DioException catch (e) {
      // Capture response diagnostics from exception
      _captureDioExceptionDiagnostics(e);
      throwWrappedDioException(e);
    }
  }

  /// Perform OCR on multiple images.
  ///
  /// [imageBytesList] - List of (bytes, format) tuples.
  /// Returns [OcrResult] with combined extracted text.
  Future<OcrResult> recognizeBatch({
    required List<(Uint8List bytes, String format)> imageBytesList,
  }) async {
    await AppLogService.info(
        'OcrService', '开始批量 OCR 识别: ${imageBytesList.length} 张图片');
    if (imageBytesList.isEmpty) {
      throw ArgumentError('imageBytesList must not be empty');
    }

    final stopwatch = Stopwatch()..start();

    final contents = <Map<String, dynamic>>[];

    // Add a text instruction for each image
    for (var i = 0; i < imageBytesList.length; i++) {
      final (bytes, format) = imageBytesList[i];
      final base64Image = base64Encode(bytes);
      final dataUri = 'data:image/$format;base64,$base64Image';
      contents.addAll([
        {'type': 'text', 'text': '图片 ${i + 1}：'},
        _buildImageContent(dataUri),
      ]);
    }

    final body = _buildRequestBody(contents);

    // Capture request diagnostics
    lastRequestBody = body;
    lastRequestUrl = _chatUrl;
    lastRequestHeaders = {
      'Content-Type': 'application/json',
      if (config.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${_maskApiKey(config.apiKey)}',
    };
    lastResponseData = null;
    lastResponseStatusCode = null;
    lastResponseHeaders = null;

    try {
      final response = await _dio.post(
        _chatUrl,
        data: body,
      );

      stopwatch.stop();

      // Capture response diagnostics
      lastResponseStatusCode = response.statusCode;
      lastResponseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'raw': '$response.data'};
      lastResponseHeaders = response.headers.map;

      final text = _extractText(response.data);

      await AppLogService.info('OcrService',
          '批量 OCR 识别完成: ${stopwatch.elapsedMilliseconds}ms, 文本长度=${text.length}');
      return OcrResult(
        text: text,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        imageCount: imageBytesList.length,
      );
    } on DioException catch (e) {
      // Capture response diagnostics from exception
      _captureDioExceptionDiagnostics(e);
      throwWrappedDioException(e);
    }
  }

  /// Capture response-level diagnostic fields from a [DioException].
  /// Mirrors the pattern in [OpenAICompatibleChatProvider.chatStream].
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

  /// Build the standard OpenAI-compatible request body.
  Map<String, dynamic> _buildRequestBody(
    List<Map<String, dynamic>> contentList,
  ) {
    final body = <String, dynamic>{
      'model': config.model,
      'messages': [
        {
          'role': 'system',
          'content': config.effectiveSystemPrompt,
        },
        {
          'role': 'user',
          'content': contentList,
        },
      ],
    };

    // Apply built-in parameters from typeConfig
    final tc = config.typeConfig;

    // max_tokens (respects enableMaxTokens toggle)
    if (tc['enableMaxTokens'] == true && tc.containsKey('maxTokens')) {
      body['max_tokens'] = config.effectiveMaxTokens;
    }

    // temperature
    if (tc['enableTemperature'] == true && tc.containsKey('temperature')) {
      body['temperature'] = config.effectiveTemperature;
    }

    // top_p
    if (tc['enableTopP'] == true && tc.containsKey('topP')) {
      body['top_p'] = (tc['topP'] as num?)?.toDouble();
    }

    // frequency_penalty
    if (tc['enableFrequencyPenalty'] == true &&
        tc.containsKey('frequencyPenalty')) {
      body['frequency_penalty'] =
          (tc['frequencyPenalty'] as num?)?.toDouble();
    }

    // presence_penalty
    if (tc['enablePresencePenalty'] == true &&
        tc.containsKey('presencePenalty')) {
      body['presence_penalty'] =
          (tc['presencePenalty'] as num?)?.toDouble();
    }

    // seed
    if (tc['enableSeed'] == true && tc.containsKey('seed')) {
      body['seed'] = (tc['seed'] as num?)?.toInt();
    }

    // stop sequences (comma-separated)
    if (tc['enableStop'] == true && tc.containsKey('stop')) {
      final stopStr = tc['stop'] as String? ?? '';
      if (stopStr.contains(',')) {
        body['stop'] =
            stopStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      } else if (stopStr.trim().isNotEmpty) {
        body['stop'] = stopStr.trim();
      }
    }

    // Apply custom parameters
    for (final param in config.customParams) {
      final name = param.paramName.trim();
      if (name.isEmpty) continue;
      final value = param.defaultValue.trim();
      if (value.isEmpty) continue;
      body[name] = _parseParamValue(value, param.type);
    }

    return body;
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

  /// Build an image content block for the chat API.
  Map<String, dynamic> _buildImageContent(String dataUri) {
    final imageUrl = <String, dynamic>{
      'url': dataUri,
    };
    // Only set detail when enableDetail is true, honoring the toggle.
    // When disabled, omit detail so the API uses its default.
    if (config.typeConfig['enableDetail'] == true &&
        config.typeConfig.containsKey('detail')) {
      imageUrl['detail'] = config.effectiveDetail;
    }
    return {
      'type': 'image_url',
      'image_url': imageUrl,
    };
  }

  /// Extract text from the standard OpenAI chat completion response.
  ///
  /// Handles:
  /// - `content` as a plain `String` (standard format)
  /// - `content` as a `List` of content blocks (e.g. `[{"type": "text", "text": "..."}]`)
  ///   — concatenates all `text` fields from blocks of type "text"
  /// - Detects garbled JSON-bracket content (e.g. `}}]}}]...`) and throws.
  String _extractText(dynamic responseData) {
    try {
      if (responseData is! Map) {
        throw Exception('API 返回格式异常（非 JSON 对象）');
      }
      final data = Map<String, dynamic>.from(responseData);

      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('API 返回了空的 choices 列表');
      }
      final message = choices[0]['message'] as Map?;
      if (message == null) {
        throw Exception('API 返回中缺少 message 字段');
      }
      final content = message['content'];
      if (content == null) {
        throw Exception('OCR 未识别到文字内容');
      }

      String text;
      if (content is String) {
        text = content;
      } else if (content is List) {
        // Some providers return content as a list of text blocks
        final parts = <String>[];
        for (final block in content) {
          if (block is Map &&
              block['type'] == 'text' &&
              block['text'] is String) {
            parts.add(block['text'] as String);
          }
        }
        if (parts.isEmpty) {
          throw Exception('OCR 未识别到文字内容（content 列表为空）');
        }
        text = parts.join('\n');
      } else {
        throw Exception('OCR 返回了未知格式的内容');
      }

      if (text.trim().isEmpty) {
        throw Exception('OCR 未识别到文字内容');
      }

      // Detect garbled content that looks like JSON closing brackets (e.g. }}]}}]...)
      // This can happen when the API returns streamed chunks that are misinterpreted.
      final bracketPattern = RegExp(r'^[}\]]+$');
      if (bracketPattern.hasMatch(text.trim())) {
        throw Exception('OCR 返回了异常内容（仅包含 JSON 括号），请检查 API 返回格式或更换模型');
      }

      return text;
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('解析 OCR 结果失败: $e');
    }
  }
}

// ============================================================================
// Factory Functions
// ============================================================================

/// Create an [OcrService] from provider configuration fields.
OcrService createOcrServiceFromConfig({
  required String host,
  required String apiKey,
  required String model,
  Map<String, dynamic> typeConfig = const {},
  List<CustomParam> customParams = const [],
}) {
  return OcrService(
    config: OcrConfig(
      host: host,
      apiKey: apiKey,
      model: model,
      typeConfig: typeConfig,
      customParams: customParams,
    ),
  );
}
