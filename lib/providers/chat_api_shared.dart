import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/ai_stream_event.dart';

// ============================================================================
// OpenRouter-format app identification headers
// ============================================================================

/// HTTP-Referer header value identifying this application, following the
/// OpenRouter convention for app attribution on leaderboards.
const String kHttpReferer = 'https://github.com/JohnXu22786/Stroom';

/// X-Title header value identifying this application, following the
/// OpenRouter convention for app attribution on leaderboards.
///
/// Note: OpenRouter also supports `X-OpenRouter-Title` as the current
/// standard header name, but we keep `X-Title` for compatibility with
/// both OpenRouter and other providers.
const String kXTitle = 'Stroom';

/// Map of application identification headers following OpenRouter format.
/// These are added to all outgoing API requests to identify the app.
Map<String, String> get openRouterAppHeaders => {
      'HTTP-Referer': kHttpReferer,
      'X-Title': kXTitle,
    };

/// Attempts to parse the error response body from a streaming [DioException].
///
/// When [ResponseType.stream] is used (SSE streaming), a non-2xx response
/// from the server results in a [DioException] whose `response.data` is a
/// [ResponseBody] (an unread stream) rather than a [Map] or [String].
/// This function reads that stream and returns the body as a `{'raw': string}`
/// map, or `null` if the data is not a [ResponseBody].
///
/// Extracted as a top-level function for testability.
Future<Map<String, dynamic>?> parseStreamErrorBody(DioException e) async {
  if (e.response?.data is ResponseBody) {
    try {
      final responseBody = e.response!.data as ResponseBody;
      final bytes = await responseBody.stream.toList();
      final allBytes = <int>[];
      for (final chunk in bytes) {
        allBytes.addAll(chunk);
      }
      return <String, dynamic>{'raw': utf8.decode(allBytes)};
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// 把 API usage 里的数值字段转为 double。
///
/// 部分网关/兼容端点把 cost/token 数以**字符串**返回（如
/// `"total_cost": "0.0000123"`、`"prompt_tokens": "123"`）——只认 num
/// 会把这类"API 已返回的计费"静默丢弃，导致累计缺失。这里 num 与
/// 数字字符串统一接受；解析失败返回 null（不把垃圾值当计费）。
/// 非有限值（NaN/±Infinity，字符串解析可能产生）同样丢弃，避免
/// totalCost 被污染成 Infinity/NaN。
double? usageNumberToDouble(dynamic value) {
  double? result;
  if (value is num) {
    result = value.toDouble();
  } else if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    result = double.tryParse(trimmed);
  }
  if (result == null || !result.isFinite) return null;
  return result;
}

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

  /// 最近一次请求的实际 token 计量（来自 API 返回的 usage 字段）。
  ///
  /// 标准化形状：`{'inputTokens': int, 'outputTokens': int}`。
  /// 流式与非流式都会填充——作为**诊断快照**（与 [lastResponseData]
  /// 同语义：共享 provider 实例下并发请求可能互相覆盖，仅用于调试）。
  ///
  /// ⚠️ 生产计量请使用 [AIStreamEvent.usage]（事件驱动、per-request
  /// 隔离），不要依赖本槽。
  Map<String, dynamic>? get lastUsage => null;

  /// Dio default headers, exposed for testing.
  Map<String, dynamic> get defaultHeaders => {};

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
  });

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
  });

  Map<String, dynamic> get defaultParams;
}
