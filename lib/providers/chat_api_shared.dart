import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
@visibleForTesting
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
    String reasoningEffort = 'medium',
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
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
  });

  Map<String, dynamic> get defaultParams;
}
