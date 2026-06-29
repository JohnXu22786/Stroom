import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

/// Mock provider that captures request parameters for inspection.
class _RequestCaptureProvider extends BaseChatProvider {
  Map<String, dynamic>? capturedExtraParams;
  int? capturedMaxTokens;
  double? capturedTemperature;
  List<Map<String, dynamic>>? capturedTools;

  @override
  String get name => 'RequestCapture';

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
  group('OpenAICompatibleChatProvider.buildBody', () {
    late OpenAICompatibleChatProvider provider;

    setUp(() {
      provider = OpenAICompatibleChatProvider(
        baseUrl: 'https://api.example.com/v1/chat/completions',
        apiKey: 'sk-test-key',
        name: 'Test Provider',
      );
    });

    test('omits temperature when null', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'Hi'}
        ],
        model: 'test-model',
      );
      expect(body.containsKey('temperature'), isFalse,
          reason: 'temperature key should be omitted when null');
    });

    test('includes temperature when value provided', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'Hi'}
        ],
        model: 'test-model',
        temperature: 0.5,
      );
      expect(body['temperature'], closeTo(0.5, 0.001));
    });

    test('omits tools when tools is null', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'Hi'}
        ],
        model: 'test-model',
        tools: null,
        stream: true,
      );
      expect(body.containsKey('tools'), isFalse,
          reason: 'tools key should be omitted when null');
    });

    test('omits tools when tools is empty list', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'Hi'}
        ],
        model: 'test-model',
        tools: [],
        stream: true,
      );
      expect(body.containsKey('tools'), isFalse,
          reason: 'tools key should be omitted when empty list');
    });

    test('includes tools when non-empty', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'Hi'}
        ],
        model: 'test-model',
        tools: [
          {
            'type': 'function',
            'function': {
              'name': 'test_tool',
              'description': 'A test tool',
              'parameters': {'type': 'object', 'properties': {}},
            },
          },
        ],
        stream: true,
      );
      expect(body.containsKey('tools'), isTrue);
      expect(body['tools'], isA<List>());
      expect((body['tools'] as List).length, equals(1));
    });

    test('includes stream parameter', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'Hi'}
        ],
        model: 'test-model',
        stream: true,
      );
      expect(body['stream'], isTrue);
    });
  });

  group('ChatService - temperature behavior', () {
    late _RequestCaptureProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = _RequestCaptureProvider();
    });

    test(
        'sendStream omits temperature from _lastRequestBody when toggle is off',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false,
          // Temperature exists but toggle is OFF
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // _lastRequestBody should NOT contain temperature when toggle is OFF
      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('temperature'), isFalse,
          reason:
              'temperature should NOT be in _lastRequestBody when toggle is off');
    });

    test('sendStream does NOT pass temperature to provider when toggle is off',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Provider should NOT receive temperature when toggle is OFF
      expect(provider.capturedTemperature, isNull,
          reason: 'temperature should be null when toggle is off');
    });

    test(
        'sendStream includes temperature in _lastRequestBody when toggle is on',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 0.3,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!['temperature'], closeTo(0.3, 0.001));
    });

    test(
        'sendStream passes configured temperature to provider when toggle is on',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 0.3,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedTemperature, closeTo(0.3, 0.001));
    });

    test('sendStreamWithTools omits temperature when toggle is off', () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event
          in service.sendStreamWithTools('Hi', history: [])) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('temperature'), isFalse,
          reason:
              'temperature should NOT be in _lastRequestBody when toggle is off');
    });

    test(
        'sendStreamWithTools does NOT pass temperature to provider when toggle off',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event
          in service.sendStreamWithTools('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedTemperature, isNull,
          reason: 'temperature should be null when toggle is off');
    });
  });

  group('ChatService - tools behavior', () {
    late _RequestCaptureProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = _RequestCaptureProvider();
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
        },
      );
    });

    test(
        'sendStreamWithTools has no tools key in _lastRequestBody when empty list',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);
      provider.reset();

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hi',
        history: [],
        tools: [],
      )) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('tools'), isFalse,
          reason:
              'tools key should NOT be in _lastRequestBody when empty list');
    });

    test('sendStreamWithTools passes null tools to provider when empty list',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);
      provider.reset();

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hi',
        history: [],
        tools: [],
      )) {
        events.add(event);
      }

      // Provider should receive null when empty list is passed
      // The provider's _buildBody conditionally excludes null/empty tools
      expect(provider.capturedTools, isNull,
          reason: 'tools should be null when empty list is passed');
    });

    test(
        'sendStreamWithTools includes tools from _lastRequestBody when non-empty',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final toolDef = ToolDefinition(
        name: 'test_tool',
        description: 'A test tool',
        parameters: {'type': 'object', 'properties': {}},
      );

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hi',
        history: [],
        tools: [toolDef],
      )) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('tools'), isTrue,
          reason: 'tools should be in _lastRequestBody when list is non-empty');
      expect(lastBody['tools'], isA<List>());
      expect((lastBody['tools'] as List).length, equals(1));
    });
  });

  group('ChatService - reasoning params in _lastRequestBody', () {
    late _RequestCaptureProvider provider;

    setUp(() {
      provider = _RequestCaptureProvider();
    });

    test(
        'sendStream includes reasoning params in _lastRequestBody when reasoning enabled',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
        },
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'thinking.budget',
            isReasoningToggle: false,
            options: ['low', 'medium', 'high'],
            enabled: true,
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream(
        'Hi',
        history: [],
        reasoning: true,
        reasoningParamValues: {'thinking.budget': 'high'},
      )) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      // Reasoning params should be passed to provider via extraParams
      expect(provider.capturedExtraParams, isNotNull,
          reason: 'extraParams should be non-null');
      expect(provider.capturedExtraParams!.containsKey('thinking'), isTrue,
          reason: 'reasoning params should be in extraParams');
      expect(provider.capturedExtraParams!['thinking'], isA<Map>());
      expect((provider.capturedExtraParams!['thinking'] as Map)['type'],
          equals('enabled'));
      expect((provider.capturedExtraParams!['thinking'] as Map)['budget'],
          equals('high'));
    });

    test(
        'sendStreamWithTools includes reasoning params in extraParams when reasoning enabled',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
        },
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'thinking.budget',
            isReasoningToggle: false,
            options: ['low', 'medium', 'high'],
            enabled: true,
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hi',
        history: [],
        reasoning: true,
        reasoningParamValues: {'thinking.budget': 'high'},
      )) {
        events.add(event);
      }

      // Reasoning params should be passed to provider via extraParams
      expect(provider.capturedExtraParams, isNotNull,
          reason: 'extraParams should be non-null');
      expect(provider.capturedExtraParams!.containsKey('thinking'), isTrue,
          reason: 'reasoning params should be in extraParams');
      expect(provider.capturedExtraParams!['thinking'], isA<Map>());
      expect((provider.capturedExtraParams!['thinking'] as Map)['type'],
          equals('enabled'));
      expect((provider.capturedExtraParams!['thinking'] as Map)['budget'],
          equals('high'));
    });
  });
}
