part of 'chat_service_tools_test.dart';

void chatServiceToolsGroup3() {
  group('Tool definition format per DeepSeek spec', () {
    test('tool definition JSON follows DeepSeek non-thinking mode spec', () {
      final toolDef = ToolDefinition(
        name: 'get_weather',
        description:
            'Get weather of a location, the user should supply a location first.',
        parameters: {
          'type': 'object',
          'properties': {
            'location': {
              'type': 'string',
              'description': 'The city and state, e.g. San Francisco, CA',
            },
          },
          'required': ['location'],
        },
      );

      final json = toolDef.toJson();

      expect(json, containsPair('type', 'function'));
      expect(json['function'], containsPair('name', 'get_weather'));
      expect(json['function'], containsPair('description', isA<String>()));
      expect(json['function'], containsPair('parameters', isA<Map>()));
    });
  });

  group('ChatService - tool message assembly per spec', () {
    test('tool_call_id in tool result matches the assistant tool call id', () {
      const toolCallId = 'call_weather_001';

      final assistantMsg = <String, dynamic>{
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': toolCallId,
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"location": "Hangzhou"}',
            },
          },
        ],
      };

      final toolResultMsg = <String, dynamic>{
        'role': 'tool',
        'tool_call_id': toolCallId,
        'content': '24℃',
      };

      final assistantToolCallId =
          (assistantMsg['tool_calls'] as List).first['id'] as String;
      expect(assistantToolCallId, equals(toolCallId));
      expect(toolResultMsg['tool_call_id'], equals(toolCallId));
      expect(assistantToolCallId, equals(toolResultMsg['tool_call_id']));
    });

    test('multiple tool calls each have matching tool_call_id', () {
      final assistantMsg = <String, dynamic>{
        'role': 'assistant',
        'content': null,
        'tool_calls': [
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
      };

      final toolResults = [
        {'role': 'tool', 'tool_call_id': 'call_weather_001', 'content': '24℃'},
        {'role': 'tool', 'tool_call_id': 'call_time_001', 'content': '12:00'},
      ];

      for (final tc in assistantMsg['tool_calls'] as List) {
        final id = tc['id'] as String;
        final matchingResult =
            toolResults.where((r) => r['tool_call_id'] == id).toList();
        expect(matchingResult.length, equals(1),
            reason:
                'Each tool call $id should have exactly one matching result');
      }
    });
  });
}
