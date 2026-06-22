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
  });
}
