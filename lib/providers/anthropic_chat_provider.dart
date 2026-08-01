import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_stream_event.dart';
import '../services/sse_client.dart';
import 'chat_api_shared.dart';

// ============================================================================
// Anthropic Messages API 实现（官方格式）
// ============================================================================

/// 官方 Anthropic Messages API 版本头。
const String kAnthropicApiVersion = '2023-06-01';

/// Anthropic 兼容聊天供应商。
///
/// 遵循官方 Messages API：
/// - 请求头：`x-api-key` + `anthropic-version`（非 Bearer）
/// - 消息：内容块数组（text / thinking / tool_use / tool_result / image / document）
/// - 流式：SSE 事件按 `data.type` 判别
///   （message_start / content_block_start / content_block_delta /
///    content_block_stop / message_delta / message_stop / error）
/// - 工具调用：`stop_reason == "tool_use"` 时在流末尾产出
///
/// 支持 OpenRouter 等 Anthropic 兼容端点（附加 OpenRouter 应用标识头无害）。
/// Anthropic 流式解析的跨事件状态（工具块 / thinking 签名 / 停止原因）。
///
/// 由 chatStream 持有，在多个 SSE 载荷间传递；提取为类便于单测驱动
/// 完整的事件序列。
@visibleForTesting
class AnthropicStreamAccumulator {
  final Map<int, Map<String, dynamic>> toolCalls = {};
  final List<String> thinkingSignatures = [];
  String? stopReason;
}

/// 处理单个 Anthropic SSE data 载荷（含跨事件状态的累计）。
///
/// 返回本载荷直接产生的 [AIStreamEvent] 列表。
@visibleForTesting
List<AIStreamEvent> processAnthropicStreamData(
  Map<String, dynamic> data,
  AnthropicStreamAccumulator acc,
) {
  final events = <AIStreamEvent>[];
  final type = data['type'] as String?;
  switch (type) {
    case 'content_block_start':
      final block = data['content_block'] as Map<String, dynamic>?;
      if (block == null) break;
      final blockType = block['type'];
      if (blockType == 'tool_use') {
        acc.toolCalls[data['index'] as int? ?? 0] = {
          'id': block['id'] as String? ?? '',
          'name': block['name'] as String? ?? '',
          'input': '',
        };
      } else if (blockType == 'thinking') {
        // thinking 块开始：新签名槽位
        acc.thinkingSignatures.add('');
      }

    case 'content_block_delta':
      final delta = data['delta'] as Map<String, dynamic>?;
      if (delta == null) break;
      switch (delta['type']) {
        case 'text_delta':
          final text = delta['text'] as String?;
          if (text != null && text.isNotEmpty) {
            events.add(AIStreamEvent(text));
          }
        case 'thinking_delta':
          final thinking = delta['thinking'] as String?;
          if (thinking != null && thinking.isNotEmpty) {
            events.add(AIStreamEvent(thinking, isReasoning: true));
          }
        case 'signature_delta':
          final signature = delta['signature'] as String?;
          if (signature != null && signature.isNotEmpty) {
            if (acc.thinkingSignatures.isNotEmpty) {
              acc.thinkingSignatures[acc.thinkingSignatures.length - 1] +=
                  signature;
            } else {
              acc.thinkingSignatures.add(signature);
            }
          }
        case 'input_json_delta':
          final partial = delta['partial_json'] as String?;
          if (partial != null && partial.isNotEmpty) {
            final index = data['index'] as int? ?? 0;
            final accEntry = acc.toolCalls[index];
            if (accEntry != null) {
              accEntry['input'] =
                  (accEntry['input'] as String? ?? '') + partial;
            }
          }
      }

    case 'message_delta':
      final delta = data['delta'] as Map<String, dynamic>?;
      final reason = delta?['stop_reason'] as String?;
      if (reason != null) acc.stopReason = reason;

    case 'error':
      final err = data['error'] as Map<String, dynamic>?;
      final msg = err?['message'] as String? ?? '未知错误';
      throw Exception('Anthropic API 错误: $msg');

    case 'message_stop':
      break;
  }
  return events;
}

