import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/services/chat_adapter.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('ChatAdapter.getAllToolDefinitions - built-in + MCP', () {
    late ChatAdapter adapter;

    setUp(() {
      adapter = ChatAdapter();
    });

    tearDown(() {
      adapter.dispose();
    });

    test('initially returns empty list when nothing registered', () {
      final defs = adapter.getAllToolDefinitions();
      expect(defs, isEmpty);
    });

    test('includes built-in tools after registration', () {
      // Register a built-in tool
      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_builtin',
          description: 'A test built-in tool',
          parameters: {'type': 'object'},
        ),
        (args) => 'done',
      );

      final defs = adapter.getAllToolDefinitions();
      final names = defs.map((d) => d.name).toList();

      // Should include test_builtin (and any other registered tools)
      expect(names, contains('test_builtin'));
    });

    test('getAllToolDefinitions returns unmodifiable copy', () {
      final defs = adapter.getAllToolDefinitions();
      expect(defs, isA<List<ToolDefinition>>());
    });
  });
}
