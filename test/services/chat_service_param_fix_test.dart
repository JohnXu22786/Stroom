import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/assistant.dart'
    show AssistantSettings, CustomParameter;
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:dio/dio.dart';

/// Mock provider that captures request parameters and simulates streaming.
class _CapturingProvider extends BaseChatProvider {
  Map<String, dynamic>? capturedExtraParams;
  int? capturedMaxTokens;
  double? capturedTemperature;
  List<Map<String, dynamic>>? capturedTools;

  @override
  String get name => 'CaptureProvider';

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
    capturedExtraParams = extraParams;
    capturedMaxTokens = maxTokens;
    capturedTemperature = temperature;
    capturedTools = tools;
    yield AIStreamEvent('');
  }

  void reset() {
    capturedExtraParams = null;
    capturedMaxTokens = null;
    capturedTemperature = null;
    capturedTools = null;
  }
}

void main() {
  group('ChatService._buildExtraParams - JSON type handling', () {
    test('JSON type model-level custom param is properly parsed', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'response_format',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
          CustomParam(
            paramName: 'metadata',
            defaultValue: '{"source": "test", "version": 2}',
            type: 'json',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      provider.reset();
      // sendStream uses Future.microtask internally, so we await a cycle
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);

      // JSON-type params should be actual parsed objects, not strings
      final responseFormat = extraParams!['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'JSON type param should be a Map, not a String');
      expect((responseFormat as Map)['type'], equals('json_object'));

      final metadata = extraParams['metadata'];
      expect(metadata, isA<Map>(),
          reason: 'JSON type param should be a Map, not a String');
      expect((metadata as Map)['source'], equals('test'));
      expect(metadata['version'], equals(2));
    });

    test('JSON type assistant-level custom param is properly parsed', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      service.setAssistantCustomParams([
        CustomParameter(
          name: 'response_format',
          type: 'json',
          value: '{"type": "json_object"}',
        ),
        CustomParameter(
          name: 'tools_config',
          type: 'json',
          value: '["tool_a", "tool_b"]',
        ),
      ]);

      provider.reset();
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);

      final responseFormat = extraParams!['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'JSON type assistant param should be a Map');
      expect((responseFormat as Map)['type'], equals('json_object'));

      final toolsConfig = extraParams['tools_config'];
      expect(toolsConfig, isA<List>(),
          reason: 'JSON type assistant param (array) should be a List');
      expect((toolsConfig as List).length, equals(2));
    });

    test('malformed JSON falls back to raw string', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'bad_json',
            defaultValue: '{invalid json}',
            type: 'json',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      provider.reset();
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);
      // Malformed JSON should return the raw string
      expect(extraParams!['bad_json'], equals('{invalid json}'));
    });
  });

  group('ChatService - number/boolean type handling', () {
    test('number type model-level custom param is sent as number', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'top_k',
            defaultValue: '50',
            type: 'number',
          ),
          CustomParam(
            paramName: 'temperature',
            defaultValue: '0.8',
            type: 'number',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      provider.reset();
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);
      expect(extraParams!['top_k'], equals(50.0),
          reason: 'number type param should be sent as num, not string');
      expect(extraParams['temperature'], equals(0.8),
          reason: 'number type param should be sent as num, not string');
    });

    test('boolean type model-level custom param is sent as bool', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'use_cache',
            defaultValue: 'true',
            type: 'boolean',
          ),
          CustomParam(
            paramName: 'stream_options',
            defaultValue: 'false',
            type: 'boolean',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      provider.reset();
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);
      expect(extraParams!['use_cache'], isTrue,
          reason: 'boolean type param should be sent as bool');
      expect(extraParams['stream_options'], isFalse,
          reason: 'boolean type param should be sent as bool');
    });
  });

  group('ChatService._lastRequestBody - parameter ordering', () {
    test('extraParams are after standard params in _lastRequestBody', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 0.5,
          'enableMaxTokens': true,
          'maxTokens': 2048,
        },
        customParams: [
          CustomParam(
            paramName: 'custom_param_1',
            defaultValue: 'value1',
            type: 'string',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      // Get the keys in order
      final keys = lastBody!.keys.toList();

      // Standard params should come first
      final messagesIdx = keys.indexOf('messages');
      final modelIdx = keys.indexOf('model');
      final maxTokensIdx = keys.indexOf('max_tokens');
      final customParamIdx = keys.indexOf('custom_param_1');

      // custom_param_1 should be after standard params
      expect(customParamIdx, greaterThan(messagesIdx),
          reason: 'custom params should be after messages');
      expect(customParamIdx, greaterThan(modelIdx),
          reason: 'custom params should be after model');
      expect(customParamIdx, greaterThan(maxTokensIdx),
          reason: 'custom params should be after max_tokens');
    });

    test('extraParams spread AFTER standard params in sendStreamWithTools',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 0.5,
          'enableMaxTokens': true,
          'maxTokens': 2048,
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event
          in service.sendStreamWithTools('Hi', history: [])) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      final keys = lastBody!.keys.toList();
      final messagesIdx = keys.indexOf('messages');
      final modelIdx = keys.indexOf('model');
      final maxTokensIdx = keys.indexOf('max_tokens');

      // Standard params should come first. If max_tokens is included,
      // it should be after messages.
      expect(modelIdx, lessThan(messagesIdx),
          reason: 'model should come before messages in body');
      expect(messagesIdx, lessThan(maxTokensIdx),
          reason: 'messages should come before max_tokens in body');
    });
  });

  group('ChatService - temperature/maxTokens toggle behavior', () {
    test('temperature NOT sent when enableTemperature is false (model-level)',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false,
          'temperature': 0.5, // value exists but toggle is OFF
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // temperature should NOT be passed to provider when toggle is OFF
      expect(provider.capturedTemperature, isNull,
          reason: 'temperature should be null when enableTemperature is false');

      // _lastRequestBody should NOT contain temperature
      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('temperature'), isFalse,
          reason: 'temperature should NOT be in body when toggle is OFF');
    });

    test('max_tokens NOT sent when enableMaxTokens is false (model-level)',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableMaxTokens': false,
          'maxTokens': 2048, // value exists but toggle is OFF
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // max_tokens should NOT be passed to provider when toggle is OFF
      expect(provider.capturedMaxTokens, isNull,
          reason: 'max_tokens should be null when enableMaxTokens is false');

      // _lastRequestBody should NOT contain max_tokens
      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('max_tokens'), isFalse,
          reason: 'max_tokens should NOT be in body when toggle is OFF');
    });

    test('temperature sent when enableTemperature is true (model-level)',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 0.3,
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // wait a frame for async
      expect(provider.capturedTemperature, closeTo(0.3, 0.001));
    });

    test('max_tokens sent when enableMaxTokens is true (model-level)',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableMaxTokens': true,
          'maxTokens': 2048,
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // wait a frame for async
      expect(provider.capturedMaxTokens, equals(2048));
    });

    test('temperature NOT sent when neither model nor assistant has it enabled',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false,
          // temperature exists but toggle off
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedTemperature, isNull);
    });

    test('assistant override sends temperature when assistant enables it',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false, // model toggle OFF
          'temperature': 0.5,
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      // Assistant enables temperature override
      service.setAssistantSettings(AssistantSettings(
        enableTemperature: true,
        temperature: 0.8,
      ));

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Assistant override should be used
      expect(provider.capturedTemperature, closeTo(0.8, 0.001));
    });
  });

  group('OpenAICompatibleChatProvider.buildBody - parameter ordering', () {
    late OpenAICompatibleChatProvider provider;

    setUp(() {
      provider = OpenAICompatibleChatProvider(
        baseUrl: 'https://api.example.com/v1/chat/completions',
        apiKey: 'sk-test-key',
        name: 'Test Provider',
      );
    });

    test('extraParams spread at the END of body', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'Hi'}
        ],
        model: 'test-model',
        maxTokens: 1024,
        temperature: 0.5,
        stream: true,
        extraParams: {
          'custom_param': 'value1',
          'top_p': 0.9,
        },
      );

      final keys = body.keys.toList();
      final modelIdx = keys.indexOf('model');
      final messagesIdx = keys.indexOf('messages');
      final maxTokensIdx = keys.indexOf('max_tokens');
      final streamIdx = keys.indexOf('stream');
      final customParamIdx = keys.indexOf('custom_param');
      final topPIdx = keys.indexOf('top_p');

      // custom_param and top_p should come after standard params
      expect(customParamIdx, greaterThan(modelIdx));
      expect(customParamIdx, greaterThan(messagesIdx));
      expect(customParamIdx, greaterThan(maxTokensIdx));
      expect(topPIdx, greaterThan(streamIdx));
    });

    test('extraParams keys override standard params (by key name)', () {
      // If an extraParam has the same key as a standard param,
      // the extraParam value wins (since it's spread after)
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'Hi'}
        ],
        model: 'test-model',
        temperature: 0.5,
        extraParams: {
          'temperature': 0.9, // override
        },
      );

      expect(body['temperature'], equals(0.9),
          reason: 'extraParams spread at end should override standard params');
    });
  });

  group('ChatService setAssistantSettings integration', () {
    test(
        'assistant settings override model temperature when enableTemperature is true',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 0.3,
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        enableTemperature: true,
        temperature: 0.9,
      ));

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Assistant override should take precedence over model config
      expect(provider.capturedTemperature, closeTo(0.9, 0.001));
    });

    test(
        'assistant settings do NOT send max_tokens when enableMaxTokens is false',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableMaxTokens': false,
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        enableMaxTokens: false,
        maxTokens: 1024,
      ));

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Neither model nor assistant has max_tokens enabled - should be null
      expect(provider.capturedMaxTokens, isNull,
          reason:
              'max_tokens should be null when both model and assistant toggles are OFF');
    });
  });
}
