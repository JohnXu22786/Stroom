import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  test(
      'new assistant snapshots save canonical content even before finalization',
      () {
    final partial =
        ChatMessage(role: 'assistant', content: '部分回复', reasoningContent: '推理');
    expect(partial.toMap()['blocks'], [
      {'type': 'reasoning', 'text': '推理', 'isComplete': true},
      {'type': 'text', 'text': '部分回复'},
    ]);
    final emptySections = ChatMessage(
        role: 'assistant',
        content: 'reply',
        reasoningContent: 'legacy thought',
        reasoningSections: []);
    expect(
        (emptySections.blocks!.first as ReasoningBlock).text, 'legacy thought');
    final emptySlot = ChatMessage(
        role: 'assistant',
        content: 'reply',
        reasoningContent: 'legacy thought',
        reasoningSections: ['']);
    expect((emptySlot.blocks!.first as ReasoningBlock).text, '');
    final toolsOnly = ChatMessage(role: 'assistant', content: '', toolCalls: [
      ToolCallData(
          id: 't', name: 'read', arguments: {}, status: ToolCallStatus.running),
    ]);
    expect(toolsOnly.blocks!.single, isA<ToolCallBlock>());
    final canonical = ChatMessage(role: 'assistant', content: '', blocks: [
      const ReasoningBlock(text: '', isComplete: false),
      const ErrorBlock(message: '停止'),
    ]);
    expect(canonical.toMap()['blocks'], [
      {'type': 'reasoning', 'text': '', 'isComplete': false},
      {'type': 'error', 'message': '停止'},
    ]);
  });
}
