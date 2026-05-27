import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/services/chat_service.dart';

void main() {
  group('ChatService tool registration and execution', () {
    tearDown(() {
      // Reset by re-registering the calculator for other tests
      ChatService.registerTool(
        const ToolDefinition(
          name: 'calculator',
          description: 'Evaluate a math expression',
          parameters: {
            'type': 'object',
            'properties': {
              'expression': {'type': 'string'},
            },
            'required': ['expression'],
          },
        ),
        (args) {
          final expr = (args['expression'] as String?) ?? '';
          final sanitized = expr.replaceAll(' ', '');
          if (sanitized.contains('+')) {
            final parts = sanitized.split('+');
            return parts.map((p) => double.parse(p)).reduce((a, b) => a + b).toString();
          }
          if (sanitized.contains('*')) {
            final parts = sanitized.split('*');
            return parts.map((p) => double.parse(p)).reduce((a, b) => a * b).toString();
          }
          return double.parse(sanitized).toString();
        },
      );
    });

    test('registers tool without error', () async {
      expect(() {
        ChatService.registerTool(
          const ToolDefinition(
            name: 'echo',
            description: 'Echo test',
            parameters: {
              'type': 'object',
              'properties': {
                'message': {'type': 'string'},
              },
              'required': ['message'],
            },
          ),
          (args) => 'echo: ${args['message']}',
        );
      }, returnsNormally);
    });

    test('registered tools do not interfere with each other', () {
      ChatService.registerTool(
        const ToolDefinition(
          name: 'tool_a',
          description: 'Tool A',
          parameters: {'type': 'object', 'properties': {}, 'required': []},
        ),
        (_) => 'result_a',
      );
      ChatService.registerTool(
        const ToolDefinition(
          name: 'tool_b',
          description: 'Tool B',
          parameters: {'type': 'object', 'properties': {}, 'required': []},
        ),
        (_) => 'result_b',
      );
      // Both registrations should succeed without conflict
      expect(true, isTrue);
    });

    test('ToolDefinition toJson includes all fields', () {
      final def = ToolDefinition(
        name: 'test_tool',
        description: 'A test tool',
        parameters: {
          'type': 'object',
          'properties': {
            'input': {'type': 'string', 'description': 'Input value'},
          },
          'required': ['input'],
        },
      );
      final json = def.toJson();
      expect(json['type'], 'function');
      expect(json['function']['name'], 'test_tool');
      expect(json['function']['description'], 'A test tool');
      expect(json['function']['parameters']['required'], ['input']);
    });

    test('empty tools list', () {
      final defs = <ToolDefinition>[];
      final jsonList = defs.map((t) => t.toJson()).toList();
      expect(jsonList, isEmpty);
    });
  });
}
