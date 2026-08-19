import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  group('MessageBlock model', () {
    test('TextBlock toMap/fromMap round-trip', () {
      final j = TextBlock(text: 'x').toMap();
      final r = MessageBlock.fromMap(j);
      expect(r, isA<TextBlock>());
      expect((r as TextBlock).text, 'x');
    });

    test('ReasoningBlock toMap/fromMap round-trip', () {
      final j = ReasoningBlock(text: 'think', isComplete: true).toMap();
      final r = MessageBlock.fromMap(j);
      expect(r, isA<ReasoningBlock>());
      expect((r as ReasoningBlock).text, 'think');
      expect(r.isComplete, true);
    });

    test('ReasoningBlock.append', () {
      final b = ReasoningBlock(text: 'a').append('b', isComplete: true);
      expect(b.text, 'ab');
      expect(b.isComplete, true);
    });

    test('ToolCallBlock toMap/fromMap round-trip', () {
      final b = ToolCallBlock(
        id: 'c1',
        name: 'search',
        arguments: {'q': 'x'},
        status: ToolCallStatus.completed,
        result: 'ok',
      );
      final j = b.toMap();
      final r = MessageBlock.fromMap(j);
      expect(r, isA<ToolCallBlock>());
      final t = r as ToolCallBlock;
      expect(t.id, 'c1');
      expect(t.name, 'search');
      expect(t.arguments, {'q': 'x'});
      expect(t.status, ToolCallStatus.completed);
      expect(t.result, 'ok');
    });

    test('ToolCallBlock missing status defaults to pending', () {
      final j = {'type': 'tool_call', 'id': 'c1', 'name': 'n', 'arguments': {}};
      expect((MessageBlock.fromMap(j) as ToolCallBlock).status,
          ToolCallStatus.pending);
    });

    test('ErrorBlock toMap/fromMap round-trip', () {
      final j = ErrorBlock(message: 'fail').toMap();
      final r = MessageBlock.fromMap(j);
      expect(r, isA<ErrorBlock>());
      expect((r as ErrorBlock).message, 'fail');
    });

    test('unknown type produces ErrorBlock', () {
      final r = MessageBlock.fromMap({'type': 'unknown', 'msg': 'x'});
      expect(r, isA<ErrorBlock>());
      expect((r as ErrorBlock).message, contains('unknown'));
    });

    test('list of mixed blocks round-trip via JSON', () {
      final blocks = <MessageBlock>[
        ReasoningBlock(text: 'think'),
        ToolCallBlock(
            id: 'c1',
            name: 's',
            arguments: {},
            status: ToolCallStatus.completed,
            result: 'ok'),
        TextBlock(text: 'answer'),
      ];
      final json = jsonEncode(blocks.map((b) => b.toMap()).toList());
      final restored = MessageBlock.fromJsonList(jsonDecode(json));
      expect(restored.length, 3);
      expect(restored[0], isA<ReasoningBlock>());
      expect(restored[1], isA<ToolCallBlock>());
      expect(restored[2], isA<TextBlock>());
    });

    test('empty list round-trip', () {
      expect(MessageBlock.fromJsonList([]), isEmpty);
    });
  });
}
