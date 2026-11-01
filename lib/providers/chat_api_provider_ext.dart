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
    final body = <String, dynamic>{
      'model': model ?? defaultParams['model'],
      'messages': messages,
      'stream': stream,
    };
    if (maxTokens != null) body['max_tokens'] = maxTokens;
    if (temperature != null) body['temperature'] = temperature;
    if (tools?.isNotEmpty == true) body['tools'] = tools;
    if (extraParams != null) body.addAll(extraParams);
    if (_apiProtocol != 'openai.responses') return body;

    final normalizedMessages =
        body.remove('messages') as List<Map<String, dynamic>>;
    final instructions = <String>[];
    final input = <Map<String, dynamic>>[];
    for (final message in normalizedMessages) {
      final role = message['role'];
      if (role == 'system' || role == 'developer') {
        final text = message['content'];
        if (text is String && text.isNotEmpty) instructions.add(text);
        continue;
      }
      final toolCalls = message['tool_calls'];
      if (toolCalls is List) {
        for (final rawCall in toolCalls.whereType<Map>()) {
          final fn = rawCall['function'];
          if (fn is! Map) continue;
          input.add({
            'type': 'function_call',
            'call_id': rawCall['id'] ?? '',
            'name': fn['name'] ?? '',
            'arguments': fn['arguments'] ?? '{}',
          });
        }
      }
      if (role == 'tool') {
        input.add({
          'type': 'function_call_output',
          'call_id': message['tool_call_id'] ?? '',
          'output': message['content'] ?? '',
        });
        continue;
      }
      final content = message['content'];
      final parts = content is List
          ? content.whereType<Map>().map((part) {
              if (part['type'] == 'image_url') {
                final imageUrl = part['image_url'];
                final url = imageUrl is Map ? imageUrl['url'] : imageUrl;
                final imagePart = <String, dynamic>{
                  'type': role == 'assistant' ? 'output_image' : 'input_image',
                };
                if (url != null) imagePart['image_url'] = url;
                return imagePart;
              }
              return <String, dynamic>{
                'type': role == 'assistant' ? 'output_text' : 'input_text',
                'text': part['text'] ?? '',
              };
            }).toList()
          : [
              {
                'type': role == 'assistant' ? 'output_text' : 'input_text',
                'text': content ?? '',
              },
            ];
      if (parts.isNotEmpty && content != null) {
        input.add({'type': 'message', 'role': role, 'content': parts});
      }
    }
    final normalizedTools = body.remove('tools');
    final responsesBody = <String, dynamic>{
      'model': body.remove('model'),
      'input': input,
      'stream': stream,
      if (instructions.isNotEmpty) 'instructions': instructions.join('\n'),
      if (body.containsKey('max_tokens'))
        'max_output_tokens': body.remove('max_tokens'),
      ...body,
      if (normalizedTools is List)
        'tools': [
          for (final tool in normalizedTools.whereType<Map>())
            if (tool['function'] is Map)
              {
                'type': 'function',
                'name': (tool['function'] as Map)['name'],
                'description': (tool['function'] as Map)['description'],
                'parameters': (tool['function'] as Map)['parameters'],
                if ((tool['function'] as Map).containsKey('strict'))
                  'strict': (tool['function'] as Map)['strict'],
              },
        ],
    };
    return responsesBody;
  }

  String _responsesText(Map data) {
    final direct = data['output_text'];
    if (direct is String) return direct;
    final output = data['output'];
    if (output is List) {
      return output
          .whereType<Map>()
          .expand((item) {
            final content = item['content'];
            return content is List ? content.whereType<Map>() : const <Map>[];
          })
          .where((part) => part['type'] == 'output_text')
          .map((part) => part['text'])
          .whereType<String>()
          .join();
    }
    throw Exception('Responses API returned no output text');
  }

  List<AIStreamEvent> _responsesStreamEvents(
    Map<String, dynamic> data,
    Map<String, Map<String, dynamic>> calls,
  ) {
    final type = data['type'];
    if (type == 'response.output_text.delta') {
      final delta = data['delta'];
      return delta is String && delta.isNotEmpty ? [AIStreamEvent(delta)] : [];
    }
    if (type == 'response.reasoning_summary_text.delta') {
      final delta = data['delta'];
      return delta is String && delta.isNotEmpty
          ? [AIStreamEvent(delta, isReasoning: true)]
          : [];
    }
    if (type == 'response.output_item.added' ||
        type == 'response.output_item.done') {
      final item = data['item'];
      if (item is Map && item['type'] == 'function_call') {
        calls[item['id']?.toString() ?? item['call_id']?.toString() ?? ''] =
            Map<String, dynamic>.from(item);
      }
    }
    if (type == 'response.function_call_arguments.delta') {
      final id =
          data['item_id']?.toString() ?? data['call_id']?.toString() ?? '';
      final call = calls.putIfAbsent(id, () => {'id': id, 'arguments': ''});
      call['arguments'] = '${call['arguments'] ?? ''}${data['delta'] ?? ''}';
    }
    if (type == 'response.function_call_arguments.done') {
      final id =
          data['item_id']?.toString() ?? data['call_id']?.toString() ?? '';
      final call = calls.putIfAbsent(id, () => {'id': id});
      call['arguments'] = data['arguments'] ?? call['arguments'] ?? '{}';
    }
    if (type == 'response.completed') {
      final usage = OpenAICompatibleChatProvider.normalizeUsage(
        (data['response'] as Map?)?['usage'],
      );
      if (usage != null) return [AIStreamEvent('', usage: usage)];
    }
    if (type == 'response.failed' || type == 'error') {
      throw Exception(
          'Responses API stream error: ${data['response'] ?? data['error'] ?? data}');
    }
    return [];
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
