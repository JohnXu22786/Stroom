import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';

/// Manages the current conversation's message list.
///
/// State: [List<ChatMessage>] for the active conversation.
final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier();
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  StreamSubscription<String>? _streamSubscription;

  ChatNotifier() : super([]);

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  /// Appends a user message, then calls [ChatService.sendStream] to get the AI
  /// response. Each emitted chunk is appended to the last assistant message
  /// (which has [ChatMessage.isStreaming] = true). When the stream completes,
  /// [isStreaming] is set to false.
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    // Cancel any in-progress stream before starting a new one.
    _streamSubscription?.cancel();

    // 1. Append user message.
    final userMsg = ChatMessage(role: 'user', content: text.trim());
    state = [...state, userMsg];

    // 2. Append an empty assistant placeholder with isStreaming = true.
    final assistantMsg =
        ChatMessage(role: 'assistant', content: '', isStreaming: true);
    state = [...state, assistantMsg];

    // 3. Subscribe to the AI response stream.
    _streamSubscription = ChatService.sendStream(text.trim()).listen(
      (chunk) {
        // Accumulate chunks onto the last (assistant) message.
        final lastIndex = state.length - 1;
        if (lastIndex < 0) return;
        final last = state[lastIndex];
        state = [
          ...state.sublist(0, lastIndex),
          last.copyWith(content: last.content + chunk),
        ];
      },
      onDone: () {
        _streamSubscription = null;
        // Mark the assistant message as fully received.
        final lastIndex = state.length - 1;
        if (lastIndex < 0) return;
        final last = state[lastIndex];
        state = [
          ...state.sublist(0, lastIndex),
          last.copyWith(isStreaming: false),
        ];
      },
      onError: (Object error, StackTrace stackTrace) {
        _streamSubscription = null;
        debugPrint('ChatService.sendStream error: $error');
        final lastIndex = state.length - 1;
        if (lastIndex < 0) return;
        final last = state[lastIndex];
        state = [
          ...state.sublist(0, lastIndex),
          last.copyWith(
            content: '${last.content}\n\n*Error: $error*',
            isStreaming: false,
          ),
        ];
      },
    );
  }

  /// Re-sends the last user message.
  ///
  /// Finds the most recent message with role == 'user', removes it and all
  /// subsequent messages, then calls [sendMessage] with the same content.
  void retryLast() {
    final userIndex = state.lastIndexWhere((m) => m.role == 'user');
    if (userIndex == -1) return;

    final lastUserContent = state[userIndex].content;
    // Truncate everything from (and including) the last user message onward.
    state = state.sublist(0, userIndex);
    sendMessage(lastUserContent);
  }

  /// Clears all messages from the current conversation.
  void clearMessages() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    state = [];
  }

  /// Replaces the entire message list (e.g. when switching conversations).
  void loadMessages(List<ChatMessage> messages) {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    state = [...messages];
  }
}
