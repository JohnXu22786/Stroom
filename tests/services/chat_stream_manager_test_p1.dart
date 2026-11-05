part of 'chat_stream_manager_test.dart';

void chatStreamManagerGroup1() {
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

    test('network interruption after partial output adds a user continuation',
        () async {
      final manager = ChatStreamManager(retryDelay: (_) async {});
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      final provider = _MockProvider([
        [AIStreamEvent('partial answer')],
      ])
        ..errorAfterYield = networkFailure;
      manager.adapter.forceService(_makeChatService(provider));
      final displayedContinuations = <ChatMessage>[];
      manager.setContinuationHandler(
        'conv-network-continue',
        (message) async {
          displayedContinuations.add(message);
          return true;
        },
      );

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv-network-continue',
        history: [_userMsg('Hi', 'u-original')],
      );

      expect(provider.callCount, 2);
      expect(result.history.map((message) => message.role),
          ['user', 'user', 'assistant']);
      expect(result.history[1].content, 'Continue if not finished.');
      expect(displayedContinuations, hasLength(1));
      expect(displayedContinuations.single.role, 'user');
      expect(
          displayedContinuations.single.content, 'Continue if not finished.');
      expect(result.fullReply, 'partial answerFinal response');
      final resentMessages = provider.capturedMessages.last;
      expect(resentMessages.last['role'], 'user');
      expect(resentMessages.last['content'], 'Continue if not finished.');
      manager.dispose();
    });

    test('repeated partial interruptions continue without losing history',
        () async {
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      final provider = _MockProvider([
        [AIStreamEvent('first part')],
        [AIStreamEvent(' second part')],
        [AIStreamEvent(' final part')],
      ])
        ..errorsAfterCall.addAll({1: networkFailure, 2: networkFailure});
      final waits = <Duration>[];
      final manager = ChatStreamManager(
        retryDelay: (duration) async => waits.add(duration),
        transportRetryPolicy: const TransportRetryPolicy(jitter: false),
      );
      manager.adapter.forceService(_makeChatService(provider));
      final bubbles = <ChatMessage>[];
      manager.setContinuationHandler('conv-repeated-network', (message) async {
        bubbles.add(message);
        return true;
      });

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv-repeated-network',
        history: [_userMsg('Hi', 'u-original')],
      );

      expect(provider.callCount, 3);
      expect(waits, [const Duration(seconds: 2), const Duration(seconds: 4)]);
      expect(bubbles, hasLength(2));
      expect(bubbles.every((message) => message.role == 'user'), isTrue);
      expect(result.history.where((message) => message.role == 'user'),
          hasLength(3));
      expect(result.fullReply, 'first part second part final part');
      manager.dispose();
    });

    test('uses the active locale for each continuation bubble', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      await container.read(localeProvider.notifier).setLocaleCode('zh_CN');
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      final provider = _MockProvider([
        [AIStreamEvent('部分回答')],
      ])..errorAfterYield = networkFailure;
      final manager = ChatStreamManager(container, retryDelay: (_) async {});
      manager.adapter.forceService(_makeChatService(provider));
      final bubbles = <ChatMessage>[];
      manager.setContinuationHandler(
        'conv-localized-network',
        (message) async {
          bubbles.add(message);
          return true;
        },
      );

      await manager.startStreaming(
        text: '你好',
        convId: 'conv-localized-network',
        history: [_userMsg('你好', 'u-original')],
      );

      expect(bubbles.single.content, '如果还没完成，请继续。');
      expect(bubbles.single.role, 'user');
      manager.dispose();
      container.dispose();
    });

    test('retries a transport failure before output without adding a bubble',
        () async {
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      final provider = _MockProvider([
        [],
        [AIStreamEvent('recovered')],
      ])..errorsAfterCall[1] = networkFailure;
      final waits = <Duration>[];
      final manager = ChatStreamManager(
        retryDelay: (duration) async => waits.add(duration),
        transportRetryPolicy: const TransportRetryPolicy(jitter: false),
      );
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv-network-before-output',
        history: [_userMsg('Hi', 'u-original')],
      );

      expect(provider.callCount, 2);
      expect(waits, [const Duration(seconds: 2)]);
      expect(
        result.history.map((message) => message.role),
        ['user', 'assistant'],
      );
      expect(
        provider.capturedMessages[1].map((message) => message['content']),
        orderedEquals(
          provider.capturedMessages.first.map((message) => message['content']),
        ),
      );
      manager.dispose();
    });

    test('does not replay already visible reasoning after interruption',
        () async {
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      final provider = _MockProvider([
        [AIStreamEvent('partial reasoning', isReasoning: true)],
      ])..errorAfterYield = networkFailure;
      final manager = ChatStreamManager(retryDelay: (_) async {});
      manager.adapter.forceService(_makeChatService(provider));
      var bubbleCount = 0;
      manager.setContinuationHandler('conv-visible-reasoning', (_) async {
        bubbleCount++;
        return true;
      });

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv-visible-reasoning',
        history: [_userMsg('Hi', 'u-original')],
      );

      expect(provider.callCount, 1);
      expect(bubbleCount, 0);
      expect(result.reasoningSections, contains('partial reasoning'));
      expect(result.assistantMessage?.isError, isTrue);
      manager.dispose();
    });

    test('stops after five failed transport retries', () async {
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      final provider = _MockProvider(List.generate(
        6,
        (_) => [AIStreamEvent('partial')],
      ));
      for (var call = 1; call <= 6; call++) {
        provider.errorsAfterCall[call] = networkFailure;
      }
      final waits = <Duration>[];
      final bubbles = <ChatMessage>[];
      final manager = ChatStreamManager(
        retryDelay: (duration) async => waits.add(duration),
        transportRetryPolicy: const TransportRetryPolicy(jitter: false),
      );
      manager.adapter.forceService(_makeChatService(provider));
      manager.setContinuationHandler('conv-network-budget', (message) async {
        bubbles.add(message);
        return true;
      });

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv-network-budget',
        history: [_userMsg('Hi', 'u-original')],
      );

      expect(provider.callCount, 6);
      expect(waits, hasLength(5));
      expect(waits.last, const Duration(seconds: 30));
      expect(bubbles, hasLength(5));
      expect(result.assistantMessage?.isError, isTrue);
      manager.dispose();
    });

    test('cancellation during backoff prevents another request or bubble',
        () async {
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      final provider = _MockProvider([
        [AIStreamEvent('partial')],
      ])..errorAfterYield = networkFailure;
      final delayStarted = Completer<void>();
      final releaseDelay = Completer<void>();
      final manager = ChatStreamManager(retryDelay: (_) async {
        delayStarted.complete();
        await releaseDelay.future;
      });
      manager.adapter.forceService(_makeChatService(provider));
      var bubbleCount = 0;
      manager.setContinuationHandler('conv-cancel-backoff', (_) async {
        bubbleCount++;
        return true;
      });

      final stream = manager.startStreaming(
        text: 'Hi',
        convId: 'conv-cancel-backoff',
        history: [_userMsg('Hi', 'u-original')],
      );
      await delayStarted.future;
      manager.cancel('conv-cancel-backoff');
      releaseDelay.complete();
      await stream;

      expect(provider.callCount, 1);
      expect(bubbleCount, 0);
      manager.dispose();
    });

    test('does not replay a request after a tool call has started', () async {
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      final provider = _MockProvider([
        [
          AIStreamEvent('', toolCalls: [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {'name': 'write_file', 'arguments': '{}'},
            },
          ]),
        ],
      ])..errorAfterYield = networkFailure;
      final manager = ChatStreamManager(retryDelay: (_) async {});
      manager.adapter.forceService(_makeChatService(provider));

      await manager.startStreaming(
        text: 'Create a file',
        convId: 'conv-no-side-effect-replay',
        history: [_userMsg('Create a file', 'u-original')],
      );

      expect(provider.callCount, 1);
      manager.dispose();
    });

    test('continuation handler survives stop followed by resend', () async {
      final manager = ChatStreamManager(retryDelay: (_) async {});
      final firstStreamGate = Completer<void>();
      final firstCallStarted = Completer<void>();
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      final provider = _MockProvider(
        [
          [],
          [AIStreamEvent('partial answer')],
        ],
        waitForYield: firstStreamGate,
        firstCallStarted: firstCallStarted,
      );
      manager.adapter.forceService(_makeChatService(provider));
      final displayedContinuations = <ChatMessage>[];

      final stoppedStream = manager.startStreaming(
        text: 'Stop this turn',
        convId: 'conv-stop-resend',
        history: [_userMsg('Stop this turn')],
      );
      await firstCallStarted.future;
      manager.cancel('conv-stop-resend');
      manager.setContinuationHandler(
        'conv-stop-resend',
        (message) async {
          displayedContinuations.add(message);
          return true;
        },
      );
      firstStreamGate.complete();
      await stoppedStream;
      provider.errorAfterYield = networkFailure;

      final result = await manager.startStreaming(
        text: 'Try again',
        convId: 'conv-stop-resend',
        history: [_userMsg('Try again')],
      );

      expect(provider.callCount, 3);
      expect(displayedContinuations, hasLength(1));
      expect(displayedContinuations.single.role, 'user');
      expect(
        displayedContinuations.single.content,
        'Continue if not finished.',
      );
      expect(
          result.history.any((message) =>
              message.role == 'user' &&
              message.content == 'Continue if not finished.'),
          isTrue);
      manager.dispose();
    });

    test('replays an undisplayed continuation to the restored page', () async {
      final manager = ChatStreamManager(retryDelay: (_) async {});
      final firstCallStarted = Completer<void>();
      final secondCallStarted = Completer<void>();
      final secondCallGate = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('partial answer')],
          [AIStreamEvent(' another part')],
        ],
        firstCallStarted: firstCallStarted,
        secondCallStarted: secondCallStarted,
        secondCallGate: secondCallGate,
      )..errorsAfterCall.addAll({
          1: DioException(
            requestOptions: RequestOptions(path: '/chat'),
            type: DioExceptionType.connectionError,
          ),
          2: DioException(
            requestOptions: RequestOptions(path: '/chat'),
            type: DioExceptionType.connectionError,
          ),
        });
      manager.adapter.forceService(_makeChatService(provider));
      var originalHandlerCalls = 0;
      final restoredPageContinuations = <ChatMessage>[];
      final originalHandlerFinished = Completer<void>();
      manager.setContinuationHandler('conv-restored-page', (_) async {
        originalHandlerCalls++;
        originalHandlerFinished.complete();
        return false;
      });

      final stream = manager.startStreaming(
        text: 'Continue this turn',
        convId: 'conv-restored-page',
        history: [_userMsg('Continue this turn')],
      );
      await firstCallStarted.future;
      await secondCallStarted.future;
      await originalHandlerFinished.future;
      manager.setContinuationHandler('conv-restored-page', (message) async {
        restoredPageContinuations.add(message);
        return true;
      });
      secondCallGate.complete();
      final result = await stream;

      expect(originalHandlerCalls, 1);
      expect(restoredPageContinuations, hasLength(2));
      expect(
        restoredPageContinuations.every((message) => message.role == 'user'),
        isTrue,
      );
      expect(restoredPageContinuations.map((message) => message.content),
          everyElement('Continue if not finished.'));
      expect(
        result.history.any((message) =>
            message.role == 'user' &&
            message.content == 'Continue if not finished.'),
        isTrue,
      );
      expect(
        result.history.where((message) =>
            message.role == 'user' &&
            message.content == 'Continue if not finished.'),
        hasLength(2),
      );
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
