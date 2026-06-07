import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/message_segment.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  group('TextSegment', () {
    test('creates with text', () {
      final seg = TextSegment('Hello');
      expect(seg.text, 'Hello');
    });

    test('is MessageSegment', () {
      final seg = TextSegment('Test');
      expect(seg, isA<MessageSegment>());
    });
  });

  group('ToolCallSegment', () {
    test('creates with ToolCallData', () {
      final tc = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '1+1'},
        status: ToolCallStatus.running,
      );
      final seg = ToolCallSegment(tc);
      expect(seg.data.id, 'call_1');
      expect(seg.data.name, 'calculator');
      expect(seg.data.status, ToolCallStatus.running);
    });

    test('is MessageSegment', () {
      final tc = ToolCallData(
        id: 'call_2',
        name: 'test',
        arguments: {},
        status: ToolCallStatus.completed,
        result: '42',
      );
      final seg = ToolCallSegment(tc);
      expect(seg, isA<MessageSegment>());
    });
  });

  group('SearchMatch', () {
    test('creates with messageId and positions', () {
      final match = SearchMatch('msg_1', 5, 10);
      expect(match.messageId, 'msg_1');
      expect(match.matchStart, 5);
      expect(match.matchEnd, 10);
    });
  });
}
