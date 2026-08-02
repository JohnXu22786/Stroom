import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_adapter.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_stream_manager.dart';
part 'chat_stream_manager_test_p1.dart';
part 'chat_stream_manager_test_p2.dart';
part 'chat_stream_manager_test_p3.dart';
part 'chat_stream_manager_test_p4.dart';

// ============================================================================
// Mock provider that yields controlled events for testing
// ============================================================================
class _MockProvider extends BaseChatProvider {
  final List<List<AIStreamEvent>> _rounds;
  int _callCount = 0;
  bool throwOnSubscribe = false;

  /// When non-null, the provider waits for this completer before yielding.
  final Completer<void>? waitForYield;

  _MockProvider(this._rounds, {this.waitForYield});

  int get callCount => _callCount;

  @override
  String get name => 'MockProvider';

  @override
  List<String> get supportedModelIds => ['test-model'];

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
    if (throwOnSubscribe) {
      throw Exception('Simulated provider error');
    }
    _callCount++;
    if (_callCount <= _rounds.length) {
      if (waitForYield != null) await waitForYield!.future;
      for (final event in _rounds[_callCount - 1]) {
        yield event;
      }
    } else {
      if (waitForYield != null) await waitForYield!.future;
      yield AIStreamEvent('Final response');
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
        'model': 'test-model',
        'max_tokens': 4096,
        'temperature': 0.7,
      };
}

// ============================================================================
// Mock provider that simulates tool call streaming (single chain)
// ============================================================================
class _MockToolCallsProvider extends BaseChatProvider {
  int _callCount = 0;

  @override
  String get name => 'MockToolProvider';

  @override
  List<String> get supportedModelIds => ['test-model'];

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
    if (_callCount == 1) {
      yield AIStreamEvent('', toolCalls: [
        {
          'id': 'call_1',
          'type': 'function',
          'function': {
            'name': 'get_weather',
            'arguments': '{"city":"Hangzhou"}',
          },
        },
      ]);
    } else {
      yield AIStreamEvent('The weather is sunny.');
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
        'model': 'test-model',
        'max_tokens': 4096,
        'temperature': 0.7,
      };
}

// ============================================================================
// Helper: create a minimal ModelConfig
// ============================================================================
ModelConfig _createModelConfig() {
  return ModelConfig(
    name: 'Test Model',
    modelId: 'test-model',
    typeConfig: {
      'context': 4096,
      'maxTokens': 2048,
    },
  );
}

// ============================================================================
// Helper: create a ChatService with a controlled mock provider
// ============================================================================
ChatService _makeChatService(BaseChatProvider provider) {
  return ChatService(
    provider: provider,
    modelConfig: _createModelConfig(),
  );
}

// ============================================================================
// Helper: create a minimal user message for history
// ============================================================================
ChatMessage _userMsg(String content, [String? id]) {
  return ChatMessage(
    role: 'user',
    content: content,
    id: id ?? 'u_$content',
  );
}

// ============================================================================
// Tests
// ============================================================================
void main() {
  chatStreamManagerGroup1();
  chatStreamManagerGroup2();
  chatStreamManagerGroup3();
  chatStreamManagerGroup4();
}
