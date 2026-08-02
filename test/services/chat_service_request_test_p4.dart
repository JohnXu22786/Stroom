part of 'chat_service_request_test.dart';

void chatServiceRequestGroup4() {
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

  // ====================================================================
  // From chat_service_extra_params_test.dart
  // ====================================================================

  group('ChatService._buildExtraParams - LLM params from typeConfig', () {
    late _ParamCaptureProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = _ParamCaptureProvider();
    });

    test(
        'includes temperature, top_p, frequency_penalty, presence_penalty, seed from typeConfig',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.5,
          'enableTemperature': true,
          'topP': 0.95,
          'frequencyPenalty': 0.2,
          'presencePenalty': 0.1,
          'seed': 12345,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams, isNotNull);
      expect(provider.capturedExtraParams!['top_p'], closeTo(0.95, 0.001));
      expect(provider.capturedExtraParams!['frequency_penalty'],
          closeTo(0.2, 0.001));
      expect(provider.capturedExtraParams!['presence_penalty'],
          closeTo(0.1, 0.001));
      expect(provider.capturedExtraParams!['seed'], equals(12345));
    });

    test('top_p defaults to not present when not in typeConfig', () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'temperature': 0.7,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams, isNotNull);
      expect(provider.capturedExtraParams!.containsKey('top_p'), isFalse);
      expect(provider.capturedExtraParams!.containsKey('frequency_penalty'),
          isFalse);
      expect(provider.capturedExtraParams!.containsKey('presence_penalty'),
          isFalse);
      expect(provider.capturedExtraParams!.containsKey('seed'), isFalse);
    });

    test(
        'temperature is read from typeConfig and passed directly when toggle is on',
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

      // Temperature is passed directly when toggle is on, not via extraParams
      expect(provider.capturedTemperature, closeTo(0.3, 0.001));
    });
  });

  // ====================================================================
  // From chat_service_provider_json_param_test.dart
  // ====================================================================

  group('Provider-level JSON custom param serialization', () {
    test(
        'provider-level JSON custom param with complex nested JSON is sent as raw object',
        () async {
      // Simulate what a user would configure for an OpenRouter provider
      // where they need to pass: {"order": ["deepinfra", "stepfun/fp8"]}
      final providerConfig = ProviderConfigItem(
        providerName: 'OpenRouter',
        host: 'https://openrouter.ai/api/v1',
        key: 'sk-test',
        customParams: [
          CustomParam(
            paramName: 'provider',
            defaultValue: '{"order": ["deepinfra", "stepfun/fp8"]}',
            type: 'json',
          ),
        ],
      );

      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
      );

      final provider = _ProviderJsonBodyCapture();
      final service = ChatService(
        provider: provider,
        modelConfig: modelConfig,
        providerConfig: providerConfig,
      );

      await for (final _ in service.sendStream('Hi', history: [])) {}

      // Check that extraParams contains the parsed Map
      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);
      expect(extraParams!['provider'], isA<Map>(),
          reason: 'provider should be a Map in extraParams');
      expect((extraParams['provider'] as Map)['order'], isA<List>(),
          reason: 'provider.order should be a List in extraParams');
      expect((extraParams['provider'] as Map)['order'],
          equals(['deepinfra', 'stepfun/fp8']),
          reason: 'provider.order should contain the correct values');

      // Check that the jsonEncode'd body has the raw JSON object
      final jsonBody = provider.capturedJsonBody;
      expect(jsonBody, isNotNull);

      final parsedBody = jsonDecode(jsonBody!) as Map<String, dynamic>;
      final providerField = parsedBody['provider'];
      expect(providerField, isA<Map>(),
          reason:
              'provider should be a Map in the final JSON body, not a String');
      expect((providerField as Map)['order'], isA<List>(),
          reason: 'provider.order should be a List in the final JSON body');
      expect(providerField['order'], equals(['deepinfra', 'stepfun/fp8']));

      // CRITICAL: Ensure the value is NOT a string
      expect(providerField is String, isFalse,
          reason: 'provider MUST NOT be a string in the JSON body');
    });

    test('provider-level JSON param with provider field override still works',
        () async {
      // Test that using custom param name "provider" works correctly
      // even though it's a common field name
      final providerConfig = ProviderConfigItem(
        providerName: 'OpenRouter',
        host: 'https://openrouter.ai/api/v1',
        key: 'sk-test',
        customParams: [
          CustomParam(
            paramName: 'provider',
            defaultValue: '{"order": ["DeepInfra", "StepFun"]}',
            type: 'json',
          ),
        ],
      );

      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
      );

      final provider = _ProviderJsonBodyCapture();
      final service = ChatService(
        provider: provider,
        modelConfig: modelConfig,
        providerConfig: providerConfig,
      );

      await for (final _ in service.sendStream('Hi', history: [])) {}

      final jsonBody = provider.capturedJsonBody;
      expect(jsonBody, isNotNull);

      final parsedBody = jsonDecode(jsonBody!) as Map<String, dynamic>;
      final providerField = parsedBody['provider'];
      expect(providerField, isA<Map>(),
          reason:
              'provider should be a Map in the final JSON body, not a String');
      expect((providerField as Map)['order'], equals(['DeepInfra', 'StepFun']));
    });

    test('both provider-level and model-level JSON params work together',
        () async {
      final providerConfig = ProviderConfigItem(
        providerName: 'OpenRouter',
        host: 'https://openrouter.ai/api/v1',
        key: 'sk-test',
        customParams: [
          CustomParam(
            paramName: 'provider',
            defaultValue: '{"order": ["deepinfra", "stepfun/fp8"]}',
            type: 'json',
          ),
        ],
      );

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

      final provider = _ProviderJsonBodyCapture();
      final service = ChatService(
        provider: provider,
        modelConfig: modelConfig,
        providerConfig: providerConfig,
      );

      await for (final _ in service.sendStream('Hi', history: [])) {}

      final jsonBody = provider.capturedJsonBody;
      expect(jsonBody, isNotNull);

      final parsedBody = jsonDecode(jsonBody!) as Map<String, dynamic>;

      // Check provider field
      final providerField = parsedBody['provider'];
      expect(providerField, isA<Map>(),
          reason: 'provider should be a Map in the final JSON body');
      expect((providerField as Map)['order'],
          equals(['deepinfra', 'stepfun/fp8']));

      // Check response_format field
      final responseFormat = parsedBody['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'response_format should be a Map in the final JSON body');
      expect((responseFormat as Map)['type'], equals('json_object'));
    });
  });
}
