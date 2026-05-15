import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'chat_api_provider.dart';
import 'chat_provider_config.dart';

// ============================================================================
// ChatProviderConfigItem — 用户持久化的聊天供应商配置
// ============================================================================
//
// Represents a single saved chat provider configuration (e.g. a user's
// OpenAI-compatible endpoint with API key and selected model).
// This is the persisted user config, NOT the registry definition
// (ChatProviderDefinition).

class ChatProviderConfigItem {
  final String id;
  String
      providerName; // matches ChatProviderDefinition.id, e.g. 'openai_compatible'
  String host; // API base URL
  String key; // API key
  List<ChatModelConfig> models; // available models
  String selectedModelId; // currently selected model ID

  ChatProviderConfigItem({
    String? id,
    required this.providerName,
    this.host = 'https://api.openai.com/v1',
    this.key = '',
    List<ChatModelConfig>? models,
    this.selectedModelId = '',
  })  : id = id ?? const Uuid().v4(),
        models = models ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'providerName': providerName,
        'host': host,
        'key': key,
        'models': models.map((m) => m.toMap()).toList(),
        'selectedModelId': selectedModelId,
      };

  factory ChatProviderConfigItem.fromMap(Map<String, dynamic> map) {
    return ChatProviderConfigItem(
      id: map['id'] as String?,
      providerName: map['providerName'] as String,
      host: map['host'] as String? ?? 'https://api.openai.com/v1',
      key: map['key'] as String? ?? '',
      models: map['models'] is List
          ? (map['models'] as List)
              .map((m) =>
                  ChatModelConfig.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList()
          : [],
      selectedModelId: map['selectedModelId'] as String? ?? '',
    );
  }
}

// ============================================================================
// Persistence providers
// ============================================================================

/// Persisted list of chat provider configs.
final chatConfigsProvider =
    StateNotifierProvider<ChatConfigsNotifier, List<ChatProviderConfigItem>>(
        (ref) {
  final notifier = ChatConfigsNotifier();
  notifier.load().then((savedId) {
    if (savedId != null) {
      ref.read(selectedChatConfigIdProvider.notifier).state = savedId;
    }
  });
  return notifier;
});

/// Currently selected config ID (or null).
final selectedChatConfigIdProvider = StateProvider<String?>((ref) => null);

class ChatConfigsNotifier extends StateNotifier<List<ChatProviderConfigItem>> {
  static const String _storageKey = 'chat_configs';

  ChatConfigsNotifier() : super([]);

  /// Load configs from SharedPreferences.
  /// Returns the saved selected config ID if it exists and is valid.
  Future<String?> load() async {
    String? validSavedId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final list = jsonDecode(jsonStr) as List;
      state = list
          .map((e) =>
              ChatProviderConfigItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      // Check saved selected ID against loaded configs
      final savedId = prefs.getString('chat_selected_config_id');
      if (savedId != null && state.any((c) => c.id == savedId)) {
        validSavedId = savedId;
      }
    } catch (e) {
      debugPrint('ChatConfigsNotifier.load: failed to load configs - $e');
    }
    return validSavedId;
  }

  /// Persist current state to SharedPreferences.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.map((c) => c.toMap()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint(
          'ChatConfigsNotifier._persist: failed to persist configs - $e');
    }
  }

  /// Add a new config.
  Future<void> add(ChatProviderConfigItem config) async {
    state = [...state, config];
    await _persist();
  }

  /// Update an existing config by ID.
  Future<void> update(String id, ChatProviderConfigItem config) async {
    state = state.map((c) => c.id == id ? config : c).toList();
    await _persist();
  }

  /// Reorder a config in the list (drag-and-drop rearrangement).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (oldIndex < newIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _persist();
  }

  /// Remove a config by ID.
  Future<void> remove(String id) async {
    state = state.where((c) => c.id != id).toList();
    await _persist();
  }
}

/// Persist the selected chat config ID to SharedPreferences.
Future<void> persistSelectedChatConfigId(String? id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setString('chat_selected_config_id', id);
    } else {
      await prefs.remove('chat_selected_config_id');
    }
  } catch (e) {
    debugPrint('Failed to persist selected chat config ID: $e');
  }
}

// ============================================================================
// Derived provider — builds ChatService from the selected config
// ============================================================================

/// Builds a [ChatService] from the currently selected chat provider config.
/// Returns null if no config is selected or the config is incomplete.
final chatServiceProvider = Provider<ChatService?>((ref) {
  final configs = ref.watch(chatConfigsProvider);
  final selectedId = ref.watch(selectedChatConfigIdProvider);
  if (selectedId == null) return null;

  final config = configs.where((c) => c.id == selectedId).firstOrNull;
  if (config == null || config.host.isEmpty || config.key.isEmpty) return null;

  // Find the selected model config; fall back to first available model.
  final modelConfig = config.models
      .where((m) => m.modelId == config.selectedModelId)
      .firstOrNull;
  final effectiveModelConfig =
      modelConfig ?? (config.models.isNotEmpty ? config.models.first : null);
  if (effectiveModelConfig == null) return null;

  final provider = createChatProviderFromConfig(
    providerName: config.providerName,
    baseUrl: config.host,
    apiKey: config.key,
  );

  return ChatService(
    provider: provider,
    modelConfig: effectiveModelConfig,
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
    } catch (e) {
      debugPrint('ChatNotifier.sendMessage: provider error - $e');
      state = ChatState(
        messages: [
          ...baseMessages,
          ChatMessage(role: 'user', content: text.trim()),
          ChatMessage(
            role: 'assistant',
            content: '**[错误: $e]**',
            isStreaming: false,
          ),
        ],
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
              content: '$partialContent\n\n**[错误: $error]**',
              isStreaming: false,
            ),
          ],
          streamingAssistantContent: '',
          isAssistantResponding: false,
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
