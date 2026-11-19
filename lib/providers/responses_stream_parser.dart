import '../models/ai_stream_event.dart';

/// Removes binary image payloads from response snapshots that may be persisted
/// with conversation diagnostics. Image events keep their original bytes for
/// attachment storage and rendering.
Map<String, dynamic> sanitizeResponsesDiagnosticData(
  Map<String, dynamic> responseData,
) =>
    Map<String, dynamic>.from(_sanitizeDiagnosticValue(responseData) as Map);

dynamic _sanitizeDiagnosticValue(dynamic value) {
  if (value is List) {
    return value.map(_sanitizeDiagnosticValue).toList();
  }
  if (value is Map) {
    final type = value['type'];
    return {
      for (final entry in value.entries)
        entry.key: _isImagePayloadField(type, entry.key, entry.value)
            ? '[image data stored as attachment]'
            : _sanitizeDiagnosticValue(entry.value),
    };
  }
  return value;
}

bool _isImagePayloadField(dynamic type, dynamic key, dynamic value) {
  if (key == 'partial_image_b64') return true;
  if (type == 'image_generation_call' && key == 'result') return true;
  if ((type == 'image' || type == 'output_image') && key == 'data') return true;
  if ((key == 'image_url' || key == 'result') &&
      value is String &&
      value.startsWith('data:image/')) {
    return true;
  }
  return false;
}

/// Accumulated state for the Responses SSE item/delta event protocol.
class ResponsesStreamAccumulator {
  final Map<int, Map<String, dynamic>> functionCalls = {};
  final Map<int, StringBuffer> argumentBuffers = {};
  final Set<String> emittedImageItems = {};
  final Set<String> emittedUnsupportedItems = {};
}

/// Parses one Responses SSE event. The returned events are safe to consume
/// incrementally; function calls are finalized from item/done or completed.
List<AIStreamEvent> processResponsesStreamData(
  Map<String, dynamic> data,
  ResponsesStreamAccumulator acc,
) {
  final events = <AIStreamEvent>[];
  final type = data['type'] as String?;
  switch (type) {
    case 'response.output_text.delta':
    case 'response.refusal.delta':
    case 'response.reasoning_summary_text.delta':
    case 'response.reasoning_text.delta':
      final text = data['delta'] as String?;
      if (text != null && text.isNotEmpty) {
        final isReasoning = type == 'response.reasoning_summary_text.delta' ||
            type == 'response.reasoning_text.delta';
        events.add(AIStreamEvent(text, isReasoning: isReasoning));
      }

    case 'response.function_call_arguments.delta':
      final index = data['output_index'] as int? ?? 0;
      final delta = data['delta'] as String?;
      if (delta != null && delta.isNotEmpty) {
        acc.argumentBuffers.putIfAbsent(index, StringBuffer.new).write(delta);
      }

    case 'response.function_call_arguments.done':
      final index = data['output_index'] as int? ?? 0;
      final arguments = data['arguments'] as String?;
      if (arguments != null) {
        acc.argumentBuffers[index] = StringBuffer(arguments);
      }

    case 'response.output_item.added':
    case 'response.output_item.done':
      final item = data['item'];
      if (item is Map) {
        _recordOutputItem(
          Map<String, dynamic>.from(item),
          data['output_index'] as int? ?? 0,
          acc,
          events,
          includeReasoning: false,
        );
      }

    case 'response.completed':
    case 'response.incomplete':
      final response = data['response'];
      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        final usage = normalizeResponsesUsage(responseMap['usage']);
        if (usage != null) events.add(AIStreamEvent('', usage: usage));
        final output = responseMap['output'];
        if (output is List) {
          for (var i = 0; i < output.length; i++) {
            final item = output[i];
            if (item is Map) {
              _recordOutputItem(
                Map<String, dynamic>.from(item),
                i,
                acc,
                events,
                includeReasoning: false,
              );
            }
          }
        }
      }

    case 'error':
    case 'response.failed':
      final error = data['error'] ??
          (data['response'] is Map ? (data['response'] as Map)['error'] : null);
      final details = error is Map ? error['message'] ?? error['code'] : error;
      throw Exception('Responses API error: ${details ?? data}');
  }
  if (type?.startsWith('response.audio.') == true &&
      acc.emittedUnsupportedItems.add('event:$type')) {
    events.add(AIStreamEvent('[Responses 输出类型暂不支持: $type]'));
  }
  return events;
}

/// Converts a completed non-streaming Responses object into the same events
/// emitted by the SSE parser, including images and function calls.
List<AIStreamEvent> parseResponsesOutput(Map<String, dynamic> response) {
  final acc = ResponsesStreamAccumulator();
  final events = <AIStreamEvent>[];
  final usage = normalizeResponsesUsage(response['usage']);
  if (usage != null) events.add(AIStreamEvent('', usage: usage));
  final output = response['output'];
  if (output is List) {
    for (var i = 0; i < output.length; i++) {
      final item = output[i];
      if (item is Map) {
        _recordOutputItem(Map<String, dynamic>.from(item), i, acc, events);
      }
    }
  }
  final calls = buildResponsesToolCallEvent(acc);
  if (calls != null) events.add(calls);
  return events;
}

