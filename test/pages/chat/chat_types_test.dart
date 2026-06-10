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
  });
}
