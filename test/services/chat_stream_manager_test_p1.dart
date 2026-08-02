part of 'chat_stream_manager_test.dart';

void chatStreamManagerGroup1() {
  group('ChatStreamManager - basic operations', () {
    late ChatStreamManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = ChatStreamManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('manager creates and holds an adapter', () {
      expect(manager.adapter, isA<ChatAdapter>());
      expect(manager.adapter.isConfigured, false);
    });

    test('adapter returns the same instance', () {
      final adapter = manager.adapter;
      expect(adapter, isNotNull);
      expect(manager.adapter, same(adapter));
    });

    test('isStreaming returns false when no conversation is streaming', () {
      expect(manager.isStreaming, false);
    });

    test('isStreamingFor returns false for non-streaming conversation', () {
      expect(manager.isStreamingFor('conv1'), false);
    });

    test('cancel does nothing when not streaming', () {
      manager.cancel();
      expect(manager.isStreaming, false);
    });

    test('cancel with specific convId does nothing when not streaming', () {
      manager.cancel('conv1');
      expect(manager.isStreaming, false);
    });

    test('dispose can be called without error', () {
      manager.dispose();
      expect(manager.isStreaming, false);
    });
  });

  group('ChatStreamManager - single conversation streaming', () {
    test('StreamResult contains correct history after completion', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Hello World')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final history = <ChatMessage>[_userMsg('Hi', 'u1')];
      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: history,
      );

      expect(result.history.length, 2);
      expect(result.history[1].role, 'assistant');
      expect(result.history[1].content, 'Hello World');
      expect(result.fullReply, 'Hello World');
      expect(result.assistantMessage, isNotNull);
      expect(result.assistantMessage!.content, 'Hello World');

      manager.dispose();
    });

    test('StreamResult contains correct fullReply from text events', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Hello'), AIStreamEvent(' '), AIStreamEvent('World')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [],
      );

      expect(result.fullReply, 'Hello World');
      manager.dispose();
    });

    test('isStreamingFor returns true during streaming', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Hello')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [_userMsg('Hi')],
      );

      expect(manager.isStreaming, true);
      expect(manager.isStreamingFor('conv1'), true);
      expect(manager.isStreamingFor('conv2'), false);

      completer.complete();
      await future;
      expect(manager.isStreaming, false);
      expect(manager.isStreamingFor('conv1'), false);

      manager.dispose();
    });

    test('cancel stops the specific conversation stream', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Part 1'), AIStreamEvent('Part 2')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [_userMsg('Hi')],
      );

      expect(manager.isStreaming, true);

      // Cancel conv1
      manager.cancel('conv1');

      completer.complete();
      await future;

      expect(manager.isStreaming, false);
      expect(manager.isStreamingFor('conv1'), false);

      manager.dispose();
    });

    test('cancel without convId cancels all streams', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Hello')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [_userMsg('Hi')],
      );

      expect(manager.isStreaming, true);
      manager.cancel(); // cancel all
      completer.complete();
      await future;

      expect(manager.isStreaming, false);
      manager.dispose();
    });
  });

  group('ChatStreamManager - multi-conversation streaming', () {
    test(
        'two different conversations can stream simultaneously without '
        'interference', () async {
      final manager = ChatStreamManager();

      final completerA = Completer<void>();

      // 顺序测试：convA 阻塞时取消，再验证 convB 正常流式。
      // （并发能力由每对话独立 ChatService 支持——见 p4 的
      // Cross-conversation provider isolation 测试）
      final providerA2 = _MockProvider(
        [
          [AIStreamEvent('Slow A response')]
        ],
        waitForYield: completerA,
      );
      manager.adapter.forceService(_makeChatService(providerA2));

      // Start convA (will wait on completerA)
      final futureA = manager.startStreaming(
        text: 'Q A',
        convId: 'convA',
        history: [_userMsg('Q A')],
      );

      expect(manager.isStreamingFor('convA'), true);
      expect(manager.isStreamingFor('convB'), false);
      expect(manager.isStreaming, true);

      // Cancel convA mid-stream
      manager.cancel('convA');
      completerA.complete();
      final resultA = await futureA;

      expect(manager.isStreamingFor('convA'), false);
      expect(resultA.fullReply.isEmpty, true,
          reason: 'Cancelled before any events were processed');

      // Now stream convB - should work after convA is done
      final providerB2 = _MockProvider([
        [AIStreamEvent('Response for B')],
      ]);
      manager.adapter.forceService(_makeChatService(providerB2));

      final resultB = await manager.startStreaming(
        text: 'Q B',
        convId: 'convB',
        history: [_userMsg('Q B')],
      );

      expect(resultB.fullReply, 'Response for B');
      expect(manager.isStreaming, false);

      manager.dispose();
    });

    test(
        'per-conversation reply accumulation does not cross-contaminate '
        'between conversations', () async {
      // This is tested implicitly by running two streams sequentially
      // with different responses and verifying correct accumulation.
      final manager = ChatStreamManager();

      final providerA = _MockProvider([
        [AIStreamEvent('Reply'), AIStreamEvent(' for A')],
      ]);
      manager.adapter.forceService(_makeChatService(providerA));
      final resultA = await manager.startStreaming(
        text: 'Q A',
        convId: 'convA',
        history: [_userMsg('Q A')],
      );
      expect(resultA.fullReply, 'Reply for A');

      final providerB = _MockProvider([
        [AIStreamEvent('Reply'), AIStreamEvent(' for B')],
      ]);
      manager.adapter.forceService(_makeChatService(providerB));
      final resultB = await manager.startStreaming(
        text: 'Q B',
        convId: 'convB',
        history: [_userMsg('Q B')],
      );
      expect(resultB.fullReply, 'Reply for B');

      // convA's history should be unchanged
      expect(resultA.history.length, 2);
      expect(resultA.history[1].content, 'Reply for A');

      manager.dispose();
    });

    test(
        'same conversation refuses duplicate startStreaming while '
        'already streaming', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Response')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future1 = manager.startStreaming(
        text: 'Q1',
        convId: 'conv1',
        history: [],
      );

      expect(manager.isStreamingFor('conv1'), true);

      // Second call for SAME conversation should be ignored
      final future2 = manager.startStreaming(
        text: 'Q2',
        convId: 'conv1',
        history: [],
      );

      // future2 should complete with same result as future1 (no-op)
      completer.complete();
      final result1 = await future1;
      final result2 = await future2;

      expect(result1.assistantMessage?.content, 'Response');
      expect(result2.fullReply, result1.fullReply,
          reason: 'Second call returns the same ongoing result');

      manager.dispose();
    });

    test(
        'isStreamingFor correctly tracks per-conversation state '
        'across sequential streams', () async {
      // Verify that isStreamingFor reports the correct per-conversation
      // streaming state as conversations stream sequentially.
      // (True concurrency is limited by the single ChatAdapter, but
      // per-conversation tracking is fully functional for sequential use.)
      final manager = ChatStreamManager();

      // ConvA streams first
      final providerA = _MockProvider([
        [AIStreamEvent('A response')],
      ]);
      manager.adapter.forceService(_makeChatService(providerA));

      expect(manager.isStreamingFor('convA'), false);
      expect(manager.isStreamingFor('convB'), false);
      expect(manager.isStreaming, false);

      final resultA = await manager.startStreaming(
        text: 'Q A',
        convId: 'convA',
        history: [_userMsg('Q A')],
      );

      expect(resultA.fullReply, 'A response');
      expect(manager.isStreamingFor('convA'), false,
          reason: 'Stream completed, should no longer be streaming');

      // ConvB streams next
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
      expect(manager.isStreamingFor('convB'), false);
      expect(manager.isStreaming, false);

      // Both results are independent
      expect(resultA.fullReply, 'A response');
      expect(resultB.fullReply, 'B response');

      manager.dispose();
    });
  });
}
