// Merged from: chat_service_request_body_test.dart,
// chat_service_request_body_extra_params_test.dart,
// chat_service_param_fix_test.dart,
// chat_service_extra_params_test.dart,
// chat_service_provider_json_param_test.dart,
// chat_service_assistant_override_test.dart,
// chat_service_json_serialization_test.dart,
// chat_service_system_prompt_test.dart
//
// Naming conflicts resolved:
// - _RequestCaptureProvider (request_body_extra_params) -> _RequestBodyExtraCapture
// - _BodyCaptureProvider (provider_json_param)          -> _ProviderJsonBodyCapture
// - _BodyCaptureProvider (json_serialization)           -> _JsonSerBodyCapture

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/assistant.dart'
    show AssistantSettings, CustomParameter;
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

/// Mock provider that captures request parameters for inspection.
/// (Originally from chat_service_request_body_test.dart)
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

/// Mock provider that captures request parameters for inspection.
/// (Originally from chat_service_request_body_extra_params_test.dart,
/// renamed to avoid conflict with the identically named class above.)
class _RequestBodyExtraCapture extends BaseChatProvider {
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

/// Mock provider that captures request parameters and simulates streaming.
/// (Originally from chat_service_param_fix_test.dart)
class _CapturingProvider extends BaseChatProvider {
  Map<String, dynamic>? capturedExtraParams;
  int? capturedMaxTokens;
  double? capturedTemperature;
  List<Map<String, dynamic>>? capturedTools;

  @override
  String get name => 'CaptureProvider';

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

/// Mock provider that captures all parameters for inspection.
/// (Originally from chat_service_extra_params_test.dart)
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

/// Mock provider that captures the ACTUAL jsonEncode'd body for inspection.
/// (Originally from chat_service_provider_json_param_test.dart, renamed
/// to avoid conflict with the identically named class in
/// chat_service_json_serialization_test.dart.)
class _ProviderJsonBodyCapture extends BaseChatProvider {
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

/// Mock provider that captures all parameters for inspection.
/// (Originally from chat_service_assistant_override_test.dart)
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

/// Mock provider that captures the ACTUAL jsonEncode'd body for inspection.
/// (Originally from chat_service_json_serialization_test.dart, renamed
/// to avoid conflict with the identically named class in
/// chat_service_provider_json_param_test.dart.)
class _JsonSerBodyCapture extends BaseChatProvider {
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

/// Mock provider that captures the API messages for inspection.
/// (Originally from chat_service_system_prompt_test.dart)
class _MessageCaptureProvider extends BaseChatProvider {
  List<Map<String, dynamic>>? capturedMessages;

  @override
  String get name => 'MessageCapture';

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
    capturedMessages = messages;
    return 'test response';
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
    capturedMessages = messages;
    yield AIStreamEvent('test response');
  }
}

void main() {
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

  group('ChatService - tools behavior', () {
    late _RequestCaptureProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = _RequestCaptureProvider();
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
        },
      );
    });

