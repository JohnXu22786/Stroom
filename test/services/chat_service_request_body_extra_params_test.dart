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
  group('ChatService - request body includes extra params', () {
    late _RequestCaptureProvider provider;

    setUp(() {
      provider = _RequestCaptureProvider();
    });

    test(
        'sendStream _lastRequestBody includes extraParams (top_p, reasoning, etc.)',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'topP': 0.95,
          'frequencyPenalty': 0.2,
          'presencePenalty': 0.1,
          'seed': 12345,
          'enableTemperature': true,
          'temperature': 0.7,
          'enableMaxTokens': true,
          'maxTokens': 4096,
        },
        customParams: [
          CustomParam(
              paramName: 'style', defaultValue: 'cheerful', type: 'string'),
          CustomParam(paramName: 'speed', defaultValue: '1.5', type: 'number'),
          CustomParam(
              paramName: 'enhanced', defaultValue: 'true', type: 'boolean'),
        ],
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

      // Basic fields should be present
      expect(lastBody!['model'], equals('test-model'));
      expect(lastBody['messages'], isA<List>());
      expect(lastBody.containsKey('max_tokens'), isTrue);
      expect(lastBody.containsKey('temperature'), isTrue);

      // Extra params should be merged into _lastRequestBody
      // top_p from typeConfig
      expect(lastBody['top_p'], closeTo(0.95, 0.001));
      // frequency_penalty from typeConfig
      expect(lastBody['frequency_penalty'], closeTo(0.2, 0.001));
      // presence_penalty from typeConfig
      expect(lastBody['presence_penalty'], closeTo(0.1, 0.001));
      // seed from typeConfig
      expect(lastBody['seed'], equals(12345));

      // Custom params should be merged
      expect(lastBody['style'], equals('cheerful'));
      expect(lastBody['speed'], equals(1.5));
      expect(lastBody['enhanced'], isTrue);

      // Reasoning params should be merged (nested)
      expect(lastBody['thinking'], isA<Map>());
      expect((lastBody['thinking'] as Map)['type'], equals('enabled'));
      expect((lastBody['thinking'] as Map)['budget'], equals('high'));
    });

    test('sendStreamWithTools _lastRequestBody includes extraParams', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'topP': 0.9,
        },
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isReasoningToggle: false,
            options: ['low', 'medium', 'high'],
            enabled: true,
          ),
        ],
      );

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
        reasoning: true,
        reasoningParamValues: {'reasoning_effort': 'high'},
        tools: [toolDef],
      )) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      // Basic fields
      expect(lastBody!['model'], equals('test-model'));
      expect(lastBody.containsKey('tools'), isTrue);

      // Extra params should be merged
      expect(lastBody['top_p'], closeTo(0.9, 0.001));
      expect(lastBody['reasoning_effort'], equals('high'));
    });

    test(
        'sendStream _lastRequestBody includes no extra params when reasoning is off',
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
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      // Not reasoning, so thinking should be 'disabled' (off value)
      expect(lastBody!['thinking'], isA<Map>());
      expect((lastBody['thinking'] as Map)['type'], equals('disabled'));
    });

    test('sendStream _lastRequestBody includes custom params with typed values',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(paramName: 'count', defaultValue: '42', type: 'number'),
          CustomParam(
              paramName: 'active', defaultValue: 'true', type: 'boolean'),
          CustomParam(
              paramName: 'style', defaultValue: 'happy', type: 'string'),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      // Custom params with proper types
      expect(lastBody!['count'], equals(42.0)); // number type
      expect(lastBody['active'], isTrue); // boolean type
      expect(lastBody['style'], equals('happy')); // string type
    });

    test('sendStream _lastRequestBody includes json type custom param',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
              paramName: 'config',
              defaultValue: '{"key": "value"}',
              type: 'json'),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      // json type custom param should be parsed to a Map
      expect(lastBody!['config'], isA<Map>());
      expect((lastBody['config'] as Map)['key'], equals('value'));
    });

    test(
        'sendStream _lastRequestBody includes reasoning param with type: number',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'temp',
            isReasoningToggle: false,
            options: ['0.5', '0.8', '1.0'],
            enabled: true,
            type: 'number',
          ),
        ],
      );

      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream(
        'Hi',
        history: [],
        reasoning: true,
        reasoningParamValues: {'temp': '0.8'},
      )) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      // number type reasoning param should be parsed to double
      expect(lastBody!['temp'], closeTo(0.8, 0.001));
    });
  });
}
