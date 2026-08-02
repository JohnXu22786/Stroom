part of 'anthropic_chat_provider.dart';

// ============================================================================
// Anthropic 流式 SSE 解析（纯函数，由 AnthropicChatProvider 与单测共用）
// ============================================================================

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
