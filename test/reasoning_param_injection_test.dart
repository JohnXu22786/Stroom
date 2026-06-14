import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

/// Mock provider that captures the request body for inspection.
class _MockProvider extends BaseChatProvider {
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
  group('reasoning params with ReasoningParam model', () {
    test('reasoning params use selected values from reasoning selections map',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
          ),
          ReasoningParam(
            paramName: 'thinking.type',
            options: ['enabled', 'disabled'],
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {
            'reasoning_effort': 'high',
            'thinking.type': 'enabled',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['reasoning_effort'], 'high');
      expect(body['thinking']['type'], 'enabled');
    });

    test('reasoning params use defaults from model config when no selection map',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
          ),
          ReasoningParam(
            paramName: 'thinking.type',
            options: ['enabled'],
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      // When no selection map is passed, use first option as default
      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // No defaults from model config - only from typeConfig
      // reasoning params without default values should not be sent
      expect(body!.containsKey('reasoning_effort'), false);
      expect(body.containsKey('thinking'), false);
    });

    test('disabled reasoning params not sent when reasoning is ON', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            options: ['enabled'],
            enabled: false,  // explicitly disabled
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      // Even with reasoning=true, a disabled param should NOT be sent
      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!.containsKey('thinking'), false);
    });

    test('enabled reasoning params without options send true when reasoning is ON',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            enabled: true,
            options: [],  // no options
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      // When enabled and no options, send true
      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking']['type'], isTrue);
    });

    test('mixed enabled/disabled params handled correctly when reasoning is ON',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            options: ['enabled'],
            enabled: true,
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
            enabled: false,  // disabled
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {
            'thinking.type': 'enabled',
            'reasoning_effort': 'high',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // thinking.type is enabled → should be sent
      expect(body!['thinking']['type'], 'enabled');
      // reasoning_effort is disabled → should NOT be sent
      expect(body.containsKey('reasoning_effort'), false);
    });

    test('no reasoning params sent when global reasoning toggle is OFF', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            options: ['enabled'],
            enabled: true,
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      // Global reasoning toggle is OFF → no params sent regardless of enabled
      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: false)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!.containsKey('thinking'), false);
    });

    test('empty reasoning params sends nothing extra when reasoning is ON',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!.containsKey('thinking'), false);
    });

    test('supports Anthropic thinking format via reasoning selections',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Claude',
        modelId: 'claude-sonnet-4-6',
        typeConfig: {'context': 128000},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            options: ['enabled'],
          ),
          ReasoningParam(
            paramName: 'thinking.budget_tokens',
            options: ['10000', '20000', '32000'],
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {
            'thinking.type': 'enabled',
            'thinking.budget_tokens': '10000',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking']['type'], 'enabled');
      expect(body['thinking']['budget_tokens'], '10000');
    });

    test('supports Google Gemini deep nesting format via reasoning selections',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Gemini',
        modelId: 'gemini-3-pro',
        typeConfig: {'context': 128000},
        reasoningParams: [
          ReasoningParam(
            paramName: 'config.thinkingConfig.thinkingLevel',
            options: ['HIGH', 'LOW'],
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {
            'config.thinkingConfig.thinkingLevel': 'HIGH',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(
          body!['config']['thinkingConfig']['thinkingLevel'], 'HIGH');
    });

    test('single-value options (e.g. only max) work correctly', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.budget_tokens',
            options: ['max'],
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {
            'thinking.budget_tokens': 'max',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking']['budget_tokens'], 'max');
    });
  });
}
