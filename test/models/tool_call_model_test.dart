import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  group('ToolDefinition - per DeepSeek/OpenRouter spec', () {
    test('toJson produces correct OpenAI-compatible format', () {
      // Both DeepSeek and OpenRouter follow the OpenAI tool definition format:
      // {
      //   "type": "function",
      //   "function": {
      //     "name": "...",
      //     "description": "...",
      //     "parameters": {...}
      //   }
      // }
      final def = ToolDefinition(
        name: 'get_weather',
        description: 'Get weather of a location',
        parameters: {
          'type': 'object',
          'properties': {
            'location': {
              'type': 'string',
              'description': 'City name',
            },
          },
          'required': ['location'],
        },
      );

      final json = def.toJson();

      // Verify top-level structure
      expect(json['type'], equals('function'));
      expect(json['function'], isA<Map<String, dynamic>>());

      // Verify function structure
      final fn = json['function'] as Map<String, dynamic>;
      expect(fn['name'], equals('get_weather'));
      expect(fn['description'], equals('Get weather of a location'));

      // Verify parameters follow JSON Schema
      final params = fn['parameters'] as Map<String, dynamic>;
      expect(params['type'], equals('object'));
      expect(params['properties']['location']['type'], equals('string'));
      expect(params['required'], equals(['location']));
    });

    test('toJson matches DeepSeek tool definition example exactly', () {
      // DeepSeek's tool calling guide shows this exact format:
      // https://api-docs.deepseek.com/guides/tool_calls
      final def = ToolDefinition(
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

      final json = def.toJson();

      // Verify matches DeepSeek example structure
      expect(json['type'], equals('function'));
      expect(json['function']['name'], equals('get_weather'));
      expect(
          json['function']['description'],
          equals(
              'Get weather of a location, the user should supply a location first.'));
      expect(json['function']['parameters']['type'], equals('object'));
      expect(json['function']['parameters']['properties']['location']['type'],
          equals('string'));
      expect(json['function']['parameters']['required'], equals(['location']));
    });

    test('toJson matches OpenRouter tool definition example', () {
      // OpenRouter's tool calling guide shows this exact format:
      // https://openrouter.ai/docs/guides/features/tool-calling
      final def = ToolDefinition(
        name: 'search_gutenberg_books',
        description: 'Search for books in the Project Gutenberg library',
        parameters: {
          'type': 'object',
          'properties': {
            'search_terms': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'List of search terms to find books',
            },
          },
          'required': ['search_terms'],
        },
      );

      final json = def.toJson();

      // Verify matches OpenRouter example structure
      expect(json['type'], equals('function'));
      expect(json['function']['name'], equals('search_gutenberg_books'));
      expect(json['function']['parameters']['type'], equals('object'));
      expect(
          json['function']['parameters']['properties']['search_terms']['type'],
          equals('array'));
      expect(
          json['function']['parameters']['properties']['search_terms']['items']
              ['type'],
          equals('string'));
      expect(
          json['function']['parameters']['required'], equals(['search_terms']));
    });

    test('ToolCallData copyWith preserves fields per spec', () {
      final data = ToolCallData(
        id: 'call_abc123',
        name: 'get_weather',
        arguments: {'location': 'Hangzhou'},
      );

      // Initial state matches spec
      expect(data.id, equals('call_abc123'));
      expect(data.name, equals('get_weather'));
      expect(data.arguments, equals({'location': 'Hangzhou'}));
      expect(data.status, equals(ToolCallStatus.pending));
      expect(data.result, isNull);

      // Update status to running
      final running = data.copyWith(status: ToolCallStatus.running);
      expect(running.status, equals(ToolCallStatus.running));
      expect(running.id, equals('call_abc123')); // unchanged

      // Update with result
      final completed = running.copyWith(
        status: ToolCallStatus.completed,
        result: '24℃',
      );
      expect(completed.status, equals(ToolCallStatus.completed));
      expect(completed.result, equals('24℃'));
      expect(completed.name, equals('get_weather')); // unchanged
      expect(
          completed.arguments, equals({'location': 'Hangzhou'})); // unchanged
    });
  });

  group('Tool call JSON round-trip - DeepSeek streaming format', () {
    test('tool call from stream delta can be deserialized', () {
      // Simulate the JSON that comes from a DeepSeek streaming delta
      // after accumulation (the final tool_calls format, not individual deltas)
      final streamJson = '''
      {
        "id": "call_weather_001",
        "type": "function",
        "function": {
          "name": "get_weather",
          "arguments": "{\\"location\\": \\"Hangzhou\\"}"
        }
      }
      ''';

      final tc = jsonDecode(streamJson) as Map<String, dynamic>;

      expect(tc['id'], equals('call_weather_001'));
      expect(tc['type'], equals('function'));
      expect(tc['function']['name'], equals('get_weather'));
      expect(tc['function']['arguments'], equals('{"location": "Hangzhou"}'));

      // This is the exact format consumed by chat_service.dart
      final fn = tc['function'] as Map<String, dynamic>;
      final rawArgs = fn['arguments'] as String;
      final parsedArgs = jsonDecode(rawArgs) as Map<String, dynamic>;
      expect(parsedArgs['location'], equals('Hangzhou'));
    });

    test('tool call arguments are valid JSON per spec', () {
      // DeepSeek spec: arguments must be valid JSON string
      final validArgs = [
        '{"location": "Hangzhou"}',
        '{}',
        '{"items": [1, 2, 3]}',
        '{"nested": {"key": "value"}}',
        '{"empty": "", "null_val": null, "bool": true, "num": 42}',
      ];

      for (final args in validArgs) {
        expect(() => jsonDecode(args), returnsNormally,
            reason: 'Arguments should be valid JSON: $args');
      }
    });
  });
}
