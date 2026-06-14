import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';

void main() {
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

      // Should include both without duplicates (they are different fields)
      expect(events.length, 2);
      expect(events.any((e) => e.text == 'OR reasoning...'), isTrue);
      expect(events.any((e) => e.text == 'OpenAI also sending...'), isTrue);
      expect(events.every((e) => e.isReasoning), isTrue);
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
                  'summary':
                      'The model analyzed by identifying constraints...',
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
      expect(events[0].text, 'The model analyzed by identifying constraints...');
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
}
