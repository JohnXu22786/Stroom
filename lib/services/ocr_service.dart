import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../l10n/app_localizations.dart';
import '../providers/chat_api_provider.dart';
import '../providers/anthropic_chat_provider.dart' show kAnthropicApiVersion;
import '../providers/llm_routed_chat_provider.dart';
import '../providers/provider_config.dart';
import '../models/ocr_batch_execution.dart';
import '../ai_gateway/ai_gateway.dart';

import '../utils/http_utils.dart';
import '../utils/http_timeout.dart';
import '../utils/ocr_diagnostics.dart';
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
  final String? routingGroupId;
  final String? routingLocalModelId;
  final String? routingAccountId;
  final String? routingDisplayName;

  /// Type-specific config (temperature, topP, maxTokens, userInstruction, etc.)
  final Map<String, dynamic> typeConfig;

  /// Custom parameters that the user defined
  final List<CustomParam> customParams;
  final int requestSizeBudgetBytes;

  const OcrConfig({
    this.model = 'gpt-4o',
    required this.apiKey,
    required this.host,
    this.systemPrompt,
    this.routingGroupId,
    this.routingLocalModelId,
    this.routingAccountId,
    this.routingDisplayName,
    this.typeConfig = const {},
    this.customParams = const [],
    this.requestSizeBudgetBytes = defaultOcrRequestSizeBudgetBytes,
  });

  /// Returns the configured endpoint with surrounding whitespace removed.
  String get normalizedHost => host.trim();

  /// The caller-localized system prompt used to guide OCR extraction.
  /// Legacy callers retain the original Chinese default.
  String get effectiveSystemPrompt =>
      systemPrompt ??
      lookupAppLocalizations(const Locale('zh', 'CN')).ocrDefaultSystemPrompt;

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
    String? routingGroupId,
    String? routingLocalModelId,
    String? routingAccountId,
    String? routingDisplayName,
    Map<String, dynamic>? typeConfig,
    List<CustomParam>? customParams,
    int? requestSizeBudgetBytes,
  }) =>
      OcrConfig(
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        host: host ?? this.host,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        routingGroupId: routingGroupId ?? this.routingGroupId,
        routingLocalModelId: routingLocalModelId ?? this.routingLocalModelId,
        routingAccountId: routingAccountId ?? this.routingAccountId,
        routingDisplayName: routingDisplayName ?? this.routingDisplayName,
        typeConfig: typeConfig ?? this.typeConfig,
        customParams: customParams ?? this.customParams,
        requestSizeBudgetBytes:
            requestSizeBudgetBytes ?? this.requestSizeBudgetBytes,
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

bool _isCompleteOcrFinishReason(String? finishReason) =>
    finishReason == null || finishReason == 'stop';

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
enum OcrRequestStage { uploading, waiting, parsing }

class OcrRequestTooLargeException implements Exception {
  final int encodedBytes;
  final int budgetBytes;

  const OcrRequestTooLargeException({
    required this.encodedBytes,
    required this.budgetBytes,
  });

  @override
  String toString() =>
      'OCR 请求的 JSON 大小为 ' +
      encodedBytes.toString() +
      ' 字节，超过 ' +
      budgetBytes.toString() +
      ' 字节配置值；请调整 OCR 供应商/模型请求大小设置或图片画质';
}

class OcrService {
  final OcrConfig config;
  final Dio _dio;
  final bool _usesInjectedDio;
  final Duration? _sendTimeoutOverride;
  final Future<AiGatewayFacade>? _routingRuntime;

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
  int? _lastDiagnosticStatusCode;

  int? _lastDurationMs;
  int _lastImageCount = 0;
  int _lastImageBytes = 0;
  String? _lastFinishReason;
  String? _lastRequestId;
  String? _lastErrorType;

  /// Safe diagnostic maps for task persistence and the error detail view.
  static List<String> _credentialValuesFromHeaders(dynamic headers) {
    final values = <String>{
      ...OcrDiagnosticSnapshot.credentialValuesFromHeaders(headers),
    };
    if (headers is Map) {
      for (final entry in headers.entries) {
        if (entry.key is! String ||
            (entry.key as String).toLowerCase() != 'authorization') {
          continue;
        }
        final rawValues =
            entry.value is List ? entry.value as List : [entry.value];
        for (final rawValue in rawValues) {
          if (rawValue is! String) continue;
          final credential =
              RegExp(r'^\S+\s+(\S+)').firstMatch(rawValue.trim())?.group(1);
          if (credential != null && credential.isNotEmpty) {
            values.add(credential);
          }
          for (final match in RegExp(
            r'''(?:^|[, \t])([A-Za-z0-9_-]+)\s*=\s*(?:"((?:\\.|[^"\\])*)"|([^,\s]+))''',
          ).allMatches(rawValue)) {
            final name = match.group(1)?.toLowerCase();
            final authParameter = (match.group(2) ?? match.group(3))
                ?.replaceAllMapped(
                    RegExp(r'\\(.)'), (match) => match.group(1)!);
            if (authParameter != null &&
                authParameter.isNotEmpty &&
                (name == 'response' ||
                    RegExp(
                      r'(?:access[_-]?token|token|password|secret|credential|signature|(?:api[_-]?)?key)',
                    ).hasMatch(name ?? ''))) {
              values.add(authParameter);
            }
          }
        }
      }
    }
    return values.toList(growable: false);
  }

  List<String> get _diagnosticRequestCredentialValues => {
        ...OcrDiagnosticSnapshot.credentialValuesFromRequest({
          'headers': lastRequestHeaders,
          'url': lastRequestUrl,
          'body': lastRequestBody,
        }),
        ..._credentialValuesFromHeaders(_dio.options.headers),
      }.toList(growable: false);

  List<String> get _diagnosticCredentialValues => [
        config.apiKey,
        ..._diagnosticRequestCredentialValues,
      ];

  Map<String, dynamic> get diagnosticRequest => OcrDiagnosticSnapshot.request(
        url: lastRequestUrl,
        imageCount: _lastImageCount,
        imageBytes: _lastImageBytes,
        durationMs: _lastDurationMs,
        requestId: null,
        excludedValues: _diagnosticCredentialValues,
      );

  Map<String, dynamic> diagnosticResponse({Object? error}) =>
      OcrDiagnosticSnapshot.response(
        statusCode: _lastDiagnosticStatusCode,
        finishReason: _lastFinishReason,
        durationMs: _lastDurationMs,
        requestId: _lastRequestId,
        errorType: _lastErrorType ?? error?.runtimeType.toString(),
        // Request IDs and finish reasons are sanitized when the response is
        // captured, while the response's request options are still available.
        // Re-reading raw response data here would lose interceptor-added
        // credential exclusions.
      );

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
    Future<AiGatewayFacade>? routingRuntime,
  })  : _sendTimeoutOverride = sendTimeout,
        _routingRuntime = config.routingGroupId == null
            ? null
            : routingRuntime ?? AiGateway.sharedPlatform(),
        _usesInjectedDio = dio != null,
        _dio = dio ??
            Dio(
              BaseOptions(
                headers: {
                  'Content-Type': 'application/json',
                  if (config.apiKey.isNotEmpty)
                    'Authorization': 'Bearer ${config.apiKey}',
                  ...openRouterAppHeaders,
                },
                connectTimeout: connectTimeout ?? connectTimeoutDefault,
                sendTimeout: sendTimeout ?? sendTimeoutForBytes(0),
                receiveTimeout: receiveTimeout ?? receiveTimeoutFallback,
              ),
            ) {
    _dio.options.connectTimeout =
        connectTimeout ?? _dio.options.connectTimeout ?? connectTimeoutDefault;
    _dio.options.receiveTimeout =
        receiveTimeout ?? _dio.options.receiveTimeout ?? receiveTimeoutFallback;
  }

  /// Dio default headers, exposed for testing.
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// Dio send timeout, exposed for diagnostic and testing.
  Duration? get sendTimeout => _dio.options.sendTimeout;

  /// Dio connect timeout, exposed for diagnostic and testing.
  Duration? get connectTimeout => _dio.options.connectTimeout;

  /// Dio receive timeout, exposed for diagnostic and testing.
  Duration? get receiveTimeout => _dio.options.receiveTimeout;

  /// Measure the exact UTF-8 JSON body used for a request without sending it.
  int encodedRequestSizeBytes({
    required List<(Uint8List bytes, String format)> imageBytesList,
  }) {
    if (imageBytesList.isEmpty) {
      throw ArgumentError('imageBytesList must not be empty');
    }
    final contents = <Map<String, dynamic>>[
      for (final (bytes, format) in imageBytesList)
        _buildImageContent(
          'data:image/' + format + ';base64,' + base64Encode(bytes),
        ),
    ];
    final instruction = config.effectiveUserInstruction;
    if (instruction.isNotEmpty) {
      contents.add({'type': 'text', 'text': instruction});
    }
    final body = _buildRequestBody(contents);
    return _encodedBodyLength(body);
  }

  /// Largest raw image length whose base64 data URI can fit the configured
  /// request budget, including this request's actual JSON envelope.
  int maxRawImageBytesWithinRequestBudget({String imageFormat = 'jpeg'}) {
    final contents = <Map<String, dynamic>>[
      _buildImageContent('data:image/$imageFormat;base64,'),
    ];
    final instruction = config.effectiveUserInstruction;
    if (instruction.isNotEmpty) {
      contents.add({'type': 'text', 'text': instruction});
    }
    final baseRequestBytes = _encodedBodyLength(_buildRequestBody(contents));
    final base64BudgetBytes = config.requestSizeBudgetBytes - baseRequestBytes;
    if (base64BudgetBytes < 4) return 0;
    return (base64BudgetBytes ~/ 4) * 3;
  }

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
    ProgressCallback? onSendProgress,
    void Function(OcrRequestStage)? onStage,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('imageBytes must not be empty');
    }

    await AppLogService.info(
      'OcrService',
      '开始 OCR 识别: 格式=$imageFormat, 大小=${imageBytes.length} 字节',
    );
    final stopwatch = Stopwatch()..start();
    var requestCredentialValues = _beginDiagnosticCapture(
      1,
      imageBytes.length,
    );

    try {
      final base64Image = base64Encode(imageBytes);
      final dataUri = 'data:image/$imageFormat;base64,$base64Image';

      // Images first, optional instruction text after them — matches the
      // official qwen-vl-ocr / DeepSeek-OCR request examples.
      final contents = <Map<String, dynamic>>[_buildImageContent(dataUri)];
      final instruction = config.effectiveUserInstruction;
      if (instruction.isNotEmpty) {
        contents.add({'type': 'text', 'text': instruction});
      }

      final body = _buildRequestBody(contents);
      _ensureRequestWithinSizeBudget(body);
      requestCredentialValues = {
        ...requestCredentialValues,
        ...OcrDiagnosticSnapshot.credentialValuesFromRequest({
          'url': _chatUrl,
          'body': body,
        }),
      }.toList(growable: false);

      lastRequestBody = body;
      final response = await _sendRequest(
        body: body,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onStage: onStage,
      );

      stopwatch.stop();

      // Capture response diagnostics
      final responseCredentialValues = {
        ...requestCredentialValues,
        ...OcrDiagnosticSnapshot.credentialValuesFromRequest({
          'body': response.requestOptions.data,
        }),
        ..._credentialValuesFromHeaders(response.requestOptions.headers),
        ...OcrDiagnosticSnapshot.credentialValuesFromHeaders(
          response.headers.map,
        ),
        ...OcrDiagnosticSnapshot.credentialValuesFromRequest({
          'body': response.data,
        }),
      }.toList(growable: false);
      lastResponseStatusCode = response.statusCode;
      _lastDiagnosticStatusCode = OcrDiagnosticSnapshot.sanitizeResponse(
        {'statusCode': response.statusCode},
        excludedValues: [config.apiKey, ...responseCredentialValues],
      )?['statusCode'] as int?;
      lastResponseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'raw': '${response.data}'};
      lastResponseHeaders = response.headers.map;
      _lastRequestId = OcrDiagnosticSnapshot.requestIdFromHeaders(
            response.headers.map,
            excludedValues: [config.apiKey, ...responseCredentialValues],
          ) ??
          OcrDiagnosticSnapshot.requestIdFromData(
            response.data,
            excludedValues: [config.apiKey, ...responseCredentialValues],
          );

      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      onStage?.call(OcrRequestStage.parsing);
      final parsed = _extractResponse(response.data);
      _lastFinishReason = OcrDiagnosticSnapshot.sanitizeResponse(
        {'finishReason': parsed.finishReason},
        excludedValues: [config.apiKey, ...responseCredentialValues],
      )?['finishReason'] as String?;

      await AppLogService.info(
        'OcrService',
        'OCR 识别完成: ${stopwatch.elapsedMilliseconds}ms, 文本长度=${parsed.text.length}',
      );
      return OcrResult(
        text: parsed.text,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        imageCount: 1,
        isComplete: _isCompleteOcrFinishReason(parsed.finishReason),
        finishReason: parsed.finishReason,
      );
    } on DioException catch (e) {
      // Capture response diagnostics from exception
      _captureDioExceptionDiagnostics(
        e,
        requestCredentialValues: requestCredentialValues,
      );
      if (e.type == DioExceptionType.cancel) rethrow;
      throwWrappedDioException(e);
    } finally {
      _finishDiagnosticCapture(stopwatch);
    }
  }

  /// Perform OCR on multiple images.
  ///
  /// [imageBytesList] - List of (bytes, format) tuples.
  /// Returns [OcrResult] with combined extracted text.
  Future<OcrResult> recognizeBatch({
    required List<(Uint8List bytes, String format)> imageBytesList,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    void Function(OcrRequestStage)? onStage,
  }) async {
    await AppLogService.info(
      'OcrService',
      '开始批量 OCR 识别: ${imageBytesList.length} 张图片',
    );
    if (imageBytesList.isEmpty) {
      throw ArgumentError('imageBytesList must not be empty');
    }
    if (imageBytesList.any((image) => image.$1.isEmpty)) {
      throw ArgumentError('imageBytesList must not contain empty image bytes');
    }

    final stopwatch = Stopwatch()..start();
    var requestCredentialValues = _beginDiagnosticCapture(
      imageBytesList.length,
      imageBytesList.fold<int>(0, (sum, image) => sum + image.$1.length),
    );

    try {
      // Consecutive image parts (image identity is conveyed by array order,
      // per official docs), then the optional instruction text last.
      final contents = <Map<String, dynamic>>[
        for (final (bytes, format) in imageBytesList)
          _buildImageContent(
            'data:image/$format;base64,${base64Encode(bytes)}',
          ),
      ];
      final instruction = config.effectiveUserInstruction;
      if (instruction.isNotEmpty) {
        contents.add({'type': 'text', 'text': instruction});
      }

      final body = _buildRequestBody(contents);
      _ensureRequestWithinSizeBudget(body);
      requestCredentialValues = {
        ...requestCredentialValues,
        ...OcrDiagnosticSnapshot.credentialValuesFromRequest({
          'url': _chatUrl,
          'body': body,
        }),
      }.toList(growable: false);

      lastRequestBody = body;
      final response = await _sendRequest(
        body: body,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onStage: onStage,
      );

      stopwatch.stop();

      // Capture response diagnostics
      final responseCredentialValues = {
        ...requestCredentialValues,
        ...OcrDiagnosticSnapshot.credentialValuesFromRequest({
          'body': response.requestOptions.data,
        }),
        ..._credentialValuesFromHeaders(response.requestOptions.headers),
        ...OcrDiagnosticSnapshot.credentialValuesFromHeaders(
          response.headers.map,
        ),
        ...OcrDiagnosticSnapshot.credentialValuesFromRequest({
          'body': response.data,
        }),
      }.toList(growable: false);
      lastResponseStatusCode = response.statusCode;
      _lastDiagnosticStatusCode = OcrDiagnosticSnapshot.sanitizeResponse(
        {'statusCode': response.statusCode},
        excludedValues: [config.apiKey, ...responseCredentialValues],
      )?['statusCode'] as int?;
      lastResponseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'raw': '${response.data}'};
      lastResponseHeaders = response.headers.map;
      _lastRequestId = OcrDiagnosticSnapshot.requestIdFromHeaders(
            response.headers.map,
            excludedValues: [config.apiKey, ...responseCredentialValues],
          ) ??
          OcrDiagnosticSnapshot.requestIdFromData(
            response.data,
            excludedValues: [config.apiKey, ...responseCredentialValues],
          );

      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      onStage?.call(OcrRequestStage.parsing);
      final parsed = _extractResponse(response.data);
      _lastFinishReason = OcrDiagnosticSnapshot.sanitizeResponse(
        {'finishReason': parsed.finishReason},
        excludedValues: [config.apiKey, ...responseCredentialValues],
      )?['finishReason'] as String?;

      await AppLogService.info(
        'OcrService',
        '批量 OCR 识别完成: ${stopwatch.elapsedMilliseconds}ms, 文本长度=${parsed.text.length}',
      );
      return OcrResult(
        text: parsed.text,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        imageCount: imageBytesList.length,
        isComplete: _isCompleteOcrFinishReason(parsed.finishReason),
        finishReason: parsed.finishReason,
      );
    } on DioException catch (e) {
      // Capture response diagnostics from exception
      _captureDioExceptionDiagnostics(
        e,
        requestCredentialValues: requestCredentialValues,
      );
      if (e.type == DioExceptionType.cancel) rethrow;
      throwWrappedDioException(e);
    } finally {
      _finishDiagnosticCapture(stopwatch);
    }
  }

  List<String> _beginDiagnosticCapture(int imageCount, int imageBytes) {
    _lastDurationMs = null;
    _lastImageCount = imageCount;
    _lastImageBytes = imageBytes;
    _lastFinishReason = null;
    _lastRequestId = null;
    _lastErrorType = null;
    final requestCredentialValues = _credentialValuesFromHeaders(
      _dio.options.headers,
    );
    lastRequestBody = null;
    lastRequestUrl = _chatUrl;
    lastRequestHeaders = {
      'Content-Type': 'application/json',
      if (config.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${_maskApiKey(config.apiKey)}',
    };
    lastResponseData = null;
    lastResponseStatusCode = null;
    _lastDiagnosticStatusCode = null;
    lastResponseHeaders = null;
    return requestCredentialValues;
  }

  void _finishDiagnosticCapture(Stopwatch stopwatch) {
    if (stopwatch.isRunning) stopwatch.stop();
    _lastDurationMs = stopwatch.elapsedMilliseconds;
  }

  int _encodedBodyLength(Map<String, dynamic> body) =>
      utf8.encode(jsonEncode(body)).length;

  int _ensureRequestWithinSizeBudget(Map<String, dynamic> body) {
    if (config.requestSizeBudgetBytes <= 0) {
      throw ArgumentError.value(
        config.requestSizeBudgetBytes,
        'requestSizeBudgetBytes',
        'OCR request size budget must be greater than zero',
      );
    }
    final encodedBytes = _encodedBodyLength(body);
    if (encodedBytes > config.requestSizeBudgetBytes) {
      throw OcrRequestTooLargeException(
        encodedBytes: encodedBytes,
        budgetBytes: config.requestSizeBudgetBytes,
      );
    }
    return encodedBytes;
  }

  Future<_OcrResponse> _sendRequest({
    required Map<String, dynamic> body,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    void Function(OcrRequestStage)? onStage,
  }) async {
    final groupId = config.routingGroupId;
    if (groupId == null) {
      final response = await _dio.post(
        _chatUrl,
        data: body,
        options: _requestOptions(encodedBytes: _encodedBodyLength(body)),
        cancelToken: cancelToken,
        onSendProgress: _uploadProgress(onSendProgress, onStage),
      );
      return _OcrResponse(
        statusCode: response.statusCode ?? 0,
        data: response.data,
        headers: response.headers.map,
        requestOptions: response.requestOptions,
      );
    }

    final runtime = await _routingRuntime!;
    final localModelId = config.routingLocalModelId ?? config.model;
    final legacyAccountId = config.routingAccountId;
    if (legacyAccountId != null) {
      await runtime.ensureLegacyOcrModelGroup(
        accountId: legacyAccountId,
        groupId: groupId,
        localModelId: localModelId,
        upstreamModelId: config.model,
        displayName: config.routingDisplayName ?? config.model,
        baseUrl: config.normalizedHost,
        apiKey: config.apiKey,
      );
    }
    onStage?.call(OcrRequestStage.uploading);
    final execution = await runtime.executeForGroupId<_OcrResponse>(
      groupId: groupId,
      localModelId: localModelId,
      requiredCapabilities: const {'vision'},
      supportedConnectorTypes: {
        ...llmRoutedChatSupportedConnectorTypes('openai.chat_completions'),
        ...llmRoutedChatSupportedConnectorTypes('openai.responses'),
        ...llmRoutedChatSupportedConnectorTypes('anthropic.messages'),
        ...llmRoutedChatSupportedConnectorTypes(
          'google.gemini.generate_content',
        ),
        ...llmRoutedChatSupportedConnectorTypes(
          'google.gemini.interactions',
        ),
        ...llmRoutedChatSupportedConnectorTypes('ollama.chat'),
      },
      candidateFilter: (candidate) {
        final protocolId = llmRoutedChatProtocolForAccountModel(
          account: candidate.account,
          upstreamModelId: candidate.upstreamModelId,
          endpointType: builtinDefaultApiProtocolForConnector(
            candidate.account.connectorType,
          ),
        );
        return llmRoutedChatSupportedConnectorTypes(protocolId)
            .contains(candidate.account.connectorType);
      },
      request: (candidate, progress) async {
        if (cancelToken?.isCancelled == true) {
          throw cancelToken!.cancelError!;
        }
        final protocolId = llmRoutedChatProtocolForAccountModel(
          account: candidate.account,
          upstreamModelId: candidate.upstreamModelId,
          endpointType: builtinDefaultApiProtocolForConnector(
            candidate.account.connectorType,
          ),
        );
        final protocolRequest = _buildProtocolRequest(
          body,
          modelId: candidate.upstreamModelId,
          protocolId: protocolId,
        );
        final routedBody = protocolRequest.body;
        onSendProgress?.call(
          0,
          utf8.encode(jsonEncode(routedBody)).length,
        );
        lastRequestBody = routedBody;
        final baseUrl = candidate.account.endpointConfig['baseUrl'] ??
            candidate.account.endpointConfig['host'] ??
            candidate.account.endpointConfig['apiBase'];
        lastRequestUrl = baseUrl is String ? baseUrl : null;
        lastRequestHeaders = {
          'Content-Type': 'application/json',
          if (protocolId == 'anthropic.messages')
            'anthropic-version': kAnthropicApiVersion,
        };
        lastResponseData = null;
        lastResponseStatusCode = null;
        lastResponseHeaders = null;
        final AiGatewayResponse response;
        try {
          response = await runtime.executor.request(
            account: candidate.account,
            modelId: candidate.upstreamModelId,
            body: routedBody,
            nativeFormat: switch (protocolId) {
              'openai.responses' => 'responses',
              'anthropic.messages' => 'anthropic',
              _ => null,
            },
            cancelToken: cancelToken,
            onSendProgress: _uploadProgress(onSendProgress, onStage),
            onRequestSent: progress.markRequestSent,
            connectTimeout:
                _dio.options.connectTimeout ?? connectTimeoutDefault,
            sendTimeout: _sendTimeoutOverride ??
                sendTimeoutForBytes(utf8.encode(jsonEncode(routedBody)).length),
            receiveTimeout:
                _dio.options.receiveTimeout ?? receiveTimeoutFallback,
          );
        } on AiGatewayExecutionException catch (error) {
          if (error.kind != AiGatewayFailureKind.request) rethrow;
          lastResponseStatusCode = error.statusCode;
          lastResponseHeaders = {
            for (final entry in error.headers.entries) entry.key: [entry.value],
          };
          rethrow;
        }
        final responseData = _decodeRoutedResponse(response.body);
        final data = _normalizeRoutedResponse(protocolId, responseData);
        lastResponseStatusCode = response.statusCode;
        lastResponseHeaders = response.headers;
        lastResponseData = responseData is Map
            ? Map<String, dynamic>.from(responseData)
            : <String, dynamic>{'raw': '$responseData'};
        final apiError = data is Map ? data['error'] : null;
        if (apiError is Map) {
          final rawCode = apiError['code'] ?? apiError['type'];
          throw AiGatewayExecutionException(
            kind: AiGatewayFailureKind.request,
            code: rawCode is String ? rawCode : null,
          );
        }
        await _recordRoutedUsage(
          progress,
          data,
          response.observation,
          runtime: runtime,
          accountId: candidate.account.id,
        );
        return _OcrResponse(
          statusCode: response.statusCode,
          data: data,
          rawData: responseData,
          headers: response.headers,
          requestOptions: RequestOptions(
            path: lastRequestUrl ?? _chatUrl,
            data: routedBody,
            headers: lastRequestHeaders ?? const {},
          ),
        );
      },
    );
    return execution.value;
  }

  Future<void> _recordRoutedUsage(
    AiGatewayRouteProgress progress,
    Object? response,
    AiGatewayConnectorObservation observation, {
    required AiGatewayFacade runtime,
    required String accountId,
  }) async {
    final reported = observation.requestUsage;
    if (reported.isKnown &&
        reported.unit != null &&
        reported.value != null &&
        reported.unit != 'requests') {
      await progress.recordUsage(
        unit: reported.unit!,
        value: reported.value!,
        source: 'provider',
      );
    }
    if (observation.remainingQuota.isKnown ||
        observation.quotaSignals.values.any((metric) => metric.isKnown)) {
      try {
        await runtime.accountManagement.recordQuotaObservation(
          accountId: accountId,
          remainingQuota: observation.remainingQuota,
          quotaSignals: observation.quotaSignals,
        );
      } catch (_) {
        // Connector quota is observational and cannot fail successful OCR.
      }
    }
    if (response is! Map || response['usage'] is! Map) return;
    final usage = OpenAICompatibleChatProvider.normalizeUsage(
      response['usage'],
    );
    if (usage == null) return;
    final observedUnit =
        reported.isKnown && reported.value != null ? reported.unit : null;
    final input = usage['inputTokens'];
    final output = usage['outputTokens'];
    if ((input is num || output is num) && observedUnit != 'tokens') {
      await progress.recordUsage(
        unit: 'tokens',
        value: (input is num ? input : 0) + (output is num ? output : 0),
        source: 'provider',
      );
    }
    final cost = usage['cost'];
    if (cost is num && observedUnit != 'usd') {
      await progress.recordUsage(unit: 'usd', value: cost, source: 'provider');
    }
  }

  Object? _decodeRoutedResponse(Object? response) {
    if (response is List<int>) {
      return jsonDecode(utf8.decode(response));
    }
    if (response is String) return jsonDecode(response);
    return response;
  }

  AiGatewayEncodedProtocolRequest _buildProtocolRequest(
    Map<String, dynamic> body, {
    required String modelId,
    required String protocolId,
  }) {
    final rawMessages = body['messages'];
    if (rawMessages is! List) {
      throw const FormatException('OCR request has no messages.');
    }
    final protocolOptions = <String, dynamic>{
      for (final entry in body.entries)
        if (!const {
          'model',
          'messages',
          'stream',
          'max_tokens',
          'temperature',
        }.contains(entry.key))
          entry.key: entry.value,
    };
    if (protocolId == 'google.gemini.generate_content' &&
        protocolOptions['top_p'] is num) {
      final generationConfig = protocolOptions['generationConfig'] is Map
          ? Map<String, dynamic>.from(
              protocolOptions['generationConfig'] as Map,
            )
          : <String, dynamic>{};
      generationConfig['topP'] = protocolOptions.remove('top_p');
      protocolOptions['generationConfig'] = generationConfig;
    } else if (protocolId == 'google.gemini.interactions' &&
        protocolOptions['top_p'] is num) {
      final generationConfig = protocolOptions['generationConfig'] is Map
          ? Map<String, dynamic>.from(
              protocolOptions['generationConfig'] as Map,
            )
          : <String, dynamic>{};
      generationConfig['top_p'] = protocolOptions.remove('top_p');
      protocolOptions['generationConfig'] = generationConfig;
    }
    final request = AiGatewayProtocolBridges.buildRequest(
      protocolId,
      AiGatewayProtocolRequest(
        modelId: modelId,
        messages: rawMessages
            .whereType<Map>()
            .map(
              (message) => AiGatewayProtocolBridges.openAiChatCompletions
                  .toStroom(Map<String, dynamic>.from(message)),
            )
            .toList(growable: false),
        stream: false,
        maxOutputTokens: body['max_tokens'] is num
            ? (body['max_tokens'] as num).toInt()
            : null,
        temperature: body['temperature'] is num
            ? (body['temperature'] as num).toDouble()
            : null,
        options: protocolOptions,
      ),
    );
    if (request == null) {
      throw UnsupportedError('OCR does not support protocol $protocolId.');
    }
    return request;
  }

  Object? _normalizeRoutedResponse(String protocolId, Object? response) {
    if (response is! Map) return response;
    final data = Map<String, dynamic>.from(response);
    if (data['choices'] is List || data.containsKey('error')) return data;

    String text = '';
    String? finishReason;
    Map<String, dynamic>? usage;
    Object? refusal;
    switch (protocolId) {
      case 'openai.responses':
        final outputText = data['output_text'];
        if (outputText is String) {
          text = outputText;
        } else if (data['output'] is List) {
          for (final item in data['output'] as List) {
            if (item is! Map || item['content'] is! List) continue;
            for (final part in item['content'] as List) {
              if (part is! Map) continue;
              final partType = part['type'];
              if (partType == 'output_text' && part['text'] is String) {
                text += part['text'] as String;
              } else if (partType == 'refusal') {
                refusal = part['refusal'];
              }
            }
          }
        }
        if (data['status'] == 'incomplete') {
          final incomplete = data['incomplete_details'];
          finishReason =
              incomplete is Map && incomplete['reason'] == 'max_output_tokens'
                  ? 'length'
                  : 'incomplete';
        }
        usage = _normalizeProtocolUsage(data['usage']);
      case 'anthropic.messages':
        final content = data['content'];
        if (content is List) {
          for (final part in content) {
            if (part is! Map) continue;
            if (part['type'] == 'text' && part['text'] is String) {
              text += part['text'] as String;
            } else if (part['type'] == 'tool_use') {
              continue;
            }
          }
        }
        refusal = data['stop_reason'] == 'refusal' ? data['stop_reason'] : null;
        if (data['stop_reason'] == 'max_tokens') finishReason = 'length';
        usage = _normalizeProtocolUsage(data['usage']);
      case 'google.gemini.generate_content':
        final candidates = data['candidates'];
        if (candidates is List &&
            candidates.isNotEmpty &&
            candidates.first is Map) {
          final candidate = candidates.first as Map;
          final content = candidate['content'];
          final parts = content is Map ? content['parts'] : null;
          if (parts is List) {
            for (final part in parts) {
              if (part is Map && part['text'] is String) {
                text += part['text'] as String;
              }
            }
          }
          final candidateFinishReason = candidate['finishReason'];
          if (candidateFinishReason == 'MAX_TOKENS') {
            finishReason = 'length';
          } else if (candidateFinishReason is String &&
              candidateFinishReason != 'STOP') {
            finishReason = candidateFinishReason;
          }
        }
        usage = _normalizeProtocolUsage(data['usageMetadata']);
      case 'google.gemini.interactions':
        final output = data['output'] ?? data['outputs'];
        if (output is String) {
          text = output;
        } else if (output is List) {
          for (final part in output.whereType<Map>()) {
            if ((part['type'] == 'text' || part['type'] == 'output_text') &&
                part['text'] is String) {
              text += part['text'] as String;
            } else if (part['type'] == 'model_output' &&
                part['content'] is List) {
              for (final content in part['content'] as List) {
                if (content is Map &&
                    content['type'] == 'text' &&
                    content['text'] is String) {
                  text += content['text'] as String;
                }
              }
            }
          }
        }
        final status = data['status'];
        if (status == 'incomplete' || status == 'requires_action') {
          finishReason = status as String;
        }
        usage = _normalizeProtocolUsage(data['usage']);
      case 'ollama.chat':
        final message = data['message'];
        if (message is Map && message['content'] is String) {
          text = message['content'] as String;
        }
        if (data['done'] == false || data['done_reason'] == 'length') {
          finishReason = 'length';
        }
        usage = _normalizeProtocolUsage({
          'input_tokens': data['prompt_eval_count'],
          'output_tokens': data['eval_count'],
        });
      default:
        return data;
    }

    return {
      'choices': [
        {
          'finish_reason': finishReason ?? 'stop',
          'message': {
            'content': text,
            ...?(refusal == null ? null : {'refusal': refusal}),
          },
        },
      ],
      ...?(usage == null ? null : {'usage': usage}),
    };
  }

  Map<String, dynamic>? _normalizeProtocolUsage(Object? rawUsage) {
    if (rawUsage is! Map) return null;
    final usage = Map<String, dynamic>.from(rawUsage);
    if (usage['promptTokenCount'] is num) {
      usage['input_tokens'] = usage['promptTokenCount'];
    }
    if (usage['candidatesTokenCount'] is num) {
      usage['output_tokens'] = usage['candidatesTokenCount'];
    }
    if (usage['total_cost'] == null && usage['cost'] == null) {
      final cost = usage['totalCost'] ?? usage['costUsd'];
      if (cost is num) usage['cost'] = cost;
    }
    return usage;
  }

  Options _requestOptions({required int encodedBytes}) => Options(
        headers: _requestAuthorizationHeaders,
        sendTimeout: _sendTimeoutOverride ??
            (_usesInjectedDio ? _dio.options.sendTimeout : null) ??
            sendTimeoutForBytes(encodedBytes),
        receiveTimeout: _dio.options.receiveTimeout ?? receiveTimeoutFallback,
      );

  Map<String, dynamic>? get _requestAuthorizationHeaders {
    final hasCallerAuthorization = _dio.options.headers.keys.any(
      (header) => header.toLowerCase() == 'authorization',
    );
    if (hasCallerAuthorization || config.apiKey.isEmpty) return null;
    return {'Authorization': 'Bearer ${config.apiKey}'};
  }

  ProgressCallback _uploadProgress(
    ProgressCallback? progress,
    void Function(OcrRequestStage)? stage,
  ) =>
      (sent, total) {
        stage?.call(OcrRequestStage.uploading);
        progress?.call(sent, total);
        if (total > 0 && sent >= total) {
          stage?.call(OcrRequestStage.waiting);
        }
      };

  /// Capture response-level diagnostic fields from a [DioException].
  /// Mirrors the pattern in [OpenAICompatibleChatProvider.chatStream].
  void _captureDioExceptionDiagnostics(
    DioException e, {
    required List<String> requestCredentialValues,
  }) {
    final responseCredentialValues = {
      ...requestCredentialValues,
      ...OcrDiagnosticSnapshot.credentialValuesFromRequest({
        'body': e.requestOptions.data,
      }),
      ..._credentialValuesFromHeaders(e.requestOptions.headers),
      ...OcrDiagnosticSnapshot.credentialValuesFromHeaders(
        e.response?.headers.map,
      ),
      ...OcrDiagnosticSnapshot.credentialValuesFromRequest({
        'body': e.response?.data,
      }),
    }.toList(growable: false);
    if (e.response?.data is Map) {
      lastResponseData = Map<String, dynamic>.from(e.response!.data as Map);
    } else if (e.response?.data is String) {
      lastResponseData = <String, dynamic>{'raw': e.response!.data as String};
    } else {
      lastResponseData = null;
    }
    lastResponseStatusCode = e.response?.statusCode;
    _lastDiagnosticStatusCode = OcrDiagnosticSnapshot.sanitizeResponse(
      {'statusCode': e.response?.statusCode},
      excludedValues: [config.apiKey, ...responseCredentialValues],
    )?['statusCode'] as int?;
    lastResponseHeaders = e.response?.headers.map;
    _lastRequestId = OcrDiagnosticSnapshot.requestIdFromHeaders(
          e.response?.headers.map,
          excludedValues: [config.apiKey, ...responseCredentialValues],
        ) ??
        OcrDiagnosticSnapshot.requestIdFromData(
          e.response?.data,
          excludedValues: [config.apiKey, ...responseCredentialValues],
        );
    _lastFinishReason = OcrDiagnosticSnapshot.sanitizeResponse(
      {'data': e.response?.data},
      excludedValues: [config.apiKey, ...responseCredentialValues],
    )?['finishReason'] as String?;
    _lastErrorType = e.type.name;
  }

  /// Build the standard OpenAI-compatible request body.
  int _validatedMaxTokens(Object? value) {
    if (value is! int || value <= 0) {
      throw ArgumentError.value(
        value,
        'maxTokens',
        'must be a positive integer when enabled',
      );
    }
    return value;
  }

  double _validatedBoundedParameter(
    Object? value,
    String name,
    double maximum,
  ) {
    if (value is! num || !value.isFinite || value < 0 || value > maximum) {
      throw ArgumentError.value(
        value,
        name,
        'must be between 0 and $maximum when enabled',
      );
    }
    return value.toDouble();
  }

  Map<String, dynamic> _buildRequestBody(
    List<Map<String, dynamic>> contentList,
  ) {
    final body = <String, dynamic>{
      'model': config.model,
      'messages': [
        {'role': 'system', 'content': config.effectiveSystemPrompt},
        {'role': 'user', 'content': contentList},
      ],
    };

    // Apply built-in parameters from typeConfig
    final tc = config.typeConfig;

    // max_tokens (respects enableMaxTokens toggle)
    if (tc['enableMaxTokens'] == true) {
      body['max_tokens'] = _validatedMaxTokens(tc['maxTokens']);
    }

    // temperature
    if (tc['enableTemperature'] == true) {
      body['temperature'] = _validatedBoundedParameter(
        tc['temperature'],
        'temperature',
        2,
      );
    }

    // top_p
    if (tc['enableTopP'] == true) {
      body['top_p'] = _validatedBoundedParameter(tc['topP'], 'topP', 1);
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
      if (const {'max_tokens', 'temperature', 'top_p'}.contains(name)) {
        continue;
      }
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
      'image_url': {'url': dataUri},
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
      requestSizeBudgetBytes: effectiveOcrRequestSizeBudgetBytes(
        providerValue: typeConfig['requestSizeBudgetBytes'],
      ),
    ),
  );
}

class _OcrResponse {
  final int statusCode;
  final Object? data;
  final Object? rawData;
  final Headers headers;
  final RequestOptions requestOptions;

  _OcrResponse({
    required this.statusCode,
    required this.data,
    this.rawData,
    required Map<String, List<String>> headers,
    required this.requestOptions,
  }) : headers = Headers.fromMap(headers);
}
