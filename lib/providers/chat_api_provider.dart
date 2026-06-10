import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/ai_stream_event.dart';
import '../services/sse_client.dart';

// ============================================================================
// OpenRouter-format app identification headers
// ============================================================================

/// HTTP-Referer header value identifying this application, following the
/// OpenRouter convention for app attribution on leaderboards.
const String kHttpReferer = 'https://github.com/JohnXu22786/Stroom';

/// X-Title header value identifying this application, following the
/// OpenRouter convention for app attribution on leaderboards.
const String kXTitle = 'Stroom';

/// Map of application identification headers following OpenRouter format.
/// These are added to all outgoing API requests to identify the app.
Map<String, String> get openRouterAppHeaders => {
      'HTTP-Referer': kHttpReferer,
      'X-Title': kXTitle,
    };

// ============================================================================
// 抽象基类 — BaseChatProvider
// ============================================================================

/// 聊天 API 供应商抽象基类
/// 采用策略模式，为不同的 LLM 聊天服务提供统一调用接口
///
/// [messages] 已预处理好为 API 格式的 message 列表，
/// 由上游 ChatService 负责将 ChatMessage 转化为 API 格式。
abstract class BaseChatProvider {
  String get name;

  List<String> get supportedModelIds;

  Map<String, dynamic>? get lastRequestBody => null;
  Map<String, dynamic>? get lastResponseData => null;
  Map<String, String>? get lastRequestHeaders => null;
  Map<String, List<String>>? get lastResponseHeaders => null;
  String? get lastRequestUrl => null;
  int? get lastResponseStatusCode => null;

