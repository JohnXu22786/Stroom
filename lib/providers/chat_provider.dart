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

  // ── Streaming batching ──────────────────────────────────────────
  //
  // When API chunks arrive faster than the UI can render, updating
  // state on every single chunk overwhelms the widget tree (every
  // state change triggers a full markdown re-parse).
  //
  // Solution: buffer incoming chunks and flush them to state on a
  // 33ms periodic timer (~30 fps). Chunks arriving within the same
  // window are coalesced into a single state update; the periodic
  // timer ensures that even during continuous high-speed streaming
  // the user sees content at a predictable frame rate.
  //
  // No size threshold — whatever accumulated in one interval window
  // is flushed as a single batch. This avoids both character-by-character
  // overhead and arbitrary size cutoffs.
  // ─────────────────────────────────────────────────────────────────

  /// Interval at which the periodic flush timer fires (~30 fps).
  static const Duration _batchInterval = Duration(milliseconds: 33);

  /// Accumulated chunks waiting to be flushed to state.
  String _pendingBuffer = '';

  /// Periodic timer that fires every [_batchInterval] to flush the buffer.
  Timer? _flushTimer;

  /// Set to true in [dispose]; guards async callbacks from operating on
  /// a destroyed StateNotifier (Timer may have already fired its callback
  /// into the event queue before cancel()).
  bool _disposed = false;

  /// Monotonically increasing counter bumped on each [sendMessage] call.
  /// Passed to [_accumulateChunk] and verified in callbacks so that stale
  /// events from a previous stream cannot corrupt the current one.
  int _generation = 0;

  ChatNotifier() : super([]);

  @override
  void dispose() {
    _disposed = true;
    _streamSubscription?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }

  // ── Chunk batching helpers ──────────────────────────────────────

  /// Append [chunk] to the pending buffer and schedule a periodic flush.
  ///
  /// All chunks received within a single [_batchInterval] window are
  /// coalesced into one state update, so fast bursts render as a single
  /// batch instead of overwhelming the widget tree chunk by chunk.
  ///
  /// Uses [Timer.periodic] so that even during continuous high-speed
  /// streaming (chunks arriving every <33ms), content is flushed and
  /// visible to the user at a predictable frame rate (~30 fps).
  void _accumulateChunk(String chunk, int generation) {
    if (_disposed || generation != _generation) return;
    _pendingBuffer += chunk;

    // Start a periodic timer on first chunk; it fires every
    // [_batchInterval] until cancelled, ensuring periodic flush
    // even during continuous fast output.
    _flushTimer ??= Timer.periodic(_batchInterval, (_) => _flushBuffer());
  }

  /// Flush the pending buffer into the last assistant message's content.
  void _flushBuffer() {
    if (_disposed) return;
    if (_pendingBuffer.isEmpty) return;

    final lastIndex = state.length - 1;
    if (lastIndex < 0 || !state[lastIndex].isStreaming) {
      // No valid streaming target — discard orphaned buffer.
      _pendingBuffer = '';
      return;
    }
    final last = state[lastIndex];

    state = [
      ...state.sublist(0, lastIndex),
      last.copyWith(content: last.content + _pendingBuffer),
    ];
    _pendingBuffer = '';
  }

  /// Flush any remaining buffer, then mark the assistant message as complete.
  ///
  /// Performs a single state update (both content flush and the
  /// isStreaming toggle) to avoid an extra widget rebuild at the end.
  void _finalizeStream() {
    if (_disposed) return;
    _flushTimer?.cancel();
    _flushTimer = null;

    final lastIndex = state.length - 1;
    if (lastIndex < 0) {
      _pendingBuffer = '';
      return;
    }
    final last = state[lastIndex];

    // If the message was already finalized (e.g. by onError following by
    // onDone), skip to avoid a redundant state update + widget rebuild.
    if (!last.isStreaming) {
      _pendingBuffer = '';
      return;
    }

    // One final flush, merged with the isStreaming toggle.
    state = [
      ...state.sublist(0, lastIndex),
      last.copyWith(
        content: last.content + _pendingBuffer,
        isStreaming: false,
      ),
    ];
    _pendingBuffer = '';
  }

  // ── Public API ──────────────────────────────────────────────────

  /// Appends a user message, then calls [ChatService.sendStream] to get the AI
  /// response. Incoming chunks are buffered and flushed to state on a
  /// 33ms periodic timer (≈30 fps). When the stream completes, the assistant
  /// message is marked as fully received.
  void sendMessage(String text) {
    if (text.trim().isEmpty || _disposed) return;

    // Cancel any in-progress stream before starting a new one.
    _streamSubscription?.cancel();
    _flushTimer?.cancel();
    _flushTimer = null;

    // If there's an orphaned streaming assistant (e.g. user sent a new
    // message before the previous stream finished), flush any pending
    // content and mark it as complete so it doesn't hang forever with
    // a loading indicator.
    final updated = List<ChatMessage>.from(state);
    if (updated.isNotEmpty) {
      final last = updated.last;
      if (last.role == 'assistant' && last.isStreaming) {
        updated[updated.length - 1] = last.copyWith(
          content: last.content + _pendingBuffer,
          isStreaming: false,
        );
      }
    }
    _pendingBuffer = '';

    // Obtain the stream first, then update state — if sendStream throws
    // synchronously, we catch it and set an error message instead of
    // leaving a dangling streaming assistant.
    late final Stream<String> stream;
    try {
      stream = ChatService.sendStream(text.trim());
    } catch (e) {
      debugPrint('ChatService.sendStream error: $e');
      state = [
        ...updated,
        ChatMessage(role: 'user', content: text.trim()),
        ChatMessage(
          role: 'assistant',
          content: '*Error: $e*',
          isStreaming: false,
        ),
      ];
      return;
    }

    state = [
      ...updated,
      ChatMessage(role: 'user', content: text.trim()),
      ChatMessage(role: 'assistant', content: '', isStreaming: true),
    ];

    // Subscribe to the AI response stream with batched periodic flush.
    final int gen = ++_generation;
    _streamSubscription = stream.listen(
      (chunk) => _accumulateChunk(chunk, gen),
      onDone: () {
        _streamSubscription = null;
        _finalizeStream();
      },
      onError: (Object error, StackTrace stackTrace) {
        _streamSubscription?.cancel();
        _streamSubscription = null;
        _flushTimer?.cancel();
        _flushTimer = null;
        if (_disposed) return;
        debugPrint('ChatService.sendStream error: $error');
        // Merge buffered content and error into a single state update.
        final lastIndex = state.length - 1;
        if (lastIndex < 0) {
          _pendingBuffer = '';
          return;
        }
        final last = state[lastIndex];
        state = [
          ...state.sublist(0, lastIndex),
          last.copyWith(
            content: '${last.content}$_pendingBuffer\n\n*Error: $error*',
            isStreaming: false,
          ),
        ];
        _pendingBuffer = '';
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
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingBuffer = '';
    _streamSubscription = null;
    state = [];
  }

  /// Replaces the entire message list (e.g. when switching conversations).
  void loadMessages(List<ChatMessage> messages) {
    _streamSubscription?.cancel();
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingBuffer = '';
    _streamSubscription = null;
    state = [...messages];
  }
}
