import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../providers/chat_api_provider.dart';

import '../utils/http_utils.dart';

// ============================================================================
// OCR Config
// ============================================================================

/// Configuration for an OpenAI-compatible OCR service.
class OcrConfig {
  final String model;
  final String apiKey;
  final String host;
  final String? systemPrompt;

  const OcrConfig({
    this.model = 'gpt-4o',
    required this.apiKey,
    required this.host,
    this.systemPrompt,
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

  OcrConfig copyWith({
    String? model,
    String? apiKey,
    String? host,
    String? systemPrompt,
  }) =>
      OcrConfig(
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        host: host ?? this.host,
        systemPrompt: systemPrompt ?? this.systemPrompt,
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
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 120),
            ));

  /// Dio default headers, exposed for testing.
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

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
      if (config.apiKey.isNotEmpty) 'Authorization': 'Bearer ${config.apiKey}',
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
      if (config.apiKey.isNotEmpty) 'Authorization': 'Bearer ${config.apiKey}',
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
      lastResponseData =
          Map<String, dynamic>.from(e.response!.data as Map);
    } else if (e.response?.data is String) {
      lastResponseData =
          <String, dynamic>{'raw': e.response!.data as String};
    } else {
      lastResponseData = null;
    }
    lastResponseStatusCode = e.response?.statusCode;
    lastResponseHeaders = e.response?.headers?.map;
  }

  /// Build the standard OpenAI-compatible request body.
  Map<String, dynamic> _buildRequestBody(
    List<Map<String, dynamic>> contentList,
  ) {
    return {
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
      'max_tokens': 4096,
      'temperature': 0.0,
    };
  }

  /// Build an image content block for the chat API.
  Map<String, dynamic> _buildImageContent(String dataUri) {
    return {
      'type': 'image_url',
      'image_url': {
        'url': dataUri,
        'detail': 'high',
      },
    };
  }

  /// Extract text from the standard OpenAI chat completion response.
  String _extractText(Map<String, dynamic> responseData) {
    try {
      final choices = responseData['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('API 返回了空的 choices 列表');
      }
      final content = choices[0]['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw Exception('OCR 未识别到文字内容');
      }
      return content;
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
}) {
  return OcrService(
    config: OcrConfig(
      host: host,
      apiKey: apiKey,
      model: model,
    ),
  );
}
