import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
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
  group('reasoning params - user configurable ReasoningParam model', () {
    test('reasoning params come from model config and selected values',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
              paramName: 'thinking.type', options: ['enabled', 'disabled']),
          ReasoningParam(
              paramName: 'reasoning_effort',
              options: ['low', 'medium', 'high']),
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
      expect(body!['thinking'], {'type': 'enabled'});
      expect(body['reasoning_effort'], 'high');
    });

    test('dot-notation creates nested objects', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
              paramName: 'thinking.type', options: ['enabled', 'disabled']),
          ReasoningParam(
              paramName: 'thinking.budget_tokens',
              options: ['5000', '10000', '20000']),
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
      expect(body!['thinking'], isA<Map>());
      expect(body['thinking']['type'], 'enabled');
      expect(body['thinking']['budget_tokens'], '10000');
    });

    test('disabled reasoning param not sent when reasoning is ON', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
              paramName: 'thinking.type', options: ['enabled'], enabled: false),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      // When reasoning is ON but the param is disabled in config, it should
      // NOT be sent.
      await for (final _
          in service.sendStream('Hi', history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!.containsKey('thinking'), false);
    });

    test('empty reasoning params sends nothing extra', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _
          in service.sendStream('Hi', history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!.containsKey('thinking'), false);
      expect(body.containsKey('reasoning_effort'), false);
    });

    test('supports different param types via reasoning selections map',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
              paramName: 'temperature', options: ['0.5', '0.8', '1.0']),
          ReasoningParam(paramName: 'stream', options: ['true', 'false']),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {
            'temperature': '0.8',
            'stream': 'true',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['temperature'], '0.8');
      expect(body['stream'], 'true');
    });

    test('supports Anthropic thinking format', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Claude',
        modelId: 'claude-sonnet-4-6',
        typeConfig: {'context': 128000},
        reasoningParams: [
          ReasoningParam(paramName: 'thinking.type', options: ['enabled']),
          ReasoningParam(
              paramName: 'thinking.budget_tokens',
              options: ['5000', '10000', '20000', '32000']),
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

    test('supports Google Gemini deep nesting format', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Gemini',
        modelId: 'gemini-3-pro',
        typeConfig: {'context': 128000},
        reasoningParams: [
          ReasoningParam(
              paramName: 'config.thinkingConfig.thinkingLevel',
              options: ['HIGH', 'LOW']),
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
      expect(body!['config']['thinkingConfig']['thinkingLevel'], 'HIGH');
    });
  });
}
