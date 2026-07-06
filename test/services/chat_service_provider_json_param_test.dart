import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:dio/dio.dart';

/// Mock provider that captures the ACTUAL jsonEncode'd body for inspection.
class _BodyCaptureProvider extends BaseChatProvider {
  String? capturedJsonBody;
  Map<String, dynamic>? capturedExtraParams;

  @override
  String get name => 'BodyCapture';

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
    // Simulate what _buildBody does + jsonEncode
    final body = {
      'model': model ?? defaultParams['model'],
      'messages': messages,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
      'stream': true,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (extraParams != null) ...extraParams,
    };
    capturedJsonBody = jsonEncode(body);
    yield AIStreamEvent('');
  }

  void reset() {
    capturedJsonBody = null;
    capturedExtraParams = null;
  }
}

void main() {
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

      final provider = _BodyCaptureProvider();
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

      final provider = _BodyCaptureProvider();
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

      final provider = _BodyCaptureProvider();
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
