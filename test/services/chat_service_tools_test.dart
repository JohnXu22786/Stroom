// Merged from: chat_service_mcp_test.dart,
// chat_service_tool_chain_format_test.dart
//
// No naming conflicts between sources for this file.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_event.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';
part 'chat_service_tools_test_p1.dart';
part 'chat_service_tools_test_p2.dart';
part 'chat_service_tools_test_p3.dart';

// ====================================================================
// Helper: A mock provider that simulates DeepSeek/OpenRouter responses
// with tool calls in the correct format.
// (Originally from chat_service_tool_chain_format_test.dart)
// ====================================================================
class _MockToolCallProvider extends BaseChatProvider {
  final List<List<Map<String, dynamic>>> _toolCallStreams;
  int _callCount = 0;

  /// Stores the messages received in the last chatStream call for inspection.
  List<Map<String, dynamic>>? lastStreamMessages;

  _MockToolCallProvider(this._toolCallStreams);

  int get callCount => _callCount;

  @override
  String get name => 'MockToolProvider';

  @override
  List<String> get supportedModelIds => [];

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
    _callCount++;
    lastStreamMessages = messages;

    if (_callCount <= _toolCallStreams.length) {
      // Yield the tool call events for this round
      final toolCalls = _toolCallStreams[_callCount - 1];
      yield AIStreamEvent('', toolCalls: toolCalls);
    } else {
      // Final round: yield text
      yield AIStreamEvent('The weather in Hangzhou is 24°C and sunny.');
    }
  }

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
    return 'Mock response';
  }

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'deepseek-v4-pro',
        'max_tokens': 4096,
        'temperature': 0.7,
      };
}

// ====================================================================
// Helper: Mock model config
// (Originally from chat_service_tool_chain_format_test.dart)
// ====================================================================
ModelConfig _createMockModelConfig() {
  return ModelConfig(
    name: 'DeepSeek V4 Pro',
    modelId: 'deepseek-v4-pro',
    typeConfig: {
      'context': 65536,
      'maxTokens': 4096,
      'temperature': 0.7,
    },
  );
}

void main() {
  chatServiceToolsGroup1();
  chatServiceToolsGroup2();
  chatServiceToolsGroup3();
}
