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
part 'chat_service_request_test_p1.dart';
part 'chat_service_request_test_p2.dart';
part 'chat_service_request_test_p3.dart';
part 'chat_service_request_test_p4.dart';
part 'chat_service_request_test_p5.dart';
part 'chat_service_request_test_p6.dart';

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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
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
    String? system,
  }) async* {
    capturedMessages = messages;
    yield AIStreamEvent('test response');
  }
}

void main() {
  chatServiceRequestGroup1();
  chatServiceRequestGroup2();
  chatServiceRequestGroup3();
  chatServiceRequestGroup4();
  chatServiceRequestGroup5();
  chatServiceRequestGroup6();
}
