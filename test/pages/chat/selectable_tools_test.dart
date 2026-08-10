import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/pages/chat/chat_types.dart';

void main() {
  group('selectableToolsForAssistant', () {
    final builtins = [
      const ToolDefinition(
        name: 'web_search',
        description: '',
        parameters: {},
      ),
      const ToolDefinition(
        name: 'todowrite',
        description: '',
        parameters: {},
      ),
    ];
    final mcpTools = [
      const ToolDefinition(
        name: 'exa_mcp',
        description: 'Exa MCP search tool',
        parameters: {},
      ),
      const ToolDefinition(
        name: 'tavily_mcp',
        description: 'Tavily MCP search tool',
        parameters: {},
      ),
    ];

    test('visible=true keeps all tools (builtins + MCP)', () {
      final result = selectableToolsForAssistant(
        allTools: [...builtins, ...mcpTools],
        mcpTools: mcpTools,
        mcpToolsVisible: true,
      );

      expect(
        result.map((t) => t.name).toList(),
        ['web_search', 'todowrite', 'exa_mcp', 'tavily_mcp'],
      );
    });

    test('visible=false filters MCP placeholder tools only', () {
      final result = selectableToolsForAssistant(
        allTools: [...builtins, ...mcpTools],
        mcpTools: mcpTools,
        mcpToolsVisible: false,
      );

      expect(
        result.map((t) => t.name).toList(),
        ['web_search', 'todowrite'],
        reason: '显示开关关闭后 MCP 工具不能出现在对话页（无法选择使用）',
      );
    });

    test('visible=false with no MCP tools keeps all builtins', () {
      final result = selectableToolsForAssistant(
        allTools: builtins,
        mcpTools: const [],
        mcpToolsVisible: false,
      );

      expect(result.map((t) => t.name).toList(), ['web_search', 'todowrite']);
    });

    test('visible=false with empty allTools returns empty', () {
      final result = selectableToolsForAssistant(
        allTools: const [],
        mcpTools: mcpTools,
        mcpToolsVisible: false,
      );

      expect(result, isEmpty);
    });

    test('result does not alias the input list', () {
      final all = [...builtins, ...mcpTools];
      final result = selectableToolsForAssistant(
        allTools: all,
        mcpTools: mcpTools,
        mcpToolsVisible: false,
      );

      expect(identical(result, all), isFalse);
      // 原列表未被修改
      expect(all.length, 4);
    });
  });

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
          reason: '显示开关/总开关关闭后，隐藏的 MCP 工具不再计入徽标计数'
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
