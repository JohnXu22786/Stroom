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
    // Capture extraParams which contain the reasoning params
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
  group('reasoning params - user configurable, no hardcoding', () {
    test('reasoning params come from model config, not provider', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          CustomParam(
              paramName: 'thinking.type',
              defaultValue: 'enabled',
              type: 'string'),
          CustomParam(
              paramName: 'reasoning_effort',
              defaultValue: 'high',
              type: 'string'),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

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
          CustomParam(
              paramName: 'thinking.type',
              defaultValue: 'enabled',
              type: 'string'),
          CustomParam(
              paramName: 'thinking.budget_tokens',
              defaultValue: '10000',
              type: 'number'),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking'], isA<Map>());
      expect(body['thinking']['type'], 'enabled');
      expect(body['thinking']['budget_tokens'], 10000.0);
    });

    test('no reasoning params sent when reasoning is disabled', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          CustomParam(
              paramName: 'thinking.type',
              defaultValue: 'enabled',
              type: 'string'),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: false)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!.containsKey('thinking'), false);
      expect(body.containsKey('reasoning_effort'), false);
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

      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!.containsKey('thinking'), false);
      expect(body.containsKey('reasoning_effort'), false);
    });

    test('supports different param types (number, boolean)', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          CustomParam(
              paramName: 'temperature',
              defaultValue: '0.8',
              type: 'number'),
          CustomParam(
              paramName: 'stream',
              defaultValue: 'true',
              type: 'boolean'),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['temperature'], 0.8);
      expect(body['stream'], true);
    });

    test('supports Anthropic thinking format', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Claude',
        modelId: 'claude-sonnet-4-6',
        typeConfig: {'context': 128000},
        reasoningParams: [
          CustomParam(
              paramName: 'thinking.type',
              defaultValue: 'enabled',
              type: 'string'),
          CustomParam(
              paramName: 'thinking.budget_tokens',
              defaultValue: '10000',
              type: 'number'),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // Anthropic format: {"thinking": {"type": "enabled", "budget_tokens": 10000}}
      expect(body!['thinking']['type'], 'enabled');
      expect(body['thinking']['budget_tokens'], 10000.0);
    });

    test('supports Google Gemini deep nesting format', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Gemini',
        modelId: 'gemini-3-pro',
        typeConfig: {'context': 128000},
        reasoningParams: [
          CustomParam(
              paramName: 'config.thinkingConfig.thinkingLevel',
              defaultValue: 'HIGH',
              type: 'string'),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // Gemini format: {"config": {"thinkingConfig": {"thinkingLevel": "HIGH"}}}
      expect(body!['config']['thinkingConfig']['thinkingLevel'], 'HIGH');
    });
  });
}
