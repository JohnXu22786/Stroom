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
}
