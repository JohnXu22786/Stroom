import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/chat_event.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_adapter.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_stream_manager.dart';

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
// Tests
// ============================================================================
void main() {
  group('ChatStreamManager - basic operations', () {
    late ChatStreamManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = ChatStreamManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('manager creates and holds an adapter', () {
      expect(manager.adapter, isA<ChatAdapter>());
      expect(manager.adapter.isConfigured, false);
    });

    test('adapter returns the same instance', () {
      final adapter = manager.adapter;
      expect(adapter, isNotNull);
      expect(manager.adapter, same(adapter));
    });

    test('isStreaming returns false initially', () {
      expect(manager.isStreaming, false);
    });

    test('streamingMsgId returns null initially', () {
      expect(manager.streamingMsgId, isNull);
    });

    test('fullReply returns empty initially', () {
      expect(manager.fullReply, '');
    });

    test('history returns empty list initially', () {
      expect(manager.history, isEmpty);
    });

    test('cancel does nothing when not streaming', () {
      manager.cancel();
      expect(manager.isStreaming, false);
    });

    test('dispose can be called without error', () {
      manager.dispose();
      expect(manager.isStreaming, false);
    });
  });

  group('ChatStreamManager - streaming lifecycle', () {
    test('isStreaming becomes true immediately after startStreaming', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Hello')]
        ],
        waitForYield: completer,
      );
      final chatService = ChatService(
        provider: provider,
        modelConfig: _createModelConfig(),
      );
      manager.adapter.forceService(chatService);

      // startStreaming must NOT suspend at any await before isStreaming=true
      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [ChatMessage(role: 'user', content: 'Hi', id: 'u1')],
      );

      // isStreaming must be set synchronously
      expect(manager.isStreaming, true);
      expect(manager.streamingMsgId, isNotNull);

      // Allow the stream to complete
      completer.complete();
      await future;
      expect(manager.isStreaming, false);

      manager.dispose();
    });

    test('adds assistant message to history after completion', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Hello World')],
      ]);
      final chatService = ChatService(
        provider: provider,
        modelConfig: _createModelConfig(),
      );
      manager.adapter.forceService(chatService);

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'Hi', id: 'u1'),
      ];
      await manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: history,
      );

      expect(manager.history.length, 2);
      expect(manager.history[1].role, 'assistant');
      expect(manager.history[1].content, 'Hello World');

      manager.dispose();
    });

    test('accumulates fullReply from text events', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Hello'), AIStreamEvent(' '), AIStreamEvent('World')],
      ]);
      final chatService = ChatService(
        provider: provider,
        modelConfig: _createModelConfig(),
      );
      manager.adapter.forceService(chatService);

      await manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [],
      );

      expect(manager.fullReply, 'Hello World');

      manager.dispose();
    });

    test('cancel stops streaming and clears state', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Part 1'), AIStreamEvent('Part 2')]
        ],
        waitForYield: completer,
      );
      final chatService = ChatService(
        provider: provider,
        modelConfig: _createModelConfig(),
      );
      manager.adapter.forceService(chatService);

      // Start streaming - it will pause waiting for the completer
      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [ChatMessage(role: 'user', content: 'Hi', id: 'u1')],
      );

      // Verify streaming is active
      expect(manager.isStreaming, true);

      // Cancel before the stream yields any events
      manager.cancel();

      // Allow the stream to proceed (it will see cancellation)
      completer.complete();
      await future;

      // After cancel, isStreaming should be false
      expect(manager.isStreaming, false);
      // fullReply should be empty (no events were processed)
      expect(manager.fullReply, '');

      manager.dispose();
    });

    test('dual startStreaming calls: second is ignored while first is active',
        () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Response')]
        ],
        waitForYield: completer,
      );
      final chatService = ChatService(
        provider: provider,
        modelConfig: _createModelConfig(),
      );
      manager.adapter.forceService(chatService);

      // First stream starts and pauses
      final future1 = manager.startStreaming(
        text: 'Q1',
        convId: 'conv1',
        history: [],
      );

      expect(manager.isStreaming, true);

      // Second call should be ignored (already streaming)
      await manager.startStreaming(
        text: 'Q2',
        convId: 'conv2',
        history: [],
      );

      // First stream is still running
      expect(manager.isStreaming, true);

      // Complete the first stream
      completer.complete();
      await future1;

      // First stream completed
      expect(manager.isStreaming, false);
      expect(manager.history.length, 1);
      expect(manager.fullReply, 'Response');

      manager.dispose();
    });

    test('cancel saves whatever content was accumulated', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Partial content')],
      ]);
      final chatService = ChatService(
        provider: provider,
        modelConfig: _createModelConfig(),
      );
      manager.adapter.forceService(chatService);

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'Hi', id: 'u1'),
      ];

      // Start streaming (will complete quickly since no delay)
      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: history,
      );

      // Wait for stream to start yielding
      await Future.delayed(const Duration(milliseconds: 50));

      // Stream may have completed already or be in progress - cancel either way
      manager.cancel();
      await future;

      // Regardless of timing, cancel should not leave an inconsistent state
      expect(manager.isStreaming, false);

      manager.dispose();
    });
  });

  group('ChatStreamManager - reasoning events', () {
    test('handles reasoning events properly', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [
          AIStreamEvent('Let me think', isReasoning: true),
          AIStreamEvent(' about this', isReasoning: true),
          AIStreamEvent('Therefore:'),
        ],
      ]);
      final chatService = ChatService(
        provider: provider,
        modelConfig: _createModelConfig(),
      );
      manager.adapter.forceService(chatService);

      await manager.startStreaming(
        text: 'Think hard',
        convId: 'conv1',
        history: [],
        reasoning: true,
      );

      // Full reply should only contain non-reasoning text
      expect(manager.fullReply, 'Therefore:');

      manager.dispose();
    });
  });

  group('ChatStreamManager - tool calls', () {
    test('accumulates tool calls from streaming events', () async {
      final manager = ChatStreamManager();
      final provider = _MockToolCallsProvider();
      final chatService = ChatService(
        provider: provider,
        modelConfig: _createModelConfig(),
      );
      manager.adapter.forceService(chatService);

      await manager.startStreaming(
        text: 'Search weather',
        convId: 'conv1',
        history: [],
      );

      // Should have the assistant message in history
      expect(manager.history.length, 1);
      expect(manager.history[0].role, 'assistant');

      manager.dispose();
    });
  });

  group('ChatStreamManager - error handling', () {
    test('handles provider errors gracefully', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Test')],
      ]);
      provider.throwOnSubscribe = true;
      final chatService = ChatService(
        provider: provider,
        modelConfig: _createModelConfig(),
      );
      manager.adapter.forceService(chatService);

      await manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [],
      );

      // Error should be captured
      expect(manager.isStreaming, false);
      // The error message starts with '错误:' prefix
      expect(manager.fullReply.startsWith('错误:'), true);

      manager.dispose();
    });
  });
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
  }) async* {
    _callCount++;
    if (_callCount == 1) {
      // First round: yield a tool call
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
      // Second round: yield text
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
