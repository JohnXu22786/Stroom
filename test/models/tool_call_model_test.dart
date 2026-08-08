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
  });
}
