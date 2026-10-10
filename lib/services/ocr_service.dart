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

  /// Type-specific config (temperature, topP, maxTokens, userInstruction, etc.)
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

  /// Returns the configured endpoint with surrounding whitespace removed.
  String get normalizedHost => host.trim();

  /// The default system prompt used to guide OCR extraction.
  String get effectiveSystemPrompt =>
      systemPrompt ?? '请提取图片中的所有文字内容，保持原始格式和排版。只返回提取的文字，不要添加额外说明。';

  /// Optional user instruction sent together with the image(s).
  /// Empty when not configured — the request then carries images only.
  String get effectiveUserInstruction =>
      (typeConfig['userInstruction'] as String?)?.trim() ?? '';

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
  final bool isComplete;
  final String? finishReason;

  const OcrResult({
    required this.text,
    this.processingTimeMs = 0,
    this.imageCount = 1,
    this.isComplete = true,
    this.finishReason,
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
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) : _dio = dio ??
            Dio(BaseOptions(
              headers: {
                'Content-Type': 'application/json',
                if (config.apiKey.isNotEmpty)
                  'Authorization': 'Bearer ${config.apiKey}',
                ...openRouterAppHeaders,
              },
              connectTimeout: connectTimeout,
              sendTimeout: sendTimeout,
              receiveTimeout: receiveTimeout,
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

  /// Close the underlying client when this service owns its lifetime.
  void close({bool force = false}) => _dio.close(force: force);

  /// The chat completions endpoint URL.
  /// The user provides the full endpoint URL including the path,
  /// so normalizedHost is used directly without rewriting or appending a path.
  String get _chatUrl => config.normalizedHost;

  /// Perform OCR on a single image.
  ///
  /// [imageBytes] - The raw image data.
  /// [imageFormat] - The image format (e.g., 'jpeg', 'png').
  /// Returns [OcrResult] with the extracted text.
  Future<OcrResult> recognize({
    required Uint8List imageBytes,
    String imageFormat = 'jpeg',
    CancelToken? cancelToken,
  }) async {
    await AppLogService.info(
        'OcrService', '开始 OCR 识别: 格式=$imageFormat, 大小=${imageBytes.length} 字节');
    final stopwatch = Stopwatch()..start();

    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:image/$imageFormat;base64,$base64Image';

    // Images first, optional instruction text after them — matches the
    // official qwen-vl-ocr / DeepSeek-OCR request examples.
    final contents = <Map<String, dynamic>>[
      _buildImageContent(dataUri),
    ];
    final instruction = config.effectiveUserInstruction;
    if (instruction.isNotEmpty) {
      contents.add({'type': 'text', 'text': instruction});
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
        cancelToken: cancelToken,
      );

      stopwatch.stop();

      // Capture response diagnostics
      lastResponseStatusCode = response.statusCode;
      lastResponseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'raw': '$response.data'};
      lastResponseHeaders = response.headers.map;

      final parsed = _extractResponse(response.data);

      await AppLogService.info('OcrService',
          'OCR 识别完成: ${stopwatch.elapsedMilliseconds}ms, 文本长度=${parsed.text.length}');
      return OcrResult(
        text: parsed.text,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        imageCount: 1,
        isComplete: parsed.finishReason != 'length',
        finishReason: parsed.finishReason,
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

    // Consecutive image parts (image identity is conveyed by array order,
    // per official docs), then the optional instruction text last.
    final contents = <Map<String, dynamic>>[
      for (final (bytes, format) in imageBytesList)
        _buildImageContent('data:image/$format;base64,${base64Encode(bytes)}'),
    ];
    final instruction = config.effectiveUserInstruction;
    if (instruction.isNotEmpty) {
      contents.add({'type': 'text', 'text': instruction});
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

      final parsed = _extractResponse(response.data);

      await AppLogService.info('OcrService',
          '批量 OCR 识别完成: ${stopwatch.elapsedMilliseconds}ms, 文本长度=${parsed.text.length}');
      return OcrResult(
        text: parsed.text,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        imageCount: imageBytesList.length,
        isComplete: parsed.finishReason != 'length',
        finishReason: parsed.finishReason,
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

    // Apply custom parameters
    for (final param in config.customParams) {
      final name = param.paramName.trim();
      if (name.isEmpty) continue;
      final rawValue = param.type == 'json'
          ? param.defaultValue
          : param.options.isNotEmpty
              ? param.options.first
              : param.defaultValue.trim().isNotEmpty
                  ? param.defaultValue
                  : param.type == 'boolean'
                      ? 'true'
                      : '';
      final value = rawValue.trim();
      if (param.type == 'string' ? rawValue.isEmpty : value.isEmpty) continue;
      if (name == 'model' || name == 'messages') {
        throw ArgumentError.value(
          name,
          'paramName',
          'Custom OCR parameters cannot override $name',
        );
      }
      final parsedValue = _parseParamValue(
        param.type == 'string' ? rawValue : value,
        param.type,
      );
      if (name == 'stream' && parsedValue != false) {
        throw ArgumentError.value(
          parsedValue,
          'stream',
          'OCR only supports non-streaming requests; configure stream=false',
        );
      }
      body[name] = parsedValue;
    }

    return body;
  }

  /// Parse a parameter value string into its proper type.
  static dynamic _parseParamValue(String value, String type) {
    switch (type) {
      case 'number':
        final numVal = num.tryParse(value);
        if (numVal == null || !numVal.isFinite) {
          throw FormatException('Invalid number OCR parameter: $value');
        }
        return numVal;
      case 'boolean':
        if (value.toLowerCase() == 'true') return true;
        if (value.toLowerCase() == 'false') return false;
        throw FormatException('Invalid boolean OCR parameter: $value');
      case 'json':
        try {
          return jsonDecode(value);
        } on FormatException catch (e) {
          throw FormatException('Invalid JSON OCR parameter: ${e.message}');
        }
      case 'string':
        return value;
      default:
        throw ArgumentError.value(
          type,
          'type',
          'Unsupported OCR parameter type',
        );
    }
  }

  /// Build an image content block for the chat API.
  Map<String, dynamic> _buildImageContent(String dataUri) {
    return {
      'type': 'image_url',
      'image_url': {
        'url': dataUri,
      },
    };
  }

  /// Extract text and completion metadata from an OpenAI chat completion.
  ///
  /// Handles:
  /// - `content` as a plain `String` (standard format)
  /// - `content` as a list of text blocks, concatenated in order
  /// - Detects garbled JSON-bracket content (e.g. `}}]}}]...`) and throws.
  ({String text, String? finishReason}) _extractResponse(dynamic responseData) {
    try {
      if (responseData is! Map) {
        throw Exception('API 返回格式异常（非 JSON 对象）');
      }
      final data = Map<String, dynamic>.from(responseData);

      final rawChoices = data['choices'];
      if (rawChoices is! List || rawChoices.isEmpty) {
        throw Exception('API 返回了空的 choices 列表');
      }
      final choice = rawChoices.first;
      if (choice is! Map) {
        throw Exception('API 返回中的 choice 格式异常');
      }
      final rawFinishReason = choice['finish_reason'];
      if (rawFinishReason != null && rawFinishReason is! String) {
        throw Exception('API 返回中的 finish_reason 格式异常');
      }
      final finishReason = rawFinishReason as String?;
      final rawMessage = choice['message'];
      if (rawMessage is! Map) {
        throw Exception('API 返回中缺少 message 字段');
      }
      final refusal = rawMessage['refusal'];
      if (refusal != null) {
        if (refusal is! String || refusal.trim().isNotEmpty) {
          final detail = refusal is String ? ': $refusal' : '';
          throw Exception('OCR 请求被模型拒绝$detail');
        }
      }
      final message = rawMessage;
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
          if (block is! Map) {
            throw Exception('OCR 返回了格式异常的 content block');
          }
          if (block['type'] != 'text') {
            throw Exception('OCR 返回了不支持的非文本 content block');
          }
          if (block['text'] is! String) {
            throw Exception('OCR 返回了格式异常的 text block');
          }
          parts.add(block['text'] as String);
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

      return (text: text, finishReason: finishReason);
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
