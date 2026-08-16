import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/ai_stream_event.dart';
import '../services/sse_client.dart';
import 'anthropic_chat_provider.dart';
import 'chat_api_shared.dart';
export 'chat_api_shared.dart';

part 'chat_api_provider_ext.dart';

// ============================================================================
// OpenAI Compatible 实现
// ============================================================================

/// OpenAI API 兼容的聊天供应商
///
/// 支持 OpenAI、Azure OpenAI、以及所有兼容 OpenAI API 格式的服务
/// （如 DeepSeek、Moonshot、Qwen 等）。
class OpenAICompatibleChatProvider extends BaseChatProvider {
  final String _apiKey;
  final String _baseUrl;
  final String _name;
  final Dio _dio;
  Map<String, dynamic>? _lastRequestBody;
  Map<String, dynamic>? _lastResponseData;
  Map<String, String>? _lastRequestHeaders;
  Map<String, List<String>>? _lastResponseHeaders;
  String? _lastRequestUrl;
  int? _lastResponseStatusCode;
  Map<String, dynamic>? _lastUsage;

  OpenAICompatibleChatProvider({
    required String baseUrl,
    required String apiKey,
    String name = 'OpenAI Compatible',
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey,
        _name = name,
        _dio = Dio(BaseOptions(
          baseUrl: '',
          headers: {
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
            ...openRouterAppHeaders,
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
        ));

  @override
  String get name => _name;

  @override
  Map<String, dynamic>? get lastRequestBody => _lastRequestBody;

  @override
  Map<String, dynamic>? get lastResponseData => _lastResponseData;

  @override
  Map<String, String>? get lastRequestHeaders => _lastRequestHeaders;

  @override
  String? get lastRequestUrl => _lastRequestUrl;

  @override
  int? get lastResponseStatusCode => _lastResponseStatusCode;

  @override
  Map<String, List<String>>? get lastResponseHeaders => _lastResponseHeaders;

  /// 最近一次请求的实际 token 计量（来自 API usage 字段）。
  /// 标准化为 {inputTokens, outputTokens}。
  @override
  Map<String, dynamic>? get lastUsage => _lastUsage;

  /// 从 usage map 提取并标准化 token 计量。
  ///
  /// 兼容 OpenAI 标准（prompt_tokens/completion_tokens）与
  /// 新版/OpenRouter 风格（input_tokens/output_tokens）。
  ///
  /// 计费（cost）纯粹采用 API 返回的值（如 OpenRouter 的 usage.total_cost），
  /// 不自作主张按价格统计（缓存/推理 token 等计价要素太多，自统计不准）。
  /// 数值字段兼容 num 与数字字符串（部分网关返回字符串）。
  @visibleForTesting
  static Map<String, dynamic>? normalizeUsage(dynamic usage) {
    if (usage is! Map) return null;
    final inputD =
        usageNumberToDouble(usage['prompt_tokens'] ?? usage['input_tokens']);
    final outputD = usageNumberToDouble(
        usage['completion_tokens'] ?? usage['output_tokens']);
    // API 返回的计费（美元）；OpenRouter 为 usage.total_cost，
    // 部分兼容端点用 usage.cost；total_cost 存在但不可解析时回退 cost
    final costD = usageNumberToDouble(usage['total_cost']) ??
        usageNumberToDouble(usage['cost']);
    final result = <String, dynamic>{};
    if (inputD != null) result['inputTokens'] = inputD.toInt();
    if (outputD != null) result['outputTokens'] = outputD.toInt();
    if (costD != null) result['cost'] = costD;
    return result.isEmpty ? null : result;
  }

  /// 检查流式 chunk 是否携带 API 错误（choices 空 + error 字段）。
  /// 有错误时抛出（对齐 Anthropic 行为，防止截断回复被当作成功）。
  @visibleForTesting
  static void throwIfApiError(Map<String, dynamic> data) {
    final apiError = data['error'];
    if (apiError is Map) {
      final msg = apiError['message'] ?? apiError.toString();
      throw Exception('API 流式错误: $msg');
    }
  }

  // TODO: 可从 CustomParam 中提取模型列表，若某 param 的 type 或 key 为 'model'，
  // 使用其 defaultValue?.split(',') 作为模型列表。目前暂无可信数据源，留空。
  @override
  List<String> get supportedModelIds => [];

  @override
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// Public wrapper around [_buildBody] for direct testing.
  @visibleForTesting
  Map<String, dynamic> buildBody(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
  }) {
    return _buildBody(messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        stream: stream,
        tools: tools,
        extraParams: extraParams);
  }

  /// Parse a single SSE data event and return a list of [AIStreamEvent]s.
  ///
  /// Handles all known reasoning formats:
  /// - `delta.reasoning_content` (string) — OpenAI standard format
  /// - `delta.reasoning` (string) — Open Router standard format
  /// - `delta.reasoning_details` (array) — Open Router structured format
  ///   - `reasoning.text` → extract `text` field
  ///   - `reasoning.summary` → extract `summary` field
  ///   - `reasoning.encrypted` → skipped (encrypted data is not human-readable)
  ///
  /// Also handles text content.
  ///
  /// **Deduplication note:** Open Router often echoes the same reasoning
  /// content in multiple fields (e.g. both `reasoning_content` and `reasoning`)
  /// within the same SSE delta chunk. To avoid word-level duplication in the
  /// final output, events with identical text are deduplicated within a single
  /// chunk.
  ///
  /// Extracted as a static method for testability — allows direct unit testing
  /// of the SSE parsing logic without mocking HTTP/SSE infrastructure.
  @visibleForTesting
  static List<AIStreamEvent> parseStreamEvent(Map<String, dynamic> data) {
    final events = <AIStreamEvent>[];
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return events;

    final delta = choices[0]['delta'] as Map<String, dynamic>?;
    if (delta == null) return events;

    // Text content
    final content = delta['content'] as String?;
    if (content != null && content.isNotEmpty) {
      events.add(AIStreamEvent(content));
    }

    // Track reasoning text already added within this delta chunk.
    // Open Router often echoes the same text in multiple fields
    // (reasoning_content, reasoning, reasoning_details), so we
    // deduplicate to avoid word-level duplication.
    final reasoningTexts = <String>{};

    // Reasoning via reasoning_content (OpenAI standard format)
    final reasoningContent = delta['reasoning_content'] as String?;
    if (reasoningContent != null && reasoningContent.isNotEmpty) {
      reasoningTexts.add(reasoningContent);
      events.add(AIStreamEvent(reasoningContent, isReasoning: true));
    }

    // Reasoning via reasoning (Open Router string format)
    final reasoning = delta['reasoning'] as String?;
    if (reasoning != null &&
        reasoning.isNotEmpty &&
        !reasoningTexts.contains(reasoning)) {
      reasoningTexts.add(reasoning);
      events.add(AIStreamEvent(reasoning, isReasoning: true));
    }

    // Reasoning via reasoning_details (Open Router structured array format)
    final reasoningDetails = delta['reasoning_details'];
    if (reasoningDetails is List) {
      for (final detail in reasoningDetails) {
        final detailType = detail is Map ? detail['type'] as String? : null;
        if (detailType == 'reasoning.text') {
          final text = detail['text'] as String?;
          if (text != null &&
              text.isNotEmpty &&
              !reasoningTexts.contains(text)) {
            reasoningTexts.add(text);
            events.add(AIStreamEvent(text, isReasoning: true));
          }
        } else if (detailType == 'reasoning.summary') {
          final summary = detail['summary'] as String?;
          if (summary != null &&
              summary.isNotEmpty &&
              !reasoningTexts.contains(summary)) {
            reasoningTexts.add(summary);
            events.add(AIStreamEvent(summary, isReasoning: true));
          }
        }
        // reasoning.encrypted is skipped — encrypted data is not human-readable
      }
    }

    // Tool call deltas (streamed in chunks by index)
    // Note: tool call accumulation across events requires external state
    // (toolCallAccumulators map in chatStream), so we don't handle it here.
    // The caller (chatStream) handles tool call accumulation separately.

    return events;
  }

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'gpt-4o',
        'max_tokens': 4096,
        'temperature': 0.7,
      };

  // ── 非流式对话 ──────────────────────────────────────────────────

  @override
  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
    String? system,
  }) async {
    if (_apiKey.isEmpty) throw Exception('API key not configured');

    final body = _buildBody(messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        extraParams: extraParams);

    debugPrint(
        'OpenAICompatibleChatProvider: POST $_baseUrl - 消息数: ${messages.length}');

    try {
      _lastRequestBody = body;
      _lastRequestUrl = _baseUrl;
      _lastRequestHeaders = {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
        ...openRouterAppHeaders,
      };
      _lastResponseStatusCode = null;
      _lastResponseData = null;
      _lastResponseHeaders = null;
      _lastUsage = null;
      final response = await _dio.post(
        _baseUrl,
        cancelToken: cancelToken,
        data: body,
      );

      _lastResponseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'raw': '$response.data'};
      _lastResponseStatusCode = response.statusCode;
      _lastResponseHeaders = response.headers.map;
      _lastUsage = normalizeUsage(
          response.data is Map ? (response.data as Map)['usage'] : null);

      final choices = response.data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('API 返回了空的 choices 列表');
      }
      final content = choices[0]['message']?['content'] as String?;
      if (content == null) {
        throw Exception('API 返回内容为空');
      }
      return content;
    } on DioException catch (e) {
      throw _handleChatDioError(e);
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  // ── 流式对话 ────────────────────────────────────────────────────

  @override
  Stream<AIStreamEvent> chatStream(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
    String? system,
  }) async* {
    if (_apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    final body = _buildBody(messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        stream: true,
        tools: tools,
        extraParams: extraParams);

    _lastRequestBody = body;
    _lastRequestUrl = _baseUrl;
    _lastRequestHeaders = {
      'Content-Type': 'application/json',
      if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
      'Accept': 'text/event-stream',
      ...openRouterAppHeaders,
    };
    _lastResponseStatusCode = null;
    _lastResponseData = null;
    _lastResponseHeaders = null;
    _lastUsage = null;

    debugPrint(
        'OpenAICompatibleChatProvider: 流式 POST $_baseUrl - 消息数: ${messages.length}');

    final Map<int, Map<String, dynamic>> toolCallAccumulators = {};
    // 本次请求的 usage（局部收集，per-request 隔离——
    // 共享 provider 实例的 _lastUsage 槽会被并发对话覆盖）
    Map<String, dynamic>? localUsage;

    try {
      // Mark as successfully connected once we start receiving events
      _lastResponseStatusCode = 200;
      await for (final event in sseStream(
        _baseUrl,
        {
          'Content-Type': 'application/json',
          if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
          'Accept': 'text/event-stream',
          ...openRouterAppHeaders,
        },
        jsonEncode(body),
        cancelToken: cancelToken,
        onResponseHeaders: (headers) {
          _lastResponseHeaders = headers;
        },
      )) {
        // Guard: both sse implementations yield lines starting with "data: ",
        // but be defensive in case a future implementation forgets the prefix.
        if (!event.startsWith('data: ')) {
          debugPrint(
              'chat_api_provider: skipping unexpected SSE event (no data: prefix)');
          continue;
        }
        final dataStr = event.substring('data: '.length).trim();
        if (dataStr == '[DONE]') break;

        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          _lastResponseData = data;

          // 流中的 API 错误 chunk（choices 空 + error 字段）必须上抛，
          // 否则会被当成正常截断回复（对齐 Anthropic 行为）
          throwIfApiError(data);

          // 收集实际 token 计量（OpenAI 规范：usage 只在末 chunk；
          // 但部分兼容端点会在中间 chunk 上报部分 usage）——
          // 逐 chunk 覆盖会丢失前段计量，改为合并保留已有键，
          // 末 chunk 的完整 usage 自然覆盖同名键。
          final usage = normalizeUsage(data['usage']);
          if (usage != null) {
            localUsage ??= {};
            localUsage.addAll(usage);
          }

          // Parse the stream event using the static helper method
          final parsedEvents = parseStreamEvent(data);

          // Yield all parsed events (content, reasoning, etc.)
          for (final pe in parsedEvents) {
            yield pe;
          }

          _accumulateToolCallDeltas(data, toolCallAccumulators);
        } catch (e) {
          // API 错误 chunk（Exception）必须上抛；仅解析/形状错误
          // （FormatException/TypeError，如代理式多余行）跳过继续。
          if (e is! FormatException && e is! TypeError) rethrow;
          debugPrint(
              'OpenAICompatibleChatProvider: failed to parse SSE chunk: $e');
        }
      }
    } catch (e) {
      await _resetForStreamError(e);
      // 错误轮也可能已产生计费 usage：先产出计量事件再上抛，
      // 让 ChatService 在 onError 之前累计到成本
      if (localUsage != null) {
        _lastUsage = localUsage;
        yield AIStreamEvent('', usage: localUsage);
      }
      rethrow;
    }

    // After stream ends, yield the usage metering for this request
    // (per-request isolation via event, not the shared _lastUsage slot)
    if (localUsage != null) {
      // 同时填充诊断槽（与 lastResponseData 同语义）
      _lastUsage = localUsage;
      yield AIStreamEvent('', usage: localUsage);
    }

    // After stream ends, yield tool calls if any were accumulated
    final toolEvent = _buildToolCallEvent(toolCallAccumulators);
    if (toolEvent != null) {
      yield toolEvent;
    }
  }
}

// ============================================================================
// 工厂函数
// ============================================================================

/// 根据配置创建聊天供应商实例
///
/// [providerName] 供应商名称
/// [baseUrl] API 基础 URL
/// [apiKey] API 密钥
/// [model] 可选，默认模型 ID
/// [endpointType] 端点类型：'openai'（默认，OpenAI 兼容）| 'anthropic'
///   （官方 Anthropic Messages API）。模型级覆盖 > 供应商级 > 'openai'。
BaseChatProvider createChatProviderFromConfig({
  required String providerName,
  required String baseUrl,
  required String apiKey,
  String? model,
  String endpointType = 'openai',
}) {
  if (endpointType == 'anthropic') {
    return AnthropicChatProvider(
      baseUrl: baseUrl,
      apiKey: apiKey,
      name: providerName,
    );
  }
  // OpenAI-compatible（默认）
  return OpenAICompatibleChatProvider(
    baseUrl: baseUrl,
    apiKey: apiKey,
    name: providerName,
  );
}
