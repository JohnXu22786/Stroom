part of 'chat_api_provider.dart';

extension _OpenAICompatibleChatProviderExt on OpenAICompatibleChatProvider {
  /// Build the request body map.
  ///
  /// [messages] 已由 ChatService 预处理为 API 格式
  ///（OpenAI multimodal content array 或 plain string）。
  ///
  /// Exposed as [buildBody] for testing.
  Map<String, dynamic> _buildBody(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
  }) {
    return {
      'model': model ?? defaultParams['model'],
      'messages': messages,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
      'stream': stream,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (extraParams != null) ...extraParams,
    };
  }

  /// 非流式请求的 Dio 错误处理：填充诊断槽后抛出标准异常。
  Exception _handleChatDioError(DioException e) {
    _lastResponseStatusCode = e.response?.statusCode;
    _lastResponseHeaders = e.response?.headers.map;
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
    return Exception('API 请求失败 (HTTP $statusCode): $detail');
  }

  /// 流式请求错误时的诊断槽重置与填充：
  /// Dio 错误读取响应体（含 ResponseType.stream 时的 ResponseBody），
  /// 非 Dio 错误清空所有乐观设置的槽位。
  Future<void> _resetForStreamError(Object e) async {
    if (e is DioException) {
      // Clear stale streaming data from successful SSE events first.
      _lastResponseData = null;

      if (e.response?.data is Map) {
        _lastResponseData = Map<String, dynamic>.from(e.response!.data as Map);
      } else if (e.response?.data is String) {
        _lastResponseData = <String, dynamic>{
          'raw': e.response!.data as String
        };
      } else {
        // When ResponseType.stream is used, non-2xx error response data
        // is a ResponseBody (unread stream). Try to read it to capture
        // the error response body for diagnostic display.
        final streamBody = await parseStreamErrorBody(e);
        if (streamBody != null) {
          _lastResponseData = streamBody;
        }
      }
      // Preserve status code even when response body is unavailable.
      _lastResponseStatusCode = e.response?.statusCode;
      _lastResponseHeaders = e.response?.headers.map;
    } else {
      // Non-DioException errors (e.g., SSE stream parse failures):
      // Reset ALL optimistically-set or stale fields to avoid
      // reporting stale data from the last successful SSE chunk.
      // BUT: if _lastResponseData already holds an API error frame
      // (set before throwIfApiError threw), keep it — otherwise the
      // error body is lost from the diagnostics slot.
      if (_lastResponseData?['error'] == null) {
        _lastResponseData = null;
      }
      _lastResponseStatusCode = null;
      _lastResponseHeaders = null;
    }
  }

  /// 累计流式 tool_calls 增量（按 index 分块到达，跨 SSE 事件累积）。
  ///
  /// 与 `chatStream` 中的 toolCallAccumulators 状态配合使用。
  void _accumulateToolCallDeltas(
      Map<String, dynamic> data, Map<int, Map<String, dynamic>> accumulators) {
    // Tool call deltas (streamed in chunks by index) — handled here
    // because accumulation requires state across multiple SSE events.
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final delta = choices[0]['delta'] as Map<String, dynamic>?;
      if (delta != null) {
        final toolCallsDelta = delta['tool_calls'] as List?;
        if (toolCallsDelta != null) {
          for (final tc in toolCallsDelta) {
            // Use null-safe index with fallback to 0.
            // Per OpenAI streaming spec, index is always present,
            // but be defensive against providers that may omit it.
            final index = tc['index'] as int? ?? 0;
            accumulators.putIfAbsent(index, () => {});
            final acc = accumulators[index]!;

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
    }
  }

  /// 流结束时将累计的 tool_calls 组装为事件（若无累计则返回 null）。
  AIStreamEvent? _buildToolCallEvent(
      Map<int, Map<String, dynamic>> accumulators) {
    // After stream ends, yield tool calls if any were accumulated
    if (accumulators.isEmpty) return null;
    final toolCalls = accumulators.entries
        .map((e) => {
              'id': e.value['id'] as String? ?? 'call_${e.key}',
              'type': e.value['type'] as String? ?? 'function',
              'function': e.value['function'] as Map<String, dynamic>? ?? {},
            })
        .toList();
    return AIStreamEvent('', toolCalls: toolCalls);
  }
}
