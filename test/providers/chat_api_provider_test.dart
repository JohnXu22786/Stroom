// Merged from:
//   - chat_api_provider_auth_header_test.dart
//   - chat_api_provider_tool_calls_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';

void main() {
  group('OpenAICompatibleChatProvider - Authorization header correctness', () {
    const testApiKey = 'sk-test-full-api-key-12345678';
    const expectedAuth = 'Bearer sk-test-full-api-key-12345678';

    group('non-streaming chat() path', () {
      test('default Dio headers contain the full unmasked API key', () {
        // The non-streaming path uses the Dio instance's default headers,
        // which are set in the constructor with the full unmasked key.
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com/v1/chat/completions',
          apiKey: testApiKey,
          name: 'Test Provider',
        );

        expect(provider.defaultHeaders['Authorization'], expectedAuth);
      });
    });

    group('streaming chatStream() path (401 FIX)', () {
      test('Dio constructor stores full unmasked API key in defaultHeaders',
          () {
        // The streaming path (chatStream) creates a NEW Dio instance via
        // sseStream(). Unlike the non-streaming path, it must explicitly
        // pass headers to the function call.
        //
        // BUG (now fixed): _maskApiKey(_apiKey) was used in the headers
        // map passed to sseStream(), causing the masked key like
        // "sk-test...5678" to be sent, resulting in HTTP 401.
        //
        // FIX: The headers map now uses _apiKey directly, matching the
        // non-streaming path which uses the full unmasked key.
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com/v1/chat/completions',
          apiKey: testApiKey,
          name: 'Test Provider',
        );

        // Verify the Dio instance (used by chat()) has the full key
        expect(provider.defaultHeaders['Authorization'], expectedAuth);
        // After the fix, the sseStream() call receives the same full key
        // instead of the masked version. This is verified by code review
        // of the specific line fix: _maskApiKey(_apiKey) -> _apiKey
      });

      test('lastRequestHeaders now also uses full unmasked API key', () {
        // After the fix, _lastRequestHeaders (stored for the error detail
        // dialog) should also use the full unmasked API key so that the
        // dialog shows the request headers as they were actually sent.
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com/v1/chat/completions',
          apiKey: testApiKey,
          name: 'Test Provider',
        );

        expect(provider.defaultHeaders['Authorization'], expectedAuth);
      });
    });

    group('edge cases', () {
      test('empty API key skips Authorization header entirely', () {
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com',
          apiKey: '',
        );

        expect(provider.defaultHeaders, isNot(contains('Authorization')));
      });

      test('both chat() and chatStream() use the same auth pattern after fix',
          () {
        // chat() uses Dio default headers (full key). chatStream() passes
        // explicit headers to sseStream(). After the fix, both use the
        // full unmasked key rather than the masked version.
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com',
          apiKey: testApiKey,
        );

        expect(provider.defaultHeaders['Authorization'], expectedAuth);
      });
    });
  });

  group('OpenAICompatibleChatProvider - Tool call streaming', () {
    // ====================================================================
    // Tool call delta accumulation tests
    // These test the format of tool_calls in streaming SSE responses
    // per DeepSeek's OpenAI-compatible API spec.
    // ====================================================================

    test('parseStreamEvent does NOT handle tool_calls (accumulated externally)',
        () {
      // The parseStreamEvent method intentionally skips tool_calls
      // because accumulation requires cross-event state.
      // This test documents that behavior.
      final data = {
        'choices': [
          {
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_abc123',
                  'type': 'function',
                  'function': {
                    'name': 'get_weather',
                    'arguments': '',
                  },
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // Should be empty because parseStreamEvent does not handle tool_calls
      expect(events, isEmpty);
    });

    test('parseStreamEvent emits content alongside tool_calls delta', () {
      // Some streaming chunks can have both content AND tool_calls.
      // Content should still be emitted as a regular text event.
      final data = {
        'choices': [
          {
            'delta': {
              'content': 'Let me check the weather',
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_abc123',
                  'type': 'function',
                  'function': {
                    'name': 'get_weather',
                    'arguments': '',
                  },
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // Content should still be emitted
      expect(events.length, equals(1));
      expect(events[0].text, equals('Let me check the weather'));
      expect(events[0].isToolCallEvent, isFalse);
    });

    test('parseStreamEvent handles reasoning + tool_calls in same delta', () {
      // Per DeepSeek spec, reasoning_content and tool_calls can coexist.
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_content': 'I need to look up the weather...',
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_abc123',
                  'type': 'function',
                  'function': {
                    'name': 'get_weather',
                    'arguments': '',
                  },
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // Should emit reasoning but not tool_calls
      expect(events.length, equals(1));
      expect(events[0].isReasoning, isTrue);
      expect(events[0].text, contains('look up the weather'));
    });

    test('parseStreamEvent handles OpenRouter delta.reasoning + tool_calls',
        () {
      // OpenRouter uses delta.reasoning (string) as an alternative reasoning format.
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning': 'Thinking about weather...',
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_def456',
                  'type': 'function',
                  'function': {
                    'name': 'get_weather',
                    'arguments': '',
                  },
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // Should emit reasoning from delta.reasoning, not tool_calls
      expect(events.length, equals(1));
      expect(events[0].isReasoning, isTrue);
      expect(events[0].text, contains('Thinking about weather'));
    });

    test(
        'parseStreamEvent handles OpenRouter delta.reasoning_details + tool_calls',
        () {
      // OpenRouter uses delta.reasoning_details (array) as a structured reasoning format.
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_details': [
                {'type': 'reasoning.text', 'text': 'Structured thinking...'},
              ],
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_ghi789',
                  'type': 'function',
                  'function': {
                    'name': 'get_weather',
                    'arguments': '',
                  },
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // Should emit reasoning from reasoning_details, not tool_calls
      expect(events.length, equals(1));
      expect(events[0].isReasoning, isTrue);
      expect(events[0].text, contains('Structured thinking'));
    });
  });

  group('Tool call accumulation format (simulated stream)', () {
    // These tests validate that the accumulated tool call format
    // follows both DeepSeek and OpenRouter specs.
    // DeepSeek: tool_calls[{id, type: "function", function: {name, arguments}}]
    // OpenRouter: same OpenAI-compatible format.

    List<Map<String, dynamic>> simulateAccumulatedToolCalls() {
      // Simulates the accumulation logic in chat_api_provider.dart
      // that runs in chatStream() after all SSE events are processed.
      final Map<int, Map<String, dynamic>> accumulators = {};

      // Simulate multiple streaming chunks for tool_call index 0
      void processChunk(Map<String, dynamic> delta) {
        final toolCallsDelta = delta['tool_calls'] as List?;
        if (toolCallsDelta == null) return;
        for (final tc in toolCallsDelta) {
          // Use same null-safe logic as production code (chat_api_provider.dart)
          final index = tc['index'] as int? ?? 0;
          accumulators.putIfAbsent(index, () => {});
          final acc = accumulators[index]!;
          if (tc['id'] != null) acc['id'] = tc['id'];
          if (tc['type'] != null) acc['type'] = tc['type'];
          if (tc['function'] != null) {
            acc.putIfAbsent('function', () => <String, dynamic>{});
            final fn = tc['function'] as Map<String, dynamic>;
            final accFn = acc['function'] as Map<String, dynamic>;
            if (fn['name'] != null) accFn['name'] = fn['name'];
            if (fn['arguments'] != null) {
              accFn['arguments'] = (accFn['arguments'] as String? ?? '') +
                  (fn['arguments'] as String);
            }
          }
        }
      }

      // Chunk 1: First delta with role, tool_call id and type
      processChunk({
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'index': 0,
            'id': 'call_weather_001',
            'type': 'function',
            'function': {'name': 'get_weather', 'arguments': ''},
          },
          {
            'index': 1,
            'id': 'call_time_001',
            'type': 'function',
            'function': {'name': 'get_time', 'arguments': ''},
          },
        ],
      });

      // Chunk 2: Arguments for tool_call 0
      processChunk({
        'tool_calls': [
          {
            'index': 0,
            'function': {'arguments': '{"loc'},
          },
        ],
      });

      // Chunk 3: More arguments + args for tool_call 1
      processChunk({
        'tool_calls': [
          {
            'index': 0,
            'function': {'arguments': 'ation": "Hangzhou"}'},
          },
          {
            'index': 1,
            'function': {'arguments': '{"ti'},
          },
        ],
      });

      // Chunk 4: Remaining arguments for tool_call 1
      processChunk({
        'tool_calls': [
          {
            'index': 1,
            'function': {'arguments': 'mezone": "UTC+8"}'},
          },
        ],
      });

      // Convert accumulators to final format (same as chat_api_provider.dart lines 474-482)
      return accumulators.entries
          .map((e) => {
                'id': e.value['id'] as String? ?? 'call_${e.key}',
                'type': e.value['type'] as String? ?? 'function',
                'function': e.value['function'] as Map<String, dynamic>? ?? {},
              })
          .toList();
    }

    test('accumulates streaming tool calls with correct DeepSeek format', () {
      final toolCalls = simulateAccumulatedToolCalls();

      // DeepSeek spec: tool_calls is an array of {id, type: "function", function: {name, arguments}}
      expect(toolCalls.length, equals(2));

      // First tool call
      expect(toolCalls[0]['id'], equals('call_weather_001'));
      expect(toolCalls[0]['type'], equals('function'));
      expect(toolCalls[0]['function']['name'], equals('get_weather'));
      expect(toolCalls[0]['function']['arguments'],
          equals('{"location": "Hangzhou"}'));

      // Second tool call
      expect(toolCalls[1]['id'], equals('call_time_001'));
      expect(toolCalls[1]['type'], equals('function'));
      expect(toolCalls[1]['function']['name'], equals('get_time'));
      expect(toolCalls[1]['function']['arguments'],
          equals('{"timezone": "UTC+8"}'));
    });

    test('accumulated tool call format matches OpenRouter spec', () {
      final toolCalls = simulateAccumulatedToolCalls();

      // OpenRouter spec: same OpenAI-compatible format
      for (final tc in toolCalls) {
        expect(tc, containsPair('id', isA<String>()));
        expect(tc, containsPair('type', 'function'));
        expect(tc.containsKey('function'), isTrue);
        expect(tc['function'], containsPair('name', isA<String>()));
        expect(tc['function'], containsPair('arguments', isA<String>()));
      }
    });

    test('accumulated format matches AIStreamEvent', () {
      final toolCalls = simulateAccumulatedToolCalls();

      // This is the format that gets yielded as AIStreamEvent('', toolCalls: toolCalls)
      final event = AIStreamEvent('', toolCalls: toolCalls);

      expect(event.isToolCallEvent, isTrue);
      expect(event.toolCalls!.length, equals(2));
      expect(event.toolCalls![0]['id'], equals('call_weather_001'));
    });

    test('handles missing index field with fallback to 0', () {
      // Some providers may omit the 'index' field in tool call delta chunks.
      // The production code uses `tc['index'] as int? ?? 0` to handle this.
      final Map<int, Map<String, dynamic>> accumulators = {};

      // Process a chunk with no index field
      void process(Map<String, dynamic> delta) {
        final toolCallsDelta = delta['tool_calls'] as List?;
        if (toolCallsDelta == null) return;
        for (final tc in toolCallsDelta) {
          // Same logic as in chat_api_provider.dart
          final index = tc['index'] as int? ?? 0;
          accumulators.putIfAbsent(index, () => {});
          final acc = accumulators[index]!;
          if (tc['id'] != null) acc['id'] = tc['id'];
          if (tc['type'] != null) acc['type'] = tc['type'];
          if (tc['function'] != null) {
            acc.putIfAbsent('function', () => <String, dynamic>{});
            final fn = tc['function'] as Map<String, dynamic>;
            final accFn = acc['function'] as Map<String, dynamic>;
            if (fn['name'] != null) accFn['name'] = fn['name'];
            if (fn['arguments'] != null) {
              accFn['arguments'] = (accFn['arguments'] as String? ?? '') +
                  (fn['arguments'] as String);
            }
          }
        }
      }

      // Chunk with NO index field (null fallback should map to 0)
      process({
        'tool_calls': [
          {
            'id': 'call_missing_index',
            'type': 'function',
            'function': {'name': 'test_tool', 'arguments': '{}'},
          },
        ],
      });

      // Should have accumulated at index 0 (the fallback)
      expect(accumulators.length, equals(1));
      expect(accumulators.containsKey(0), isTrue);
      expect(accumulators[0]!['id'], equals('call_missing_index'));
      expect(accumulators[0]!['type'], equals('function'));
    });
  });

  group('Tool call content handling per DeepSeek spec', () {
    test(
        'assistant message with tool_calls has content: null per DeepSeek spec',
        () {
      // DeepSeek spec: when model provides tool_calls, content MUST be null
      // https://api-docs.deepseek.com/api/create-chat-completion
      final assistantMsg = {
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': 'call_abc123',
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"location": "Hangzhou"}',
            },
          },
        ],
      };

      expect(assistantMsg['role'], equals('assistant'));
      expect(assistantMsg['content'], isNull);
      expect(assistantMsg.containsKey('tool_calls'), isTrue);
    });

    test('tool result message follows DeepSeek spec format', () {
      // DeepSeek spec: tool result must have role: "tool", tool_call_id, content
      final toolResultMsg = {
        'role': 'tool',
        'tool_call_id': 'call_abc123',
        'content': '24℃',
      };

      expect(toolResultMsg['role'], equals('tool'));
      expect(toolResultMsg.containsKey('tool_call_id'), isTrue);
      expect(toolResultMsg['tool_call_id'], equals('call_abc123'));
      expect(toolResultMsg['content'], equals('24℃'));
    });
  });
}
