import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/services/chat_service.dart';

void main() {
  group('ChatService - Built-in tools listing', () {
    setUp(() {
      // Reset static state by re-registering known tools
      // (Static state persists across tests, so we just verify
      //  the getter works with whatever is registered.)
    });

    test('getRegisteredToolDefinitions returns all registered tools', () {
      // Register test tools
      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_tool_1',
          description: 'Test tool 1',
          parameters: {'type': 'object'},
        ),
        (args) => 'result_1',
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_tool_2',
          description: 'Test tool 2',
          parameters: {'type': 'object'},
        ),
        (args) => 'result_2',
      );

      final defs = ChatService.getRegisteredToolDefinitions();
      final names = defs.map((d) => d.name).toSet();

      // Should contain both test tools (calculator is also registered by default)
      expect(names, contains('test_tool_1'));
      expect(names, contains('test_tool_2'));
    });

    test('registered tool definitions have correct structure', () {
      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_calc',
          description: 'A calculator',
          parameters: {
            'type': 'object',
            'properties': {
              'expr': {'type': 'string'},
            },
            'required': ['expr'],
          },
        ),
        (args) => '0',
      );

      final defs = ChatService.getRegisteredToolDefinitions();
      final calc =
          defs.where((d) => d.name == 'test_calc').firstOrNull;
      expect(calc, isNotNull);
      expect(calc!.name, equals('test_calc'));
      expect(calc.description, equals('A calculator'));
      expect(calc.parameters['type'], equals('object'));
      expect(
        (calc.parameters['properties'] as Map)['expr']['type'],
        equals('string'),
      );
    });

    test('getRegisteredToolDefinitions does not throw when empty', () {
      // This should always return something since calculator is registered
      // in chat_page initState, but the getter should be safe.
      expect(() => ChatService.getRegisteredToolDefinitions(), returnsNormally);
    });
  });
}
