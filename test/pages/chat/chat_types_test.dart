import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  group('ChatTypes', () {
    group('TextSegment', () {
      test('stores text correctly', () {
        final segment = TextSegment('Hello world');
        expect(segment.text, 'Hello world');
      });

      test('is a subtype of MessageSegment', () {
        final MessageSegment segment = TextSegment('test');
        expect(segment, isA<TextSegment>());
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

      test('is a subtype of MessageSegment', () {
        final data = ToolCallData(
          id: 'call_2',
          name: 'calculator',
          arguments: {'expression': '1 + 1'},
          status: ToolCallStatus.completed,
          result: '2',
        );
        final MessageSegment segment = ToolCallSegment(data);
        expect(segment, isA<ToolCallSegment>());
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

    group('SearchMode', () {
      test('has current and global values', () {
        expect(SearchMode.current, SearchMode.current);
        expect(SearchMode.global, SearchMode.global);
        expect(SearchMode.current, isNot(SearchMode.global));
      });
    });

    group('isStreamingProvider', () {
      test('starts as false', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(isStreamingProvider), false);
      });

      test('can be toggled to true', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(isStreamingProvider.notifier).state = true;
        expect(container.read(isStreamingProvider), true);
      });

      test('can be toggled back to false', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(isStreamingProvider.notifier).state = true;
        container.read(isStreamingProvider.notifier).state = false;
        expect(container.read(isStreamingProvider), false);
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
    });
  });
}
