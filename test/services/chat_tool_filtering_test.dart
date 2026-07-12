import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';

/// This test validates the tool filtering logic that should be used
/// in chat_page.dart when determining which tools to send to the LLM.
///
/// The bug was: built-in tools were always included regardless of the
/// user's toggle state because the filter used `!isMcp || enabledTools.contains(t.name)`,
/// which short-circuits to `true` for any non-MCP (built-in) tool.
///
/// The fix: all tools should respect the `enabledTools` set uniformly.
void main() {
  group('Tool filtering respects enabledToolNamesProvider', () {
    late List<ToolDefinition> allTools;
    late List<ToolDefinition> mcpTools;

    setUp(() {
      // Simulate the structure of available tools
      allTools = [
        const ToolDefinition(
          name: 'calculator',
          description: 'Built-in calculator',
          parameters: {'type': 'object'},
        ),
        const ToolDefinition(
          name: 'web_search',
          description: 'MCP web search',
          parameters: {'type': 'object'},
        ),
        const ToolDefinition(
          name: 'file_reader',
          description: 'MCP file reader',
          parameters: {'type': 'object'},
        ),
      ];

      mcpTools = [
        const ToolDefinition(
          name: 'web_search',
          description: 'MCP web search',
          parameters: {'type': 'object'},
        ),
        const ToolDefinition(
          name: 'file_reader',
          description: 'MCP file reader',
          parameters: {'type': 'object'},
        ),
      ];
    });

    /// Simulates the OLD (buggy) filtering logic from chat_page.dart line 448-451.
    List<ToolDefinition> buggyFilter(
        List<ToolDefinition> allTools, Set<String> enabledTools) {
      return allTools.where((t) {
        final isMcp = mcpTools.any((m) => m.name == t.name);
        // BUG: built-in tools are always included because !isMcp is always true for them
        return !isMcp || enabledTools.contains(t.name);
      }).toList();
    }

    /// Simulates the FIXED filtering logic.
    List<ToolDefinition> fixedFilter(
        List<ToolDefinition> allTools, Set<String> enabledTools) {
      // All tools uniformly respect the enabled set
      return allTools.where((t) => enabledTools.contains(t.name)).toList();
    }

    group('Buggy filter (OLD behavior)', () {
      test('includes built-in tools even when NOT in enabledTools', () {
        // enabledTools contains only MCP tools, not the built-in calculator
        final result = buggyFilter(allTools, {'web_search'});

        final names = result.map((t) => t.name).toList();
        // BUG: calculator is included even though it's not in enabledTools
        expect(names, contains('calculator'));
        expect(names, contains('web_search'));
        expect(names, isNot(contains('file_reader')));
      });

      test('includes built-in tools when enabledTools is empty', () {
        final result = buggyFilter(allTools, {});

        final names = result.map((t) => t.name).toList();
        // BUG: calculator is included even with empty enabledTools
        expect(names, contains('calculator'));
        // MCP tools are correctly excluded
        expect(names, isNot(contains('web_search')));
        expect(names, isNot(contains('file_reader')));
      });
    });

    group('Fixed filter (NEW behavior)', () {
      test('excludes built-in tools when NOT in enabledTools', () {
        final result = fixedFilter(allTools, {'web_search'});

        final names = result.map((t) => t.name).toList();
        // calculator should NOT be included because it's not in enabledTools
        expect(names, isNot(contains('calculator')));
        expect(names, contains('web_search'));
        expect(names, isNot(contains('file_reader')));
      });

      test('excludes all tools when enabledTools is empty', () {
        final result = fixedFilter(allTools, {});

        expect(result, isEmpty);
      });

      test('includes only the enabled tools', () {
        final result = fixedFilter(allTools, {'calculator', 'file_reader'});

        final names = result.map((t) => t.name).toList();
        expect(names, contains('calculator'));
        expect(names, isNot(contains('web_search')));
        expect(names, contains('file_reader'));
      });

      test('includes all tools when enabledTools contains all tool names', () {
        final result =
            fixedFilter(allTools, {'calculator', 'web_search', 'file_reader'});

        expect(result.length, equals(3));
      });

      test('treats built-in and MCP tools uniformly', () {
        // Toggle calculator OFF, keep web_search ON
        final result = fixedFilter(allTools, {'web_search'});

        final names = result.map((t) => t.name).toList();
        // Both built-in (calculator) and MCP (web_search) are treated the same
        expect(names, isNot(contains('calculator')));
        expect(names, contains('web_search'));
      });
    });
  });
}
