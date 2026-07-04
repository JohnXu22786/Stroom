import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/assistant.dart' show CustomParameter;
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

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

      final provider = _BodyCaptureProvider();
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

      final provider = _BodyCaptureProvider();
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

      final provider = _BodyCaptureProvider();
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

      final provider = _BodyCaptureProvider();
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
