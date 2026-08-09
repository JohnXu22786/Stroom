import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_adapter.dart';

void main() {
  group('mergeReasoningParams', () {
    ReasoningParam providerParam(String name,
        {bool toggle = false, bool effort = false}) {
      return ReasoningParam(
        paramName: name,
        isReasoningToggle: toggle,
        isEffortParam: effort,
        options: ['a', 'b'],
      );
    }

    test('model params come first, then non-overridden provider params', () {
      final merged = mergeReasoningParams(
        [
          providerParam('thinking.type', toggle: true),
          providerParam('reasoning_effort', effort: true),
          providerParam('budget_tokens'),
        ],
        [
          providerParam('model_only'),
        ],
      );
      expect(merged.map((p) => p.paramName).toList(), [
        'model_only',
        'thinking.type',
        'reasoning_effort',
        'budget_tokens',
      ]);
    });

    test('model param with the same name replaces the provider param', () {
      final provider = providerParam(
        'reasoning_effort',
        effort: true,
      );
      final model = ReasoningParam(
        paramName: 'reasoning_effort',
        isEffortParam: true,
        options: ['low', 'medium', 'high'],
      );
      final merged = mergeReasoningParams([provider], [model]);
      expect(merged.length, 1);
      expect(identical(merged.first, model), isTrue);
      expect(merged.first.options, ['low', 'medium', 'high']);
    });

    test('empty-name provider params are skipped', () {
      final merged = mergeReasoningParams(
        [
          ReasoningParam(paramName: ''),
          providerParam('valid'),
        ],
        [],
      );
      expect(merged.map((p) => p.paramName).toList(), ['valid']);
    });

    test('empty-name model params do not shadow provider params', () {
      final merged = mergeReasoningParams(
        [providerParam('reasoning_effort')],
        [ReasoningParam(paramName: '')],
      );
      expect(merged.map((p) => p.paramName).toList(), [
        '',
        'reasoning_effort',
      ]);
    });

    test('findEffortParam prefers the model effort param over provider one',
        () {
      final merged = mergeReasoningParams(
        [
          ReasoningParam(
            paramName: 'provider.effort',
            isEffortParam: true,
            options: ['low', 'high'],
          ),
        ],
        [
          ReasoningParam(
            paramName: 'model.effort',
            isEffortParam: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
      );
      expect(findEffortParam(merged)!.paramName, 'model.effort');
    });

    test('findEffortParam falls back to the provider effort param', () {
      final merged = mergeReasoningParams(
        [
          ReasoningParam(
            paramName: 'provider.effort',
            isEffortParam: true,
            options: ['low', 'high'],
          ),
        ],
        [],
      );
      expect(findEffortParam(merged)!.paramName, 'provider.effort');
    });
  });

  group('ReasoningParam.inheritedFromProvider', () {
    test('defaults to false', () {
      final param = ReasoningParam(paramName: 'x');
      expect(param.inheritedFromProvider, isFalse);
    });

    test('is not serialized by toMap', () {
      final param = ReasoningParam(
        paramName: 'x',
        inheritedFromProvider: true,
      );
      expect(param.toMap().containsKey('inheritedFromProvider'), isFalse);
    });

    test('is not preserved by copy()', () {
      final param = ReasoningParam(
        paramName: 'x',
        inheritedFromProvider: true,
      );
      expect(param.copy().inheritedFromProvider, isFalse);
    });
  });

  group('ChatAdapter merged reasoningParams', () {
    late ChatAdapter adapter;
    late ProviderEntriesState entriesState;

    setUp(() {
      adapter = ChatAdapter();
      final providerConfig = ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
        models: [
          ModelConfig(
            name: 'Test Model',
            modelId: 'test-model',
            typeConfig: {'context': 4096},
            reasoningParams: [
              ReasoningParam(
                paramName: 'budget_tokens',
                options: ['1000', '2000'],
              ),
            ],
          ),
        ],
      );
      entriesState = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_llm',
            type: 'llm',
            name: 'Test Provider',
            configs: [providerConfig],
          ),
        ],
      );
    });

    tearDown(() {
      adapter.dispose();
    });

    test('reasoningParams merge provider + model params', () {
      adapter.configure(entriesState);
      final params = adapter.reasoningParams;
      expect(params.map((p) => p.paramName).toList(), [
        'budget_tokens',
        'thinking.type',
        'reasoning_effort',
      ]);
    });

    test('model param with provider-shared name replaces the provider one', () {
      // Model overrides the effort param name: the merged list must contain
      // the model's version only (no duplicate of the provider's).
      entriesState = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_llm',
            type: 'llm',
            name: 'Test Provider',
            configs: [
              ProviderConfigItem(
                providerName: 'Test Provider',
                host: 'https://api.example.com/v1',
                key: 'sk-test',
                reasoningParams: [
                  ReasoningParam(
                    paramName: 'reasoning_effort',
                    isEffortParam: true,
                    options: ['low', 'high'],
                  ),
                ],
                models: [
                  ModelConfig(
                    name: 'Test Model',
                    modelId: 'test-model',
                    typeConfig: {'context': 4096},
                    reasoningParams: [
                      ReasoningParam(
                        paramName: 'reasoning_effort',
                        isEffortParam: true,
                        options: ['low', 'medium', 'high'],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      adapter.configure(entriesState);
      final params = adapter.reasoningParams;
      expect(params.length, 1);
      expect(params.first.paramName, 'reasoning_effort');
      expect(params.first.options, ['low', 'medium', 'high']);
    });

    test('hasReasoningParams true when only the provider defines params', () {
      // Model has no reasoning params of its own; the provider's toggle +
      // effort params must still enable the chat reasoning UI.
      entriesState = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_llm',
            type: 'llm',
            name: 'Test Provider',
            configs: [
              ProviderConfigItem(
                providerName: 'Test Provider',
                host: 'https://api.example.com/v1',
                key: 'sk-test',
                reasoningParams: [
                  ReasoningParam(
                    paramName: 'thinking.type',
                    isReasoningToggle: true,
                    onValue: 'enabled',
                    offValue: 'disabled',
                  ),
                ],
                models: [
                  ModelConfig(
                    name: 'Test Model',
                    modelId: 'test-model',
                    typeConfig: {'context': 4096},
                    reasoningParams: [],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      adapter.configure(entriesState);
      expect(adapter.hasReasoningParams, isTrue);
      expect(adapter.reasoningParams.length, 1);
    });

    test('provider-origin params are copies; model params are live refs', () {
      // 聊天面板会就地修改 param.enabled；供应商参数必须返回副本，
      // 防止污染共享的供应商配置（影响该供应商下所有模型）。
      adapter.configure(entriesState);
      final params = adapter.reasoningParams;

      // 'budget_tokens' 来自模型 → 引用原对象（保留既有行为）
      final modelParam =
          params.firstWhere((p) => p.paramName == 'budget_tokens');
      final cachedModel = adapter.modelConfig!;
      expect(identical(modelParam, cachedModel.reasoningParams.first), isTrue);

      // 'thinking.type' / 'reasoning_effort' 来自供应商 → 副本
      final providerToggle =
          params.firstWhere((p) => p.paramName == 'thinking.type');
      final cachedProvider =
          entriesState.entries.firstWhere((e) => e.type == 'llm').configs.first;
      expect(
        identical(providerToggle, cachedProvider.reasoningParams.first),
        isFalse,
        reason: '供应商参数必须是副本，避免面板就地修改写穿到共享配置',
      );
      // 修改副本不影响共享配置
      providerToggle.enabled = false;
      expect(cachedProvider.reasoningParams.first.enabled, isTrue);
    });

    test('hasReasoningParams false when both layers have only an empty toggle',
        () {
      entriesState = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_llm',
            type: 'llm',
            name: 'Test Provider',
            configs: [
              ProviderConfigItem(
                providerName: 'Test Provider',
                host: 'https://api.example.com/v1',
                key: 'sk-test',
                reasoningParams: [
                  ReasoningParam(paramName: '', isReasoningToggle: true),
                ],
                models: [
                  ModelConfig(
                    name: 'Test Model',
                    modelId: 'test-model',
                    typeConfig: {'context': 4096},
                    reasoningParams: [],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      adapter.configure(entriesState);
      expect(adapter.hasReasoningParams, isFalse);
    });
  });
}
