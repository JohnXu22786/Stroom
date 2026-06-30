import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

/// Creates a mock provider that captures the request body for inspection.
class CapturingChatProvider extends BaseChatProvider {
  Map<String, dynamic>? capturedBody;
  bool throwError = false;

  @override
  String get name => 'CapturingProvider';

  @override
  List<String> get supportedModelIds => ['test-model'];

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test-model',
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
    if (throwError) {
      throw Exception('Simulated error');
    }
    capturedBody = {
      'model': model,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'reasoning': reasoning,
      'reasoningEffort': reasoningEffort,
      'tools': tools,
      'extraParams': extraParams,
    };
    // Yield a minimal event so the stream doesn't hang
    yield AIStreamEvent('');
  }
}

void main() {
  group('Reasoning effort data flow', () {
    late CapturingChatProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = CapturingChatProvider();
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test Model',
        typeConfig: {
          'context': 4096,
          'temperature': 0.7,
        },
      );
    });

    test('sendStream passes reasoning=true and default reasoningEffort',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream(
        'Hello',
        history: [],
        reasoning: true,
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isTrue);
      expect(provider.capturedBody!['reasoningEffort'], 'medium');
    });

    test('sendStream passes reasoning=false to provider', () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream(
        'Hello',
        history: [],
        reasoning: false,
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isFalse);
      expect(provider.capturedBody!['reasoningEffort'], 'medium');
    });

    test('sendStream passes custom reasoningEffort value', () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream(
        'Hello',
        history: [],
        reasoning: true,
        reasoningEffort: 'high',
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isTrue);
      expect(provider.capturedBody!['reasoningEffort'], 'high');
    });

    test(
        'ChatService.sendStreamWithTools chains reasoning and effort correctly',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hello',
        history: [],
        reasoning: true,
        reasoningEffort: 'low',
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isTrue);
      expect(provider.capturedBody!['reasoningEffort'], 'low');
    });

    test('ChatService.sendStreamWithTools passes default reasoningEffort',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hello',
        history: [],
        reasoning: true,
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isTrue);
      expect(provider.capturedBody!['reasoningEffort'], 'medium');
    });
  });
}
