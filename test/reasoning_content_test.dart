import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_adapter.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/chat_event.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/provider_config.dart';

/// A mock ChatProvider that simulates streaming with reasoning content.
class MockChatProvider extends BaseChatProvider {
  @override
  String get name => 'mock';

  @override
  List<String> get supportedModelIds => [];

  @override
  Map<String, dynamic> get defaultParams => {};

  StreamController<AIStreamEvent>? _controller;

  /// Injects a reasoning event into the stream.
  void emitReasoning(String text) {
    _controller?.add(AIStreamEvent(text, isReasoning: true));
  }

  /// Injects a text event into the stream.
  void emitText(String text) {
    _controller?.add(AIStreamEvent(text));
  }

  /// Signals the stream is done.
  void endStream() {
    _controller?.close();
  }

  @override
  Stream<AIStreamEvent> chatStream(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
  }) async* {
    _controller = StreamController<AIStreamEvent>();
    try {
      await for (final event in _controller!.stream) {
        if (cancelToken?.isCancelled ?? false) break;
        yield event;
      }
    } finally {
      if (_controller != null && !_controller!.isClosed) {
        await _controller!.close();
      }
      _controller = null;
    }
  }

  @override
  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
  }) {
    throw UnimplementedError();
  }
}

/// A minimal ModelConfig for testing.
ModelConfig _testModelConfig() {
  return ModelConfig(
    name: 'test-model',
    modelId: 'test-model',
    customParams: [],
  );
}

