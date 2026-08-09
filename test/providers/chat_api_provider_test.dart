// Merged from:
//   - chat_api_provider_auth_header_test.dart
//   - chat_api_provider_tool_calls_test.dart
import 'package:flutter_test/flutter_test.dart';
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

    group('edge cases', () {
      test('empty API key skips Authorization header entirely', () {
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com',
          apiKey: '',
        );

        expect(provider.defaultHeaders, isNot(contains('Authorization')));
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

  group('throwIfApiError (stream error chunk)', () {
    test('error map 抛出异常', () {
      expect(
        () => OpenAICompatibleChatProvider.throwIfApiError({
          'error': {'message': 'rate limit exceeded'},
        }),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'msg', contains('rate limit exceeded'))),
      );
    });

    test('无 error 字段不抛', () {
      expect(
        () => OpenAICompatibleChatProvider.throwIfApiError({
          'choices': [
            {
              'delta': {'content': 'ok'}
            }
          ],
        }),
        returnsNormally,
      );
      expect(
        () => OpenAICompatibleChatProvider.throwIfApiError({
          'error': 'not-a-map',
        }),
        returnsNormally,
      );
    });
  });
}
