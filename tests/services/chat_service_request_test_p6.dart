part of 'chat_service_request_test.dart';

void chatServiceRequestGroup6() {
  group('ChatService assistant settings override model params', () {
    late _CaptureProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = _CaptureProvider();
    });

    test('assistant with streaming override works with sendStreamWithTools',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.7,
          'topP': 0.95,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        temperature: 0.3,
        enableTemperature: true,
        topP: 0.5,
        enableTopP: true,
      ));

      final events = <dynamic>[];
      await for (final event
          in service.sendStreamWithTools('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedTemperature, closeTo(0.3, 0.001));
      expect(provider.capturedExtraParams!['top_p'], closeTo(0.5, 0.001));
    });

    test('setAssistantSettings with null clears override', () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.5,
          'enableTemperature': true,
          'topP': 0.95,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      // Set assistant settings
      service.setAssistantSettings(AssistantSettings(
        temperature: 0.1,
        enableTemperature: true,
        topP: 0.5,
        enableTopP: true,
      ));
      // Then clear them
      service.setAssistantSettings(null);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Model params should be used after clearing
      expect(provider.capturedTemperature, closeTo(0.5, 0.001));
      expect(provider.capturedExtraParams!['top_p'], closeTo(0.95, 0.001));
    });

    test('assistant maxTokens disabled does NOT override model maxTokens',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.7,
          'enableMaxTokens': true,
          'maxTokens': 8192,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        maxTokens: 2048,
        enableMaxTokens: false,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Model maxTokens (from typeConfig.maxTokens) should be used
      expect(provider.capturedMaxTokens, equals(8192));
    });

    test('assistant frequencyPenalty disabled does NOT override', () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.7,
          'frequencyPenalty': 0.2,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        frequencyPenalty: 1.5,
        enableFrequencyPenalty: false,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams!['frequency_penalty'],
          closeTo(0.2, 0.001));
    });

    test('assistant presencePenalty disabled does NOT override', () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.7,
          'presencePenalty': 0.1,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        presencePenalty: 1.0,
        enablePresencePenalty: false,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams!['presence_penalty'],
          closeTo(0.1, 0.001));
    });

    test('assistant seed disabled does NOT override model seed', () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.7,
          'seed': 99999,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        seed: 123,
        enableSeed: false,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams!['seed'], equals(99999));
    });

    test('assistant topP added when model has no topP in typeConfig', () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.7,
          // No topP in model config
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        topP: 0.3,
        enableTopP: true,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Assistant topP should be added even though model doesn't have topP
      expect(provider.capturedExtraParams!['top_p'], closeTo(0.3, 0.001));
    });

    test('assistant enableSeed with null seed does not add seed', () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.7,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        seed: null,
        enableSeed: true,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Seed should NOT be in extra params since assistant seed is null
      expect(provider.capturedExtraParams!.containsKey('seed'), isFalse);
    });
  });

  // ====================================================================
  // From chat_service_json_serialization_test.dart
  // ====================================================================

  group('ChatService - JSON type custom param full serialization', () {
    test(
        'model-level JSON custom param is sent as raw object in jsonEncode body',
        () async {
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
        ],
      );

      final provider = _JsonSerBodyCapture();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      await for (final _ in service.sendStream('Hi', history: [])) {}

      // Check that extraParams contains the parsed Map
      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);
      expect(extraParams!['response_format'], isA<Map>(),
          reason: 'response_format should be a Map in extraParams');

      // Check that the jsonEncode'd body has the raw JSON object
      final jsonBody = provider.capturedJsonBody;
      expect(jsonBody, isNotNull);

      final parsedBody = jsonDecode(jsonBody!) as Map<String, dynamic>;
      final responseFormat = parsedBody['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'response_format should be a Map in the final JSON body');
      expect((responseFormat as Map)['type'], equals('json_object'));
    });

    test(
        'assistant-level JSON custom param is sent as raw object in jsonEncode body',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
      );

      final provider = _JsonSerBodyCapture();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      service.setAssistantCustomParams([
        CustomParameter(
          name: 'response_format',
          type: 'json',
          value: '{"type": "json_object"}',
        ),
      ]);

      await for (final _ in service.sendStream('Hi', history: [])) {}

      // Check that extraParams contains the parsed Map
      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);
      expect(extraParams!['response_format'], isA<Map>(),
          reason: 'response_format should be a Map in extraParams');

      // Check that the jsonEncode'd body has the raw JSON object
      final jsonBody = provider.capturedJsonBody;
      expect(jsonBody, isNotNull);

      final parsedBody = jsonDecode(jsonBody!) as Map<String, dynamic>;
      final responseFormat = parsedBody['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'response_format should be a Map in the final JSON body');
      expect((responseFormat as Map)['type'], equals('json_object'));
    });

    test(
        'assistant-level JSON param with already-parsed Map value is not double-parsed',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
      );

      final provider = _JsonSerBodyCapture();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      // Simulate the case where value is already a Map (e.g., from persistence)
      service.setAssistantCustomParams([
        CustomParameter(
          name: 'response_format',
          type: 'json',
          value: {'type': 'json_object'},
        ),
      ]);

      await for (final _ in service.sendStream('Hi', history: [])) {}

      final jsonBody = provider.capturedJsonBody;
      expect(jsonBody, isNotNull);

      final parsedBody = jsonDecode(jsonBody!) as Map<String, dynamic>;
      final responseFormat = parsedBody['response_format'];
      expect(responseFormat, isA<Map>(),
          reason:
              'Already-parsed Map should remain a Map in the final JSON body');
      expect((responseFormat as Map)['type'], equals('json_object'));
    });

    test('sendStreamWithTools also correctly serializes JSON custom params',
        () async {
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
        ],
      );

      final provider = _JsonSerBodyCapture();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final toolDef = ToolDefinition(
        name: 'test_tool',
        description: 'A test tool',
        parameters: {'type': 'object', 'properties': {}},
      );

      await for (final _ in service.sendStreamWithTools(
        'Hi',
        history: [],
        tools: [toolDef],
      )) {}

      final jsonBody = provider.capturedJsonBody;
      expect(jsonBody, isNotNull);

      final parsedBody = jsonDecode(jsonBody!) as Map<String, dynamic>;
      final responseFormat = parsedBody['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'response_format should be a Map in sendStreamWithTools');
      expect((responseFormat as Map)['type'], equals('json_object'));
    });
  });
}
