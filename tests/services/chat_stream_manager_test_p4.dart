part of 'chat_stream_manager_test.dart';

void chatStreamManagerGroup4() {
  group('ChatStreamManager - reasoning buffer non-duplication', () {
    test(
        'each reasoning section contains only its own content (not previous sections)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      // Two rounds of reasoning separated by tool calls:
      // Section 0: "Think about A"
      // Section 1: "Think about B" (must NOT include "Think about A")
      // Section 2: "Final thought"
      final provider = _MockProvider([
        // Round 1: reasoning + tool call
        [
          AIStreamEvent('Think about A', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc1',
              'type': 'function',
              'function': {
                'name': 'search',
                'arguments': '{"q":"A"}',
              },
            },
          ]),
        ],
        // Round 2: second reasoning + tool call
        [
          AIStreamEvent('Think about B', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc2',
              'type': 'function',
              'function': {
                'name': 'search',
                'arguments': '{"q":"B"}',
              },
            },
          ]),
        ],
        // Round 3: final reasoning + answer
        [
          AIStreamEvent('Final thought', isReasoning: true),
          AIStreamEvent('Final answer'),
        ],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Query',
        convId: 'conv-dedup',
        history: [
          _userMsg('Query', 'u1'),
        ],
      );

      // Should have at least 3 reasoning sections
      expect(result.reasoningSections.length, greaterThanOrEqualTo(3),
          reason:
              'Expected >=3 sections, got ${result.reasoningSections.length}');

      // Section 0: only "Think about A"
      expect(result.reasoningSections[0], contains('Think about A'));
      expect(result.reasoningSections[0], isNot(contains('Think about B')));
      expect(result.reasoningSections[0], isNot(contains('Final thought')));

      // Section 1: only "Think about B", NOT "Think about A"
      final s1 = result.reasoningSections[1];
      expect(s1, contains('Think about B'));
      expect(s1, isNot(contains('Think about A')),
          reason: 'Section 1 must not contain Section 0 content: "$s1"');

      // Section 2: only "Final thought", not previous content
      final s2 = result.reasoningSections[2];
      expect(s2, contains('Final thought'));
      expect(s2, isNot(contains('Think about A')));
      expect(s2, isNot(contains('Think about B')));

      manager.dispose();
    });

    test('textSections correctly partitioned at tool call boundaries',
        () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();

      final provider = _MockProvider([
        // Round 1: reasoning + text + tool call
        [
          AIStreamEvent('Think about A', isReasoning: true),
          AIStreamEvent('Intermediate text 1'),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc1',
              'type': 'function',
              'function': {
                'name': 'search',
                'arguments': '{"q":"A"}',
              },
            },
          ]),
        ],
        // Round 2: second reasoning + more text + second tool call
        [
          AIStreamEvent('Think about B', isReasoning: true),
          AIStreamEvent('Intermediate text 2'),
          AIStreamEvent('', toolCalls: [
            {
              'id': 'tc2',
              'type': 'function',
              'function': {
                'name': 'web_fetch',
                'arguments': '{"url":"b.com"}',
              },
            },
          ]),
        ],
        // Round 3: final reasoning + final answer
        [
          AIStreamEvent('Final thought', isReasoning: true),
          AIStreamEvent('Final answer text'),
        ],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Query',
        convId: 'conv-text-section',
        history: [_userMsg('Query', 'u1')],
      );

      // Check textSections is present and correctly partitioned
      final ts = result.textSections;
      expect(ts, isNotNull);
      expect(ts.length, 3,
          reason: 'Expected 3 text sections (one per round), got ${ts.length}');
      expect(ts[0], contains('Intermediate text 1'));
      expect(ts[1], contains('Intermediate text 2'));
      expect(ts[2], contains('Final answer text'));

      // Each text section should contain ONLY its round's text
      expect(ts[0], isNot(contains('Intermediate text 2')));
      expect(ts[1], isNot(contains('Intermediate text 1')));
      expect(ts[2], isNot(contains('Intermediate text 1')));

      // Verify ChatMessage.textSessions matches
      final msg = result.assistantMessage;
      expect(msg, isNotNull);
      expect(msg!.textSections, isNotNull);
      expect(msg.textSections!.length, 3);
      expect(msg.textSections![0], contains('Intermediate text 1'));
      expect(msg.textSections![1], contains('Intermediate text 2'));
      expect(msg.textSections![2], contains('Final answer text'));

      manager.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Cross-conversation provider isolation tests
  // ═══════════════════════════════════════════════════════════════

  group('Cross-conversation provider isolation', () {
    test(
      'BUG-REPRO Issue B: _activeConvId preserved when other stream is running',
      () async {
        // Issue B: When stream A completes while B is still streaming,
        // startStreaming cleanup at line 636 sets _activeConvId = null,
        // which blocks B's future throttled provider updates.
        //
        // Expected: _activeConvId should not be null while another
        // stream exists. It should point to the still-running stream.
        final manager = ChatStreamManager();

        // Block convA so convB can start while A is still running
        final blockA = Completer<void>();
        final providerA = _MockProvider(
          [
            [AIStreamEvent('A response')],
          ],
          waitForYield: blockA,
        );
        manager.adapter.forceService(_makeChatService(providerA));
        final futureA = manager.startStreaming(
          text: 'Q A',
          convId: 'convA',
          history: [_userMsg('Q A')],
        );

        expect(manager.isStreamingFor('convA'), true);

        // Sequential streaming works: complete convA, then start convB
        blockA.complete();
        final resultA = await futureA;
        expect(resultA.fullReply, 'A response');

        // After A completes, no conversation is streaming
        expect(manager.isStreamingFor('convA'), false);
        expect(manager.isStreaming, false);

        // Start convB — should succeed since convA is done
        final providerB = _MockProvider([
          [AIStreamEvent('B response')],
        ]);
        manager.adapter.forceService(_makeChatService(providerB));
        final resultB = await manager.startStreaming(
          text: 'Q B',
          convId: 'convB',
          history: [_userMsg('Q B')],
        );
        expect(resultB.fullReply, 'B response');

        manager.dispose();
      },
    );

    test(
      'guards: starting a different conversation does NOT abandon the old one '
      '(concurrent streaming with per-conversation services)',
      () async {
        final manager = ChatStreamManager();

        // Use a WAITING mock to keep convA alive while we start convB.
        final blockA = Completer<void>();
        final providerA = _MockProvider(
          [
            [AIStreamEvent('A response')],
          ],
          waitForYield: blockA,
        );
        manager.adapter.forceService(_makeChatService(providerA));
        final futureA = manager.startStreaming(
          text: 'Q A',
          convId: 'convA',
          history: [_userMsg('Q A')],
        );

        expect(manager.isStreamingFor('convA'), true);

        // Start convB while convA is blocked — with per-conversation
        // ChatService instances, convA should KEEP streaming concurrently.
        final providerB = _MockProvider([
          [AIStreamEvent('B response')],
        ]);
        manager.adapter.forceService(_makeChatService(providerB));
        final futureB = manager.startStreaming(
          text: 'Q B',
          convId: 'convB',
          history: [_userMsg('Q B')],
        );

        // BOTH conversations should be streaming concurrently
        expect(manager.isStreamingFor('convA'), true);
        expect(manager.isStreamingFor('convB'), true);

        // Complete convA's blocked provider
        blockA.complete();

        // Both should complete normally
        expect((await futureB).fullReply, 'B response');
        expect((await futureA).fullReply, 'A response');

        manager.dispose();
      },
    );

    test(
      'cleanup: _streams entry is removed before resultCompleter is nulled',
      () async {
        final manager = ChatStreamManager();

        // Run a stream to completion
        final provider = _MockProvider([
          [AIStreamEvent('Response')],
        ]);
        manager.adapter.forceService(_makeChatService(provider));
        final result = await manager.startStreaming(
          text: 'Q',
          convId: 'convTest',
          history: [_userMsg('Q')],
        );

        expect(result.fullReply, 'Response');
        expect(manager.isStreaming, false);

        // After completion, _streams should not contain 'convTest'.
        // If resultCompleter was nulled before _streams.remove, a
        // subsequent duplicate startStreaming for 'convTest' would
        // find the entry in _streams but crash on resultCompleter!.
        expect(manager.isStreamingFor('convTest'), false);

        // Now start a fresh stream for 'convTest' — should succeed
        // (not return a stale resultCompleter).
        final provider2 = _MockProvider([
          [AIStreamEvent('Second response')],
        ]);
        manager.adapter.forceService(_makeChatService(provider2));
        final result2 = await manager.startStreaming(
          text: 'Q2',
          convId: 'convTest',
          history: [_userMsg('Q2')],
        );
        expect(result2.fullReply, 'Second response');

        manager.dispose();
      },
    );
  });
}
