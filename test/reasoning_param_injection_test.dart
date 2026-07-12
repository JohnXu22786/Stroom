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
  group('reasoning params with ReasoningParam model', () {
    test('reasoning toggle sends onValue when global toggle is ON', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _
          in service.sendStream('Hi', history: [], reasoning: true)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking']['type'], 'enabled');
    });

    test('reasoning toggle sends offValue when global toggle is OFF', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _
          in service.sendStream('Hi', history: [], reasoning: false)) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['thinking']['type'], 'disabled');
    });

    test(
        'additional enabled params sent with selected values when reasoning ON',
        () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
            enabled: true,
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {
            'reasoning_effort': 'high',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // Toggle always sent
      expect(body!['thinking']['type'], 'enabled');
      // Enabled additional param sent
      expect(body['reasoning_effort'], 'high');
    });

    test('additional disabled params not sent when reasoning is ON', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
            enabled: false,
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: true,
          reasoningParamValues: {
            'reasoning_effort': 'high',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // Toggle always sent
      expect(body!['thinking']['type'], 'enabled');
      // Disabled additional param NOT sent
      expect(body.containsKey('reasoning_effort'), false);
    });

    test('additional params not sent when global toggle is OFF', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
            enabled: true,
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [],
          reasoning: false,
          reasoningParamValues: {
            'reasoning_effort': 'high',
          })) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      // Toggle always sent → offValue
      expect(body!['thinking']['type'], 'disabled');
      // Additional params NOT sent when global toggle is OFF
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

      await for (final _
          in service.sendStream('Hi', history: [], reasoning: true)) {}

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
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
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
            isReasoningToggle: true,
            onValue: 'HIGH',
            offValue: 'LOW',
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi',
          history: [], reasoning: true, reasoningParamValues: {})) {}

      final body = provider.lastRequestBody;
      expect(body, isNotNull);
      expect(body!['config']['thinkingConfig']['thinkingLevel'], 'HIGH');
    });

    test('single-value options (e.g. only max) work correctly', () async {
      final provider = _MockProvider();
      final modelConfig = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'thinking.budget_tokens',
            options: ['max'],
            enabled: true,
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
      expect(body!['thinking']['type'], 'enabled');
      expect(body['thinking']['budget_tokens'], 'max');
    });
  });
}
