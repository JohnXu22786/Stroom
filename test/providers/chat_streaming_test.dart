// Merged from:
//   - open_router_reasoning_parse_test.dart
//   - streaming_reasoning_content_test.dart
//   - task_provider_json_param_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';

void main() {
  // ====================================================================
  // OpenRouter / OpenAI reasoning parsing (parseStreamEvent)
  // ====================================================================
  group('OpenAICompatibleChatProvider.parseStreamEvent', () {
    // ====================================================================
    // OpenAI standard format: delta.reasoning_content (string)
    // ====================================================================
    test('parses OpenAI standard reasoning_content from delta', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_content': 'Let me think through this...',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events.length, 1);
      expect(events[0].text, 'Let me think through this...');
      expect(events[0].isReasoning, isTrue);
    });

    test('ignores empty reasoning_content', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_content': '',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events, isEmpty);
    });

    test('parses both content and reasoning_content in same delta', () {
      final data = {
        'choices': [
          {
            'delta': {
              'content': 'This is the final answer.',
              'reasoning_content': 'Let me think...',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events.length, 2);
      expect(events[0].text, 'This is the final answer.');
      expect(events[0].isReasoning, isFalse);
      expect(events[1].text, 'Let me think...');
      expect(events[1].isReasoning, isTrue);
    });

    // ====================================================================
    // Open Router standard format: delta.reasoning (string)
    // ====================================================================
    test('parses Open Router reasoning (string) from delta', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning': 'I need to analyze this step by step...',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events.length, 1);
      expect(events[0].text, 'I need to analyze this step by step...');
      expect(events[0].isReasoning, isTrue);
    });

    test('ignores empty reasoning string', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning': '',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events, isEmpty);
    });

    test('parses reasoning alongside reasoning_content in same delta', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning': 'OR reasoning...',
              'reasoning_content': 'OpenAI also sending...',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // Should include both without duplicates (they are different fields
      // with different content)
      expect(events.length, 2);
      expect(events.any((e) => e.text == 'OR reasoning...'), isTrue);
      expect(events.any((e) => e.text == 'OpenAI also sending...'), isTrue);
      expect(events.every((e) => e.isReasoning), isTrue);
    });

    test(
        'deduplicates reasoning when reasoning_content and reasoning have identical text',
        () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning': 'The user said...',
              'reasoning_content': 'The user said...',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // When both fields contain the same text (as OpenRouter does when
      // proxying DeepSeek), only one event should be emitted.
      expect(events.length, 1);
      expect(events[0].text, 'The user said...');
      expect(events[0].isReasoning, isTrue);
    });

    test(
        'deduplicates reasoning across reasoning_details, reasoning, and reasoning_content',
        () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_content': 'Let me think...',
              'reasoning': 'Let me think...',
              'reasoning_details': [
                {
                  'type': 'reasoning.text',
                  'text': 'Let me think...',
                  'id': 'reasoning-text-1',
                  'index': 0,
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // All three fields contain the same text; only one event should be emitted.
      expect(events.length, 1);
      expect(events[0].text, 'Let me think...');
      expect(events[0].isReasoning, isTrue);
    });

    test(
        'deduplicates reasoning_details items when they duplicate string reasoning fields',
        () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_content': 'Step by step...',
              'reasoning_details': [
                {
                  'type': 'reasoning.text',
                  'text': 'Step by step...',
                  'id': 'reasoning-text-1',
                  'index': 0,
                },
                {
                  'type': 'reasoning.summary',
                  'summary': 'Summary...',
                  'id': 'reasoning-summary-1',
                  'index': 1,
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // reasoning_content duplicates with the first reasoning_details item,
      // but summary is different so should still be included.
      expect(events.length, 2);
      expect(events[0].text, 'Step by step...');
      expect(events[0].isReasoning, isTrue);
      expect(events[1].text, 'Summary...');
      expect(events[1].isReasoning, isTrue);
    });

    // ====================================================================
    // Open Router structured format: delta.reasoning_details (array)
    // ====================================================================
    test('parses reasoning_details with reasoning.text type', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_details': [
                {
                  'type': 'reasoning.text',
                  'text': 'Let me reason step by step...',
                  'signature': null,
                  'id': 'reasoning-text-1',
                  'format': 'anthropic-claude-v1',
                  'index': 0,
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events.length, 1);
      expect(events[0].text, 'Let me reason step by step...');
      expect(events[0].isReasoning, isTrue);
    });

    test('parses reasoning_details with reasoning.summary type', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_details': [
                {
                  'type': 'reasoning.summary',
                  'summary': 'The model analyzed by identifying constraints...',
                  'id': 'reasoning-summary-1',
                  'index': 0,
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events.length, 1);
      expect(
          events[0].text, 'The model analyzed by identifying constraints...');
      expect(events[0].isReasoning, isTrue);
    });

    test('skips reasoning_details with reasoning.encrypted type', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_details': [
                {
                  'type': 'reasoning.encrypted',
                  'data': 'eyJlbmNyeXB0ZWQiOiJ0cnVlIn0=',
                  'id': 'reasoning-encrypted-1',
                  'index': 0,
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // Encrypted data is not human-readable, should be skipped
      expect(events, isEmpty);
    });

    test('handles multiple reasoning_details items in one delta', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_details': [
                {
                  'type': 'reasoning.text',
                  'text': 'First reasoning step...',
                  'id': 'reasoning-text-1',
                  'index': 0,
                },
                {
                  'type': 'reasoning.text',
                  'text': 'Second reasoning step...',
                  'id': 'reasoning-text-2',
                  'index': 1,
                },
                {
                  'type': 'reasoning.summary',
                  'summary': 'Summary of reasoning...',
                  'id': 'reasoning-summary-1',
                  'index': 2,
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events.length, 3);
      expect(events[0].text, 'First reasoning step...');
      expect(events[0].isReasoning, isTrue);
      expect(events[1].text, 'Second reasoning step...');
      expect(events[1].isReasoning, isTrue);
      expect(events[2].text, 'Summary of reasoning...');
      expect(events[2].isReasoning, isTrue);
    });

    test('handles mixed reasoning_details, reasoning, and reasoning_content',
        () {
      final data = {
        'choices': [
          {
            'delta': {
              'content': 'Regular content.',
              'reasoning_content': 'OpenAI thinking...',
              'reasoning': 'OR thinking...',
              'reasoning_details': [
                {
                  'type': 'reasoning.text',
                  'text': 'Structured thinking...',
                  'id': 'reasoning-text-1',
                  'index': 0,
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events.length, 4);
      expect(events[0].text, 'Regular content.');
      expect(events[0].isReasoning, isFalse);
      expect(events[1].text, 'OpenAI thinking...');
      expect(events[1].isReasoning, isTrue);
      expect(events[2].text, 'OR thinking...');
      expect(events[2].isReasoning, isTrue);
      expect(events[3].text, 'Structured thinking...');
      expect(events[3].isReasoning, isTrue);
    });

    // ====================================================================
    // Edge cases
    // ====================================================================
    test('returns empty list for data with no choices', () {
      final data = <String, dynamic>{'id': '123', 'object': 'chat.completion'};

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events, isEmpty);
    });

    test('returns empty list for data with empty choices', () {
      final data = <String, dynamic>{'choices': <Map<String, dynamic>>[]};

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events, isEmpty);
    });

    test('returns empty list for data with null delta', () {
      final data = {
        'choices': [
          {'delta': null},
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events, isEmpty);
    });

    test('returns empty list for data with empty delta', () {
      final data = {
        'choices': [
          {'delta': <String, dynamic>{}},
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events, isEmpty);
    });

    test('handles null reasoning_details gracefully', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_details': null,
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events, isEmpty);
    });

    test('handles non-list reasoning_details gracefully', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_details': 'not an array',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      expect(events, isEmpty);
    });

    test('handles reasoning_details item with missing type field', () {
      final data = {
        'choices': [
          {
            'delta': {
              'reasoning_details': [
                {
                  'text': 'Some text but no type field',
                  'id': 'reasoning-unknown-1',
                  'index': 0,
                },
              ],
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(data);

      // Items without a recognized type should be skipped
      expect(events, isEmpty);
    });
  });

  // ====================================================================
  // DeepSeek streaming reasoning -> content sequence
  // ====================================================================
  group('Streaming reasoning content parsing', () {
    // ===================================================================
    // DeepSeek-style streaming: reasoning comes first, then content
    // ===================================================================
    test('parses DeepSeek streaming reasoning_content events', () {
      // Simulate a series of SSE delta chunks as DeepSeek sends them
      // during thinking mode streaming.

      // Chunk 1: Reasoning content starts
      final chunk1 = {
        'choices': [
          {
            'delta': {
              'reasoning_content': 'Let me analyze this problem step by step.',
              'role': 'assistant',
            },
          },
        ],
      };

      // Chunk 2: More reasoning
      final chunk2 = {
        'choices': [
          {
            'delta': {
              'reasoning_content': ' First, I need to understand the question.',
            },
          },
        ],
      };

      // Chunk 3: Still reasoning
      final chunk3 = {
        'choices': [
          {
            'delta': {
              'reasoning_content': ' The key insight here is that...',
            },
          },
        ],
      };

      // Chunk 4: Transition to answer (content starts, reasoning ends)
      final chunk4 = {
        'choices': [
          {
            'delta': {
              'content': 'Here is my answer:',
            },
          },
        ],
      };

      // Chunk 5: More answer content
      final chunk5 = {
        'choices': [
          {
            'delta': {
              'content': ' The answer is 42.',
            },
          },
        ],
      };

      // Parse each chunk
      final events1 = OpenAICompatibleChatProvider.parseStreamEvent(chunk1);
      final events2 = OpenAICompatibleChatProvider.parseStreamEvent(chunk2);
      final events3 = OpenAICompatibleChatProvider.parseStreamEvent(chunk3);
      final events4 = OpenAICompatibleChatProvider.parseStreamEvent(chunk4);
      final events5 = OpenAICompatibleChatProvider.parseStreamEvent(chunk5);

      // Verify reasoning events
      expect(events1.length, 1);
      expect(events1[0].text, 'Let me analyze this problem step by step.');
      expect(events1[0].isReasoning, isTrue);

      expect(events2.length, 1);
      expect(events2[0].text, ' First, I need to understand the question.');
      expect(events2[0].isReasoning, isTrue);

      expect(events3.length, 1);
      expect(events3[0].text, ' The key insight here is that...');
      expect(events3[0].isReasoning, isTrue);

      // Verify text (non-reasoning) events
      expect(events4.length, 1);
      expect(events4[0].text, 'Here is my answer:');
      expect(events4[0].isReasoning, isFalse);

      expect(events5.length, 1);
      expect(events5[0].text, ' The answer is 42.');
      expect(events5[0].isReasoning, isFalse);
    });

    test('reasoning and content never appear in same event for DeepSeek format',
        () {
      // DeepSeek format: reasoning_content and content are never both
      // non-null in the same delta
      final chunk = {
        'choices': [
          {
            'delta': {
              'reasoning_content': 'Thinking...',
              'content': null,
              'role': 'assistant',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(chunk);

      expect(events.length, 1);
      expect(events[0].isReasoning, isTrue);
      expect(events[0].text, 'Thinking...');
    });

    test('handles initial delta with only role and empty content', () {
      // DeepSeek sends first chunk with role=assistant, content=""
      final chunk = {
        'choices': [
          {
            'delta': {
              'content': '',
              'role': 'assistant',
            },
          },
        ],
      };

      final events = OpenAICompatibleChatProvider.parseStreamEvent(chunk);

      // Empty content should not produce any events
      expect(events, isEmpty);
    });

    test('handles multiple reasoning content chunks sequentially', () {
      // Simulate a full streaming sequence
      final chunks = [
        {
          'choices': [
            {
              'delta': {'content': '', 'role': 'assistant'}
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {'reasoning_content': 'Step 1: '}
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {'reasoning_content': 'analyze'}
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {'reasoning_content': ' data.'}
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {'content': 'Sure!'}
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {'content': ' Here is'}
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {'content': ' the answer.'}
            },
          ],
        },
      ];

      final allEvents = chunks
          .map(OpenAICompatibleChatProvider.parseStreamEvent)
          .expand((e) => e)
          .toList();

      // First chunk has no events (empty content)
      // Chunks 2-4 are reasoning
      // Chunks 5-7 are text content

      expect(allEvents.length, 6);
      expect(allEvents[0].isReasoning, isTrue);
      expect(allEvents[0].text, 'Step 1: ');
      expect(allEvents[1].isReasoning, isTrue);
      expect(allEvents[1].text, 'analyze');
      expect(allEvents[2].isReasoning, isTrue);
      expect(allEvents[2].text, ' data.');
      expect(allEvents[3].isReasoning, isFalse);
      expect(allEvents[3].text, 'Sure!');
      expect(allEvents[4].isReasoning, isFalse);
      expect(allEvents[4].text, ' Here is');
      expect(allEvents[5].isReasoning, isFalse);
      expect(allEvents[5].text, ' the answer.');
    });

    test('reasoning content sections are properly accumulated across chunks',
        () {
      // Simulate how the ChatService accumulates reasoning content
      String reasoningBuffer = '';

      final chunks = [
        {'reasoning_content': 'I need to think'},
        {'reasoning_content': ' about this problem'},
        {'reasoning_content': ' carefully.'},
        {'content': 'The answer is:'},
        {'content': ' 42.'},
      ];

      // Simulate the accumulation logic
      final reasoningEvents = <AIStreamEvent>[];
      final textEvents = <AIStreamEvent>[];

      for (final chunk in chunks) {
        final data = {
          'choices': [
            {'delta': chunk},
          ],
        };
        final events = OpenAICompatibleChatProvider.parseStreamEvent(data);
        for (final event in events) {
          if (event.isReasoning) {
            reasoningBuffer += event.text;
            reasoningEvents.add(event);
          } else if (event.text.isNotEmpty) {
            textEvents.add(event);
          }
        }
      }

      // Verify the accumulated reasoning
      expect(reasoningBuffer, 'I need to think about this problem carefully.');
      expect(reasoningEvents.length, 3);
      expect(textEvents.length, 2);

      // After the first text event arrives, reasoning is complete
      final reasoningComplete =
          textEvents.isNotEmpty && reasoningBuffer.isNotEmpty;
      expect(reasoningComplete, isTrue,
          reason:
              'When text events arrive after reasoning, reasoning should be complete');
    });

    test('no reasoning section shown when only text content is streamed', () {
      // Provider should not show any reasoning section for text-only response
      final chunks = <Map<String, String>>[
        {'content': 'Hello'},
        {'content': ' world!'},
      ];

      final allEvents = chunks
          .map((chunk) {
            final data = {
              'choices': [
                {'delta': chunk},
              ],
            };
            return OpenAICompatibleChatProvider.parseStreamEvent(data);
          })
          .expand((e) => e)
          .toList();

      expect(allEvents.length, 2);
      expect(allEvents.every((e) => e.isReasoning == false), isTrue,
          reason:
              'No reasoning events should be present for text-only response');
    });
  });

  // ====================================================================
  // TaskListNotifier.parseJsonCustomParams - JSON type handling
  // ====================================================================
  group('TaskListNotifier.parseJsonCustomParams - JSON type handling', () {
    test('JSON string value is parsed to Map when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'response_format': '{"type": "json_object"}',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'response_format',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      final responseFormat = params['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'JSON type param should be a Map, not a String');
      expect((responseFormat as Map)['type'], equals('json_object'));
    });

    test('JSON string value is parsed to List when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'tools_config': '["tool_a", "tool_b"]',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'tools_config',
            defaultValue: '["tool_a", "tool_b"]',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      final toolsConfig = params['tools_config'];
      expect(toolsConfig, isA<List>(),
          reason: 'JSON type param (array) should be a List, not a String');
      expect((toolsConfig as List).length, equals(2));
      expect(toolsConfig[0], equals('tool_a'));
    });

    test('Invalid JSON string falls back to raw string for json type', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'bad_json': '{invalid json}',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'bad_json',
            defaultValue: '{invalid json}',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      // Malformed JSON should return the raw string
      expect(params['bad_json'], equals('{invalid json}'));
    });

    test('Non-JSON type params are NOT parsed', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'top_k': '50',
        'use_cache': 'true',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(paramName: 'top_k', defaultValue: '50', type: 'number'),
          CustomParam(
              paramName: 'use_cache', defaultValue: 'true', type: 'boolean'),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      // Number and boolean type params should NOT be parsed by this function
      expect(params['top_k'], equals('50'),
          reason: 'number type param should remain as string');
      expect(params['use_cache'], equals('true'),
          reason: 'boolean type param should remain as string');
    });

    test('Empty string is kept as empty string for json type', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'empty_json': '',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'empty_json',
            defaultValue: '',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      expect(params['empty_json'], equals(''));
    });

    test('Params with names not in modelConfig.customParams are kept as-is',
        () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'unknown_param': '{"some": "json"}',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        // No custom params defined in config
        customParams: [],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      // Without type info, the param should remain unchanged
      expect(params['unknown_param'], equals('{"some": "json"}'));
    });

    test('Already-parsed Map values are not double-parsed', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'response_format': {'type': 'json_object'},
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'response_format',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      // Already a Map, should remain unchanged
      final responseFormat = params['response_format'];
      expect(responseFormat, isA<Map>());
      expect((responseFormat as Map)['type'], equals('json_object'));
    });

    test('JSON number string is parsed to num when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'temperature': '0.8',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'temperature',
            defaultValue: '0.8',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      final value = params['temperature'];
      expect(value, isA<num>(),
          reason: 'JSON number string should be parsed to num');
      expect((value as num), closeTo(0.8, 0.001));
    });

    test('JSON boolean string is parsed to bool when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'flag': 'true',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'flag',
            defaultValue: 'true',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      expect(params['flag'], isTrue,
          reason: 'JSON boolean string should be parsed to bool');
    });

    test('JSON null string is parsed to null when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'nullable': 'null',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'nullable',
            defaultValue: 'null',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      expect(params['nullable'], isNull,
          reason: 'JSON null string should be parsed to null');
    });

    test('Multiple JSON params are all parsed correctly', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'config_a': '{"type": "json_object"}',
        'config_b': '["item1", "item2"]',
        'count': '42',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'config_a',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
          CustomParam(
            paramName: 'config_b',
            defaultValue: '["item1", "item2"]',
            type: 'json',
          ),
          CustomParam(
            paramName: 'count',
            defaultValue: '42',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      expect(params['config_a'], isA<Map>());
      expect(params['config_b'], isA<List>());
      expect(params['count'], isA<num>());
      expect((params['count'] as num), equals(42));
    });

    test('Complex nested JSON object is parsed correctly', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'config': '{"nested": {"key": "value", "list": [1, 2, 3]}}',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'config',
            defaultValue: '{"nested": {"key": "value", "list": [1, 2, 3]}}',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      final config = params['config'];
      expect(config, isA<Map>());
      expect((config as Map)['nested']['key'], equals('value'));
      expect((config['nested']['list'] as List).length, equals(3));
    });

    test('Null params map is handled without crash', () {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'response_format',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
        ],
      );

      // Should not throw when params is null
      expect(
        () => TaskListNotifier.parseJsonCustomParams(null, modelConfig),
        returnsNormally,
      );
    });

    test('ModelConfig with no custom params is handled without crash', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'some_param': 'value',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
      );

      // Should not throw when customParams is empty
      expect(
        () => TaskListNotifier.parseJsonCustomParams(params, modelConfig),
        returnsNormally,
      );
      expect(params['some_param'], equals('value'));
    });
  });
}
