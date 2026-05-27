import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/ai_stream_event.dart';
import '../services/sse_client.dart';

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
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
        ));

  @override
  String get name => _name;

  // TODO: 可从 CustomParam 中提取模型列表，若某 param 的 type 或 key 为 'model'，
  // 使用其 defaultValue?.split(',') 作为模型列表。目前暂无可信数据源，留空。
  @override
  List<String> get supportedModelIds => [];

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
      if (reasoning) ..._reasoningParams(),
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (extraParams != null) ...extraParams,
    };
  }

  Map<String, dynamic> _reasoningParams() => {
        'thinking': {'type': 'enabled'},
      };

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
      final response = await _dio.post(
        _baseUrl,
        cancelToken: cancelToken,
        data: body,
      );

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
      final statusCode = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      String detail;
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

    debugPrint(
        'OpenAICompatibleChatProvider: 流式 POST $_baseUrl - 消息数: ${messages.length}');

    final Map<int, Map<String, dynamic>> toolCallAccumulators = {};

    await for (final event in sseStream(
      _baseUrl,
      {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
        'Accept': 'text/event-stream',
      },
      jsonEncode(body),
      cancelToken: cancelToken,
    )) {
      final dataStr = event.substring('data: '.length).trim();
      if (dataStr == '[DONE]') break;

      try {
        final data = jsonDecode(dataStr) as Map<String, dynamic>;
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