    test(
        'sendStreamWithTools has no tools key in _lastRequestBody when empty list',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);
      provider.reset();

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hi',
        history: [],
        tools: [],
      )) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('tools'), isFalse,
          reason:
              'tools key should NOT be in _lastRequestBody when empty list');
    });

    test('sendStreamWithTools passes null tools to provider when empty list',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);
      provider.reset();

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hi',
        history: [],
        tools: [],
      )) {
        events.add(event);
      }

      // Provider should receive null when empty list is passed
      // The provider's _buildBody conditionally excludes null/empty tools
      expect(provider.capturedTools, isNull,
          reason: 'tools should be null when empty list is passed');
    });

    test(
        'sendStreamWithTools includes tools from _lastRequestBody when non-empty',
        () async {
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
        tools: [toolDef],
      )) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('tools'), isTrue,
          reason: 'tools should be in _lastRequestBody when list is non-empty');
      expect(lastBody['tools'], isA<List>());
      expect((lastBody['tools'] as List).length, equals(1));
    });
  });

  group('ChatService - reasoning params in _lastRequestBody', () {
    late _RequestCaptureProvider provider;

    setUp(() {
      provider = _RequestCaptureProvider();
    });

    test(
        'sendStream includes reasoning params in _lastRequestBody when reasoning enabled',
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

      // Reasoning params should be passed to provider via extraParams
      expect(provider.capturedExtraParams, isNotNull,
          reason: 'extraParams should be non-null');
      expect(provider.capturedExtraParams!.containsKey('thinking'), isTrue,
          reason: 'reasoning params should be in extraParams');
      expect(provider.capturedExtraParams!['thinking'], isA<Map>());
      expect((provider.capturedExtraParams!['thinking'] as Map)['type'],
          equals('enabled'));
      expect((provider.capturedExtraParams!['thinking'] as Map)['budget'],
          equals('high'));
    });

    test(
        'sendStreamWithTools includes reasoning params in extraParams when reasoning enabled',
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
      await for (final event in service.sendStreamWithTools(
        'Hi',
        history: [],
        reasoning: true,
        reasoningParamValues: {'thinking.budget': 'high'},
      )) {
        events.add(event);
      }

      // Reasoning params should be passed to provider via extraParams
      expect(provider.capturedExtraParams, isNotNull,
          reason: 'extraParams should be non-null');
      expect(provider.capturedExtraParams!.containsKey('thinking'), isTrue,
          reason: 'reasoning params should be in extraParams');
      expect(provider.capturedExtraParams!['thinking'], isA<Map>());
      expect((provider.capturedExtraParams!['thinking'] as Map)['type'],
          equals('enabled'));
      expect((provider.capturedExtraParams!['thinking'] as Map)['budget'],
          equals('high'));
    });
  });

  // ====================================================================
  // From chat_service_request_body_extra_params_test.dart
  // ====================================================================

  group('ChatService - request body includes extra params', () {
    late _RequestBodyExtraCapture provider;

    setUp(() {
      provider = _RequestBodyExtraCapture();
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

  // ====================================================================
  // From chat_service_param_fix_test.dart
  // ====================================================================

  group('ChatService._buildExtraParams - JSON type handling', () {
    test('JSON type model-level custom param is properly parsed', () async {
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
          CustomParam(
            paramName: 'metadata',
            defaultValue: '{"source": "test", "version": 2}',
            type: 'json',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      provider.reset();
      // sendStream uses Future.microtask internally, so we await a cycle
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);

      // JSON-type params should be actual parsed objects, not strings
      final responseFormat = extraParams!['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'JSON type param should be a Map, not a String');
      expect((responseFormat as Map)['type'], equals('json_object'));

      final metadata = extraParams['metadata'];
      expect(metadata, isA<Map>(),
          reason: 'JSON type param should be a Map, not a String');
      expect((metadata as Map)['source'], equals('test'));
      expect(metadata['version'], equals(2));
    });

    test('JSON type assistant-level custom param is properly parsed', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      service.setAssistantCustomParams([
        CustomParameter(
          name: 'response_format',
          type: 'json',
          value: '{"type": "json_object"}',
        ),
        CustomParameter(
          name: 'tools_config',
          type: 'json',
          value: '["tool_a", "tool_b"]',
        ),
      ]);

      provider.reset();
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);

      final responseFormat = extraParams!['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'JSON type assistant param should be a Map');
      expect((responseFormat as Map)['type'], equals('json_object'));

      final toolsConfig = extraParams['tools_config'];
      expect(toolsConfig, isA<List>(),
          reason: 'JSON type assistant param (array) should be a List');
      expect((toolsConfig as List).length, equals(2));
    });

    test('malformed JSON falls back to raw string', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'bad_json',
            defaultValue: '{invalid json}',
            type: 'json',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      provider.reset();
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);
      // Malformed JSON should return the raw string
      expect(extraParams!['bad_json'], equals('{invalid json}'));
    });
  });

  group('ChatService - number/boolean type handling', () {
    test('number type model-level custom param is sent as number', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'top_k',
            defaultValue: '50',
            type: 'number',
          ),
          CustomParam(
            paramName: 'temperature',
            defaultValue: '0.8',
            type: 'number',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      provider.reset();
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);
      expect(extraParams!['top_k'], equals(50.0),
          reason: 'number type param should be sent as num, not string');
      expect(extraParams['temperature'], equals(0.8),
          reason: 'number type param should be sent as num, not string');
    });

    test('boolean type model-level custom param is sent as bool', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {'context': 4096},
        customParams: [
          CustomParam(
            paramName: 'use_cache',
            defaultValue: 'true',
            type: 'boolean',
          ),
          CustomParam(
            paramName: 'stream_options',
            defaultValue: 'false',
            type: 'boolean',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      provider.reset();
      service.sendStream('Hi', history: []).listen((_) {});
      await Future.delayed(Duration.zero);

      final extraParams = provider.capturedExtraParams;
      expect(extraParams, isNotNull);
      expect(extraParams!['use_cache'], isTrue,
          reason: 'boolean type param should be sent as bool');
      expect(extraParams['stream_options'], isFalse,
          reason: 'boolean type param should be sent as bool');
    });
  });

  group('ChatService._lastRequestBody - parameter ordering', () {
    test('extraParams are after standard params in _lastRequestBody', () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 0.5,
          'enableMaxTokens': true,
          'maxTokens': 2048,
        },
        customParams: [
          CustomParam(
            paramName: 'custom_param_1',
            defaultValue: 'value1',
            type: 'string',
          ),
        ],
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      // Get the keys in order
      final keys = lastBody!.keys.toList();

      // Standard params should come first
      final messagesIdx = keys.indexOf('messages');
      final modelIdx = keys.indexOf('model');
      final maxTokensIdx = keys.indexOf('max_tokens');
      final customParamIdx = keys.indexOf('custom_param_1');

      // custom_param_1 should be after standard params
      expect(customParamIdx, greaterThan(messagesIdx),
          reason: 'custom params should be after messages');
      expect(customParamIdx, greaterThan(modelIdx),
          reason: 'custom params should be after model');
      expect(customParamIdx, greaterThan(maxTokensIdx),
          reason: 'custom params should be after max_tokens');
    });

    test('extraParams spread AFTER standard params in sendStreamWithTools',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': true,
          'temperature': 0.5,
          'enableMaxTokens': true,
          'maxTokens': 2048,
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event
          in service.sendStreamWithTools('Hi', history: [])) {
        events.add(event);
      }

      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);

      final keys = lastBody!.keys.toList();
      final messagesIdx = keys.indexOf('messages');
      final modelIdx = keys.indexOf('model');
      final maxTokensIdx = keys.indexOf('max_tokens');

      // Standard params should come first. If max_tokens is included,
      // it should be after messages.
      expect(modelIdx, lessThan(messagesIdx),
          reason: 'model should come before messages in body');
      expect(messagesIdx, lessThan(maxTokensIdx),
          reason: 'messages should come before max_tokens in body');
    });
  });

  group('ChatService - temperature/maxTokens toggle behavior', () {
    test('temperature NOT sent when enableTemperature is false (model-level)',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false,
          'temperature': 0.5, // value exists but toggle is OFF
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // temperature should NOT be passed to provider when toggle is OFF
      expect(provider.capturedTemperature, isNull,
          reason: 'temperature should be null when enableTemperature is false');

      // _lastRequestBody should NOT contain temperature
      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('temperature'), isFalse,
          reason: 'temperature should NOT be in body when toggle is OFF');
    });

    test('max_tokens NOT sent when enableMaxTokens is false (model-level)',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableMaxTokens': false,
          'maxTokens': 2048, // value exists but toggle is OFF
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // max_tokens should NOT be passed to provider when toggle is OFF
      expect(provider.capturedMaxTokens, isNull,
          reason: 'max_tokens should be null when enableMaxTokens is false');

      // _lastRequestBody should NOT contain max_tokens
      final lastBody = service.lastRequestBody;
      expect(lastBody, isNotNull);
      expect(lastBody!.containsKey('max_tokens'), isFalse,
          reason: 'max_tokens should NOT be in body when toggle is OFF');
    });

    test('temperature sent when enableTemperature is true (model-level)',
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

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // wait a frame for async
      expect(provider.capturedTemperature, closeTo(0.3, 0.001));
    });

    test('max_tokens sent when enableMaxTokens is true (model-level)',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableMaxTokens': true,
          'maxTokens': 2048,
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // wait a frame for async
      expect(provider.capturedMaxTokens, equals(2048));
    });

    test('temperature NOT sent when neither model nor assistant has it enabled',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false,
          // temperature exists but toggle off
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      expect(provider.capturedTemperature, isNull);
    });

    test('assistant override sends temperature when assistant enables it',
        () async {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        typeConfig: {
          'context': 4096,
          'enableTemperature': false, // model toggle OFF
          'temperature': 0.5,
        },
      );

      final provider = _CapturingProvider();
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      // Assistant enables temperature override
      service.setAssistantSettings(AssistantSettings(
        enableTemperature: true,
        temperature: 0.8,
      ));

      final events = <dynamic>[];
      provider.reset();
      await for (final event in service.sendStream('Hi', history: [])) {
        events.add(event);
      }

      // Assistant override should be used
      expect(provider.capturedTemperature, closeTo(0.8, 0.001));
    });
  });

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
