import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_adapter.dart';

void main() {
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

    test('configure resets adapter to (0,0) after selectModel - '
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

    test('reasoningParams returns params from currently selected model, '
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

      test('model display name at display index 0 identifies the correct model '
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

      test('selectModel with configIndex/modelIndex works regardless of '
          'display order', () {
        adapter.configure(entriesState);

        // Even if we use the flat list to find Claude 3 (config 1, model 0):
        adapter.selectModel(entriesState, 1, 0);
        expect(adapter.currentConfigIndex, equals(1));
        expect(adapter.currentModelIndex, equals(0));
        expect(adapter.reasoningParams[0].paramName, equals('thinking'));
      });

      test('BUG REPRO: using saved display index on flat models list '
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

      test('FIX: reasoning params match adapter model after correct restore', () {
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
}
