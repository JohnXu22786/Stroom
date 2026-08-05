part of 'chat_service_tools_test.dart';

void chatServiceToolsGroup2() {
  // ====================================================================
  // From chat_service_tool_chain_format_test.dart
  // ====================================================================

  group('ChatService.sendStreamWithTools - tool chain format compliance', () {
    late ChatService service;
    late _MockToolCallProvider mockProvider;

    setUp(() {
      mockProvider = _MockToolCallProvider([]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test(
        'tool call chain produces ToolCallStart, ToolCallComplete, then TextEvent',
        () async {
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_weather_001',
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"location": "Hangzhou"}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      // Register a tool handler
      ChatService.registerTool(
        const ToolDefinition(
          name: 'get_weather',
          description: 'Get weather',
          parameters: {
            'type': 'object',
            'properties': {
              'location': {'type': 'string'},
            },
            'required': ['location'],
          },
        ),
        (args) => '24°C',
      );

      final events = <ChatEvent>[];
      final history = [
        ChatMessage(role: 'user', content: 'What is the weather in Hangzhou?'),
      ];

      await service
          .sendStreamWithTools(
            'What is the weather in Hangzhou?',
            history: history,
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(
            (event) => events.add(event),
            onError: (e) => fail('Unexpected error: $e'),
          )
          .asFuture();

      // Expect: ReasoningSectionEndEvent (between rounds), ToolCallStartEvent,
      // ToolCallCompleteEvent, then TextEvent (from round 2)
      expect(events.length, equals(4));

      // The ReasoningSectionEndEvent is emitted between tool call rounds
      // to signal the UI to split reasoning chains.
      expect(events[0], isA<ReasoningSectionEndEvent>(),
          reason:
              'ReasoningSectionEndEvent is emitted between tool call rounds');

      // Verify event sequence and types
      expect(events[1], isA<ToolCallStartEvent>());
      expect(events[2], isA<ToolCallCompleteEvent>());
      expect(events[3], isA<TextEvent>());

      // Verify tool call start event
      final toolStart = events[1] as ToolCallStartEvent;
      expect(toolStart.toolCall.id, equals('call_weather_001'));
      expect(toolStart.toolCall.name, equals('get_weather'));
      expect(toolStart.toolCall.arguments, equals({'location': 'Hangzhou'}));
      expect(toolStart.toolCall.status, equals(ToolCallStatus.running));

      // Verify tool call complete event
      final toolComplete = events[2] as ToolCallCompleteEvent;
      expect(toolComplete.toolCallId, equals('call_weather_001'));
      expect(toolComplete.result, equals('24°C'));

      // Verify final text event
      final textEvent = events[3] as TextEvent;
      expect(textEvent.text, contains('24°C'));
    });

    test('tool call chain respects loop protection (max 10 iterations)',
        () async {
      mockProvider = _MockToolCallProvider(
        List.generate(
            15,
            (i) => [
                  {
                    'id': 'call_loop_$i',
                    'type': 'function',
                    'function': {
                      'name': 'loop_tool',
                      'arguments': '{"iteration": $i}',
                    },
                  },
                ]),
      );
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );
      // 配置 maxToolCalls=10：与测试名一致（此前缺失导致循环无上限）
      service.setAssistantSettings(
        AssistantSettings(maxToolCalls: 10, enableMaxToolCalls: true),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'loop_tool',
          description: 'Test tool for loop protection',
          parameters: {
            'type': 'object',
            'properties': {
              'iteration': {'type': 'integer'},
            },
            'required': ['iteration'],
          },
        ),
        (args) => 'result',
      );

      final events = <ChatEvent>[];
      final history = [
        ChatMessage(role: 'user', content: 'Test loop protection'),
      ];

      await service
          .sendStreamWithTools(
            'Test loop protection',
            history: history,
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(
            (event) => events.add(event),
            onError: (e) => fail('Unexpected error: $e'),
          )
          .asFuture();

      // maxToolCalls=10：最多 10 轮工具调用 + 1 轮收尾轮
      // （收尾轮 tools 已禁用，但 mock 不尊重禁用仍返回工具调用，
      // 循环在总轮数（maxRounds+1）处强制退出）
      final toolStartEvents = events.whereType<ToolCallStartEvent>().toList();
      expect(toolStartEvents.length, lessThanOrEqualTo(11));
      // Should have at least 1 tool call since mock always returns tool calls
      expect(toolStartEvents.length, greaterThan(0));
    });

    test('assistant message with tool_calls has content:null per DeepSeek spec',
        () async {
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_test_001',
            'type': 'function',
            'function': {
              'name': 'test_tool',
              'arguments': '{}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_tool',
          description: 'Test tool',
          parameters: {'type': 'object'},
        ),
        (args) => 'done',
      );

      await service
          .sendStreamWithTools(
            'test',
            history: [ChatMessage(role: 'user', content: 'test')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .drain();

      // The second chatStream call has the assistant+tool messages appended.
      // lastStreamMessages is set by the mock on the LAST call (the text response call).
      // The tool messages were appended to messages before the second call.
      final lastMessages = mockProvider.lastStreamMessages;
      expect(lastMessages, isNotNull);

      // Find the assistant message with tool_calls
      final assistantWithToolCalls = lastMessages!.where(
          (m) => m['role'] == 'assistant' && m.containsKey('tool_calls'));
      expect(assistantWithToolCalls, isNotEmpty,
          reason: 'Should have at least one assistant message with tool_calls');

      for (final msg in assistantWithToolCalls) {
        expect(msg['content'], isNull,
            reason:
                'DeepSeek spec: assistant message with tool_calls must have content: null');
        expect(msg['tool_calls'], isA<List>());
      }

      // Find the tool result messages
      final toolResults = lastMessages.where((m) => m['role'] == 'tool');
      expect(toolResults, isNotEmpty,
          reason: 'Should have at least one tool result message');
      for (final msg in toolResults) {
        expect(msg.containsKey('tool_call_id'), isTrue,
            reason: 'DeepSeek spec: tool message must have tool_call_id');
        expect(msg.containsKey('content'), isTrue,
            reason: 'DeepSeek spec: tool message must have content');
      }
    });

    test(
        'multiple parallel tool calls produce ONE assistant message per DeepSeek spec',
        () async {
      // DeepSeek spec: ALL tool_calls in a single assistant message,
      // not separate assistant messages per tool call.
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_weather_001',
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"location": "Hangzhou"}',
            },
          },
          {
            'id': 'call_time_001',
            'type': 'function',
            'function': {
              'name': 'get_time',
              'arguments': '{"timezone": "UTC+8"}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'get_weather',
          description: 'Get weather',
          parameters: {'type': 'object'},
        ),
        (args) => '24°C',
      );
      ChatService.registerTool(
        const ToolDefinition(
          name: 'get_time',
          description: 'Get time',
          parameters: {'type': 'object'},
        ),
        (args) => '12:00',
      );

      await service
          .sendStreamWithTools(
            'test',
            history: [ChatMessage(role: 'user', content: 'test')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .drain();

      // The last stream call has the assistant + tool results appended
      final lastMessages = mockProvider.lastStreamMessages;
      expect(lastMessages, isNotNull);

      // Should have exactly ONE assistant message with tool_calls,
      // not separate messages per tool call
      final assistantWithToolCalls = lastMessages!.where(
          (m) => m['role'] == 'assistant' && m.containsKey('tool_calls'));
      expect(assistantWithToolCalls.length, equals(1),
          reason:
              'DeepSeek spec: ALL tool_calls must be in ONE assistant message');

      final oneAssistant = assistantWithToolCalls.first;
      final toolCallsList = oneAssistant['tool_calls'] as List;
      expect(toolCallsList.length, equals(2),
          reason: 'All 2 tool calls should be in a single assistant message');

      // Verify both tool calls are present
      final ids = toolCallsList.map((tc) => tc['id'] as String).toSet();
      expect(ids, contains('call_weather_001'));
      expect(ids, contains('call_time_001'));

      // Should have exactly 2 tool result messages
      final toolResults = lastMessages.where((m) => m['role'] == 'tool');
      expect(toolResults.length, equals(2));
    });

    test(
        'assistant message with tool_calls has content:null per OpenAI-compatible spec',
        () async {
      // OpenAI-compatible spec (followed by DeepSeek, OpenRouter):
      // assistant message with tool_calls has content: null
      // and tool_calls: [{id, type: "function", function: {name, arguments}}]
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_test_001',
            'type': 'function',
            'function': {
              'name': 'test_tool',
              'arguments': '{}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_tool',
          description: 'Test tool',
          parameters: {'type': 'object'},
        ),
        (args) => 'done',
      );

      await service
          .sendStreamWithTools(
            'test',
            history: [ChatMessage(role: 'user', content: 'test')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .drain();

      final lastMessages = mockProvider.lastStreamMessages;
      expect(lastMessages, isNotNull);

      final assistantWithToolCalls = lastMessages!.where(
          (m) => m['role'] == 'assistant' && m.containsKey('tool_calls'));

      // Each assistant message should have content: null when tool_calls present
      for (final msg in assistantWithToolCalls) {
        expect(msg['content'], isNull,
            reason:
                'OpenAI-compatible spec: assistant message with tool_calls has content: null');
        expect(msg['tool_calls'], isA<List>());
      }
    });

    test(
        'multiple tool calls execute in parallel (both start before any completes)',
        () async {
      // Requirement: when the assistant triggers multiple tool calls at once,
      // they must run SIMULTANEOUSLY, not one after another.
      // Sequential execution yields: Start(A), Complete(A), Start(B), Complete(B).
      // Parallel execution yields:   Start(A), Start(B), Complete(A), Complete(B).
      // Both Start events are emitted synchronously before any async handler
      // can finish, so this ordering is deterministic.
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_par_a',
            'type': 'function',
            'function': {
              'name': 'parallel_slow_a',
              'arguments': '{}',
            },
          },
          {
            'id': 'call_par_b',
            'type': 'function',
            'function': {
              'name': 'parallel_slow_b',
              'arguments': '{}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'parallel_slow_a',
          description: 'Slow tool A',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'result_a';
        },
      );
      ChatService.registerTool(
        const ToolDefinition(
          name: 'parallel_slow_b',
          description: 'Slow tool B',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'result_b';
        },
      );

      final events = <ChatEvent>[];
      await service
          .sendStreamWithTools(
            'test',
            history: [ChatMessage(role: 'user', content: 'test')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(
            (event) => events.add(event),
            onError: (e) => fail('Unexpected error: $e'),
          )
          .asFuture();

      final starts = events
          .whereType<ToolCallStartEvent>()
          .map((e) => e.toolCall.id)
          .toList();
      final completes = events
          .whereType<ToolCallCompleteEvent>()
          .map((e) => e.toolCallId)
          .toList();

      expect(starts, ['call_par_a', 'call_par_b'],
          reason: 'Both tool calls must be started.');
      expect(completes, ['call_par_a', 'call_par_b'],
          reason: 'Results must be reported in declaration order '
              '(Anthropic requires tool_result blocks ordered like tool_use blocks).');

      // The core parallel assertion: the second Start event must arrive
      // BEFORE the first Complete event. With sequential execution this
      // ordering is impossible (Complete(A) would precede Start(B)).
      final eventsAfterFilteringEnd =
          events.where((e) => e is! ReasoningSectionEndEvent).toList();
      expect(eventsAfterFilteringEnd[0], isA<ToolCallStartEvent>());
      expect(eventsAfterFilteringEnd[1], isA<ToolCallStartEvent>(),
          reason: 'Second tool call must START before the first completes — '
              'tools must run in parallel, not sequentially.');
      expect(eventsAfterFilteringEnd[2], isA<ToolCallCompleteEvent>());
      expect(eventsAfterFilteringEnd[3], isA<ToolCallCompleteEvent>());

      // Both results must be preserved.
      final results = events
          .whereType<ToolCallCompleteEvent>()
          .map((e) => e.result)
          .toList();
      expect(results, ['result_a', 'result_b']);
    });

    test('a failing tool among parallel tools does not abort the others',
        () async {
      // One tool throws, the other succeeds: the failing tool's result is
      // 'Error: ...', the other still completes, and both results are sent
      // back to the model in declaration order.
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_fail_1',
            'type': 'function',
            'function': {
              'name': 'parallel_fail_a',
              'arguments': '{}',
            },
          },
          {
            'id': 'call_ok_2',
            'type': 'function',
            'function': {
              'name': 'parallel_ok_b',
              'arguments': '{}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'parallel_fail_a',
          description: 'Failing tool',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          throw Exception('boom');
        },
      );
      ChatService.registerTool(
        const ToolDefinition(
          name: 'parallel_ok_b',
          description: 'OK tool',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return 'ok_result';
        },
      );

      final events = <ChatEvent>[];
      await service
          .sendStreamWithTools(
            'test',
            history: [ChatMessage(role: 'user', content: 'test')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(
            (event) => events.add(event),
            onError: (e) => fail('Unexpected error: $e'),
          )
          .asFuture();

      final completes = events
          .whereType<ToolCallCompleteEvent>()
          .map((e) => (e.toolCallId, e.result))
          .toList();
      expect(completes.length, 2);
      expect(completes[0].$1, 'call_fail_1');
      expect(completes[0].$2, startsWith('Error:'));
      expect(completes[1].$1, 'call_ok_2');
      expect(completes[1].$2, 'ok_result');
    });

    test(
        'cancelling during parallel execution stops cleanly (no complete events)',
        () async {
      // User taps Stop while tools are still running: the stream must end
      // without emitting ToolCallCompleteEvent and without hanging or
      // throwing. The already-started tool futures are abandoned safely
      // (_runTool never throws → no unhandled async errors).
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_cancel_1',
            'type': 'function',
            'function': {
              'name': 'cancel_slow_a',
              'arguments': '{}',
            },
          },
          {
            'id': 'call_cancel_2',
            'type': 'function',
            'function': {
              'name': 'cancel_slow_b',
              'arguments': '{}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'cancel_slow_a',
          description: 'Slow tool',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return 'a';
        },
      );
      ChatService.registerTool(
        const ToolDefinition(
          name: 'cancel_slow_b',
          description: 'Slow tool',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return 'b';
        },
      );

      final events = <ChatEvent>[];
      final sub = service
          .sendStreamWithTools(
            'test',
            history: [ChatMessage(role: 'user', content: 'test')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(
            (event) => events.add(event),
            onError: (e) => fail('Unexpected error: $e'),
          );
      // Cancel shortly after the start events are emitted (handlers still
      // running — deterministic: starts are synchronous, handlers take 200ms).
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.cancel();

      await sub.asFuture().timeout(const Duration(seconds: 5),
          onTimeout: () => fail('Stream did not complete after cancel'));

      expect(events.whereType<ToolCallStartEvent>().length, 2,
          reason: 'Both tools must have started before cancel.');
      expect(events.whereType<ToolCallCompleteEvent>(), isEmpty,
          reason: 'No complete events after cancel.');
    });

    test(
        'cancel then immediately resend: old round must not disturb the new request',
        () async {
      // The cancel→resend race: while round 1's tools are still running the
      // user cancels and immediately sends a new message. _isCancelledByUser
      // is reset by the new send, so the old round must terminate via its
      // controller.isClosed guard — otherwise it would cancel the new
      // request's _cancelToken/_streamSubscription (aborting or hanging the
      // new stream) and fire a ghost, billed provider request.
      mockProvider = _MockToolCallProvider([
        // Round 1 (old send): 2 slow tool calls
        const [
          {
            'id': 'call_resend_1',
            'type': 'function',
            'function': {
              'name': 'resend_slow_a',
              'arguments': '{}',
            },
          },
          {
            'id': 'call_resend_2',
            'type': 'function',
            'function': {
              'name': 'resend_slow_b',
              'arguments': '{}',
            },
          },
        ],
        // Round 2 (new send): immediate text response
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'resend_slow_a',
          description: 'Slow tool',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return 'a';
        },
      );
      ChatService.registerTool(
        const ToolDefinition(
          name: 'resend_slow_b',
          description: 'Slow tool',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return 'b';
        },
      );

      final events1 = <ChatEvent>[];
      final sub1 = service
          .sendStreamWithTools(
            'first message',
            history: [ChatMessage(role: 'user', content: 'first message')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(
            (event) => events1.add(event),
            onError: (e) => fail('Unexpected error in first stream: $e'),
          );

      // Let the start events fire (synchronous), then cancel while the
      // 200ms tool handlers are still running.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.cancel();

      // Immediately resend: provider call #2 yields an immediate text reply.
      final events2 = <ChatEvent>[];
      final sub2 = service
          .sendStreamWithTools(
            'second message',
            history: [ChatMessage(role: 'user', content: 'second message')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(
            (event) => events2.add(event),
            onError: (e) => fail('Unexpected error in second stream: $e'),
          );

      await sub1.asFuture().timeout(const Duration(seconds: 5),
          onTimeout: () => fail('First stream did not complete'));
      await sub2.asFuture().timeout(const Duration(seconds: 5),
          onTimeout: () => fail(
              'Second stream hung — the old round likely cancelled the new request'));

      // The old round: both tools started, no completions (cancelled).
      expect(events1.whereType<ToolCallStartEvent>().length, 2);
      expect(events1.whereType<ToolCallCompleteEvent>(), isEmpty);
      // The new send must complete normally with its text reply.
      expect(events2.whereType<TextEvent>(), isNotEmpty,
          reason: 'New request must not be disturbed by the old round.');
      expect(events2.whereType<ToolCallStartEvent>(), isEmpty,
          reason: 'The new round has no tool calls in this mock.');
    });
  });
}
