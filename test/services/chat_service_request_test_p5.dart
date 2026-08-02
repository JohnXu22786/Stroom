part of 'chat_service_request_test.dart';

void chatServiceRequestGroup5() {
  // ====================================================================
  // From chat_service_assistant_override_test.dart
  // ====================================================================

  group('ChatService assistant settings override model params', () {
    late _CaptureProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = _CaptureProvider();
    });

    test('model params are used when assistant settings are NOT set', () async {
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

      // Temperature and maxTokens passed directly
      expect(provider.capturedTemperature, closeTo(0.5, 0.001));
      // Extra params from model
      expect(provider.capturedExtraParams!['top_p'], closeTo(0.95, 0.001));
      expect(provider.capturedExtraParams!['frequency_penalty'],
          closeTo(0.2, 0.001));
      expect(provider.capturedExtraParams!['presence_penalty'],
          closeTo(0.1, 0.001));
      expect(provider.capturedExtraParams!['seed'], equals(12345));
    });

    test('assistant settings override model temperature when enabled',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.5,
          'topP': 0.95,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings(
        temperature: 0.1,
        enableTemperature: true,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Assistant temperature should override model temperature
      expect(provider.capturedTemperature, closeTo(0.1, 0.001));
    });

    test('assistant settings do NOT override model temperature when disabled',
        () async {
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
      service.setAssistantSettings(AssistantSettings(
        temperature: 0.1,
        enableTemperature: false, // disabled
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Model temperature should remain
      expect(provider.capturedTemperature, closeTo(0.5, 0.001));
    });

    test('assistant settings override model topP when enabled', () async {
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
        topP: 0.5,
        enableTopP: true,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams!['top_p'], closeTo(0.5, 0.001));
    });

    test('assistant settings do NOT override model topP when disabled',
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
        topP: 0.5,
        enableTopP: false, // disabled
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams!['top_p'], closeTo(0.95, 0.001));
    });

    test('assistant settings override maxTokens when enabled', () async {
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
        maxTokens: 2048,
        enableMaxTokens: true,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedMaxTokens, equals(2048));
    });

    test('assistant settings override frequencyPenalty when enabled', () async {
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
        enableFrequencyPenalty: true,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams!['frequency_penalty'],
          closeTo(1.5, 0.001));
    });

    test('assistant settings override presencePenalty when enabled', () async {
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
        enablePresencePenalty: true,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams!['presence_penalty'],
          closeTo(1.0, 0.001));
    });

    test('assistant settings override seed when enabled', () async {
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
        enableSeed: true,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedExtraParams!['seed'], equals(123));
    });

    test('assistant custom params still override model custom params',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.7,
        },
        customParams: [
          CustomParam(
            paramName: 'top_k',
            type: 'number',
            defaultValue: '40',
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      service.setAssistantSettings(AssistantSettings());
      // Custom params are applied separately via setAssistantCustomParams
      service.setAssistantCustomParams([
        CustomParameter(name: 'top_k', type: 'number', value: 100),
      ]);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Assistant custom params should override model custom params
      expect(provider.capturedExtraParams!['top_k'], equals(100.0));
    });

    test('assistant settings with all disabled uses model params only',
        () async {
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 8192,
          'temperature': 0.7,
          'enableTemperature': true,
          'topP': 0.9,
          'frequencyPenalty': 0.1,
          'presencePenalty': 0.0,
          'seed': 42,
        },
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);
      // All switches disabled - should not override anything
      service.setAssistantSettings(AssistantSettings(
        temperature: 0.1,
        enableTemperature: false,
        topP: 0.1,
        enableTopP: false,
        maxTokens: 100,
        enableMaxTokens: false,
        frequencyPenalty: 1.0,
        enableFrequencyPenalty: false,
        presencePenalty: 1.0,
        enablePresencePenalty: false,
        seed: 1,
        enableSeed: false,
      ));

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // All model params should be used
      expect(provider.capturedTemperature, closeTo(0.7, 0.001));
      expect(provider.capturedExtraParams!['top_p'], closeTo(0.9, 0.001));
      expect(provider.capturedExtraParams!['frequency_penalty'],
          closeTo(0.1, 0.001));
      expect(provider.capturedExtraParams!['presence_penalty'],
          closeTo(0.0, 0.001));
      expect(provider.capturedExtraParams!['seed'], equals(42));
    });
  });

  // ====================================================================
  // From chat_service_system_prompt_test.dart
  // ====================================================================

  group('ChatService system prompt', () {
    late _MessageCaptureProvider provider;
    late ModelConfig modelConfig;
    late ChatService service;

    setUp(() {
      provider = _MessageCaptureProvider();
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test Model',
        typeConfig: {},
        customParams: [],
        reasoningParams: [],
      );
      service = ChatService(provider: provider, modelConfig: modelConfig);
    });

    test(
      'system prompt is prepended when set via setAssistantPrompt',
      () async {
        // Set the assistant prompt
        service.setAssistantPrompt(
          'You are a helpful assistant. Speak Chinese.',
        );

        final history = <ChatMessage>[
          ChatMessage(role: 'user', content: 'Hello'),
        ];

        final stream = service.sendStream('Hello', history: history);
        await stream.toList();

        final messages = provider.capturedMessages;
        expect(messages, isNotNull);
        expect(messages!.length, greaterThanOrEqualTo(2));

        // First message should be the system prompt
        expect(messages[0]['role'], 'system');
        expect(
          messages[0]['content'],
          'You are a helpful assistant. Speak Chinese.',
        );
      },
    );

    test('user message comes after system prompt', () async {
      service.setAssistantPrompt('Be helpful.');

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'What is Flutter?'),
      ];

      final stream = service.sendStream('What is Flutter?', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 2);
      expect(messages[0]['role'], 'system');
      expect(messages[1]['role'], 'user');
      expect(messages[1]['content'], 'What is Flutter?');
    });

    test('system prompt not added when empty', () async {
      service.setAssistantPrompt('');

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'Hello'),
      ];

      final stream = service.sendStream('Hello', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 1);
      expect(messages[0]['role'], 'user');
    });

    test('system prompt not added when null', () async {
      service.setAssistantPrompt(null);

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'Hello'),
      ];

      final stream = service.sendStream('Hello', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 1);
      expect(messages[0]['role'], 'user');
    });

    test('system prompt is first message with tool calls flow', () async {
      service.setAssistantPrompt('You are a helpful assistant.');

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'Hello'),
      ];

      final stream = service.sendStreamWithTools('Hello', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 2);
      expect(messages[0]['role'], 'system');
      expect(messages[0]['content'], 'You are a helpful assistant.');
      expect(messages[1]['role'], 'user');
    });
  });
}
