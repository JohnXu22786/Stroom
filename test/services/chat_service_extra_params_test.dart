import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

/// Mock provider that captures all parameters for inspection.
class _ParamCaptureProvider extends BaseChatProvider {
  Map<String, dynamic>? capturedExtraParams;
  int? capturedMaxTokens;
  double? capturedTemperature;

  @override
  String get name => 'ParamCapture';

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
    yield AIStreamEvent('');
  }

  void reset() {
    capturedExtraParams = null;
    capturedMaxTokens = null;
    capturedTemperature = null;
  }
}

void main() {
  group('ChatService._buildExtraParams - LLM params from typeConfig', () {
    late _ParamCaptureProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = _ParamCaptureProvider();
    });

    test('includes temperature, top_p, frequency_penalty, presence_penalty, seed from typeConfig',
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
      expect(provider.capturedExtraParams!['frequency_penalty'], closeTo(0.2, 0.001));
      expect(provider.capturedExtraParams!['presence_penalty'], closeTo(0.1, 0.001));
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
      expect(provider.capturedExtraParams!.containsKey('frequency_penalty'), isFalse);
      expect(provider.capturedExtraParams!.containsKey('presence_penalty'), isFalse);
      expect(provider.capturedExtraParams!.containsKey('seed'), isFalse);
    });

    test('temperature is read from typeConfig and passed directly when toggle is on', () async {
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
}