  /// Dio default headers, exposed for testing.
  Map<String, dynamic> get defaultHeaders => {};

  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
  });

  Stream<AIStreamEvent> chatStream(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
  });

  Map<String, dynamic> get defaultParams;
}

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

  // TODO: 可从 CustomParam 中提取模型列表，若某 param 的 type 或 key 为 'model'，
  // 使用其 defaultValue?.split(',') 作为模型列表。目前暂无可信数据源，留空。
  @override
  List<String> get supportedModelIds => [];

  @override
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// 构建请求体
  ///
  /// [messages] 已由 ChatService 预处理为 API 格式
  ///（OpenAI multimodal content array 或 plain string）。
  Map<String, dynamic> _buildBody(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
  }) {
    return {
      'model': model ?? defaultParams['model'],
      'messages': messages,
      'max_tokens': maxTokens ?? defaultParams['max_tokens'],
      'temperature': temperature ?? defaultParams['temperature'],
      'stream': stream,
      if (reasoning) ..._reasoningParams(model),
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (extraParams != null) ...extraParams,
    };
  }

  Map<String, dynamic> _reasoningParams(String? model) {
    if (model != null) {
      final lower = model.toLowerCase();
      if (lower.contains('deepseek') || lower.contains('r1')) {
        return {'thinking': {'type': 'enabled'}};
      }
    }
    return {'reasoning_effort': 'medium'};
  }

  /// Mask API key for display, showing only first 8 chars and last 4 chars.
  String _maskApiKey(String key) {
    if (key.isEmpty) return '****';
    if (key.length <= 4) return '${key.substring(0, 1)}***';
    if (key.length <= 16) return '${key.substring(0, 4)}****';
    return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
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
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
  }) async {
    if (_apiKey.isEmpty) throw Exception('API key not configured');

    final body = _buildBody(messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        reasoning: reasoning,
        extraParams: extraParams);

    debugPrint(
        'OpenAICompatibleChatProvider: POST $_baseUrl - 消息数: ${messages.length}');

    try {
      _lastRequestBody = body;
      _lastRequestUrl = _baseUrl;
      _lastRequestHeaders = {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'Authorization': 'Bearer ${_maskApiKey(_apiKey)}',
        ...openRouterAppHeaders,
      };
      _lastResponseStatusCode = null;
      _lastResponseData = null;
      _lastResponseHeaders = null;
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
      _lastResponseStatusCode = e.response?.statusCode;
      _lastResponseHeaders = e.response?.headers?.map;
      if (e.response?.data is Map) {
        _lastResponseData = Map<String, dynamic>.from(e.response!.data as Map);
      } else if (e.response?.data is String) {
        _lastResponseData = <String, dynamic>{'raw': e.response!.data as String};
      }
      final statusCode = e.response?.statusCode ?? 0;
      String detail;
      final body = e.response?.data;
      if (body is Map) {
        detail = body['error'] is Map
            ? '${body['error']['message'] ?? body}'
            : '$body';
      } else if (body is String) {
        detail = body;
      } else {
        detail = '$body';
      }
      throw Exception('API 请求失败 (HTTP $statusCode): $detail');
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
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
  }) async* {
    if (_apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    final body = _buildBody(messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        reasoning: reasoning,
        stream: true,
        tools: tools,
        extraParams: extraParams);

    _lastRequestBody = body;
    _lastRequestUrl = _baseUrl;
    _lastRequestHeaders = {
      'Content-Type': 'application/json',
      if (_apiKey.isNotEmpty) 'Authorization': 'Bearer ${_maskApiKey(_apiKey)}',
      'Accept': 'text/event-stream',
      ...openRouterAppHeaders,
    };
    _lastResponseStatusCode = null;
    _lastResponseData = null;
    _lastResponseHeaders = null;

    debugPrint(
        'OpenAICompatibleChatProvider: 流式 POST $_baseUrl - 消息数: ${messages.length}');

    final Map<int, Map<String, dynamic>> toolCallAccumulators = {};

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
      )) {
        // Guard: both sse implementations yield lines starting with "data: ",
        // but be defensive in case a future implementation forgets the prefix.
        if (!event.startsWith('data: ')) {
          debugPrint('chat_api_provider: skipping unexpected SSE event (no data: prefix)');
          continue;
        }
        final dataStr = event.substring('data: '.length).trim();
        if (dataStr == '[DONE]') break;

        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          _lastResponseData = data;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            if (delta == null) continue;

            // Text content
            final content = delta['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield AIStreamEvent(content);
            }

            // Reasoning content
            if (reasoning) {
              final reasoningContent = delta['reasoning_content'] as String?;
              if (reasoningContent != null && reasoningContent.isNotEmpty) {
                yield AIStreamEvent(reasoningContent, isReasoning: true);
              }
            }

            // Tool call deltas (streamed in chunks by index)
            final toolCallsDelta = delta['tool_calls'] as List?;
            if (toolCallsDelta != null) {
              for (final tc in toolCallsDelta) {
                final index = tc['index'] as int;
                toolCallAccumulators.putIfAbsent(index, () => {});
                final acc = toolCallAccumulators[index]!;

                if (tc['id'] != null) acc['id'] = tc['id'];
                if (tc['type'] != null) acc['type'] = tc['type'];
                if (tc['function'] != null) {
                  acc.putIfAbsent('function', () => <String, dynamic>{});
                  final fn = tc['function'] as Map<String, dynamic>;
                  final accFn = acc['function'] as Map<String, dynamic>;
                  if (fn['name'] != null) accFn['name'] = fn['name'];
                  if (fn['arguments'] != null) {
                    accFn['arguments'] = (accFn['arguments'] as String? ?? '') +
                        (fn['arguments'] as String);
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('OpenAICompatibleChatProvider: failed to parse SSE chunk: $e');
        }
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.data is Map) {
          _lastResponseData =
              Map<String, dynamic>.from(e.response!.data as Map);
        } else if (e.response?.data is String) {
          _lastResponseData =
              <String, dynamic>{'raw': e.response!.data as String};
        } else {
          // Clear stale streaming data when response body is a Stream,
          // null, or otherwise unparseable (e.g., non-2xx HTTP with
          // ResponseType.stream).
          _lastResponseData = null;
        }
        // Preserve status code even when response body is unavailable.
        _lastResponseStatusCode = e.response?.statusCode;
        _lastResponseHeaders = e.response?.headers?.map;
      } else {
        // Non-DioException errors (e.g., SSE stream parse failures):
        // Reset ALL optimistically-set or stale fields to avoid
        // reporting stale data from the last successful SSE chunk.
        _lastResponseStatusCode = null;
        _lastResponseData = null;
        _lastResponseHeaders = null;
      }
      rethrow;
    }

    // After stream ends, yield tool calls if any were accumulated
    if (toolCallAccumulators.isNotEmpty) {
      final toolCalls = toolCallAccumulators.entries
          .map((e) => {
                'id': e.value['id'] as String? ?? 'call_${e.key}',
                'type': e.value['type'] as String? ?? 'function',
                'function': e.value['function'] as Map<String, dynamic>? ?? {},
              })
          .toList();
      yield AIStreamEvent('', toolCalls: toolCalls);
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
BaseChatProvider createChatProviderFromConfig({
  required String providerName,
  required String baseUrl,
  required String apiKey,
  String? model,
}) {
  // For now, always return OpenAICompatibleChatProvider
  // Future: support other provider types
  return OpenAICompatibleChatProvider(
    baseUrl: baseUrl,
    apiKey: apiKey,
    name: providerName,
  );
}
