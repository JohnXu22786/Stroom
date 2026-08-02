part of 'chat_service_request_test.dart';

void chatServiceRequestGroup1() {
  // ====================================================================
  // From chat_service_request_body_test.dart
  // ====================================================================

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
}
