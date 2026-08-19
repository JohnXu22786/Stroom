import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/pages/chat/chat_types.dart';

void main() {
  group('pruneUnselectableToolNames', () {
    final selectable = [
      const ToolDefinition(
        name: 'web_search',
        description: '',
        parameters: {},
      ),
    ];

    test('drops enabled names that are no longer selectable', () {
      final result = pruneUnselectableToolNames(
        enabledNames: {'web_search', 'exa_mcp'},
        selectableTools: selectable,
      );

      expect(result, {'web_search'},
          reason: '总开关关闭后，隐藏的 MCP 工具不再计入徽标计数'
              '（运行时启用集与已保存偏好保持不变，仅展示层过滤）');
    });

    test('keeps selectable names untouched', () {
      final result = pruneUnselectableToolNames(
        enabledNames: {'web_search', 'todowrite'},
        selectableTools: [
          ...selectable,
          const ToolDefinition(
            name: 'todowrite',
            description: '',
            parameters: {},
          ),
        ],
      );

      expect(result, {'web_search', 'todowrite'});
    });

    test('empty selectable list prunes everything', () {
      final result = pruneUnselectableToolNames(
        enabledNames: {'web_search', 'exa_mcp'},
        selectableTools: const [],
      );

      expect(result, isEmpty);
    });

    test('empty enabled set stays empty', () {
      final result = pruneUnselectableToolNames(
        enabledNames: const {},
        selectableTools: selectable,
      );

      expect(result, isEmpty);
    });
  });
}
