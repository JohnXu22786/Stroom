import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

/// Mock provider that captures all parameters for inspection.
class _CaptureProvider extends BaseChatProvider {
  Map<String, dynamic>? capturedExtraParams;
  int? capturedMaxTokens;
  double? capturedTemperature;
  bool? capturedReasoning;

  @override
  String get name => 'Capture';

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
    capturedReasoning = reasoning;
    yield AIStreamEvent('');
  }

  void reset() {
    capturedExtraParams = null;
    capturedMaxTokens = null;
    capturedTemperature = null;
    capturedReasoning = null;
  }
}

void main() {
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
      expect(
          provider.capturedExtraParams!['presence_penalty'], closeTo(0.1, 0.001));
      expect(provider.capturedExtraParams!['seed'], equals(12345));
    });

    test('assistant settings override model temperature when enabled', () async {
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
      expect(provider.capturedExtraParams!['presence_penalty'], closeTo(0.0, 0.001));
      expect(provider.capturedExtraParams!['seed'], equals(42));
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

    test('assistant frequencyPenalty disabled does NOT override',
        () async {
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

    test('assistant presencePenalty disabled does NOT override',
        () async {
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

    test('assistant seed disabled does NOT override model seed',
        () async {
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

    test('assistant topP added when model has no topP in typeConfig',
        () async {
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

    test('assistant enableSeed with null seed does not add seed',
        () async {
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
}
