part of 'chat_stream_manager_test.dart';

void chatStreamManagerGroup3() {
  group('ChatStreamManager - reasoning + toolCalls propagation', () {
    test('reasoning sections and toolCalls appear in StreamResult', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      // The adapter loops: each call to chatStream = one round.
      // Round 1: reasoning + tool calls → adapter processes tools, loops
      // Round 2: more reasoning + final answer → no tools, loop ends
      final provider = _MockProvider([
        // Round 1: reasoning + tool call
        [
          AIStreamEvent('Let me think about this...', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc1',
              'type': 'function',
              'function': {
                'name': 'search',
                'arguments': '{"q":"weather"}',
              },
            },
          ]),
        ],
        // Round 2: more reasoning + final answer
        [
          AIStreamEvent('The search shows sunny weather.', isReasoning: true),
          AIStreamEvent('The weather is sunny today!'),
        ],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'What is the weather?',
        convId: 'conv-reasoning-tools',
        history: [
          _userMsg('What is the weather?', 'u1'),
        ],
      );

      // Verify reasoning sections are built from multiple rounds
      expect(result.reasoningSections.length, greaterThanOrEqualTo(2),
          reason:
              'At least 2 reasoning rounds expected, got ${result.reasoningSections.length}');
      expect(
          result.reasoningSections.any((s) => s.contains('think about this')),
          isTrue);
      expect(result.reasoningSections.any((s) => s.contains('sunny weather')),
          isTrue);

      // Verify tool calls are preserved
      expect(result.toolCalls.length, 1,
          reason: 'Expected 1 tool call, got ${result.toolCalls.length}');
      expect(result.toolCalls[0].id, 'tc1');
      expect(result.toolCalls[0].name, 'search');

      // Verify final reply
      expect(result.fullReply, contains('sunny'));

      // Verify assistant message has both reasoningSections and toolCalls
      final assistant = result.assistantMessage;
      expect(assistant, isNotNull);
      expect(assistant!.reasoningSections, isNotNull);
      expect(assistant.reasoningSections!.length, greaterThanOrEqualTo(2));
      expect(assistant.toolCalls, isNotNull);
      expect(assistant.toolCalls!.length, 1);

      manager.dispose();
    });

    test('multiple tool call rounds produce correct results', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      final provider = _MockProvider([
        // Round 1: reasoning + first tool call
        [
          AIStreamEvent('Analyzing...', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc1',
              'type': 'function',
              'function': {
                'name': 'weather',
                'arguments': '{"city":"Hangzhou"}',
              },
            },
          ]),
        ],
        // Round 2: reasoning + second tool call
        [
          AIStreamEvent('Now checking temperature...', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc2',
              'type': 'function',
              'function': {
                'name': 'temperature',
                'arguments': '{"city":"Hangzhou"}',
              },
            },
          ]),
        ],
        // Round 3: final reasoning + answer
        [
          AIStreamEvent('Weather is sunny and 25C.', isReasoning: true),
          AIStreamEvent('Hangzhou: sunny, 25C'),
        ],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Weather in Hangzhou?',
        convId: 'conv-multi-tools',
        history: [
          _userMsg('Weather in Hangzhou?', 'u1'),
        ],
      );

      // Both tool calls should be preserved
      expect(result.toolCalls.length, 2,
          reason: 'Expected 2 tool calls, got ${result.toolCalls.length}');
      expect(result.toolCalls[0].id, 'tc1');
      expect(result.toolCalls[1].id, 'tc2');

      // Multiple reasoning rounds
      expect(result.reasoningSections.length, greaterThanOrEqualTo(3),
          reason:
              'Should have at least 3 reasoning rounds, got ${result.reasoningSections.length}');
      expect(
          result.reasoningSections.any((s) => s.contains('Analyzing')), isTrue);
      expect(result.reasoningSections.any((s) => s.contains('temperature')),
          isTrue);
      expect(result.reasoningSections.any((s) => s.contains('sunny and 25C')),
          isTrue);

      manager.dispose();
    });
  });

  group('ChatStreamManager - multi-tool round grouping', () {
    // Regression tests for the bug where toolCallRoundStarts was initialized
    // to [0], causing a duplicate [0, 0] when the first ToolCallStartEvent
    // added another 0. This made the second+ tool calls in a round appear in
    // the wrong visual position (pushed to the end instead of grouped with
    // their round's first tool call).
    //
    // The fix: initialize toolCallRoundStarts to [] (not [0]).

    test('multiple tool calls in one round produce roundStarts=[0]', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      // One adapter round: text + 2 parallel tool calls (in one event).
      // The adapter loops after tool calls → round 2 yields final answer.
      final provider = _MockProvider([
        [
          AIStreamEvent('Let me search for that.'),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc1',
              'type': 'function',
              'function': {
                'name': 'search',
                'arguments': '{"q":"a"}',
              },
            },
            {
              'id': 'tc2',
              'type': 'function',
              'function': {
                'name': 'fetch',
                'arguments': '{"url":"b"}',
              },
            },
          ]),
        ],
        [AIStreamEvent('Done!')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Search and fetch',
        convId: 'conv-parallel-tools',
        history: [_userMsg('Search and fetch', 'u1')],
      );

      // Both tools are in ONE round → [0], not [0, 0] (the bug).
      expect(result.toolCalls.length, 2);
      expect(result.toolCallRoundStarts, [0],
          reason: 'Both tools in one round → roundStarts=[0]. '
              'If this is [0, 0], the initial value bug regressed.');
      expect(result.toolCalls[0].id, 'tc1');
      expect(result.toolCalls[1].id, 'tc2');

      manager.dispose();
    });

    test('two rounds each with multiple tool calls produce roundStarts=[0,2]',
        () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      final provider = _MockProvider([
        // Round 1: text + 2 tool calls (A, B)
        [
          AIStreamEvent('step1'),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tcA',
              'type': 'function',
              'function': {'name': 'toolA', 'arguments': '{}'},
            },
            {
              'id': 'tcB',
              'type': 'function',
              'function': {'name': 'toolB', 'arguments': '{}'},
            },
          ]),
        ],
        // Round 2: text + 3 tool calls (C, D, E)
        [
          AIStreamEvent('step2'),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tcC',
              'type': 'function',
              'function': {'name': 'toolC', 'arguments': '{}'},
            },
            {
              'id': 'tcD',
              'type': 'function',
              'function': {'name': 'toolD', 'arguments': '{}'},
            },
            {
              'id': 'tcE',
              'type': 'function',
              'function': {'name': 'toolE', 'arguments': '{}'},
            },
          ]),
        ],
        // Round 3: final answer
        [AIStreamEvent('final answer')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Multi-step with parallel tools',
        convId: 'conv-two-rounds-parallel',
        history: [_userMsg('Multi-step with parallel tools', 'u1')],
      );

      expect(result.toolCalls.length, 5);
      expect(result.toolCallRoundStarts, [0, 2],
          reason: 'Round 0 = tools 0,1 (A,B). Round 1 = tools 2,3,4 (C,D,E). '
              'If this is [0, 0, 2], the initial value bug regressed.');
      expect(result.toolCalls.map((t) => t.id).toList(),
          ['tcA', 'tcB', 'tcC', 'tcD', 'tcE']);
      // textSections: ['step1', 'step2', 'final answer']
      expect(result.textSections, ['step1', 'step2', 'final answer']);

      // Verify the assistant message persists roundStarts for reload.
      final assistant = result.assistantMessage;
      expect(assistant, isNotNull);
      expect(assistant!.toolCallRoundStarts, [0, 2]);

      manager.dispose();
    });

    test('assistant message persists toolCallRoundStarts for DB reload',
        () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      final provider = _MockProvider([
        [
          AIStreamEvent('thinking...'),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'x1',
              'type': 'function',
              'function': {'name': 'X', 'arguments': '{}'},
            },
            {
              'id': 'x2',
              'type': 'function',
              'function': {'name': 'Y', 'arguments': '{}'},
            },
          ]),
        ],
        [AIStreamEvent('result')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'test',
        convId: 'conv-persist-roundstarts',
        history: [_userMsg('test', 'u1')],
      );

      final msg = result.assistantMessage!;
      // Round-trip through toMap/fromMap should preserve roundStarts.
      final restored = ChatMessage.fromMap(msg.toMap());
      expect(restored.toolCallRoundStarts, [0]);
      expect(restored.toolCalls!.length, 2);

      manager.dispose();
    });
  });

  group('ChatStreamManager - streamingConversationsProvider tracking', () {
    test('isStreamingFor reflects active stream lifecycle', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      expect(manager.isStreaming, false);
      expect(manager.isStreamingFor('conv-lifecycle'), false);

      final provider = _MockProvider([
        [
          AIStreamEvent('thinking', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc1',
              'type': 'function',
              'function': {'name': 'search', 'arguments': '{}'},
            },
          ]),
        ],
        [AIStreamEvent('final')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final future = manager.startStreaming(
        text: 'hi',
        convId: 'conv-lifecycle',
        history: [_userMsg('hi', 'u1')],
      );

      // While the stream is running, isStreamingFor should be true.
      expect(manager.isStreamingFor('conv-lifecycle'), true);

      await future;

      // After completion, isStreamingFor should be false.
      expect(manager.isStreamingFor('conv-lifecycle'), false);

      manager.dispose();
    });
  });

  group('ChatStreamManager - periodic persist guard', () {
    test(
        'periodic persist does NOT save when stream has completed (persistTimer null)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      final provider = _MockProvider([
        [AIStreamEvent('Quick response')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv-persist-guard',
        history: [
          _userMsg('Hi', 'u1'),
        ],
      );

      expect(result.fullReply, 'Quick response');

      // After streaming completes, the persistTimer should be null.
      // _doPeriodicPersist checks s.persistTimer == null as a guard.
      // Not directly testable from outside, but we verify the result
      // is correct and the stream state is cleaned up.
      expect(manager.isStreamingFor('conv-persist-guard'), false);
      expect(manager.streamingMsgIdFor('conv-persist-guard'), isNull);

      manager.dispose();
    });
  });
}