void main() {
  group('ChatService reasoning content accumulation', () {
    late MockChatProvider mockProvider;
    late ChatService chatService;

    setUp(() {
      mockProvider = MockChatProvider();
      chatService = ChatService(
        provider: mockProvider,
        modelConfig: _testModelConfig(),
      );
    });

    tearDown(() {
      chatService.dispose();
    });

    test('reasoningContent starts empty', () {
      expect(chatService.reasoningContent, '');
    });

    test('sendStream accumulates reasoning content during streaming', () async {
      final stream = chatService.sendStream(
        'hello',
        history: [],
        reasoning: true,
      );

      // Allow microtask to establish the subscription
      await Future<void>.delayed(Duration.zero);

      // Emit reasoning content
      mockProvider.emitReasoning('First reasoning step. ');
      await Future<void>.delayed(Duration.zero);

      // Reasoning buffer should have accumulated content
      expect(chatService.reasoningContent, contains('First reasoning step'));

      // Emit more reasoning content
      mockProvider.emitReasoning('Second reasoning step. ');
      await Future<void>.delayed(Duration.zero);

      expect(chatService.reasoningContent,
          contains('First reasoning step. Second reasoning step'));

      // End the stream
      mockProvider.endStream();

      // Collect remaining
      await for (final _ in stream) {
        // drain
      }

      // After stream ends, reasoning buffer is still available
      expect(chatService.reasoningContent,
          'First reasoning step. Second reasoning step. ');
    });

    test('ChatService captures reasoning events regardless of reasoning flag (flag controls API provider emission, not service processing)', () async {
      final stream = chatService.sendStream(
        'hello',
        history: [],
        reasoning: false, // even with reasoning=false, service still buffers if events arrive
      );

      await Future<void>.delayed(Duration.zero);

      // If the provider emits reasoning events (e.g., DeepSeek always emits them),
      // ChatService should capture them
      mockProvider.emitReasoning('Should be captured');
      await Future<void>.delayed(Duration.zero);

      // ChatService always accumulates reasoning events that arrive
      expect(chatService.reasoningContent, 'Should be captured');

      mockProvider.endStream();
      await for (final _ in stream) {
        // drain
      }
    });

    test(
        'sendStreamWithTools accumulates reasoning content during streaming',
        () async {
      final stream = chatService.sendStreamWithTools(
        'hello',
        history: [],
        reasoning: true,
      );

      await Future<void>.delayed(Duration.zero);

      mockProvider.emitReasoning('Deep thinking... ');
      await Future<void>.delayed(Duration.zero);

      expect(chatService.reasoningContent, contains('Deep thinking'));

      mockProvider.emitReasoning('More thinking...');
      await Future<void>.delayed(Duration.zero);

      expect(chatService.reasoningContent,
          contains('Deep thinking... More thinking'));

      mockProvider.emitText('Final answer');
      await Future<void>.delayed(Duration.zero);

      mockProvider.endStream();

      await for (final _ in stream) {
        // drain
      }

      expect(chatService.reasoningContent,
          'Deep thinking... More thinking...');
    });

    test('reasoningContent is accessible from ChatAdapter', () {
      final adapter = ChatAdapter();
      // Before configuration, reasoningContent is empty
      expect(adapter.reasoningContent, '');
    });
  });

  group('ChatMessage reasoningContent serialization', () {
    test('toMap includes reasoningContent when set', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Final answer',
        reasoningContent: 'Step 1: think\nStep 2: conclude',
      );

      final map = msg.toMap();
      expect(map.containsKey('reasoningContent'), true);
      expect(map['reasoningContent'], 'Step 1: think\nStep 2: conclude');
    });

    test('toMap does NOT include reasoningContent when null', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Final answer',
      );

      final map = msg.toMap();
      expect(map.containsKey('reasoningContent'), false);
    });

    test('fromMap restores reasoningContent', () {
      final originalMap = <String, dynamic>{
        'id': 'test123',
        'role': 'assistant',
        'content': 'Final answer',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'reasoningContent': 'Step 1: think\nStep 2: conclude',
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.reasoningContent, isNotNull);
      expect(msg.reasoningContent, 'Step 1: think\nStep 2: conclude');
    });

    test('fromMap handles null reasoningContent gracefully', () {
      final originalMap = <String, dynamic>{
        'id': 'test456',
        'role': 'assistant',
        'content': 'Hello',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.reasoningContent, isNull);
    });

    test('serialization round-trip preserves reasoningContent', () {
      final original = ChatMessage(
        role: 'assistant',
        content: 'The answer is 42.',
        reasoningContent: 'I need to compute 6 * 7.\n6 * 7 = 42.',
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.reasoningContent, original.reasoningContent);
      expect(restored.content, original.content);
    });

    test('reasoningContent is empty string after round-trip if null', () {
      final original = ChatMessage(
        role: 'assistant',
        content: 'No reasoning',
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.reasoningContent, isNull);
    });
  });

  group('reasoning params format (OpenAI compatible)', () {
    late OpenAICompatibleChatProvider provider;

    setUp(() {
      provider = OpenAICompatibleChatProvider(
        baseUrl: 'http://invalid-host-test/chat/completions',
        apiKey: 'test-key',
        name: 'test',
      );
    });

    Future<Map<String, dynamic>?> getRequestBody({
      bool reasoning = false,
      String? model,
    }) async {
      try {
        await provider.chat(
          [{'role': 'user', 'content': 'hi'}],
          reasoning: reasoning,
          model: model,
        );
      } catch (_) {
        // Expected to fail — request body is captured before the call
      }
      return provider.lastRequestBody;
    }

    test('DeepSeek model uses thinking format', () async {
      final body = await getRequestBody(reasoning: true, model: 'deepseek-chat');
      expect(body, isNotNull);
      expect(body!['thinking'], {'type': 'enabled'});
      expect(body.containsKey('reasoning_effort'), false);
    });

    test('OpenAI model uses reasoning_effort format', () async {
      final body = await getRequestBody(reasoning: true, model: 'o1-mini');
      expect(body, isNotNull);
      expect(body!['reasoning_effort'], 'medium');
      expect(body.containsKey('thinking'), false);
    });

    test('No reasoning params when reasoning is false', () async {
      final body = await getRequestBody(reasoning: false, model: 'deepseek-chat');
      expect(body, isNotNull);
      expect(body!.containsKey('thinking'), false);
      expect(body.containsKey('reasoning_effort'), false);
    });
  });

  group('Reasoning content streaming parsing (OpenAI compatible)', () {
    test('AIStreamEvent correctly identifies reasoning content', () {
      final reasoningEvent = AIStreamEvent('thinking...', isReasoning: true);
      expect(reasoningEvent.isReasoning, true);
      expect(reasoningEvent.text, 'thinking...');
      expect(reasoningEvent.isToolCallEvent, false);

      final textEvent = AIStreamEvent('hello');
      expect(textEvent.isReasoning, false);
      expect(textEvent.text, 'hello');
    });
  });
}
