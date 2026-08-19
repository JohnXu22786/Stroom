part of 'chat_stream_manager_test.dart';

void chatStreamManagerGroup2() {
  group('ChatStreamManager - reasoning events', () {
    test('handles reasoning events properly with StreamResult', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [
          AIStreamEvent('Let me think', isReasoning: true),
          AIStreamEvent(' about this', isReasoning: true),
          AIStreamEvent('Therefore:'),
        ],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Think hard',
        convId: 'conv1',
        history: [],
        reasoning: true,
      );

      // Full reply should only contain non-reasoning text
      expect(result.fullReply, 'Therefore:');

      manager.dispose();
    });
  });

  group('ChatStreamManager - tool calls', () {
    test('accumulates tool calls from streaming events in StreamResult',
        () async {
      final manager = ChatStreamManager();
      final provider = _MockToolCallsProvider();
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Search weather',
        convId: 'conv1',
        history: [],
      );

      expect(result.history.length, 1);
      expect(result.history[0].role, 'assistant');

      manager.dispose();
    });
  });

  group('ChatStreamManager - error handling', () {
    test('provider error is captured in StreamResult', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Test')],
      ]);
      provider.throwOnSubscribe = true;
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [],
      );

      expect(manager.isStreaming, false);
      expect(result.fullReply.startsWith('错误:'), true);

      manager.dispose();
    });

    test('error in one conversation does not affect another', () async {
      final manager = ChatStreamManager();

      // First, a failing stream
      final badProvider = _MockProvider([
        [AIStreamEvent('Test')],
      ]);
      badProvider.throwOnSubscribe = true;
      manager.adapter.forceService(_makeChatService(badProvider));

      final resultBad = await manager.startStreaming(
        text: 'Bad',
        convId: 'convBad',
        history: [],
      );
      expect(resultBad.fullReply.startsWith('错误:'), true);

      // Then, a good stream should work
      final goodProvider = _MockProvider([
        [AIStreamEvent('Good response')],
      ]);
      manager.adapter.forceService(_makeChatService(goodProvider));

      final resultGood = await manager.startStreaming(
        text: 'Good',
        convId: 'convGood',
        history: [],
      );
      expect(resultGood.fullReply, 'Good response');

      manager.dispose();
    });
  });

  group('ChatStreamManager - cleanup', () {
    test('dispose stops all streams and cleans up', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Response')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [_userMsg('Hi')],
      );

      expect(manager.isStreamingFor('conv1'), true);

      // Dispose while streaming
      manager.dispose();
      completer.complete();
      await future; // Should complete without error after dispose

      expect(manager.isStreaming, false);
    });
  });

  group('ChatStreamManager - sequential multi-message history', () {
    test('3 sequential messages produce correct growing StreamResult.history',
        () async {
      final manager = ChatStreamManager();

      // Msg 1: user sends "hi"
      final provider1 = _MockProvider([
        [AIStreamEvent('Hello!')],
      ]);
      manager.adapter.forceService(_makeChatService(provider1));

      var history = <ChatMessage>[_userMsg('hi', 'u1')];
      final result1 = await manager.startStreaming(
        text: 'hi',
        convId: 'conv-seq',
        history: List.from(history),
      );

      // After msg 1: 1 user + 1 assistant = 2
      expect(result1.history.length, 2,
          reason: '1st message should have 2 entries (user + assistant)');
      expect(result1.history[0].role, 'user');
      expect(result1.history[1].role, 'assistant');
      expect(result1.history[1].content, 'Hello!');

      // Use result1.history as the input for msg 2 (simulating page behavior)
      history = List.from(result1.history);

      // Msg 2: user appends "how are you"
      history.add(_userMsg('how are you', 'u2'));

      final provider2 = _MockProvider([
        [AIStreamEvent('I am fine!')],
      ]);
      manager.adapter.forceService(_makeChatService(provider2));

      final result2 = await manager.startStreaming(
        text: 'how are you',
        convId: 'conv-seq',
        history: List.from(history),
      );

      // After msg 2: 2 users + 2 assistants = 4
      expect(result2.history.length, 4,
          reason:
              '2nd message should have 4 entries (user1+assistant1+user2+assistant2), got ${result2.history.length}');
      expect(result2.history[0].role, 'user');
      expect(result2.history[1].role, 'assistant');
      expect(result2.history[2].role, 'user');
      expect(result2.history[3].role, 'assistant');
      expect(result2.history[3].content, 'I am fine!');

      // Use result2.history as input for msg 3
      history = List.from(result2.history);

      // Msg 3: user appends "thanks"
      history.add(_userMsg('thanks', 'u3'));

      final provider3 = _MockProvider([
        [AIStreamEvent('You welcome!')],
      ]);
      manager.adapter.forceService(_makeChatService(provider3));

      final result3 = await manager.startStreaming(
        text: 'thanks',
        convId: 'conv-seq',
        history: List.from(history),
      );

      // After msg 3: 3 users + 3 assistants = 6
      expect(result3.history.length, 6,
          reason:
              '3rd message should have 6 entries (3 users + 3 assistants), got ${result3.history.length}');
      expect(result3.history[4].role, 'user');
      expect(result3.history[5].role, 'assistant');
      expect(result3.history[5].content, 'You welcome!');

      manager.dispose();
    });

    test('edit then re-send truncates history correctly', () async {
      final manager = ChatStreamManager();

      // Build up: 2 messages (4 entries)
      final provider1 = _MockProvider([
        [AIStreamEvent('Response 1')],
      ]);
      manager.adapter.forceService(_makeChatService(provider1));

      var history = <ChatMessage>[_userMsg('msg1', 'u1')];
      var result = await manager.startStreaming(
        text: 'msg1',
        convId: 'conv-edit',
        history: List.from(history),
      );
      expect(result.history.length, 2);

      history = List.from(result.history);
      history.add(_userMsg('msg2', 'u2'));

      final provider2 = _MockProvider([
        [AIStreamEvent('Response 2')],
      ]);
      manager.adapter.forceService(_makeChatService(provider2));

      result = await manager.startStreaming(
        text: 'msg2',
        convId: 'conv-edit',
        history: List.from(history),
      );
      expect(result.history.length, 4);

      // Now simulate edit: remove msg2 (index 2, 0-based) and re-send
      history = List.from(result.history);
      history.removeRange(2, history.length); // removes msg2+response2
      expect(history.length, 2,
          reason: 'After edit-remove, history should have 2 entries');

      // "Edit" msg2 with new text
      history.add(_userMsg('msg2-edited', 'u2-edited'));

      final provider3 = _MockProvider([
        [AIStreamEvent('Response 2 edited')],
      ]);
      manager.adapter.forceService(_makeChatService(provider3));

      result = await manager.startStreaming(
        text: 'msg2-edited',
        convId: 'conv-edit',
        history: List.from(history),
      );

      // After edit: 2 old entries + 1 new user + 1 new assistant = 4
      expect(result.history.length, 4,
          reason:
              'After edit, history should have 4 entries (msg1+resp1+edited+newResp), got ${result.history.length}');

      // The old response2 should NOT be present
      final contents = result.history
          .where((m) => m.role == 'assistant')
          .map((m) => m.content)
          .toList();
      expect(contents, ['Response 1', 'Response 2 edited'],
          reason:
              'Should contain only Response 1 and the new edited response, not old Response 2');

      manager.dispose();
    });

    test(
        'page-level edit flow: _editUserMessageWithText saves truncated history before re-send',
        () async {
      // This test validates the edit flow without a full widget tree.
      // It verifies that when history is truncated and then a new stream
      // is started, the result does not contain the old truncated messages.

      final manager = ChatStreamManager();

      // Step 1: Build 2-message history via manager
      final provider1 = _MockProvider([
        [AIStreamEvent('Resp1')],
      ]);
      manager.adapter.forceService(_makeChatService(provider1));

      var history = <ChatMessage>[_userMsg('Q1', 'u1')];
      history = (await manager.startStreaming(
        text: 'Q1',
        convId: 'c-edit2',
        history: List.from(history),
      ))
          .history;

      expect(history.length, 2);

      history.add(_userMsg('Q2', 'u2'));
      final provider2 = _MockProvider([
        [AIStreamEvent('Resp2')],
      ]);
      manager.adapter.forceService(_makeChatService(provider2));
      history = (await manager.startStreaming(
        text: 'Q2',
        convId: 'c-edit2',
        history: List.from(history),
      ))
          .history;

      expect(history.length, 4);
      expect(history[3].content, 'Resp2');

      // Step 2: Simulate edit — remove index 2 onward (Q2 + Resp2)
      final preEdit = List<ChatMessage>.from(history);
      preEdit.removeRange(2, preEdit.length);
      expect(preEdit.length, 2);

      // Step 3: "Re-send" with edited text
      preEdit.add(_userMsg('Q2-edited', 'u2-edited'));
      final provider3 = _MockProvider([
        [AIStreamEvent('Resp2-edited')],
      ]);
      manager.adapter.forceService(_makeChatService(provider3));
      final finalHistory = (await manager.startStreaming(
        text: 'Q2-edited',
        convId: 'c-edit2',
        history: List.from(preEdit),
      ))
          .history;

      // Should be 4 entries, with old Resp2 gone
      expect(finalHistory.length, 4,
          reason:
              'Edit should produce 4 entries (2 old + 1 edited-user + 1 new assistant)');
      expect(finalHistory[2].role, 'user');
      expect(finalHistory[2].content, 'Q2-edited');
      expect(finalHistory[3].role, 'assistant');
      expect(finalHistory[3].content, 'Resp2-edited');

      // Verify old Resp2 is NOT present
      for (final m in finalHistory) {
        if (m.role == 'assistant') {
          expect(m.content, isNot('Resp2'),
              reason: 'Old assistant response should be gone after edit');
        }
      }

      manager.dispose();
    });
  });
}
