import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/aws_bedrock_converse.dart';

void main() {
  group('AwsBedrockConverseAdapter', () {
    test('maps chat turns, inference options, tools and tool results', () {
      final body = AwsBedrockConverseAdapter.toConverse({
        'messages': [
          {'role': 'system', 'content': 'Be concise.'},
          {'role': 'user', 'content': 'Add 2 and 3.'},
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'id': 'call-1',
                'type': 'function',
                'function': {'name': 'add', 'arguments': '{"a":2,"b":3}'},
              },
            ],
          },
          {'role': 'tool', 'tool_call_id': 'call-1', 'content': '5'},
        ],
        'max_tokens': 123,
        'temperature': 0.25,
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'add',
              'description': 'Add two numbers.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'a': {'type': 'integer'},
                  'b': {'type': 'integer'},
                },
              },
            },
          },
        ],
        'tool_choice': 'auto',
      });

      expect(body['system'], [
        {'text': 'Be concise.'},
      ]);
      expect(body['messages'], [
        {
          'role': 'user',
          'content': [
            {'text': 'Add 2 and 3.'},
          ],
        },
        {
          'role': 'assistant',
          'content': [
            {
              'toolUse': {
                'toolUseId': 'call-1',
                'name': 'add',
                'input': {'a': 2, 'b': 3},
              },
            },
          ],
        },
        {
          'role': 'user',
          'content': [
            {
              'toolResult': {
                'toolUseId': 'call-1',
                'content': [
                  {'text': '5'},
                ],
              },
            },
          ],
        },
      ]);
      expect(body['inferenceConfig'], {'maxTokens': 123, 'temperature': 0.25});
      expect(body['toolConfig'], isA<Map>());
    });

    test('groups consecutive tool results into one Bedrock user turn', () {
      final body = AwsBedrockConverseAdapter.toConverse({
        'messages': [
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'id': 'call-1',
                'function': {'name': 'first', 'arguments': '{}'},
              },
              {
                'id': 'call-2',
                'function': {'name': 'second', 'arguments': '{}'},
              },
            ],
          },
          {'role': 'tool', 'tool_call_id': 'call-1', 'content': 'one'},
          {'role': 'tool', 'tool_call_id': 'call-2', 'content': 'two'},
        ],
      });

      expect(body['messages'], [
        {
          'role': 'assistant',
          'content': [
            {
              'toolUse': {
                'toolUseId': 'call-1',
                'name': 'first',
                'input': <String, dynamic>{},
              },
            },
            {
              'toolUse': {
                'toolUseId': 'call-2',
                'name': 'second',
                'input': <String, dynamic>{},
              },
            },
          ],
        },
        {
          'role': 'user',
          'content': [
            {
              'toolResult': {
                'toolUseId': 'call-1',
                'content': [
                  {'text': 'one'},
                ],
              },
            },
            {
              'toolResult': {
                'toolUseId': 'call-2',
                'content': [
                  {'text': 'two'},
                ],
              },
            },
          ],
        },
      ]);
    });

    test(
      'maps Converse text, tool use and usage to Chat Completions shape',
      () {
        final response = AwsBedrockConverseAdapter.fromConverse({
          'output': {
            'message': {
              'role': 'assistant',
              'content': [
                {'text': '5'},
                {
                  'toolUse': {
                    'toolUseId': 'call-1',
                    'name': 'add',
                    'input': {'a': 2, 'b': 3},
                  },
                },
              ],
            },
          },
          'stopReason': 'tool_use',
          'usage': {'inputTokens': 9, 'outputTokens': 4},
        });

        expect(response['choices'], [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': '5',
              'tool_calls': [
                {
                  'id': 'call-1',
                  'type': 'function',
                  'function': {'name': 'add', 'arguments': '{"a":2,"b":3}'},
                },
              ],
            },
            'finish_reason': 'tool_calls',
          },
        ]);
        expect(response['usage'], {'prompt_tokens': 9, 'completion_tokens': 4});
      },
    );
  });
}
