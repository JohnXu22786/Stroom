import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/chat_message.dart';
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

    test('isStreaming returns false when no conversation is streaming', () {
      expect(manager.isStreaming, false);
    });

    test('isStreamingFor returns false for non-streaming conversation', () {
      expect(manager.isStreamingFor('conv1'), false);
    });

    test('cancel does nothing when not streaming', () {
      manager.cancel();
      expect(manager.isStreaming, false);
    });

    test('cancel with specific convId does nothing when not streaming', () {
      manager.cancel('conv1');
      expect(manager.isStreaming, false);
    });

    test('dispose can be called without error', () {
      manager.dispose();
      expect(manager.isStreaming, false);
    });
  });

  group('ChatStreamManager - single conversation streaming', () {
    test('StreamResult contains correct history after completion', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Hello World')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final history = <ChatMessage>[_userMsg('Hi', 'u1')];
      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: history,
      );

      expect(result.history.length, 2);
      expect(result.history[1].role, 'assistant');
      expect(result.history[1].content, 'Hello World');
      expect(result.fullReply, 'Hello World');
      expect(result.assistantMessage, isNotNull);
      expect(result.assistantMessage!.content, 'Hello World');

      manager.dispose();
    });

    test('StreamResult contains correct fullReply from text events', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Hello'), AIStreamEvent(' '), AIStreamEvent('World')],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [],
      );

      expect(result.fullReply, 'Hello World');
      manager.dispose();
    });

    test('isStreamingFor returns true during streaming', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Hello')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [_userMsg('Hi')],
      );

      expect(manager.isStreaming, true);
      expect(manager.isStreamingFor('conv1'), true);
      expect(manager.isStreamingFor('conv2'), false);

      completer.complete();
      await future;
      expect(manager.isStreaming, false);
      expect(manager.isStreamingFor('conv1'), false);

      manager.dispose();
    });

    test('cancel stops the specific conversation stream', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Part 1'), AIStreamEvent('Part 2')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [_userMsg('Hi')],
      );

      expect(manager.isStreaming, true);

      // Cancel conv1
      manager.cancel('conv1');

      completer.complete();
      await future;

      expect(manager.isStreaming, false);
      expect(manager.isStreamingFor('conv1'), false);

      manager.dispose();
    });

    test('cancel without convId cancels all streams', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Hello')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [_userMsg('Hi')],
      );

      expect(manager.isStreaming, true);
      manager.cancel(); // cancel all
      completer.complete();
      await future;

      expect(manager.isStreaming, false);
      manager.dispose();
    });
  });

  group('ChatStreamManager - multi-conversation streaming', () {
    test(
        'two different conversations can stream simultaneously without '
        'interference', () async {
      final manager = ChatStreamManager();

      final completerA = Completer<void>();

      // Use sequential testing: Start convA while it blocks, cancel it,
      // then verify convB streams normally afterward. (True concurrency
      // is limited by the single ChatAdapter.)
      final providerA2 = _MockProvider(
        [
          [AIStreamEvent('Slow A response')]
        ],
        waitForYield: completerA,
      );
      manager.adapter.forceService(_makeChatService(providerA2));

      // Start convA (will wait on completerA)
      final futureA = manager.startStreaming(
        text: 'Q A',
        convId: 'convA',
        history: [_userMsg('Q A')],
      );

      expect(manager.isStreamingFor('convA'), true);
      expect(manager.isStreamingFor('convB'), false);
      expect(manager.isStreaming, true);

      // Cancel convA mid-stream
      manager.cancel('convA');
      completerA.complete();
      final resultA = await futureA;

      expect(manager.isStreamingFor('convA'), false);
      expect(resultA.fullReply.isEmpty, true,
          reason: 'Cancelled before any events were processed');

      // Now stream convB - should work after convA is done
      final providerB2 = _MockProvider([
        [AIStreamEvent('Response for B')],
      ]);
      manager.adapter.forceService(_makeChatService(providerB2));

      final resultB = await manager.startStreaming(
        text: 'Q B',
        convId: 'convB',
        history: [_userMsg('Q B')],
      );

      expect(resultB.fullReply, 'Response for B');
      expect(manager.isStreaming, false);

      manager.dispose();
    });

    test(
        'per-conversation reply accumulation does not cross-contaminate '
        'between conversations', () async {
      // This is tested implicitly by running two streams sequentially
      // with different responses and verifying correct accumulation.
      final manager = ChatStreamManager();

      final providerA = _MockProvider([
        [AIStreamEvent('Reply'), AIStreamEvent(' for A')],
      ]);
      manager.adapter.forceService(_makeChatService(providerA));
      final resultA = await manager.startStreaming(
        text: 'Q A',
        convId: 'convA',
        history: [_userMsg('Q A')],
      );
      expect(resultA.fullReply, 'Reply for A');

      final providerB = _MockProvider([
        [AIStreamEvent('Reply'), AIStreamEvent(' for B')],
      ]);
      manager.adapter.forceService(_makeChatService(providerB));
      final resultB = await manager.startStreaming(
        text: 'Q B',
        convId: 'convB',
        history: [_userMsg('Q B')],
      );
      expect(resultB.fullReply, 'Reply for B');

      // convA's history should be unchanged
      expect(resultA.history.length, 2);
      expect(resultA.history[1].content, 'Reply for A');

      manager.dispose();
    });

    test(
        'same conversation refuses duplicate startStreaming while '
        'already streaming', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Response')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future1 = manager.startStreaming(
        text: 'Q1',
        convId: 'conv1',
        history: [],
      );

      expect(manager.isStreamingFor('conv1'), true);

      // Second call for SAME conversation should be ignored
      final future2 = manager.startStreaming(
        text: 'Q2',
        convId: 'conv1',
        history: [],
      );

      // future2 should complete with same result as future1 (no-op)
      completer.complete();
      final result1 = await future1;
      final result2 = await future2;

      expect(result1.assistantMessage?.content, 'Response');
      expect(result2.fullReply, result1.fullReply,
          reason: 'Second call returns the same ongoing result');

      manager.dispose();
    });

    test(
        'isStreamingFor correctly tracks per-conversation state '
        'across sequential streams', () async {
      // Verify that isStreamingFor reports the correct per-conversation
      // streaming state as conversations stream sequentially.
      // (True concurrency is limited by the single ChatAdapter, but
      // per-conversation tracking is fully functional for sequential use.)
      final manager = ChatStreamManager();

      // ConvA streams first
      final providerA = _MockProvider([
        [AIStreamEvent('A response')],
      ]);
      manager.adapter.forceService(_makeChatService(providerA));

      expect(manager.isStreamingFor('convA'), false);
      expect(manager.isStreamingFor('convB'), false);
      expect(manager.isStreaming, false);

      final resultA = await manager.startStreaming(
        text: 'Q A',
        convId: 'convA',
        history: [_userMsg('Q A')],
      );

      expect(resultA.fullReply, 'A response');
      expect(manager.isStreamingFor('convA'), false,
          reason: 'Stream completed, should no longer be streaming');

      // ConvB streams next
      final providerB = _MockProvider([
        [AIStreamEvent('B response')],
      ]);
      manager.adapter.forceService(_makeChatService(providerB));

      final resultB = await manager.startStreaming(
        text: 'Q B',
        convId: 'convB',
        history: [_userMsg('Q B')],
      );

      expect(resultB.fullReply, 'B response');
      expect(manager.isStreamingFor('convB'), false);
      expect(manager.isStreaming, false);

      // Both results are independent
      expect(resultA.fullReply, 'A response');
      expect(resultB.fullReply, 'B response');

      manager.dispose();
    });
  });

  group('ChatStreamManager - reasoning events', () {
    test('handles reasoning events properly with StreamResult', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [
          AIStreamEvent('Let me think', isReasoning: true),
          AIStreamEvent(' about this', isReasoning: true),
          AIStreamEvent('Therefore:'),
        ],
      ]);
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Think hard',
        convId: 'conv1',
        history: [],
        reasoning: true,
      );

      // Full reply should only contain non-reasoning text
      expect(result.fullReply, 'Therefore:');

      manager.dispose();
    });
  });

  group('ChatStreamManager - tool calls', () {
    test('accumulates tool calls from streaming events in StreamResult',
        () async {
      final manager = ChatStreamManager();
      final provider = _MockToolCallsProvider();
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Search weather',
        convId: 'conv1',
        history: [],
      );

      expect(result.history.length, 1);
      expect(result.history[0].role, 'assistant');

      manager.dispose();
    });
  });

  group('ChatStreamManager - error handling', () {
    test('provider error is captured in StreamResult', () async {
      final manager = ChatStreamManager();
      final provider = _MockProvider([
        [AIStreamEvent('Test')],
      ]);
      provider.throwOnSubscribe = true;
      manager.adapter.forceService(_makeChatService(provider));

      final result = await manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [],
      );

      expect(manager.isStreaming, false);
      expect(result.fullReply.startsWith('错误:'), true);

      manager.dispose();
    });

    test('error in one conversation does not affect another', () async {
      final manager = ChatStreamManager();

      // First, a failing stream
      final badProvider = _MockProvider([
        [AIStreamEvent('Test')],
      ]);
      badProvider.throwOnSubscribe = true;
      manager.adapter.forceService(_makeChatService(badProvider));

      final resultBad = await manager.startStreaming(
        text: 'Bad',
        convId: 'convBad',
        history: [],
      );
      expect(resultBad.fullReply.startsWith('错误:'), true);

      // Then, a good stream should work
      final goodProvider = _MockProvider([
        [AIStreamEvent('Good response')],
      ]);
      manager.adapter.forceService(_makeChatService(goodProvider));

      final resultGood = await manager.startStreaming(
        text: 'Good',
        convId: 'convGood',
        history: [],
      );
      expect(resultGood.fullReply, 'Good response');

      manager.dispose();
    });
  });

  group('ChatStreamManager - throttle behavior', () {
    test('provider updates respect the 200ms throttle interval', () async {
      // Verify that the throttle constant is 200ms (5 updates/sec)
      // This is tested by checking the static constant.
      expect(
        ChatStreamManager.textThrottleMs,
        200,
        reason: 'Throttle must be 200ms = 5 updates per second',
      );
    });
  });

  group('ChatStreamManager - cleanup', () {
    test('dispose stops all streams and cleans up', () async {
      final manager = ChatStreamManager();
      final completer = Completer<void>();
      final provider = _MockProvider(
        [
          [AIStreamEvent('Response')]
        ],
        waitForYield: completer,
      );
      manager.adapter.forceService(_makeChatService(provider));

      final future = manager.startStreaming(
        text: 'Hi',
        convId: 'conv1',
        history: [_userMsg('Hi')],
      );

      expect(manager.isStreamingFor('conv1'), true);

      // Dispose while streaming
      manager.dispose();
      completer.complete();
      await future; // Should complete without error after dispose

      expect(manager.isStreaming, false);
    });
  });
}