AIStreamEvent? buildResponsesToolCallEvent(ResponsesStreamAccumulator acc) {
  if (acc.functionCalls.isEmpty) return null;
  final calls = acc.functionCalls.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return AIStreamEvent(
    '',
    toolCalls: [
      for (final entry in calls)
        {
          'id': entry.value['call_id'] as String? ??
              entry.value['id'] as String? ??
              'call_${entry.key}',
          'type': 'function',
          'function': {
            'name': entry.value['name'] as String? ?? 'unknown',
            'arguments': acc.argumentBuffers[entry.key]?.toString() ??
                entry.value['arguments'] as String? ??
                '{}',
          },
        },
    ],
  );
}

void _recordOutputItem(
  Map<String, dynamic> item,
  int index,
  ResponsesStreamAccumulator acc,
  List<AIStreamEvent> events, {
  bool includeReasoning = true,
}) {
  final type = item['type'] as String?;
  if (type == 'function_call') {
    acc.functionCalls[index] = Map<String, dynamic>.from(item);
    final arguments = item['arguments'] as String?;
    if (arguments != null && arguments.isNotEmpty) {
      acc.argumentBuffers[index] = StringBuffer(arguments);
    }
  } else if (type == 'image_generation_call') {
    final result = item['result'];
    if (result is String &&
        result.isNotEmpty &&
        acc.emittedImageItems.add('output:$index')) {
      final dataUri = RegExp(
        r'^data:([^;,]+);base64,(.*)$',
        dotAll: true,
      ).firstMatch(result);
      final outputFormat = item['output_format'] as String?;
      final outputMime = item['mime_type'] as String? ??
          switch (outputFormat?.toLowerCase()) {
            'jpeg' || 'jpg' => 'image/jpeg',
            'webp' => 'image/webp',
            _ => 'image/png',
          };
      events.add(
        AIStreamEvent(
          '',
          images: [
            AIStreamImage(
              mimeType: dataUri?.group(1) ?? outputMime,
              base64Data: dataUri?.group(2) ?? result,
            ),
          ],
        ),
      );
    }
  } else if (type == 'reasoning') {
    if (includeReasoning) {
      final summary = item['summary'];
      if (summary is List) {
        final text = summary
            .whereType<Map>()
            .where((part) => part['type'] == 'summary_text')
            .map((part) => part['text'])
            .whereType<String>()
            .join();
        if (text.isNotEmpty) {
          events.add(AIStreamEvent(text, isReasoning: true));
        }
      }
    }
  } else if (type == 'message') {
    final content = item['content'];
    if (content is List) {
      for (var partIndex = 0; partIndex < content.length; partIndex++) {
        final part = content[partIndex];
        if (part is! Map) continue;
        final type = part['type'];
        if (type == 'output_text') {
          // In completed response events the streamed delta already delivered
          // this text. Non-stream parsing handles it separately below.
          continue;
        }
        if (type == 'image' || type == 'output_image') {
          final image = part['result'] ?? part['image_url'];
          if (image is String &&
              image.isNotEmpty &&
              acc.emittedImageItems.add('output:$index:content:$partIndex')) {
            final dataUri = RegExp(
              r'^data:([^;,]+);base64,(.*)$',
              dotAll: true,
            ).firstMatch(image);
            if (dataUri != null) {
              events.add(
                AIStreamEvent(
                  '',
                  images: [
                    AIStreamImage(
                      mimeType: dataUri.group(1) ?? 'image/png',
                      base64Data: dataUri.group(2) ?? '',
                    ),
                  ],
                ),
              );
            }
          }
        } else if (type is String &&
            type != 'output_text' &&
            type != 'refusal' &&
            acc.emittedUnsupportedItems
                .add('output:$index:content:$partIndex')) {
          events.add(AIStreamEvent('[Responses 输出类型暂不支持: $type]'));
        }
      }
    }
  } else if (type != null && acc.emittedUnsupportedItems.add('output:$index')) {
    events.add(AIStreamEvent('[Responses 输出类型暂不支持: $type]'));
  }
}

Map<String, dynamic>? normalizeResponsesUsage(dynamic value) {
  if (value is! Map) return null;
  final input = _number(value['input_tokens']);
  final output = _number(value['output_tokens']);
  final result = <String, dynamic>{};
  if (input != null) result['inputTokens'] = input.toInt();
  if (output != null) result['outputTokens'] = output.toInt();
  final inputDetails = value['input_tokens_details'];
  final outputDetails = value['output_tokens_details'];
  if (inputDetails is Map && _number(inputDetails['cached_tokens']) != null) {
    result['cachedInputTokens'] =
        _number(inputDetails['cached_tokens'])!.toInt();
  }
  if (outputDetails is Map &&
      _number(outputDetails['reasoning_tokens']) != null) {
    result['reasoningTokens'] =
        _number(outputDetails['reasoning_tokens'])!.toInt();
  }
  final cost = _number(value['total_cost']) ?? _number(value['cost']);
  if (cost != null && cost.isFinite) result['cost'] = cost.toDouble();
  return result.isEmpty ? null : result;
}

num? _number(dynamic value) {
  final parsed = value is num
      ? value
      : value is String
          ? num.tryParse(value)
          : null;
  return parsed != null && parsed.isFinite ? parsed : null;
}

/// Extracts user-visible text from a complete Responses object.
String responsesText(Map<String, dynamic> response) {
  final text = StringBuffer();
  final output = response['output'];
  if (output is List) {
    for (final item in output) {
      if (item is! Map || item['type'] != 'message') continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is Map) {
          final type = part['type'];
          if (type == 'output_text' && part['text'] is String) {
            text.write(part['text']);
          } else if (type == 'refusal' && part['refusal'] is String) {
            text.write(part['refusal']);
          }
        }
      }
    }
  }
  return text.toString();
}
