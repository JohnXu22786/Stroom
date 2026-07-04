import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';

void main() {
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
}
