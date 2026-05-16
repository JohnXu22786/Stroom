import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'chat_api_provider.dart';
import 'provider_config.dart';

// ============================================================================
// Derived provider — builds ChatService from the selected config
// ============================================================================

/// Builds a [ChatService] from the currently selected chat provider config.
/// Returns null if no config is selected or the config is incomplete.
final chatServiceProvider = Provider<ChatService?>((ref) {
  final entriesState = ref.watch(providerEntriesProvider);
  // 找到 type == 'llm' 的条目
  final llmEntry =
      entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
  if (llmEntry == null || llmEntry.configs.isEmpty) return null;

  // 取第一个配置（或按用户选择的逻辑）
  final config = llmEntry.configs.first;
  if (config.host.isEmpty || config.key.isEmpty) return null;

  final modelConfig = config.models.isNotEmpty ? config.models.first : null;
  if (modelConfig == null) return null;

  final provider = createChatProviderFromConfig(
    providerName: config.providerName,
    baseUrl: config.host,
    apiKey: config.key,
  );

  return ChatService(
    provider: provider,
    modelConfig: modelConfig,
  );
});

/// ── State ────────────────────────────────────────────────────────────────────
///
/// Separates completed messages from in-progress streaming content so that
/// widget tree rebuilds during streaming only affect a small widget consuming
/// [streamingAssistantContent], not the entire message list.
class ChatState {
  /// Messages whose content is fully received (including the last user message
  /// and any previous assistant turns).
  final List<ChatMessage> messages;

  /// In-progress assistant content that is still being streamed. Updated on
  /// each flush cycle so a dedicated streaming widget can listen to this field
  /// without rebuilding the full list.
  final String streamingAssistantContent;

  /// Whether the AI is currently generating a response.
  final bool isAssistantResponding;

  /// Optional error message to display (e.g. "请先配置聊天供应商").
  final String? error;

  const ChatState({
    this.messages = const [],
    this.streamingAssistantContent = '',
    this.isAssistantResponding = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? streamingAssistantContent,
    bool? isAssistantResponding,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      streamingAssistantContent:
          streamingAssistantContent ?? this.streamingAssistantContent,
      isAssistantResponding:
          isAssistantResponding ?? this.isAssistantResponding,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  String toString() => 'ChatState(messages: ${messages.length}, '
      'streamingAssistantContent: "${streamingAssistantContent.length} chars", '
      'isAssistantResponding: $isAssistantResponding, '
      'error: ${error?.length ?? 0} chars)';
}

/// ── Provider ─────────────────────────────────────────────────────────────────
///
/// Manages the current conversation's message list and streaming state.
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});

/// ── Notifier ─────────────────────────────────────────────────────────────────
class ChatNotifier extends StateNotifier<ChatState> {
  StreamSubscription<String>? _streamSubscription;

  /// The active chat service to use for real API calls.
  /// Set externally (e.g. from ChatPage) when the selected config changes.
  ChatService? _chatService;

  /// Set the active chat service (called when the selected config changes).
  void setChatService(ChatService? service) {
    _chatService = service;
  }

  // ── Streaming batching ──────────────────────────────────────────
  //
  // When API chunks arrive faster than the UI can render, updating
  // state on every single chunk overwhelms the widget tree (every
  // state change triggers a full markdown re-parse).
  //
  // Solution: buffer incoming chunks and flush them to state on a
  // periodic timer. Chunks arriving within the same window are
  // coalesced into a single state update; the periodic timer ensures
  // that even during continuous high-speed streaming the user sees
  // content at a predictable frame rate.
  //
  // No size threshold — whatever accumulated in one interval window
  // is flushed as a single batch. This avoids both character-by-character
  // overhead and arbitrary size cutoffs.
  // ─────────────────────────────────────────────────────────────────

  /// Interval at which the periodic flush timer fires (~10 fps).
  ///
  /// Made public so other files can reference this value if needed.
  static const Duration batchInterval = Duration(milliseconds: 100);

  /// Accumulated chunks waiting to be flushed to state.
  String _pendingBuffer = '';

  /// Periodic timer that fires every [batchInterval] to flush the buffer.
  Timer? _flushTimer;

  /// Set to true in [dispose]; guards async callbacks from operating on
  /// a destroyed StateNotifier (Timer may have already fired its callback
  /// into the event queue before cancel()).
  bool _disposed = false;

  /// Monotonically increasing counter bumped on each [sendMessage] call.
  /// Passed to [_accumulateChunk] and verified in callbacks so that stale
  /// events from a previous stream cannot corrupt the current one.
  int _generation = 0;

  ChatNotifier() : super(const ChatState());

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
  /// All chunks received within a single [batchInterval] window are
  /// coalesced into one state update, so fast bursts render as a single
  /// batch instead of overwhelming the widget tree chunk by chunk.
  ///
  /// Uses [Timer.periodic] so that even during continuous high-speed
  /// streaming (chunks arriving every <100ms), content is flushed and
  /// visible to the user at a predictable frame rate (~10 fps).
  void _accumulateChunk(String chunk, int generation) {
    if (_disposed || generation != _generation) return;
    _pendingBuffer += chunk;

    // Start a periodic timer on first chunk; it fires every
    // [batchInterval] until cancelled, ensuring periodic flush
    // even during continuous fast output.
    _flushTimer ??= Timer.periodic(batchInterval, (_) => _flushBuffer());
  }

