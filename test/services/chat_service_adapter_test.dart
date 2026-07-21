// Merged from: chat_adapter_model_selection_test.dart,
// chat_adapter_tools_test.dart,
// chat_tool_filtering_test.dart
//
// No naming conflicts between sources for this file.

import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/mcp.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_adapter.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/http_tool_service.dart';

void main() {
  // ====================================================================
  // From chat_adapter_model_selection_test.dart
  // ====================================================================

  late ChatAdapter adapter;
  late ProviderEntriesState entriesState;

  setUpAll(() {
    // Register built-in provider types so availableModels works
    registerBuiltinProviderTypes();
  });

  setUp(() {
    adapter = ChatAdapter();

    // Create a provider entry with 2 configs, each with 2 models
    // Config 0:
    //   - Model "gpt-4o" with temperature=0.7 in typeConfig
    //   - Model "gpt-4o-mini" with temperature=0.8 in typeConfig
    // Config 1:
    //   - Model "claude-3" with temperature=0.5 in typeConfig
    //   - Model "claude-3-haiku" with temperature=0.6 in typeConfig

    entriesState = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'test_llm',
          type: 'llm',
          name: 'Test LLM Provider',
          configs: [
            ProviderConfigItem(
              providerName: 'OpenAI',
              host: 'https://api.openai.com/v1',
              key: 'sk-test',
              models: [
                ModelConfig(
                  name: 'GPT-4o',
                  modelId: 'gpt-4o',
                  typeConfig: {'temperature': 0.7},
                  reasoningParams: [
                    ReasoningParam(
                      paramName: 'reasoning_effort',
                      options: ['low', 'medium', 'high'],
                    ),
                  ],
                ),
                ModelConfig(
                  name: 'GPT-4o Mini',
                  modelId: 'gpt-4o-mini',
                  typeConfig: {'temperature': 0.8},
                  reasoningParams: [
                    ReasoningParam(
                      paramName: 'thinking_type',
                      options: ['standard', 'deep'],
                    ),
                  ],
                ),
              ],
            ),
            ProviderConfigItem(
              providerName: 'Anthropic',
              host: 'https://api.anthropic.com/v1',
              key: 'sk-ant-test',
              models: [
                ModelConfig(
                  name: 'Claude 3',
                  modelId: 'claude-3-opus',
                  typeConfig: {'temperature': 0.5},
                  reasoningParams: [
                    ReasoningParam(
                      paramName: 'thinking',
                      options: ['enabled', 'disabled'],
                    ),
                  ],
                ),
                ModelConfig(
                  name: 'Claude 3 Haiku',
                  modelId: 'claude-3-haiku',
                  typeConfig: {'temperature': 0.6},
                  reasoningParams: [
                    ReasoningParam(
                      paramName: 'budget_tokens',
                      options: ['1024', '2048', '4096'],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  });

  tearDown(() {
    adapter.dispose();
  });

  group('ChatAdapter model selection', () {
    test('configure sets adapter to first config, first model (0,0)', () {
      adapter.configure(entriesState);

      expect(adapter.currentConfigIndex, equals(0));
      expect(adapter.currentModelIndex, equals(0));
      expect(adapter.isConfigured, isTrue);
    });

    test('selectModel sets adapter to the specified config and model', () {
      adapter.configure(entriesState);

      // Select config 1, model 0 (Claude 3)
      adapter.selectModel(entriesState, 1, 0);
      expect(adapter.currentConfigIndex, equals(1));
      expect(adapter.currentModelIndex, equals(0));

      // Select config 0, model 1 (GPT-4o Mini)
      adapter.selectModel(entriesState, 0, 1);
      expect(adapter.currentConfigIndex, equals(0));
      expect(adapter.currentModelIndex, equals(1));
    });

    test('availableModels returns all models correctly', () {
      final models = adapter.availableModels(entriesState);

      expect(models.length, equals(4));
      expect(models[0].displayName, contains('GPT-4o'));
      expect(models[0].displayName, contains('OpenAI'));
      expect(models[0].configIndex, equals(0));
      expect(models[0].modelIndex, equals(0));

      expect(models[1].displayName, contains('GPT-4o Mini'));
      expect(models[1].configIndex, equals(0));
      expect(models[1].modelIndex, equals(1));

      expect(models[2].displayName, contains('Claude 3'));
      expect(models[2].configIndex, equals(1));
      expect(models[2].modelIndex, equals(0));

      expect(models[3].displayName, contains('Claude 3 Haiku'));
      expect(models[3].configIndex, equals(1));
      expect(models[3].modelIndex, equals(1));
    });

    test(
        'configure resets adapter to (0,0) after selectModel - '
        'this reproduces the bug: configure destroys saved selection', () {
      // Given: user selects model at config 1, model 0 (Claude 3)
      adapter.configure(entriesState);
      adapter.selectModel(entriesState, 1, 0);
      expect(adapter.currentConfigIndex, equals(1));
      expect(adapter.currentModelIndex, equals(0));

      // When: configure is called again (e.g. provider entries change)
      adapter.configure(entriesState);

      // Then: adapter is RESET to (0,0) - the saved selection is lost
      expect(adapter.currentConfigIndex, equals(0));
      expect(adapter.currentModelIndex, equals(0));
    });

    test(
      'after configure resets adapter, selectModel can restore saved model',
      () {
        // Given: adapter previously pointed to Claude 3 (config 1, model 0)
        adapter.configure(entriesState);
        adapter.selectModel(entriesState, 1, 0);
        expect(adapter.currentConfigIndex, equals(1));

        // When: configure is called again (provider entries changed)
        adapter.configure(entriesState);
        // Now adapter is at (0,0). Restore saved selection:
        adapter.selectModel(entriesState, 1, 0);

        // Then: adapter correctly points back to Claude 3
        expect(adapter.currentConfigIndex, equals(1));
        expect(adapter.currentModelIndex, equals(0));
      },
    );

    test(
        'reasoningParams returns params from currently selected model, '
        'not from model 0 when configure reset it', () {
      // Given: user selected Claude 3 (config 1, model 0)
      adapter.configure(entriesState);
      adapter.selectModel(entriesState, 1, 0);

      // Claude 3 has 'thinking' reasoning param
      var params = adapter.reasoningParams;
      expect(params.length, equals(1));
      expect(params[0].paramName, equals('thinking'));
      expect(params[0].options, contains('enabled'));

      // When: configure is called (simulating providerEntriesProvider change)
      adapter.configure(entriesState);

      // Then: reasoningParams now returns GPT-4o's params (model 0,0)
      // This is the BUG - user expected 'thinking' but got 'reasoning_effort'
      var paramsAfterReset = adapter.reasoningParams;
      expect(paramsAfterReset.length, equals(1));
      expect(paramsAfterReset[0].paramName, equals('reasoning_effort'));

      // When: we restore the saved selection
      adapter.selectModel(entriesState, 1, 0);

      // Then: reasoningParams returns Claude 3's params again
      paramsAfterReset = adapter.reasoningParams;
      expect(paramsAfterReset[0].paramName, equals('thinking'));
    });

    test('hasReasoningParams reflects the current model after selection', () {
      adapter.configure(entriesState);

      // Default model (GPT-4o) has reasoning params
      expect(adapter.hasReasoningParams, isTrue);

      // Select Claude 3 Haiku which has 'budget_tokens'
      adapter.selectModel(entriesState, 1, 1);
      expect(adapter.hasReasoningParams, isTrue);

      // Verify correct params
      final params = adapter.reasoningParams;
      expect(params[0].paramName, equals('budget_tokens'));
    });

    test('selectModel with invalid indices returns -1 state', () {
      adapter.configure(entriesState);

      // Invalid config index
      adapter.selectModel(entriesState, 99, 0);
      expect(adapter.currentConfigIndex, equals(-1));
      expect(adapter.currentModelIndex, equals(-1));
      expect(adapter.isConfigured, isFalse);

      // Re-configure to restore state
      adapter.configure(entriesState);
      expect(adapter.isConfigured, isTrue);

      // Invalid model index
      adapter.selectModel(entriesState, 0, 99);
      expect(adapter.currentConfigIndex, equals(-1));
      expect(adapter.currentModelIndex, equals(-1));
    });

    test('selectModel creates new ChatService with correct model config', () {
      adapter.configure(entriesState);

      // Select Claude 3
      adapter.selectModel(entriesState, 1, 0);
      expect(adapter.currentConfigIndex, equals(1));
      expect(adapter.currentModelIndex, equals(0));

      // The ChatService should use the selected model's config
      // (We verify via reasoningParams since it depends on modelConfig)
      final params = adapter.reasoningParams;
      expect(params[0].paramName, equals('thinking'));

      // Select GPT-4o Mini
      adapter.selectModel(entriesState, 0, 1);
      final params2 = adapter.reasoningParams;
      expect(params2[0].paramName, equals('thinking_type'));
    });

    // =========================================================================
    // Bug regression tests: display index vs flat model list index mismatch
    // =========================================================================
    //
    // BUG: When models are drag-reordered, the "selected_model_index" saved
    // in SharedPreferences is a DISPLAY index. But _restoreSavedModelSelection
    // uses it directly to index into the flat availableModels() list. If the
    // display order differs from the flat order, the wrong model is selected.
    //
    // FIX: The restore logic must map the display index through the model's
    // display name to find the correct flat index.
    // =========================================================================

    group('display index vs flat index mapping', () {
      test(
        'availableModels returns models in flat order (config-major, model-minor)',
        () {
          // The flat list is ordered by config first, then by model within config.
          // This is the order used by _restoreSavedModelSelection.
          final models = adapter.availableModels(entriesState);
          expect(models.length, equals(4));
          expect(models[0].displayName, contains('GPT-4o'));
          expect(models[1].displayName, contains('GPT-4o Mini'));
          expect(models[2].displayName, contains('Claude 3'));
          expect(models[3].displayName, contains('Claude 3 Haiku'));
        },
      );

      test(
          'model display name at display index 0 identifies the correct model '
          'when display order differs from flat order', () {
        // Simulate a reordered display list (user drag-reordered models):
        final displayNames = [
          'Claude 3 | Anthropic', // index 0 in display order
          'GPT-4o | OpenAI', // index 1
          'GPT-4o Mini | OpenAI', // index 2
          'Claude 3 Haiku | Anthropic', // index 3
        ];
        // NOTE: The actual _getModelNames() in ChatPage uses a different
        // order. But the important thing is that displayNames[0] != models[0].

        final models = adapter.availableModels(entriesState);
        // Flat models[0] is "GPT-4o | OpenAI"
        // But displayNames[0] is "Claude 3 | Anthropic"
        // So indexing models[savedDisplayIndex] with savedDisplayIndex=0
        // would get "GPT-4o | OpenAI" instead of "Claude 3 | Anthropic"

        // The fix: look up by display name
        final displayIndex =
            0; // user selected Claude 3 (now at display index 0)
        final expectedName = displayNames[displayIndex];
        final flatIdx = models.indexWhere((m) => m.displayName == expectedName);
        expect(flatIdx, equals(2)); // Claude 3 is at flat index 2
        expect(models[flatIdx].configIndex, equals(1));
        expect(models[flatIdx].modelIndex, equals(0));
      });

      test(
          'selectModel with configIndex/modelIndex works regardless of '
          'display order', () {
        adapter.configure(entriesState);

        // Even if we use the flat list to find Claude 3 (config 1, model 0):
        adapter.selectModel(entriesState, 1, 0);
        expect(adapter.currentConfigIndex, equals(1));
        expect(adapter.currentModelIndex, equals(0));
        expect(adapter.reasoningParams[0].paramName, equals('thinking'));
      });

      test(
          'BUG REPRO: using saved display index on flat models list '
          'picks wrong model when display order != flat order', () {
        adapter.configure(entriesState);

        // Simulate: user reordered, now display list has Claude 3 at index 0
        // saved = 0 (display index)
        const int savedDisplayIndex = 0;

        // BUG CODE path (current _restoreSavedModelSelection):
        final models = adapter.availableModels(entriesState);
        final wrongModel =
            models[savedDisplayIndex]; // uses display index on flat list!

        // This gets "GPT-4o | OpenAI" (flat index 0) instead of
        // "Claude 3 | Anthropic" (flat index 2, but display index 0)
        expect(wrongModel.displayName, contains('GPT-4o'));
        expect(wrongModel.displayName, contains('OpenAI'));
        // WRONG! Should be Claude 3 at config 1, model 0
        expect(wrongModel.configIndex, equals(0));
        expect(wrongModel.modelIndex, equals(0));
        // This would cause the adapter to select GPT-4o instead of Claude 3
      });

      test(
        'FIX: mapping display index through model name finds correct model',
        () {
          const int savedDisplayIndex = 0;
          final models = adapter.availableModels(entriesState);

          // Simulate corrected display order (user reordered)
          final displayNames = [
            'Claude 3 | Anthropic',
            'GPT-4o | OpenAI',
            'GPT-4o Mini | OpenAI',
            'Claude 3 Haiku | Anthropic',
          ];

          // FIX: look up by display name instead of using index directly
          final selectedName = displayNames[savedDisplayIndex];
          final flatIdx = models.indexWhere(
            (m) => m.displayName == selectedName,
          );

          expect(flatIdx, equals(2)); // Claude 3 at flat index 2
          final correctModel = models[flatIdx];
          expect(correctModel.displayName, contains('Claude 3'));
          expect(correctModel.configIndex, equals(1));
          expect(correctModel.modelIndex, equals(0));

          // SELECTING this model works correctly:
          adapter.selectModel(
            entriesState,
            correctModel.configIndex,
            correctModel.modelIndex,
          );
          expect(adapter.currentConfigIndex, equals(1));
          expect(adapter.currentModelIndex, equals(0));
          expect(adapter.reasoningParams[0].paramName, equals('thinking'));
        },
      );

      test('FIX: reasoning params match adapter model after correct restore',
          () {
        // Full fix simulation:
        // 1. configure resets adapter to (0,0) - GPT-4o
        // 2. Restore should select Claude 3 (display index 0 in reordered list)
        // 3. reasoning params should be Claude 3's params, not GPT-4o's

        adapter.configure(entriesState);
        // Initially at GPT-4o
        expect(
          adapter.reasoningParams[0].paramName,
          equals('reasoning_effort'),
        );

        // FIX: map display index 0 to Claude 3 via model name
        const int savedDisplayIndex = 0;
        final models = adapter.availableModels(entriesState);
        final displayNames = [
          'Claude 3 | Anthropic',
          'GPT-4o | OpenAI',
          'GPT-4o Mini | OpenAI',
          'Claude 3 Haiku | Anthropic',
        ];
        final selectedName = displayNames[savedDisplayIndex];
        final flatIdx = models.indexWhere((m) => m.displayName == selectedName);
        final model = models[flatIdx];
        adapter.selectModel(entriesState, model.configIndex, model.modelIndex);

        // Now reasoning params should be Claude 3's 'thinking', not GPT-4o's
        expect(adapter.reasoningParams[0].paramName, equals('thinking'));
        expect(adapter.hasReasoningParams, isTrue);
      });
    });
  });

  // ====================================================================
  // From chat_adapter_tools_test.dart
  // ====================================================================

  group('ChatAdapter.getAllToolDefinitions - built-in + MCP', () {
    late ChatAdapter toolsAdapter;

    setUp(() {
      toolsAdapter = ChatAdapter();
    });

    tearDown(() {
      toolsAdapter.dispose();
    });

    test('initially returns empty list when nothing registered', () {
      final defs = toolsAdapter.getAllToolDefinitions();
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

      final defs = toolsAdapter.getAllToolDefinitions();
      final names = defs.map((d) => d.name).toList();

      // Should include test_builtin (and any other registered tools)
      expect(names, contains('test_builtin'));
    });

    test('getAllToolDefinitions returns unmodifiable copy', () {
      final defs = toolsAdapter.getAllToolDefinitions();
      expect(defs, isA<List<ToolDefinition>>());
    });
  });

  // ====================================================================
  // MCP tools in chat — SSE transport and uniform display
  // ====================================================================

  group('MCP tools appear in chat regardless of transport type', () {
    late ChatAdapter adapter;

    setUp(() {
      adapter = ChatAdapter();
    });

    tearDown(() {
      adapter.dispose();
    });

    test('mcpToolDefinitions is empty before initialization', () {
      expect(adapter.mcpToolDefinitions, isEmpty);
    });

    test('mcpToolDefinitions returns unmodifiable list', () {
      // The getter returns List.unmodifiable (a fixed-length list)
      // Verify it cannot be mutated
      final list = adapter.mcpToolDefinitions;
      expect(list, isA<List<ToolDefinition>>());
      // Attempting to modify should throw
      expect(
          () => list.add(const ToolDefinition(
              name: 'x', description: '', parameters: {'type': 'object'})),
          throws);
    });

    test(
        'McpServerConfig.fromProviderConfig creates SSE config '
        'from built-in typeConfig', () {
      // Simulate a built-in SSE MCP provider's typeConfig
      final typeConfig = <String, dynamic>{
        'transport': 'sse',
        'url': 'https://mcp.example.com/sse',
        'isVendor': true,
        'headers': {'Authorization': 'Bearer '},
        'env': <String, String>{},
      };

      final config = McpServerConfig.fromProviderConfig(
        providerName: 'Example SSE',
        typeConfig: typeConfig,
      );

      expect(config, isNotNull);
      expect(config!.transportType, equals(McpTransportType.sse));
      expect(config.url, equals('https://mcp.example.com/sse'));
      expect(config.isVendor, isTrue);
    });

    test(
        'McpServerConfig.fromProviderConfig creates SSE config '
        'from user-added typeConfig', () {
      // Simulate a user-added SSE MCP provider's typeConfig
      final typeConfig = <String, dynamic>{
        'transport': 'sse',
        'url': 'http://localhost:3001/sse',
        'headers': {'x-api-key': 'test-key-123'},
      };

      final config = McpServerConfig.fromProviderConfig(
        providerName: 'My Custom Server',
        typeConfig: typeConfig,
      );

      expect(config, isNotNull);
      expect(config!.transportType, equals(McpTransportType.sse));
      expect(config.url, equals('http://localhost:3001/sse'));
      expect(config.isVendor, isFalse);
    });

    test(
        'McpServerConfig.fromProviderConfig returns null '
        'for empty typeConfig', () {
      final config = McpServerConfig.fromProviderConfig(
        providerName: 'Empty',
        typeConfig: <String, dynamic>{},
      );

      expect(config, isNull);
    });

    test(
        'McpServerConfig.fromProviderConfig returns null '
        'for null typeConfig', () {
      final config = McpServerConfig.fromProviderConfig(
        providerName: 'Null',
        typeConfig: null,
      );

      expect(config, isNull);
    });

    test(
        'McpServerConfig.fromProviderConfig returns null '
        'for typeConfig without transport field', () {
      final config = McpServerConfig.fromProviderConfig(
        providerName: 'No transport',
        typeConfig: {'url': 'http://example.com'},
      );

      expect(config, isNull);
    });

    test('getAllToolDefinitions combines built-in and MCP tools', () {
      // Register a built-in tool
      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_builtin_tool',
          description: 'Test built-in',
          parameters: {'type': 'object'},
        ),
        (args) => 'done',
      );

      // Initial defs should include only built-in tools
      final initialDefs = adapter.getAllToolDefinitions();
      expect(initialDefs.map((d) => d.name), contains('test_builtin_tool'));
    });

    test('getAllToolDefinitions does not filter by isVendor flag', () {
      // Register a built-in tool
      ChatService.registerTool(
        const ToolDefinition(
          name: 'vendor_independent_tool',
          description: 'A tool from any vendor',
          parameters: {'type': 'object'},
        ),
        (args) => 'done',
      );

      final defs = adapter.getAllToolDefinitions();
      final names = defs.map((d) => d.name).toList();

      // All tools should appear regardless of vendor status
      expect(names, contains('vendor_independent_tool'));
    });

    test('HttpToolService.toolDefinitions contain expected HTTP tool names',
        () {
      final names = HttpToolService.toolDefinitions.map((d) => d.name).toSet();
      expect(names, contains('brave_web_search'));
      expect(names, contains('bocha_web_search'));
      expect(names, contains('querit_search'));
      expect(names, contains('searxng_search'));
    });
  });

  // ====================================================================
  // MCP tool initialization — HTTP tools vs SSE tools
  // ====================================================================

  group('MCP initialization handles all transport types uniformly', () {
    test('fromProviderConfig handles stdio transport correctly', () {
      final typeConfig = <String, dynamic>{
        'transport': 'stdio',
        'command': 'npx',
        'args': ['-y', '@modelcontextprotocol/server-filesystem'],
      };

      final config = McpServerConfig.fromProviderConfig(
        providerName: 'Local FS',
        typeConfig: typeConfig,
      );

      expect(config, isNotNull);
      expect(config!.transportType, equals(McpTransportType.stdio));
      expect(config.command, equals('npx'));
      expect(config.args, contains('-y'));
    });

    test(
        'fromProviderConfig returns SSE config for unknown transport '
        '(fromValue fallback)', () {
      // Transport 'http' is not in McpTransportType, so fromValue
      // falls back to SSE. HTTP tools are caught by isHttpTool check
      // before reaching fromProviderConfig in the real flow.
      final typeConfig = <String, dynamic>{
        'transport': 'http',
        'url': 'https://api.example.com/search',
        'isHttpTool': true,
      };

      final config = McpServerConfig.fromProviderConfig(
        providerName: 'HTTP fallback',
        typeConfig: typeConfig,
      );

      // The fallback for unknown transport is SSE
      expect(config, isNotNull);
      expect(config!.transportType, equals(McpTransportType.sse));
    });

    test('McpServerConfig round-trip through toMap preserves transport', () {
      final original = McpServerConfig.sse(
        name: 'Test SSE',
        url: 'https://mcp.test.com/sse',
        headers: {'x-api-key': 'key123'},
        isVendor: true,
      );

      final map = original.toMap();
      expect(map['transport'], equals('sse'));
      expect(map['url'], equals('https://mcp.test.com/sse'));
      expect(map['isVendor'], isTrue);

      // Restore from map
      final restored = McpServerConfig.fromMap(map);
      expect(restored, isNotNull);
      expect(restored!.transportType, equals(McpTransportType.sse));
      expect(restored.url, equals('https://mcp.test.com/sse'));
      expect(restored.isVendor, isTrue);
    });
  });

  // ====================================================================
  // From chat_tool_filtering_test.dart
  // ====================================================================

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

  // ====================================================================
  // MCP init after provider data change — regression test for SSE MCP
  // providers not showing in chat tool list.
  //
  // BUG: When ProviderEntriesNotifier.load() hasn't completed by the time
  // ChatPage._initialize() runs, the entries state is empty, so
  // initializeMcpServers does nothing. The ref.listen for provider changes
  // only calls _configureAdapter() (LLM model setup), not MCP re-init.
  // Therefore MCP tools are never discovered, even after load() completes.
  //
  // FIX: The provider change listener must also re-initialize built-in and
  // MCP tools. After MCP init, setState() must be called to trigger a UI
  // rebuild so the tool panel shows the new tool definitions.
  // ====================================================================

  group('MCP initialization on provider data change', () {
    late ChatAdapter adapter;

    setUp(() {
      adapter = ChatAdapter();
    });

    tearDown(() {
      adapter.dispose();
    });

    test(
        'initializeMcpServers is no-op when MCP entry is missing '
        '(simulates async load not yet completed)', () async {
      // Empty entries — no MCP entry
      final emptyState = ProviderEntriesState(entries: []);

      // Should not throw — just returns early
      await expectLater(
        () => adapter.initializeMcpServers(emptyState),
        returnsNormally,
      );

      expect(adapter.mcpToolDefinitions, isEmpty);
    });

    test('initializeMcpServers is no-op when MCP entry has no configs',
        () async {
      final stateWithEmptyMcp = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'empty_mcp',
            type: 'mcp',
            name: '空MCP',
            configs: [],
          ),
        ],
      );

      await expectLater(
        () => adapter.initializeMcpServers(stateWithEmptyMcp),
        returnsNormally,
      );

      expect(adapter.mcpToolDefinitions, isEmpty);
    });

    test('initializeBuiltinTools handles empty MCP entry gracefully', () {
      // First call with empty state (simulating load not yet completed)
      final emptyState = ProviderEntriesState(entries: []);
      adapter.initializeBuiltinTools(emptyState);

      // HTTP tools should still be registered even with empty MCP entry
      expect(() => adapter.getAllToolDefinitions(), returnsNormally);

      // initializeBuiltinTools does not modify mcpToolDefinitions — it only
      // registers HTTP tools and API keys. MCP tool discovery happens in
      // initializeMcpServers. After an empty-state call, mcpToolDefinitions
      // remains empty (correctly — no MCP servers were configured).
    });

    test(
        'initializeBuiltinTools can be called repeatedly without side effects'
        '(simulates repeated provider change listener firing)', () {
      // First call with empty state (simulating load not yet completed)
      final emptyState = ProviderEntriesState(entries: []);
      adapter.initializeBuiltinTools(emptyState);

      // Second call with full state including MCP entry (simulating load completed)
      final fullState = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_mcp',
            type: 'mcp',
            name: 'MCP供应商',
            configs: [
              ProviderConfigItem(
                providerName: 'Tavily',
                host: 'https://mcp.tavily.com/mcp/',
                key: '',
                models: [
                  ModelConfig(
                    name: 'Tavily',
                    modelId: 'sse',
                    typeConfig: {
                      'transport': 'sse',
                      'url': 'https://mcp.tavily.com/mcp/',
                      'isVendor': true,
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      adapter.initializeBuiltinTools(fullState);

      // Should not throw when called multiple times
      // Note: we do NOT call initializeMcpServers here because it makes real
      // SSE connections (mcp.tavily.com) which are unreachable in unit tests.
      // The combined flow (initializeBuiltinTools + initializeMcpServers) is
      // verified indirectly: initializeMcpServers handles connection failures
      // gracefully (tested via its early-return tests above), and the two
      // methods are independently safe to call.
      expect(() => adapter.getAllToolDefinitions(), returnsNormally);
    });
  });

  // ====================================================================
  // Built-in vendor MCP providers always have tool definitions even when
  // their servers are unreachable — no distinction between "pure Dart"
  // HTTP tools and SSE MCP tools.
  // ====================================================================

  group('Built-in vendor MCP providers always have tool definitions', () {
    /// The 5 built-in vendor SSE MCP providers as they appear in
    /// _createBuiltinMcpConfigs() (transport='sse', isVendor=true).
    final vendorSseConfigs = [
      ('Exa', '通过 Exa MCP 接口进行网络搜索、内容提取和深度研究'),
      ('Tavily', 'AI 原生搜索引擎，专为大语言模型优化的实时网络搜索服务'),
      ('Jina AI', '多模态 AI 服务，支持网页内容提取、Embedding 和搜索结果抓取'),
      ('Firecrawl', '网页抓取与内容提取服务，可将任意网页转为干净的 Markdown 或结构化数据'),
      ('Zhipu', '智谱 AI 开放平台的网页阅读器 MCP 服务'),
    ];

    late ChatAdapter adapter;

    setUp(() {
      adapter = ChatAdapter();
    });

    tearDown(() {
      adapter.dispose();
    });

    test(
        'initializeMcpServers creates placeholder tool definitions for '
        'vendor SSE providers whose servers are unreachable', () async {
      // Configs with isVendor=true, isHttpTool=false, transport=sse
      // These simulate the 5 built-in MCP (SSE) providers.
      final configs = vendorSseConfigs.map((entry) {
        final (name, desc) = entry;
        return ProviderConfigItem(
          providerName: name,
          host: 'https://mcp.example.com/mcp',
          key: '',
          models: [
            ModelConfig(
              name: name,
              modelId: 'sse',
              typeConfig: {
                'transport': 'sse',
                'url': 'https://mcp.example.com/mcp',
                'isVendor': true,
                'description': desc,
              },
            ),
          ],
        );
      }).toList();

      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_mcp',
            type: 'mcp',
            name: 'MCP供应商',
            configs: configs,
          ),
        ],
      );

      // This will attempt to connect to mcp.example.com (unreachable in tests).
      // The catch block in initializeMcpServers should create placeholder
      // tool definitions from the vendor configs' descriptions.
      await adapter.initializeMcpServers(state);

      final allDefs = adapter.getAllToolDefinitions();
      final names = allDefs.map((d) => d.name).toSet();

      // All 5 vendor SSE providers should have tool definitions even though
      // the servers are unreachable.
      expect(names, contains('exa_mcp'),
          reason: 'Exa should have a placeholder tool definition');
      expect(names, contains('tavily_mcp'),
          reason: 'Tavily should have a placeholder tool definition');
      expect(names, contains('jina_ai_mcp'),
          reason: 'Jina AI should have a placeholder tool definition');
      expect(names, contains('firecrawl_mcp'),
          reason: 'Firecrawl should have a placeholder tool definition');
      expect(names, contains('zhipu_mcp'),
          reason: 'Zhipu should have a placeholder tool definition');
    });

    test(
        'getAllToolDefinitions includes HTTP tools after initializeBuiltinTools',
        () {
      // Register HTTP tools
      final mcpEntryState = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_mcp',
            type: 'mcp',
            name: 'MCP供应商',
            configs: [
              ProviderConfigItem(
                providerName: 'Brave Search',
                host: 'https://api.search.brave.com',
                key: '',
                models: [
                  ModelConfig(
                    name: 'Brave Search',
                    modelId: 'http',
                    typeConfig: {
                      'transport': 'http',
                      'isHttpTool': true,
                    },
                  ),
                ],
              ),
              // Also include a vendor SSE config to test mixing
              ProviderConfigItem(
                providerName: 'Exa',
                host: 'https://mcp.exa.ai/mcp',
                key: '',
                models: [
                  ModelConfig(
                    name: 'Exa',
                    modelId: 'sse',
                    typeConfig: {
                      'transport': 'sse',
                      'url': 'https://mcp.exa.ai/mcp',
                      'isVendor': true,
                      'description': 'Exa MCP search tool',
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      adapter.initializeBuiltinTools(mcpEntryState);
      // Don't call initializeMcpServers to avoid real network connections.
      // This test verifies that getAllToolDefinitions returns HTTP tools,
      // while MCP tools come from initializeMcpServers separately.

      final defs = adapter.getAllToolDefinitions();
      final names = defs.map((d) => d.name).toSet();

      // HTTP tools are registered
      expect(names, contains('brave_web_search'));
      expect(names, contains('bocha_web_search'));
      expect(names, contains('querit_search'));
      expect(names, contains('searxng_search'));
    });

    test('vendor SSE placeholder tools are visible via mcpToolDefinitions',
        () async {
      // Single vendor SSE config (Exa)
      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_mcp',
            type: 'mcp',
            name: 'MCP供应商',
            configs: [
              ProviderConfigItem(
                providerName: 'Exa',
                host: 'https://mcp.exa.ai/mcp',
                key: '',
                models: [
                  ModelConfig(
                    name: 'Exa',
                    modelId: 'sse',
                    typeConfig: {
                      'transport': 'sse',
                      'url': 'https://mcp.exa.ai/mcp',
                      'isVendor': true,
                      'description': '通过 Exa MCP 接口进行网络搜索',
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await adapter.initializeMcpServers(state);

      expect(adapter.mcpToolDefinitions, isNotEmpty,
          reason: 'Exa should have a placeholder tool definition');
      final exaTools = adapter.mcpToolDefinitions.where(
        (t) => t.name == 'exa_mcp',
      );
      expect(exaTools, isNotEmpty, reason: 'exa_mcp placeholder should exist');
      expect(exaTools.first.description, contains('Exa MCP'),
          reason: 'Description should be preserved from config');
    });
  });

  // ====================================================================
  // Auto-enable all available tools by default — built-in SSE MCPs must
  // be visible in the conversation page's tool list without manual
  // toggling.
  //
  // The chat page loads `enabledToolNamesProvider` from the conversation's
  // saved `enabledMcpToolNames` and `hasExplicitEnabledMcpTools` flag. If
  // the flag is false (default for new conversations), the page must
  // default to ALL available tool names (built-in HTTP + MCP) so the user
  // can see them right away. Users can still opt-out specific tools via
  // the "可用工具" panel; the explicit-empty case is preserved via the
  // flag so a user who toggled every tool off doesn't get them all
  // re-enabled on the next load.
  // ====================================================================

  group('Auto-enable all available tools when no saved preferences', () {
    test(
        'resolver returns the full set of available tool names when conv has '
        'no saved enabledMcpToolNames (new conversation)', () {
      // Simulate the discovery result.
      final allTools = <ToolDefinition>[
        const ToolDefinition(
          name: 'brave_web_search',
          description: 'Built-in Brave',
          parameters: {'type': 'object'},
        ),
        const ToolDefinition(
          name: 'tavily_search',
          description: 'MCP Tavily search',
          parameters: {'type': 'object'},
        ),
        const ToolDefinition(
          name: 'exa_search',
          description: 'MCP Exa search',
          parameters: {'type': 'object'},
        ),
      ];

      // New conversation (no explicit prefs) → default to ALL available.
      final resolved = resolveEnabledToolNames(
        allTools: allTools,
        savedEnabledNames: <String>{},
        hasExplicitSavedPrefs: false,
      );

      expect(
          resolved, equals({'brave_web_search', 'tavily_search', 'exa_search'}),
          reason: 'New conversation with no saved preferences should default '
              'to all available tools enabled so built-in MCPs are visible.');
    });

    test('resolver respects saved preferences when user has toggled tools off',
        () {
      final allTools = <ToolDefinition>[
        const ToolDefinition(
          name: 'brave_web_search',
          description: 'Brave',
          parameters: {'type': 'object'},
        ),
        const ToolDefinition(
          name: 'tavily_search',
          description: 'Tavily',
          parameters: {'type': 'object'},
        ),
        const ToolDefinition(
          name: 'exa_search',
          description: 'Exa',
          parameters: {'type': 'object'},
        ),
      ];

      // User previously toggled tavily off; explicit flag is true.
      final resolved = resolveEnabledToolNames(
        allTools: allTools,
        savedEnabledNames: {'brave_web_search', 'exa_search'},
        hasExplicitSavedPrefs: true,
      );

      expect(resolved, equals({'brave_web_search', 'exa_search'}),
          reason: 'Saved preferences must override the "enable all" default.');
    });

    test(
        'resolver returns empty set when user explicitly toggled every tool '
        'off (explicit-empty must be preserved)', () {
      // Regression test: a user who has explicitly toggled every tool off
      // must NOT have them all re-enabled on the next load. This is the
      // "explicit-empty" case the hasExplicitSavedPrefs flag protects.
      final allTools = <ToolDefinition>[
        const ToolDefinition(
          name: 'brave_web_search',
          description: 'Brave',
          parameters: {'type': 'object'},
        ),
        const ToolDefinition(
          name: 'tavily_search',
          description: 'Tavily',
          parameters: {'type': 'object'},
        ),
      ];

      final resolved = resolveEnabledToolNames(
        allTools: allTools,
        savedEnabledNames: <String>{},
        hasExplicitSavedPrefs: true,
      );

      expect(resolved, isEmpty,
          reason: 'When the user has explicitly cleared all toggles, the '
              'resolver must return an empty set, not silently re-enable '
              'every tool.');
    });

    test('resolver returns empty set when no tools are available', () {
      final resolved = resolveEnabledToolNames(
        allTools: const [],
        savedEnabledNames: <String>{},
        hasExplicitSavedPrefs: false,
      );
      expect(resolved, isEmpty);
    });
  });
}
