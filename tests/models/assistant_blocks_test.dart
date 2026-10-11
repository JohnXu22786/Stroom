import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  test(
    'new assistant snapshots save canonical content even before finalization',
    () {
      final partial = ChatMessage(
        role: 'assistant',
        content: '部分回复',
        reasoningContent: '推理',
      );
      expect(partial.toMap()['blocks'], [
        {'type': 'reasoning', 'text': '推理', 'isComplete': true},
        {'type': 'text', 'text': '部分回复'},
      ]);
      final emptySections = ChatMessage(
        role: 'assistant',
        content: 'reply',
        reasoningContent: 'legacy thought',
        reasoningSections: [],
      );
      expect(
        (emptySections.blocks!.first as ReasoningBlock).text,
        'legacy thought',
      );
      final emptySlot = ChatMessage(
        role: 'assistant',
        content: 'reply',
        reasoningContent: 'legacy thought',
        reasoningSections: [''],
      );
      expect((emptySlot.blocks!.first as ReasoningBlock).text, '');
      final toolsOnly = ChatMessage(
        role: 'assistant',
        content: '',
        toolCalls: [
          ToolCallData(
            id: 't',
            name: 'read',
            arguments: {},
            status: ToolCallStatus.running,
          ),
        ],
      );
      expect(toolsOnly.blocks!.single, isA<ToolCallBlock>());
      final canonical = ChatMessage(
        role: 'assistant',
        content: '',
        blocks: [
          const ReasoningBlock(text: '', isComplete: false),
          const ErrorBlock(message: '停止'),
        ],
      );
      expect(canonical.toMap()['blocks'], [
        {'type': 'reasoning', 'text': '', 'isComplete': false},
        {'type': 'error', 'message': '停止'},
      ]);
    },
  );

  test('copyWith content updates the derived assistant text block', () {
    final original = ChatMessage(role: 'assistant', content: 'old reply');

    final updated = original.copyWith(content: 'new reply');

    expect(updated.content, 'new reply');
    expect(updated.blocks, hasLength(1));
    expect(updated.blocks!.single, isA<TextBlock>());
    expect((updated.blocks!.single as TextBlock).text, 'new reply');
  });

  test(
    'legacy assistant content without text sections follows its old order',
    () {
      final legacy = ChatMessage(
        role: 'assistant',
        content: 'legacy reply',
        toolCalls: [
          ToolCallData(
            id: 'tool-1',
            name: 'lookup',
            arguments: const {},
            status: ToolCallStatus.completed,
            result: 'done',
          ),
        ],
        toolCallRoundStarts: [0],
      );

      expect(legacy.blocks!.first, isA<ToolCallBlock>());
      expect(legacy.blocks!.last, isA<TextBlock>());
      expect((legacy.blocks!.last as TextBlock).text, 'legacy reply');
    },
  );

  test(
    'copyWith content refreshes text sections and preserves transcript steps',
    () {
      final original = ChatMessage(
        role: 'assistant',
        content: 'old reply',
        reasoningSections: ['thought'],
        textSections: ['old reply'],
        toolCalls: [
          ToolCallData(
            id: 'tool-1',
            name: 'lookup',
            arguments: const {},
            status: ToolCallStatus.completed,
            result: 'done',
          ),
        ],
        toolCallRoundStarts: [0],
      );

      final updated = original.copyWith(content: 'new reply');

      expect(updated.content, 'new reply');
      expect(updated.textSections, ['new reply']);
      expect(updated.blocks, hasLength(3));
      expect((updated.blocks![0] as ReasoningBlock).text, 'thought');
      expect((updated.blocks![1] as TextBlock).text, 'new reply');
      expect((updated.blocks![2] as ToolCallBlock).id, 'tool-1');
    },
  );
}