  /// Flush the pending buffer into [streamingAssistantContent].
  void _flushBuffer() {
    if (_disposed) return;
    if (_pendingBuffer.isEmpty) return;
    if (!state.isAssistantResponding) {
      // No active stream — discard orphaned buffer.
      _pendingBuffer = '';
      return;
    }

    state = state.copyWith(
      streamingAssistantContent:
          state.streamingAssistantContent + _pendingBuffer,
    );
    _pendingBuffer = '';
  }

  /// Flush any remaining buffer, then move the accumulated streaming content
  /// into [messages] as a completed assistant message.
  ///
  /// Resets streaming state so that [isAssistantResponding] is false and
  /// [streamingAssistantContent] is cleared.
  void _finalizeStream() {
    if (_disposed) return;
    _flushTimer?.cancel();
    _flushTimer = null;

    if (!state.isAssistantResponding) {
      // Already finalized (e.g. onError followed by onDone) — skip.
      _pendingBuffer = '';
      return;
    }

    final completeContent = state.streamingAssistantContent + _pendingBuffer;
    _pendingBuffer = '';

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          role: 'assistant',
          content: completeContent,
          isStreaming: false,
        ),
      ],
      streamingAssistantContent: '',
      isAssistantResponding: false,
    );
  }

  // ── Public API ──────────────────────────────────────────────────

  /// Appends a user message, then gets the AI response.
  ///
  /// If [_chatService] is set (real API mode), it builds conversation history
  /// from [state.messages] and calls the provider. Otherwise it falls back
  /// to the static mock [ChatService.sendStream].
  ///
  /// Incoming chunks are buffered and flushed to [streamingAssistantContent]
  /// on a periodic timer. When the stream completes, the full content is
  /// moved into [messages] as a completed assistant message.
  void sendMessage(String text) {
    if (text.trim().isEmpty || _disposed) return;

    // Cancel any in-progress stream before starting a new one.
    _streamSubscription?.cancel();
    _flushTimer?.cancel();
    _flushTimer = null;

    // If there's an orphaned streaming assistant (e.g. user sent a new
    // message before the previous stream finished), finalize its partial
    // content as a completed message so it doesn't hang forever.
    List<ChatMessage> baseMessages = [...state.messages];
    if (state.isAssistantResponding) {
      final orphanContent = state.streamingAssistantContent + _pendingBuffer;
      _pendingBuffer = '';
      baseMessages = [
        ...baseMessages,
        ChatMessage(
          role: 'assistant',
          content: orphanContent,
          isStreaming: false,
        ),
      ];
    } else {
      _pendingBuffer = '';
    }

    // If no chat service is configured, show error and abort.
    if (_chatService == null) {
      state = ChatState(
        messages: [
          ...baseMessages,
          ChatMessage(role: 'user', content: text.trim()),
        ],
        error: '请先配置聊天供应商',
      );
      return;
    }

    // Build conversation history for the API call.
    final history = [...baseMessages];

    // Obtain the stream first, then update state — if the provider throws
    // synchronously, we catch it and set an error message instead of
    // leaving a dangling streaming assistant.
    late final Stream<String> stream;
    try {
      stream = _chatService!.sendStream(text.trim(), history: history);
    } catch (e, st) {
      debugPrint('ChatNotifier.sendMessage: provider error - $e');
      state = ChatState(
        messages: [
          ...baseMessages,
          ChatMessage(role: 'user', content: text.trim()),
          ChatMessage(
            role: 'assistant',
            content: '$e',
            isStreaming: false,
            isError: true,
          ),
        ],
        error: '$e\n$st',
      );
      return;
    }

    state = ChatState(
      messages: [
        ...baseMessages,
        ChatMessage(role: 'user', content: text.trim()),
      ],
      streamingAssistantContent: '',
      isAssistantResponding: true,
    );

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
        debugPrint('ChatNotifier.sendMessage: stream error - $error');

        // Combine buffered content and error into a single completed message.
        final partialContent = state.streamingAssistantContent + _pendingBuffer;
        _pendingBuffer = '';

        state = state.copyWith(
          messages: [
            ...state.messages,
            ChatMessage(
              role: 'assistant',
              content: '$partialContent\n\n$error',
              isStreaming: false,
              isError: true,
            ),
          ],
          streamingAssistantContent: '',
          isAssistantResponding: false,
          error: '$error\n$stackTrace',
        );
      },
    );
  }

  /// Re-sends the last user message.
  ///
  /// Finds the most recent message with role == 'user', removes it and all
  /// subsequent messages, then calls [sendMessage] with the same content.
  void retryLast() {
    if (state.messages.isEmpty) return;
    final userIndex = state.messages.lastIndexWhere((m) => m.role == 'user');
    if (userIndex == -1) return;

    final lastUserContent = state.messages[userIndex].content;
    // Truncate everything from (and including) the last user message onward.
    state = ChatState(messages: state.messages.sublist(0, userIndex));
    sendMessage(lastUserContent);
  }

  /// Clears all messages and resets streaming state.
  void clearMessages() {
    _streamSubscription?.cancel();
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingBuffer = '';
    _streamSubscription = null;
    state = const ChatState();
  }

  /// Clears the error state (called after the UI has displayed it).
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Replaces the entire message list (e.g. when switching conversations).
  void loadMessages(List<ChatMessage> messages) {
    _streamSubscription?.cancel();
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingBuffer = '';
    _streamSubscription = null;
    state = ChatState(messages: [...messages]);
  }
}
