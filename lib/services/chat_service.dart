import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../models/chat_message.dart';
import '../providers/chat_api_provider.dart';
import '../providers/chat_provider_config.dart';

// ====================================================================
// ChatService — AI 聊天服务抽象层
// ====================================================================
//
// Two usage modes:
//
// 1. Instance mode (preferred, for real API calls):
//    final service = ChatService(provider: ..., modelConfig: ...);
//    service.sendStream(text, history: history);
//
// 2. Static mode (mock, for development/testing):
//    ChatService.sendStream(text);
// ====================================================================

class ChatService {
  // ── Instance fields (used when constructed with a provider) ─────
  final BaseChatProvider? _provider;
  final ChatModelConfig? _modelConfig;
  StreamSubscription<String>? _streamSubscription;
  StreamController<String>? _controller;

  /// Construct an instance backed by a real provider and model config.
  ChatService({
    required BaseChatProvider provider,
    required ChatModelConfig modelConfig,
  })  : _provider = provider,
        _modelConfig = modelConfig;

  /// Whether there's an active streaming session (instance or static).
  bool get isStreamActive => _controller != null && !_controller!.isClosed;

  // ── Instance methods ────────────────────────────────────────────

  /// Stream a message - sends user message + history to the API provider,
  /// yields response chunks via stream.
  ///
  /// [userMessage] - the new user message text
  /// [history] - previous messages in the conversation (used as context)
  /// Returns a Stream<String> of response chunks.
  Stream<String> sendStream(String userMessage,
      {required List<ChatMessage> history}) {
    cancel();

    _controller = StreamController<String>(
      onCancel: () {
        debugPrint('ChatService: stream cancelled');
        _cleanUp();
      },
    );

    // Build messages list: history + new user message
    final messages = [
      ...history,
      ChatMessage(role: 'user', content: userMessage),
    ];

    _streamSubscription = _provider!
        .chatStream(
      messages,
      model: _modelConfig!.modelId,
      maxTokens: _modelConfig!.maxTokens,
      temperature: _modelConfig!.temperature,
    )
        .listen(
      (chunk) {
        if (!_controller!.isClosed) {
          _controller!.add(chunk);
        }
      },
      onDone: () {
        _streamSubscription = null;
        if (!_controller!.isClosed) {
          _controller!.close();
        }
        _cleanUp();
      },
      onError: (Object error) {
        _streamSubscription = null;
        debugPrint('ChatService stream error: $error');
        if (!_controller!.isClosed) {
          _controller!.addError(error);
          _controller!.close();
        }
        _cleanUp();
      },
    );

    return _controller!.stream;
  }

  /// Non-streaming version - collects stream into a single string.
  Future<String> send(String userMessage,
      {required List<ChatMessage> history}) async {
    final chunks = <String>[];
    await for (final chunk in sendStream(userMessage, history: history)) {
      chunks.add(chunk);
    }
    return chunks.join('');
  }

  /// Cancel the current stream
  void cancel() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }
    _cleanUp();
  }

  void _cleanUp() {
    if (_controller?.isClosed ?? true) {
      _controller = null;
    }
  }

  /// Dispose permanently (no more streams possible after this)
  void dispose() {
    cancel();
  }
}
