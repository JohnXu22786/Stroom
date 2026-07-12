import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/pages/chat/chat_types.dart';

void main() {
  group('Reasoning sections initialization', () {
    test('streamingReasoningSectionsProvider starts as empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sections = container.read(streamingReasoningSectionsProvider);
      expect(sections, isEmpty, reason: '推理章节应在无推理内容时初始化为空列表，而非[""]');
    });

    test('streamingReasoningProvider starts as empty string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reasoning = container.read(streamingReasoningProvider);
      expect(reasoning, isEmpty);
    });

    test('isStreamingProvider starts as false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isStreaming = container.read(isStreamingProvider);
      expect(isStreaming, isFalse);
    });

    test('can add reasoning section to empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate the start of reasoning: first section
      container.read(streamingReasoningSectionsProvider.notifier).state = [];

      // Add reasoning content - this simulates ReasoningEvent handler logic
      final sections = [...container.read(streamingReasoningSectionsProvider)];
      if (sections.isEmpty) {
        sections.add('First reasoning text');
      } else {
        sections[sections.length - 1] = 'First reasoning text';
      }
      container.read(streamingReasoningSectionsProvider.notifier).state =
          sections;

      expect(container.read(streamingReasoningSectionsProvider).length, 1);
      expect(
        container.read(streamingReasoningSectionsProvider).first,
        'First reasoning text',
      );

      // Simulate ReasoningSectionEndEvent - add new empty section
      final sections2 = [...container.read(streamingReasoningSectionsProvider)];
      sections2.add('');
      container.read(streamingReasoningSectionsProvider.notifier).state =
          sections2;

      expect(container.read(streamingReasoningSectionsProvider).length, 2);

      // Fill second section (simulating second round of reasoning)
      final sections3 = [...container.read(streamingReasoningSectionsProvider)];
      sections3[sections3.length - 1] = 'Second reasoning text';
      container.read(streamingReasoningSectionsProvider.notifier).state =
          sections3;

      expect(
        container.read(streamingReasoningSectionsProvider).last,
        'Second reasoning text',
      );
    });

    test('sectioned reasoning works with empty sections (no reasoning content)',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate streaming start with no reasoning content yet
      container.read(streamingReasoningSectionsProvider.notifier).state = [];
      container.read(streamingReasoningProvider.notifier).state = '';

      // Simulate finalization when no reasoning was received
      final reasoningBuffer = '';
      var finalSections = [
        ...container.read(streamingReasoningSectionsProvider),
      ];
      if (finalSections.isNotEmpty) {
        finalSections[finalSections.length - 1] = reasoningBuffer;
      } else {
        // Don't add empty section - reasoningBuffer is empty
        // Keep sections empty so no button is shown
      }
      container.read(streamingReasoningSectionsProvider.notifier).state =
          finalSections;

      expect(container.read(streamingReasoningSectionsProvider), isEmpty,
          reason: '无推理内容时章节列表应为空，避免显示空按钮');
    });

    test('streamingReasoningSectionsProvider can be updated with new content',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(streamingReasoningSectionsProvider.notifier).state = [
        'test reasoning',
      ];

      expect(container.read(streamingReasoningSectionsProvider).length, 1);
      expect(container.read(streamingReasoningSectionsProvider).first,
          'test reasoning');
    });
  });

  group('Streaming providers lifecycle', () {
    test('streaming providers reset correctly for new session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate old session state
      container.read(streamingReasoningSectionsProvider.notifier).state = [
        'old reasoning',
        'more reasoning',
      ];
      container.read(streamingReasoningProvider.notifier).state = 'old buffer';
      container.read(streamingMsgIdProvider.notifier).state = 'old-msg-id';
      container.read(streamingFullReplyProvider.notifier).state = 'old content';

      // Reset for new session
      container.read(streamingReasoningSectionsProvider.notifier).state = [];
      container.read(streamingReasoningProvider.notifier).state = '';
      container.read(streamingMsgIdProvider.notifier).state = 'new-msg-id';
      container.read(streamingFullReplyProvider.notifier).state = '';

      expect(container.read(streamingReasoningSectionsProvider), isEmpty);
      expect(container.read(streamingReasoningProvider), isEmpty);
      expect(container.read(streamingMsgIdProvider), 'new-msg-id');
      expect(container.read(streamingFullReplyProvider), isEmpty);
    });
  });
}