/// 根据流结束时的累计状态构建工具调用事件（若适用）。
///
/// 仅在 `stop_reason == "tool_use"` 且存在累计工具块时产出
/// （避免中断时把残缺累计块当作有效工具调用）。提取为静态方法
/// 便于直接测试 chatStream 末尾的产出逻辑。
@visibleForTesting
AIStreamEvent? buildToolCallEvent(AnthropicStreamAccumulator acc) {
  if (acc.stopReason != 'tool_use' || acc.toolCalls.isEmpty) return null;
  final toolCalls = acc.toolCalls.entries.map((e) {
    final inputJson = (e.value['input'] as String? ?? '').trim();
    Object? input;
    if (inputJson.isNotEmpty) {
      try {
        input = jsonDecode(inputJson);
      } catch (_) {
        input = <String, dynamic>{};
      }
    } else {
      input = <String, dynamic>{};
    }
    return {
      'id': e.value['id'] as String? ?? 'toolu_${e.key}',
      'name': e.value['name'] as String? ?? '',
      'input': input,
    };
  }).toList();
  return AIStreamEvent('', toolCalls: toolCalls);
}

class AnthropicChatProvider extends BaseChatProvider {
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

  AnthropicChatProvider({
    required String baseUrl,
    required String apiKey,
    String name = 'Anthropic',
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey,
        _name = name,
        _dio = Dio(BaseOptions(
          baseUrl: '',
          headers: {
            'Content-Type': 'application/json',
            'anthropic-version': kAnthropicApiVersion,
            if (apiKey.isNotEmpty) 'x-api-key': apiKey,
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

  /// 最近一次请求的实际 token 计量（Anthropic usage 字段）。
  /// 标准化为 {inputTokens, outputTokens}。
  @override
  Map<String, dynamic>? get lastUsage => _lastUsage;

  // TODO: 可从 CustomParam 中提取模型列表，目前暂无可信数据源，留空。
  @override
  List<String> get supportedModelIds => [];

  @override
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// 判断 extraParams 是否启用了 extended thinking。
  ///
  /// Anthropic 官方限制：extended thinking 开启时 temperature 必须为 1。
  /// 识别 thinking.type 为 enabled/adaptive 等开头的值。
  static bool _hasExtendedThinking(Map<String, dynamic>? extraParams) {
    final thinking = extraParams?['thinking'];
    if (thinking is Map) {
      final type = thinking['type'];
      if (type is String) {
        final t = type.toLowerCase();
        return t == 'enabled' || t == 'adaptive' || t == 'on';
      }
    }
    return false;
  }

  /// Build the request body map（Anthropic 官方格式）。
  ///
  /// [messages] 已由协议层构建为 Anthropic 格式
  /// （content 字符串或内容块数组，system 走 [system] 参数）。
  Map<String, dynamic> _buildBody(
    List<Map<String, dynamic>> messages, {
    String? system,
    String? model,
    int? maxTokens,
    double? temperature,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
  }) {
    final thinking = _hasExtendedThinking(extraParams);
    return {
      'model': model ?? defaultParams['model'],
      // Anthropic 官方要求 max_tokens 必填
      'max_tokens': maxTokens ?? 4096,
      'messages': messages,
      if (system != null && system.isNotEmpty) 'system': system,
      // Extended thinking 要求 temperature = 1（官方限制），省略则默认 1
      if (temperature != null && !thinking) 'temperature': temperature,
      'stream': stream,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (extraParams != null) ...extraParams,
    };
  }

  /// Public wrapper around [_buildBody] for direct testing.
  @visibleForTesting
  Map<String, dynamic> buildBody(
    List<Map<String, dynamic>> messages, {
    String? system,
    String? model,
    int? maxTokens,
    double? temperature,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
  }) {
    return _buildBody(messages,
        system: system,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        stream: stream,
        tools: tools,
        extraParams: extraParams);
  }

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'claude-3-5-sonnet',
        'max_tokens': 4096,
        'temperature': 1.0,
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
        system: system,
        extraParams: extraParams);

    debugPrint(
        'AnthropicChatProvider: POST $_baseUrl - 消息数: ${messages.length}');

    try {
      _lastRequestBody = body;
      _lastRequestUrl = _baseUrl;
      _lastRequestHeaders = {
        'Content-Type': 'application/json',
        'anthropic-version': kAnthropicApiVersion,
        if (_apiKey.isNotEmpty) 'x-api-key': _apiKey,
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
      // 收集实际 token 计量（非流式响应体 usage 字段）
      final usage =
          response.data is Map ? (response.data as Map)['usage'] : null;
      if (usage is Map) {
        _lastUsage = {};
        var input = usage['input_tokens'] is num
            ? (usage['input_tokens'] as num).toInt()
            : 0;
        if (usage['cache_read_input_tokens'] is num) {
          input += (usage['cache_read_input_tokens'] as num).toInt();
        }
        if (usage['cache_creation_input_tokens'] is num) {
          input += (usage['cache_creation_input_tokens'] as num).toInt();
        }
        if (input > 0) _lastUsage!['inputTokens'] = input;
        final output = usage['output_tokens'];
        if (output is num) _lastUsage!['outputTokens'] = output.toInt();
        final cost = usage['total_cost'] ?? usage['cost'];
        if (cost is num) _lastUsage!['cost'] = cost.toDouble();
      }

      final contentBlocks = response.data['content'] as List?;
      if (contentBlocks == null || contentBlocks.isEmpty) {
        throw Exception('API 返回了空的 content 列表');
      }
      final parts = <String>[];
      for (final block in contentBlocks) {
        if (block is Map && block['type'] == 'text') {
          final text = block['text'] as String?;
          if (text != null) parts.add(text);
        }
      }
      if (parts.isEmpty) {
        throw Exception('API 返回内容为空');
      }
      return parts.join('');
    } on DioException catch (e) {
      _lastResponseStatusCode = e.response?.statusCode;
      _lastResponseHeaders = e.response?.headers.map;
      if (e.response?.data is Map) {
        _lastResponseData = Map<String, dynamic>.from(e.response!.data as Map);
      } else if (e.response?.data is String) {
        _lastResponseData = <String, dynamic>{
          'raw': e.response!.data as String
        };
      }
      final statusCode = e.response?.statusCode ?? 0;
      String detail;
      final body = e.response?.data;
      if (body is Map) {
        final err = body['error'];
        detail = err is Map ? '${err['message'] ?? body}' : '$body';
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
        system: system,
        tools: tools,
        extraParams: extraParams);

    _lastRequestBody = body;
    _lastRequestUrl = _baseUrl;
    _lastRequestHeaders = {
      'Content-Type': 'application/json',
      'anthropic-version': kAnthropicApiVersion,
      if (_apiKey.isNotEmpty) 'x-api-key': _apiKey,
      'Accept': 'text/event-stream',
      ...openRouterAppHeaders,
    };
    _lastResponseStatusCode = null;
    _lastResponseData = null;
    _lastResponseHeaders = null;
    _lastUsage = null;

    debugPrint(
        'AnthropicChatProvider: 流式 POST $_baseUrl - 消息数: ${messages.length}');

    final acc = AnthropicStreamAccumulator();
    // 本次请求的 usage（局部收集，per-request 隔离）
    Map<String, dynamic>? localUsage;

    try {
      _lastResponseStatusCode = 200;
      await for (final frame in sseEventStream(
        _baseUrl,
        {
          'Content-Type': 'application/json',
          'anthropic-version': kAnthropicApiVersion,
          if (_apiKey.isNotEmpty) 'x-api-key': _apiKey,
          'Accept': 'text/event-stream',
          ...openRouterAppHeaders,
        },
        jsonEncode(body),
        cancelToken: cancelToken,
        onResponseHeaders: (headers) {
          _lastResponseHeaders = headers;
        },
      )) {
        final dataStr = frame.data.trim();
        if (dataStr.isEmpty) continue;
        // 兼容代理式终止符（部分网关在流末尾发送 [DONE]）
        if (dataStr == '[DONE]') break;

        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          _lastResponseData = data;

          // 收集实际 token 计量：
          // - message_start 的 usage.input_tokens（+ cache_read/cache_creation
          //   计入上下文占用）
          // - message_delta 的 usage.output_tokens
          // - API 返回的 cost（OpenRouter anthropic 兼容端点可能带 total_cost）
          if (data['type'] == 'message_start') {
            final msg = data['message'] as Map<String, dynamic>?;
            final usage = msg?['usage'];
            if (usage is Map) {
              localUsage ??= {};
              // 输入 = input_tokens + 缓存读取/创建（缓存 token 同样占用上下文）
              var input = usage['input_tokens'] is num
                  ? (usage['input_tokens'] as num).toInt()
                  : 0;
              if (usage['cache_read_input_tokens'] is num) {
                input += (usage['cache_read_input_tokens'] as num).toInt();
              }
              if (usage['cache_creation_input_tokens'] is num) {
                input += (usage['cache_creation_input_tokens'] as num).toInt();
              }
              if (input > 0) localUsage!['inputTokens'] = input;
              final cost = usage['total_cost'] ?? usage['cost'];
              if (cost is num) {
                // 兼容两端点重复上报 total_cost：取较大值而非累加，避免双计
                final existing = (localUsage!['cost'] as num?)?.toDouble() ?? 0;
                if (cost.toDouble() > existing) {
                  localUsage!['cost'] = cost.toDouble();
                }
              }
            }
          } else if (data['type'] == 'message_delta') {
            final usage = data['usage'];
            if (usage is Map) {
              localUsage ??= {};
              final output = usage['output_tokens'];
              if (output is num) localUsage!['outputTokens'] = output.toInt();
              final cost = usage['total_cost'] ?? usage['cost'];
              if (cost is num) {
                // 与 message_start 的 cost 取较大值（兼容重复上报）
                final existing = (localUsage!['cost'] as num?)?.toDouble() ?? 0;
                if (cost.toDouble() > existing) {
                  localUsage!['cost'] = cost.toDouble();
                }
              }
            }
          }

          final events = processAnthropicStreamData(data, acc);
          for (final e in events) {
            yield e;
          }
        } catch (e) {
          // 网络/协议层异常（DioException）与 API 错误事件
          // （processAnthropicStreamData 对 error 类型抛出的 Exception）
          // 必须上抛，否则真实 API 错误会被当成正常截断回复。
          // 仅解析/形状错误（FormatException 与 TypeError——
          // 如代理式多余行 data: [] / data: "keepalive"）跳过继续。
          if (e is! FormatException && e is! TypeError) rethrow;
          debugPrint('AnthropicChatProvider: failed to parse SSE chunk: $e');
        }
      }
    } catch (e) {
      if (e is DioException) {
        // Clear stale streaming data from successful SSE events first.
        _lastResponseData = null;

        if (e.response?.data is Map) {
          _lastResponseData =
              Map<String, dynamic>.from(e.response!.data as Map);
        } else if (e.response?.data is String) {
          _lastResponseData = <String, dynamic>{
            'raw': e.response!.data as String
          };
        } else {
          final streamBody = await parseStreamErrorBody(e);
          if (streamBody != null) {
            _lastResponseData = streamBody;
          }
        }
        _lastResponseStatusCode = e.response?.statusCode;
        _lastResponseHeaders = e.response?.headers.map;
      } else {
        _lastResponseStatusCode = null;
        _lastResponseData = null;
        _lastResponseHeaders = null;
      }
      // 错误轮也可能已产生计费 usage：先产出计量事件再上抛
      if (localUsage != null && localUsage!.isNotEmpty) {
        yield AIStreamEvent('', usage: localUsage);
      }
      rethrow;
    }

    // 流结束后：产出 usage 计量（per-request 隔离）
    if (localUsage != null && localUsage!.isNotEmpty) {
      yield AIStreamEvent('', usage: localUsage);
    }

    // 流结束后：产出 thinking 签名（供下一轮链重建续接 extended thinking）
    if (acc.thinkingSignatures.isNotEmpty) {
      yield AIStreamEvent('', thinkingSignature: acc.thinkingSignatures.last);
    }

    // 流结束后：仅在 stop_reason 为 tool_use 时产出工具调用
    final toolEvent = buildToolCallEvent(acc);
    if (toolEvent != null) {
      yield toolEvent;
    }
  }
}
