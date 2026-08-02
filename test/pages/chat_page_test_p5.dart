part of 'chat_page_test.dart';

void chatPageGroup5() {
  // ─────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────
  // From chat_page_reasoning_init_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('Reasoning sections initialization', () {
    test('streamingReasoningSectionsProvider starts as empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sections =
          container.read(streamingReasoningSectionsProvider('test-conv-id'));
      expect(sections, isEmpty, reason: '推理章节应在无推理内容时初始化为空列表，而非[""]');
    });

    test('streamingReasoningProvider starts as empty string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reasoning =
          container.read(streamingReasoningProvider('test-conv-id'));
      expect(reasoning, isEmpty);
    });

    test('isStreamingProvider starts as false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isStreaming = container.read(isStreamingProvider('test-conv-id'));
      expect(isStreaming, isFalse);
    });

    test('can add reasoning section to empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate the start of reasoning: first section
      container
          .read(streamingReasoningSectionsProvider('test-conv-id').notifier)
          .state = [];

      // Add reasoning content - this simulates ReasoningEvent handler logic
      final sections = [
        ...container.read(streamingReasoningSectionsProvider('test-conv-id'))
      ];
      if (sections.isEmpty) {
        sections.add('First reasoning text');
      } else {
        sections[sections.length - 1] = 'First reasoning text';
      }
      container
          .read(streamingReasoningSectionsProvider('test-conv-id').notifier)
          .state = sections;

      expect(
          container
              .read(streamingReasoningSectionsProvider('test-conv-id'))
              .length,
          1);
      expect(
        container
            .read(streamingReasoningSectionsProvider('test-conv-id'))
            .first,
        'First reasoning text',
      );

      // Simulate ReasoningSectionEndEvent - add new empty section
      final sections2 = [
        ...container.read(streamingReasoningSectionsProvider('test-conv-id'))
      ];
      sections2.add('');
      container
          .read(streamingReasoningSectionsProvider('test-conv-id').notifier)
          .state = sections2;

      expect(
          container
              .read(streamingReasoningSectionsProvider('test-conv-id'))
              .length,
          2);

      // Fill second section (simulating second round of reasoning)
      final sections3 = [
        ...container.read(streamingReasoningSectionsProvider('test-conv-id'))
      ];
      sections3[sections3.length - 1] = 'Second reasoning text';
      container
          .read(streamingReasoningSectionsProvider('test-conv-id').notifier)
          .state = sections3;

      expect(
        container.read(streamingReasoningSectionsProvider('test-conv-id')).last,
        'Second reasoning text',
      );
    });

    test('sectioned reasoning works with empty sections (no reasoning content)',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate streaming start with no reasoning content yet
      container
          .read(streamingReasoningSectionsProvider('test-conv-id').notifier)
          .state = [];
      container
          .read(streamingReasoningProvider('test-conv-id').notifier)
          .state = '';

      // Simulate finalization when no reasoning was received
      final reasoningBuffer = '';
      var finalSections = [
        ...container.read(streamingReasoningSectionsProvider('test-conv-id')),
      ];
      if (finalSections.isNotEmpty) {
        finalSections[finalSections.length - 1] = reasoningBuffer;
      } else {
        // Don't add empty section - reasoningBuffer is empty
        // Keep sections empty so no button is shown
      }
      container
          .read(streamingReasoningSectionsProvider('test-conv-id').notifier)
          .state = finalSections;

      expect(container.read(streamingReasoningSectionsProvider('test-conv-id')),
          isEmpty,
          reason: '无推理内容时章节列表应为空，避免显示空按钮');
    });

    test('streamingReasoningSectionsProvider can be updated with new content',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(streamingReasoningSectionsProvider('test-conv-id').notifier)
          .state = [
        'test reasoning',
      ];

      expect(
          container
              .read(streamingReasoningSectionsProvider('test-conv-id'))
              .length,
          1);
      expect(
          container
              .read(streamingReasoningSectionsProvider('test-conv-id'))
              .first,
          'test reasoning');
    });
  });

  group('Streaming providers lifecycle', () {
    test('streaming providers reset correctly for new session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate old session state
      container
          .read(streamingReasoningSectionsProvider('test-conv-id').notifier)
          .state = [
        'old reasoning',
        'more reasoning',
      ];
      container
          .read(streamingReasoningProvider('test-conv-id').notifier)
          .state = 'old buffer';
      container.read(streamingMsgIdProvider('test-conv-id').notifier).state =
          'old-msg-id';
      container
          .read(streamingFullReplyProvider('test-conv-id').notifier)
          .state = 'old content';

      // Reset for new session
      container
          .read(streamingReasoningSectionsProvider('test-conv-id').notifier)
          .state = [];
      container
          .read(streamingReasoningProvider('test-conv-id').notifier)
          .state = '';
      container.read(streamingMsgIdProvider('test-conv-id').notifier).state =
          'new-msg-id';
      container
          .read(streamingFullReplyProvider('test-conv-id').notifier)
          .state = '';

      expect(container.read(streamingReasoningSectionsProvider('test-conv-id')),
          isEmpty);
      expect(
          container.read(streamingReasoningProvider('test-conv-id')), isEmpty);
      expect(
          container.read(streamingMsgIdProvider('test-conv-id')), 'new-msg-id');
      expect(
          container.read(streamingFullReplyProvider('test-conv-id')), isEmpty);
    });
  });
}
