import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  group('ChatTypes', () {
    group('TextSegment', () {
      test('stores text correctly', () {
        final segment = TextSegment('Hello world');
        expect(segment.text, 'Hello world');
      });
    });

    group('ToolCallSegment', () {
      test('stores tool call data correctly', () {
        final data = ToolCallData(
          id: 'call_1',
          name: 'calculator',
          arguments: {'expression': '2 + 2'},
          status: ToolCallStatus.completed,
          result: '4',
        );
        final segment = ToolCallSegment(data);
        expect(segment.data.id, 'call_1');
        expect(segment.data.name, 'calculator');
        expect(segment.data.arguments['expression'], '2 + 2');
        expect(segment.data.status, ToolCallStatus.completed);
        expect(segment.data.result, '4');
      });
    });

    group('ReasoningSegment', () {
      test('stores sectionIndex and isStreaming=false correctly', () {
        final segment = ReasoningSegment(sectionIndex: 0, isStreaming: false);
        expect(segment.sectionIndex, 0);
        expect(segment.isStreaming, false);
      });

      test('stores isStreaming=true correctly', () {
        final segment = ReasoningSegment(sectionIndex: 1, isStreaming: true);
        expect(segment.sectionIndex, 1);
        expect(segment.isStreaming, true);
      });

      test('defaults isStreaming to false', () {
        final segment = ReasoningSegment(sectionIndex: 2);
        expect(segment.sectionIndex, 2);
        expect(segment.isStreaming, false);
      });
    });

    group('SearchMatch', () {
      test('stores search match data correctly', () {
        final match = SearchMatch('msg1', 5, 10);
        expect(match.messageId, 'msg1');
        expect(match.matchStart, 5);
        expect(match.matchEnd, 10);
      });
    });

    group('mergeConsecutiveTextSegments', () {
      test('merges multiple consecutive TextSegments into one', () {
        final segments = <MessageSegment>[
          TextSegment('Hello '),
          TextSegment('World'),
          TextSegment('!'),
        ];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged.length, 1);
        expect((merged.first as TextSegment).text, 'Hello World!');
      });

      test('keeps TextSegments separated by ToolCallSegment separate', () {
        final data = ToolCallData(
          id: 'call_1',
          name: 'test',
          arguments: {},
          status: ToolCallStatus.completed,
          result: 'ok',
        );
        final segments = <MessageSegment>[
          TextSegment('Before '),
          ToolCallSegment(data),
          TextSegment('After'),
        ];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged.length, 3);
        expect((merged[0] as TextSegment).text, 'Before ');
        expect(merged[1], isA<ToolCallSegment>());
        expect((merged[2] as TextSegment).text, 'After');
      });

      test('single TextSegment stays as-is', () {
        final segments = <MessageSegment>[
          TextSegment('Just me'),
        ];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged.length, 1);
        expect((merged.first as TextSegment).text, 'Just me');
      });

      test('empty list returns empty', () {
        final segments = <MessageSegment>[];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged, isEmpty);
      });

      test('merges multiple text blocks separated by tool calls', () {
        final data1 = ToolCallData(
          id: 'call_a',
          name: 'tool_a',
          arguments: {},
          status: ToolCallStatus.completed,
        );
        final data2 = ToolCallData(
          id: 'call_b',
          name: 'tool_b',
          arguments: {},
          status: ToolCallStatus.completed,
        );
        final segments = <MessageSegment>[
          TextSegment('A'),
          TextSegment('B'),
          ToolCallSegment(data1),
          TextSegment('C'),
          TextSegment('D'),
          ToolCallSegment(data2),
          TextSegment('E'),
        ];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged.length, 5);
        expect((merged[0] as TextSegment).text, 'AB');
        expect(merged[1], isA<ToolCallSegment>());
        expect((merged[2] as TextSegment).text, 'CD');
        expect(merged[3], isA<ToolCallSegment>());
        expect((merged[4] as TextSegment).text, 'E');
      });

      test('ReasoningSegment acts as a boundary between TextSegments', () {
        final segments = <MessageSegment>[
          TextSegment('Before '),
          ReasoningSegment(sectionIndex: 0, isStreaming: false),
          TextSegment('After'),
        ];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged.length, 3);
        expect((merged[0] as TextSegment).text, 'Before ');
        expect(merged[1], isA<ReasoningSegment>());
        expect((merged[1] as ReasoningSegment).sectionIndex, 0);
        expect((merged[2] as TextSegment).text, 'After');
      });

      test('multiple TextSegments before ReasoningSegment are merged', () {
        final segments = <MessageSegment>[
          TextSegment('Hello '),
          TextSegment('World'),
          ReasoningSegment(sectionIndex: 0),
          TextSegment('End'),
        ];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged.length, 3);
        expect((merged[0] as TextSegment).text, 'Hello World');
        expect(merged[1], isA<ReasoningSegment>());
        expect((merged[2] as TextSegment).text, 'End');
      });

      test(
          'mixed ReasoningSegment, ToolCallSegment, TextSegment are kept separate',
          () {
        final data = ToolCallData(
          id: 'call_1',
          name: 'search',
          arguments: {},
          status: ToolCallStatus.completed,
        );
        final segments = <MessageSegment>[
          TextSegment('Text1 '),
          TextSegment('Text1b'),
          ReasoningSegment(sectionIndex: 0, isStreaming: false),
          ToolCallSegment(data),
          TextSegment('Text2'),
          ReasoningSegment(sectionIndex: 1, isStreaming: false),
          TextSegment('Text3'),
        ];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged.length, 6);
        expect((merged[0] as TextSegment).text, 'Text1 Text1b');
        expect(merged[1], isA<ReasoningSegment>());
        expect(merged[2], isA<ToolCallSegment>());
        expect((merged[3] as TextSegment).text, 'Text2');
        expect(merged[4], isA<ReasoningSegment>());
        expect((merged[5] as TextSegment).text, 'Text3');
      });

      test('single ReasoningSegment with no TextSegments stays as-is', () {
        final segments = <MessageSegment>[
          ReasoningSegment(sectionIndex: 0, isStreaming: false),
        ];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged.length, 1);
        expect(merged[0], isA<ReasoningSegment>());
      });

      test(
          'ReasoningSegment between two TextSegment blocks after ToolCallSegment',
          () {
        final data = ToolCallData(
          id: 'call_a',
          name: 'tool_a',
          arguments: {},
          status: ToolCallStatus.completed,
        );
        final segments = <MessageSegment>[
          TextSegment('Round 1 text '),
          TextSegment('more'),
          ToolCallSegment(data),
          ReasoningSegment(sectionIndex: 0, isStreaming: false),
          TextSegment('Round 2 text'),
          TextSegment(' continues'),
        ];
        final merged = mergeConsecutiveTextSegments(segments);
        expect(merged.length, 4);
        expect((merged[0] as TextSegment).text, 'Round 1 text more');
        expect(merged[1], isA<ToolCallSegment>());
        expect(merged[2], isA<ReasoningSegment>());
        expect((merged[3] as TextSegment).text, 'Round 2 text continues');
      });
    });
  });
}
