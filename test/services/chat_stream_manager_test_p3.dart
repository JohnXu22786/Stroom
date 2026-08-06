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

    test(
        'round 2 that starts with reasoning but NO text records a new round start',
        () async {
      // Regression test for the "all thoughts at the bottom" bug:
      // A tool round preceded only by reasoning (the standard DeepSeek
      // reasoning-model agent pattern — reasoning_content then tool_calls,
      // no visible text) used to be grouped into round 0 because the
      // ToolCallStartEvent split condition only looked at text chunks.
      // The result: round 2's reasoning section was rendered AFTER all
      // tool calls by _buildWithRounds' trailing loop.
      //
      // Each tool round emits a ReasoningSectionEndEvent before its own
      // ToolCallStartEvents — that event is the authoritative round
      // boundary and must create a new round start even when the last
      // text chunk is empty.
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      final provider = _MockProvider([
        // Round 1: reasoning + tool A (no visible text)
        [
          AIStreamEvent('Let me analyze step 1...', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc1',
              'type': 'function',
              'function': {'name': 'toolA', 'arguments': '{}'},
            },
          ]),
        ],
        // Round 2: reasoning + tool B (no visible text — the bug trigger)
        [
          AIStreamEvent('Now checking step 2...', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc2',
              'type': 'function',
              'function': {'name': 'toolB', 'arguments': '{}'},
            },
          ]),
        ],
        // Round 3: final answer
        [AIStreamEvent('final answer')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'multi-round reasoning only',
        convId: 'conv-reasoning-only-rounds',
        history: [_userMsg('multi-round reasoning only', 'u1')],
      );

      expect(result.toolCalls.length, 2);
      // Round 0 starts at tool index 0 (tc1), round 1 at tool index 1 (tc2).
      // If this is [0], round 2's tools were merged into round 0 and its
      // reasoning section will be rendered at the bottom of the message.
      expect(result.toolCallRoundStarts, [0, 1],
          reason: 'Reasoning-only round 2 must record a new round start. '
              'If this is [0], the "thoughts at the bottom" bug regressed.');
      // Exact sections: each round's reasoning + the trailing placeholder
      // the final ReasoningSectionEndEvent adds (the renderer depends on
      // this shape — index i of reasoningSections pairs with round i).
      expect(result.reasoningSections,
          ['Let me analyze step 1...', 'Now checking step 2...', '']);
      // Round 1 and 2 have no visible text; the final answer lands in
      // chunk 2, which the renderer places after the last tool round.
      expect(result.textSections, ['', '', 'final answer']);

      // The assistant message persists the corrected round starts.
      final assistant = result.assistantMessage;
      expect(assistant, isNotNull);
      expect(assistant!.toolCallRoundStarts, [0, 1]);

      manager.dispose();
    });

    test('tools in the same round stay grouped after round-boundary change',
        () async {
      // Parallel tools from ONE assistant response (no ReasoningSectionEndEvent
      // between them) must stay in a single round — the pendingRoundStart
      // flag set by the previous round's end event must only affect the
      // FIRST tool call of the next round.
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      final provider = _MockProvider([
        // Round 1: reasoning + 2 parallel tool calls
        [
          AIStreamEvent('Analyzing...', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc1',
              'type': 'function',
              'function': {'name': 'toolA', 'arguments': '{}'},
            },
            {
              'id': 'tc2',
              'type': 'function',
              'function': {'name': 'toolB', 'arguments': '{}'},
            },
          ]),
        ],
        // Round 2: reasoning + 2 parallel tool calls
        [
          AIStreamEvent('Verifying...', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc3',
              'type': 'function',
              'function': {'name': 'toolC', 'arguments': '{}'},
            },
            {
              'id': 'tc4',
              'type': 'function',
              'function': {'name': 'toolD', 'arguments': '{}'},
            },
          ]),
        ],
        // Round 3: final answer
        [AIStreamEvent('done')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'parallel tools two rounds',
        convId: 'conv-parallel-two-rounds',
        history: [_userMsg('parallel tools two rounds', 'u1')],
      );

      expect(result.toolCalls.length, 4);
      // Round 0 = tc1, tc2 (indices 0..1); round 1 = tc3, tc4 (index 2).
      expect(result.toolCallRoundStarts, [0, 2],
          reason: 'Each round\'s parallel tools must stay grouped. '
              'Round 0 starts at tc1 (index 0), round 1 at tc3 (index 2).');
      expect(result.toolCalls.map((t) => t.id).toList(),
          ['tc1', 'tc2', 'tc3', 'tc4']);

      manager.dispose();
    });

    test(
        'user trigger: 10 parallel tools with repeated names + reasoning-only round 2',
        () async {
      // User-reported reproduction of the original "thoughts at the bottom"
      // bug: one API response fires ~10 tool calls at once, the SAME tool
      // name is called repeatedly for different content, and the next round
      // starts with reasoning only (no visible text) before more tools.
      // With the fix, round 2 must record its own round boundary
      // (roundStarts=[0,10]) so its reasoning renders between the two tool
      // batches instead of at the bottom.
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      final provider = _MockProvider([
        // Round 1: reasoning + 10 parallel tool calls (web_search repeated
        // for different queries, fetch_url repeated for different URLs)
        [
          AIStreamEvent('Planning the search...', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            for (var i = 0; i < 10; i++)
              {
                'id': 'tc_batch1_$i',
                'type': 'function',
                'function': {
                  'name': i.isEven ? 'web_search' : 'fetch_url',
                  'arguments': '{"q": "query $i"}',
                },
              },
          ]),
        ],
        // Round 2: reasoning only (no text) + 2 more parallel tools
        [
          AIStreamEvent('Analyzing the results...', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc_batch2_0',
              'type': 'function',
              'function': {
                'name': 'web_search',
                'arguments': '{"q": "follow-up"}',
              },
            },
            {
              'id': 'tc_batch2_1',
              'type': 'function',
              'function': {
                'name': 'fetch_url',
                'arguments': '{"url": "https://example.com"}',
              },
            },
          ]),
        ],
        // Round 3: final answer
        [AIStreamEvent('Here is the summary.')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Search all these topics',
        convId: 'conv-user-trigger-10-tools',
        history: [_userMsg('Search all these topics', 'u1')],
      );

      // All 12 tool calls preserved in declaration order.
      expect(result.toolCalls.length, 12);
      expect(result.toolCalls.map((t) => t.id).toList(), [
        for (var i = 0; i < 10; i++) 'tc_batch1_$i',
        'tc_batch2_0',
        'tc_batch2_1',
      ]);
      // Repeated tool names survive: 5+1 web_search, 5+1 fetch_url.
      expect(result.toolCalls.where((t) => t.name == 'web_search').length, 6);
      expect(result.toolCalls.where((t) => t.name == 'fetch_url').length, 6);
      // Round 0 = tools 0..9, round 1 = tools 10..11. If this is [0],
      // round 2's tools were merged into round 0 and its reasoning would
      // render at the bottom — the exact user-reported symptom.
      expect(result.toolCallRoundStarts, [0, 10],
          reason: '10-tool round + reasoning-only round 2 must record a new '
              'round start at index 10. If this is [0], the "thoughts at '
              'the bottom" bug regressed for the user trigger.');
      // Both reasoning sections + trailing placeholder, and per-round text
      // chunks (rounds 1-2 have no visible text).
      expect(result.reasoningSections,
          ['Planning the search...', 'Analyzing the results...', '']);
      expect(result.textSections, ['', '', 'Here is the summary.']);

      // Persisted for reload with the corrected boundaries.
      final assistant = result.assistantMessage;
      expect(assistant, isNotNull);
      expect(assistant!.toolCallRoundStarts, [0, 10]);
      expect(assistant.toolCalls!.length, 12);

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

    test('partialPersistHasContent: pure tool round has content', () {
      // Guard for the persist change: with parallel execution a whole
      // round's tool cards start at once, so a crash mid-round must not
      // lose them — a stream whose ONLY content is tool calls must pass
      // the periodic-persist guard.
      expect(
        ChatStreamManager.partialPersistHasContent(
          fullReply: '',
          reasoningSections: const [],
          hasAccumulatedToolCalls: true,
        ),
        isTrue,
        reason: 'Pure tool round (no text/reasoning) must be persisted.',
      );
    });

    test('partialPersistHasContent: empty stream has no content', () {
      expect(
        ChatStreamManager.partialPersistHasContent(
          fullReply: '',
          reasoningSections: const [],
          hasAccumulatedToolCalls: false,
        ),
        isFalse,
        reason: 'Nothing to persist yet.',
      );
    });

    test('partialPersistHasContent: sealed reasoning (empty buffer) counts',
        () {
      // ReasoningSectionEndEvent resets the reasoning buffer, but the
      // sealed section content must still count as persistable content.
      expect(
        ChatStreamManager.partialPersistHasContent(
          fullReply: '',
          reasoningSections: const ['think1', '', ''],
          hasAccumulatedToolCalls: false,
        ),
        isTrue,
      );
    });

    test('partialPersistHasContent: text counts as content', () {
      expect(
        ChatStreamManager.partialPersistHasContent(
          fullReply: 'partial answer',
          reasoningSections: const [],
          hasAccumulatedToolCalls: false,
        ),
        isTrue,
      );
    });

    test('partialPersistHasContent: lone empty section has no content', () {
      // State right after a ReasoningSectionEndEvent on a round that had
      // no reasoning: [''] must not count as content (in the real stream
      // such a state always has pending tool calls, which the helper
      // catches separately).
      expect(
        ChatStreamManager.partialPersistHasContent(
          fullReply: '',
          reasoningSections: const [''],
          hasAccumulatedToolCalls: false,
        ),
        isFalse,
      );
    });
  });
}
