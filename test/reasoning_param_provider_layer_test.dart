import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/assistant.dart' show CustomParameter;
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

/// Mock provider that captures the request body for inspection.
class _MockProvider extends BaseChatProvider {
  @override
  Map<String, dynamic>? lastRequestBody;

  @override
  String get name => 'Mock';

  @override
  List<String> get supportedModelIds => [];

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test',
        'max_tokens': 4096,
        'temperature': 0.7,
      };

  @override
  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
    String? system,
  }) async {
    throw UnimplementedError();
  }

  @override
  Stream<AIStreamEvent> chatStream(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
    String? system,
  }) async* {
    lastRequestBody = {
      'model': model ?? defaultParams['model'],
      'messages': messages,
      'max_tokens': maxTokens ?? defaultParams['max_tokens'],
      'temperature': temperature ?? defaultParams['temperature'],
      'stream': true,
      if (extraParams != null) ...extraParams,
    };
    yield AIStreamEvent('');
  }
}

void main() {
  group('provider-level reasoning params in request body', () {
    late _MockProvider provider;

    setUp(() {
      provider = _MockProvider();
    });

    ModelConfig plainModel() => ModelConfig(
          name: 'Test',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
        );

    ProviderConfigItem providerWithReasoning({
      ReasoningParam? toggle,
      List<ReasoningParam> additional = const [],
    }) {
      return ProviderConfigItem(
        providerName: 'Test Provider',
        host: 'https://api.example.com/v1',
        key: 'sk-test',
        reasoningParams: [
          if (toggle != null) toggle,
          ...additional,
        ],
      );
    }

    test('provider toggle sends offValue when global reasoning is OFF',
        () async {
      final service = ChatService(
        provider: provider,
        modelConfig: plainModel(),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
        ),
      );

      await for (final _
          in service.sendStream('Hi', history: [], reasoning: false)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // Off value must be sent explicitly — mirrors the model-level toggle
      // behavior; leaving the toggle absent would not disable reasoning on
      // providers that require an explicit off value.
      expect(body!['thinking'], isA<Map>());
      expect((body['thinking'] as Map)['type'], 'disabled');
    });

    test('provider toggle sends onValue when global reasoning is ON', () async {
      final service = ChatService(
        provider: provider,
        modelConfig: plainModel(),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
        ),
      );

      await for (final _
          in service.sendStream('Hi', history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking']['type'], 'enabled');
    });

    test(
        'provider additional params sent with selected value when reasoning ON',
        () async {
      final service = ChatService(
        provider: provider,
        modelConfig: plainModel(),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          additional: [
            ReasoningParam(
              paramName: 'reasoning_effort',
              options: ['low', 'medium', 'high'],
              enabled: true,
            ),
          ],
        ),
      );

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {'reasoning_effort': 'high'})) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking']['type'], 'enabled');
      expect(body['reasoning_effort'], 'high');
    });

    test('provider additional params not sent when reasoning is OFF', () async {
      final service = ChatService(
        provider: provider,
        modelConfig: plainModel(),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          additional: [
            ReasoningParam(
              paramName: 'reasoning_effort',
              options: ['low', 'medium', 'high'],
              enabled: true,
            ),
          ],
        ),
      );

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: false,
          reasoningParamValues: {'reasoning_effort': 'high'})) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // Toggle off value still sent, additional params dropped
      expect(body!['thinking']['type'], 'disabled');
      expect(body.containsKey('reasoning_effort'), isFalse);
    });

    test(
        'provider name-only param sends nothing when no value selected (no name-as-value garbage)',
        () async {
      // Provider declares the param name only; the value is expected to come
      // from the model override or the chat panel selection. Without a value,
      // sending the param name itself would inject garbage into the request.
      final service = ChatService(
        provider: provider,
        modelConfig: plainModel(),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          additional: [
            ReasoningParam(
              paramName: 'reasoning_effort',
              enabled: true,
              options: [],
            ),
          ],
        ),
      );

      await for (final _
          in service.sendStream('Hi', history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking']['type'], 'enabled');
      expect(body.containsKey('reasoning_effort'), isFalse);
    });

    test('provider name-only param sends the selected value when present',
        () async {
      final service = ChatService(
        provider: provider,
        modelConfig: plainModel(),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          additional: [
            ReasoningParam(
              paramName: 'reasoning_effort',
              enabled: true,
              options: [],
            ),
          ],
        ),
      );

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {'reasoning_effort': 'high'})) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['reasoning_effort'], 'high');
    });

    test('model param overrides provider param with the same name', () async {
      // Three-layer override: provider < model. The model's version of
      // reasoning_effort must win over the provider's. 两层使用同名参数但
      // 类型不同（provider: number → 'medium' 强转为 0.0；model: string →
      // 保持 'medium'），请求体即可区分是哪一层的值生效。
      final service = ChatService(
        provider: provider,
        modelConfig: ModelConfig(
          name: 'Test',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
          reasoningParams: [
            ReasoningParam(
              paramName: 'reasoning_effort',
              isEffortParam: true,
              options: ['low', 'medium', 'high'],
              enabled: true,
              type: 'string',
            ),
          ],
        ),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          additional: [
            ReasoningParam(
              paramName: 'reasoning_effort',
              options: ['low', 'high'],
              enabled: true,
              type: 'number',
            ),
          ],
        ),
      );

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {'reasoning_effort': 'medium'})) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // 若 provider 层获胜，'medium' 会被强转为 0.0；保留字符串即模型层生效
      expect(body!['reasoning_effort'], 'medium');
      expect(body['thinking']['type'], 'enabled');
    });

    test(
        'provider effort param is skipped when the model has its own effort '
        'param (stale value must not be injected)', () async {
      // 模型有自己命名的力度参数时，供应商的力度参数被遮蔽；
      // 即使 reasoningParamValues 里有它的陈旧值，也不得发送。
      final service = ChatService(
        provider: provider,
        modelConfig: ModelConfig(
          name: 'Test',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
          reasoningParams: [
            ReasoningParam(
              paramName: 'model.effort',
              isEffortParam: true,
              options: ['x', 'y'],
              enabled: true,
            ),
          ],
        ),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          additional: [
            ReasoningParam(
              paramName: 'provider.effort',
              isEffortParam: true,
              options: ['a', 'b'],
              enabled: true,
            ),
          ],
        ),
      );

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {
            'provider.effort': 'a', // 陈旧值（UI 已无法清除）
            'model.effort': 'x',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // 点号参数名展开为嵌套对象
      expect((body!['model'] as Map)['effort'], 'x');
      expect(body.containsKey('provider'), isFalse,
          reason: '被模型力度参数遮蔽的供应商力度参数不得发送陈旧值');
    });

    test('provider toggle + model toggle with the same name: model wins',
        () async {
      // 同名开关双写路径：provider 层先写、model 层后写 → 模型值生效。
      final service = ChatService(
        provider: provider,
        modelConfig: ModelConfig(
          name: 'Test',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
          reasoningParams: [
            ReasoningParam(
              paramName: 'thinking.type',
              isReasoningToggle: true,
              onValue: 'model_on',
              offValue: 'model_off',
            ),
          ],
        ),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'provider_on',
            offValue: 'provider_off',
          ),
        ),
      );

      await for (final _
          in service.sendStream('Hi', history: [], reasoning: false)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking']['type'], 'model_off');
    });

    test('assistant custom param overrides model reasoning param (3 layers)',
        () async {
      // Three-layer override: provider < model < assistant. An assistant
      // custom param with the same name must win over the model's reasoning
      // param (custom params are written after reasoning params).
      final service = ChatService(
        provider: provider,
        modelConfig: ModelConfig(
          name: 'Test',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
          reasoningParams: [
            ReasoningParam(
              paramName: 'reasoning_effort',
              options: ['low', 'medium', 'high'],
              enabled: true,
            ),
          ],
        ),
        providerConfig: providerWithReasoning(
          toggle: ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
        ),
      );
      service.setAssistantCustomParams([
        CustomParameter(
          name: 'reasoning_effort',
          type: 'string',
          value: 'high',
        ),
      ]);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {'reasoning_effort': 'low'})) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['reasoning_effort'], 'high');
    });
  });
}
