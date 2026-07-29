import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../pages/chat/chat_types.dart';
import '../providers/chat_stream_provider.dart';
import '../providers/conversation_provider.dart';
import 'app_log_service.dart';
import 'chat_adapter.dart';

// ============================================================================
// ChatStreamManager — 对话流式请求管理器
// ============================================================================
//
// 职责：
// - 持有 [ChatAdapter] 实例，管理其生命周期
// - 独立于页面 Widget 运行流式请求循环
// - 支持每条对话独立跟踪流式状态，最多一个流在运行（adapter 限制）
// - 通过 Riverpod providers 向页面暴露当前活跃对话的流式状态
// - 在流式过程中定期持久化部分结果，防止应用中断丢失
// - 在流式完成后自动持久化完整消息
// - 支持取消和销毁
//
// 与 ChatPage 的关系：
// - ChatStreamManager 是 app 级单例，不依赖任何页面 Widget
// - ChatPage 通过 chatStreamManagerProvider 获取管理器引用
// - ChatPage 将发送请求、取消等操作委托给管理器
// - ChatPage 通过 watch providers 获取实时流式状态
// - ChatPage 调用 activateConversation 切换 providers 输出到指定对话
// ============================================================================

// ============================================================================
// StreamResult — 流式请求完成后返回的结果
// ============================================================================

/// The result of a streaming request, returned by [ChatStreamManager.startStreaming].
///
/// Contains the final message history (including the assistant's response),
/// the accumulated reply text, and any tool calls or reasoning content.
class StreamResult {
  /// The conversation message history after the assistant message was appended.
  final List<ChatMessage> history;

  /// The newly created assistant message, or null if no text was received.
  final ChatMessage? assistantMessage;

  /// The full accumulated reply text from the stream.
  final String fullReply;

  /// The accumulated reasoning buffer, or empty if no reasoning events.
  final String reasoningBuffer;

  /// All reasoning sections (for multi-step tool call rounds).
  final List<String> reasoningSections;

  /// Per-round text chunks that mirror the Agent chain structure,
  /// allowing assistant speech to be interleaved between reasoning
  /// and tool call blocks instead of all appearing at the end.
  final List<String> textSections;

  /// Tool calls accumulated during the stream.
  final List<ToolCallData> toolCalls;

  /// Indices into [toolCalls] where each new tool-call round begins.
  /// Used by [buildAgentChainSegments] to group consecutive tool calls
  /// that belong to the same assistant step (separated by non-empty text).
  final List<int> toolCallRoundStarts;

  /// Whether the stream was cancelled by the user.
  final bool cancelled;

  const StreamResult({
    required this.history,
    this.assistantMessage,
    this.fullReply = '',
    this.reasoningBuffer = '',
    this.reasoningSections = const [],
    this.textSections = const [],
    this.toolCalls = const [],
    this.toolCallRoundStarts = const [],
    this.cancelled = false,
  });

  /// Whether the stream completed with an error (not cancelled).
  bool get isError => fullReply.startsWith('错误:') && !cancelled;

  /// Whether the stream produced any content.
  bool get hasContent => fullReply.isNotEmpty;
}

// ============================================================================
// _ConversationStreamState — per-conversation mutable streaming state
// ============================================================================

class _ConversationStreamState {
  final String convId;
  bool cancelledByUser = false;
  /// Guards against overlapping periodic persist calls from the timer.
  bool _isPersisting = false;
  String? streamingMsgId;
  String fullReply = '';
  String reasoningBuffer = '';
  List<String> reasoningSections = [];

  /// Per-round text chunks that mirror reasoning sections: each time a new
  /// tool call round begins, a new chunk is started so that post-stream
  /// segment building can interleave assistant speech between reasoning and
  /// tool call blocks in the correct Agent chain order.
  List<String> textChunks = [''];

  List<ToolCallData> toolCalls = [];
  List<ChatMessage> history = [];
  bool hasReceivedFirstToken = false;
  bool isComplete = false;

  /// Accumulator for tool calls across streaming rounds (used for history).
  final List<ToolCallData> accumulatedToolCalls = [];

  /// Indices into [toolCalls] where each new tool-call round begins.
  /// Used by buildAgentChainSegments to correctly group consecutive
  /// tool calls that belong to the same assistant "step".
  ///
  /// Initialized empty (NOT [0]) — the first ToolCallStartEvent adds
  /// index 0 when it creates the first new text chunk. Pre-seeding [0]
  /// would cause a duplicate [0, 0], splitting round 0's tools across
  /// phantom rounds.
  List<int> toolCallRoundStarts = [];

  /// Throttle timers
  DateTime lastTextUpdate = DateTime.now();
  DateTime lastReasoningUpdate = DateTime.now();

  /// Periodic persistence timer
  Timer? persistTimer;

  /// Completer used to return the same future for duplicate startStreaming
  /// calls on the same conversation.
  Completer<StreamResult>? resultCompleter;

  _ConversationStreamState({required this.convId});
}

// ============================================================================
// ChatStreamManager
// ============================================================================

class ChatStreamManager {
  final Ref? _ref;
  final ChatAdapter _adapter = ChatAdapter();

  // ── Per-conversation stream states ──
  final Map<String, _ConversationStreamState> _streams = {};

  // ── Throttle constants ──
  static const Duration _textThrottle = Duration(milliseconds: 200); // 5次/秒
  static const Duration _reasoningThrottle = Duration(milliseconds: 200);

  /// Public constant for testing / verification.
  static const int textThrottleMs = 200;

  // ── Periodic persistence interval ──
  static const Duration _persistInterval = Duration(seconds: 5);

  ChatStreamManager([this._ref]);

  // ── 公开 getter ──

  ChatAdapter get adapter => _adapter;

  /// Whether ANY conversation is currently streaming.
  bool get isStreaming => _streams.isNotEmpty;

  /// Returns the first active streaming conversation ID, or null if none.
  /// (Legacy getter; with family providers, _activeConvId no longer exists.)
  String? get activeStreamingConvId =>
      _streams.isNotEmpty ? _streams.keys.first : null;

  // ── Legacy getters (operate on the first active conversation) ──

  /// The streaming conversation ID (first active).
  String? get streamingConvId => activeStreamingConvId;

  /// The streaming message ID for the first active conversation.
  String? get streamingMsgId {
    final first = activeStreamingConvId;
    return first != null ? _streams[first]?.streamingMsgId : null;
  }

  /// The full reply for the first active conversation.
  String get fullReply {
    final first = activeStreamingConvId;
    return first != null ? (_streams[first]?.fullReply ?? '') : '';
  }

  /// The reasoning buffer for the first active conversation.
  String get reasoningBuffer {
    final first = activeStreamingConvId;
    return first != null ? (_streams[first]?.reasoningBuffer ?? '') : '';
  }

  /// Reasoning sections for the first active conversation.
  List<String> get reasoningSections {
    final first = activeStreamingConvId;
    return first != null
        ? List.unmodifiable(_streams[first]?.reasoningSections ?? [])
        : const [];
  }

  /// Tool calls for the first active conversation.
  List<ToolCallData> get toolCalls {
    final first = activeStreamingConvId;
    return first != null
        ? List.unmodifiable(_streams[first]?.toolCalls ?? [])
        : const [];
  }

  /// Message history for the first active conversation.
  List<ChatMessage> get history {
    final first = activeStreamingConvId;
    return first != null
        ? List.unmodifiable(_streams[first]?.history ?? [])
        : const [];
  }

  bool get hasReceivedFirstToken {
    final first = activeStreamingConvId;
    return first != null && (_streams[first]?.hasReceivedFirstToken ?? false);
  }

  // ── Per-conversation queries ──

  /// Whether [convId] is currently streaming.
  bool isStreamingFor(String convId) => _streams.containsKey(convId);

  /// The streaming message ID for a specific conversation.
  String? streamingMsgIdFor(String convId) => _streams[convId]?.streamingMsgId;

  /// The full reply for a specific conversation.
  String fullReplyFor(String convId) => _streams[convId]?.fullReply ?? '';

  /// The history for a specific conversation.
  List<ChatMessage> historyFor(String convId) =>
      List.unmodifiable(_streams[convId]?.history ?? []);

  /// Reasoning sections for a specific conversation.
  List<String> reasoningSectionsFor(String convId) =>
      List.unmodifiable(_streams[convId]?.reasoningSections ?? []);

  /// Tool calls for a specific conversation.
  List<ToolCallData> toolCallsFor(String convId) =>
      List.unmodifiable(_streams[convId]?.toolCalls ?? []);

  /// Whether the first token has been received for a specific conversation.
  bool hasFirstTokenFor(String convId) =>
      _streams[convId]?.hasReceivedFirstToken ?? false;

  /// Text chunks for a specific conversation.
  List<String> textChunksFor(String convId) =>
      List.unmodifiable(_streams[convId]?.textChunks ?? []);

  /// Tool call round starts for a specific conversation.
  List<int> toolCallRoundStartsFor(String convId) =>
      List.unmodifiable(_streams[convId]?.toolCallRoundStarts ?? []);

  /// The in-progress reasoning buffer for a specific conversation.
  /// Returns the content of the currently-accumulating reasoning section,
  /// or an empty string if no reasoning stream is active for this convId.
  String reasoningBufferFor(String convId) =>
      _streams[convId]?.reasoningBuffer ?? '';

  // ── Provider 更新辅助 ──

  void _setProvider<T>(StateProvider<T> provider, T value) {
    if (_ref == null) return;
    _ref!.read(provider.notifier).state = value;
  }

  // ── 公共 API ──

  /// Pushes the streaming state of [convId] to its per-conversation
  /// family provider instances. If the conversation has no active stream,
  /// clears the provider for this conversation.
  void activateConversation(String convId) {
    final state = _streams[convId];
    if (state != null) {
      _pushStateToProviders(state);
    } else {
      _clearProvidersFor(convId);
    }
  }

  /// 启动流式请求，独立于页面 Widget 在后台运行。
  ///
  /// [text] 用户消息文本
  /// [convId] 当前对话 ID
  /// [history] 当前对话的消息历史（不包含新创建的消息）
  /// [tools] 启用的工具列表
  /// [reasoning] 是否启用推理
  ///
  /// 返回 [StreamResult]，包含最终的对话历史和助手消息。
  Future<StreamResult> startStreaming({
    required String text,
    required String convId,
    required List<ChatMessage> history,
    List<ToolDefinition> tools = const [],
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    String? streamingMsgId,
  }) async {
    // If this conversation already has a stream running, return the
    // pending future so the caller awaits the same result.
    if (_streams.containsKey(convId)) {
      final existing = _streams[convId]!;
      // If the existing stream was cancelled (user tapped Stop), clean
      // up immediately and allow a fresh stream. Without this, a
      // Stop→re-Send sequence would return the cancelled stream's stale
      // result, losing the new user message from history.
      if (existing.cancelledByUser) {
        existing.persistTimer?.cancel();
        existing.persistTimer = null;
        _streams.remove(convId);
        // Fall through to start a new stream below.
      } else {
        debugPrint('[ChatStreamManager] 对话 $convId 已有流式请求进行中');
        return _streams[convId]!.resultCompleter!.future;
      }
    }

    // Each conversation gets its own ChatService via the adapter, so
    // multiple conversations can stream concurrently. No need to
    // abandon other conversations' streams.
    // Create per-conversation state and its result completer.
    // ALL synchronous setup must happen BEFORE the first await so
    // that isStreaming / isStreamingFor are correct immediately.
    final resultCompleter = Completer<StreamResult>();
    final state = _ConversationStreamState(convId: convId)
      ..resultCompleter = resultCompleter;
    state.history = List.from(history);
    state.lastTextUpdate = DateTime.now();
    state.lastReasoningUpdate = DateTime.now();

    final aiMsgId =
        streamingMsgId ?? 'a${DateTime.now().millisecondsSinceEpoch}';
    state.streamingMsgId = aiMsgId;

    _streams[convId] = state;

    // Track this conversation in the streaming set so the page can detect
    // completion (see streamingConversationsProvider docs).
    _setProvider(streamingConversationsProvider, <String>{
      ..._ref?.read(streamingConversationsProvider) ?? const {},
      convId
    });

    // Push initial state to this conversation's family providers
    _pushStateToProviders(state);

    // Start periodic persistence timer
    state.persistTimer = Timer.periodic(_persistInterval, (_) {
      _doPeriodicPersist(state);
    });

    // Snapshot the ChatService instance BEFORE the first await so that
    // Snapshot this conversation's ChatService before any await.
    // The adapter creates a per-conversation service on demand, so
    // capture it here for raw data (lastRequestBody etc.) in finally.
    final _snappedChatService = _adapter.getOrCreateService(convId);

    // Start the provider stream BEFORE yielding to the event loop so
    // that the ChatService is guaranteed to be the one we just created.
    // The stream controller will buffer any events produced before the
    // await-for loop subscribes below.
    final stream = _adapter.sendStreamWithTools(
      text,
      history: state.history,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
      tools: tools,
      convId: convId,
    );

    // Now safe to yield to event loop — all state is established and the
    // provider stream is already created.
    await AppLogService.info('ChatStreamManager',
        '[STREAM-MGR] startStreaming: begin, convId=$convId, historyLen=${history.length}');

    Object? streamError;
    Map<String, dynamic>? rawRequestCapture;
    Map<String, dynamic>? rawResponseCapture;

    try {
      await for (final event in stream) {
        if (state.cancelledByUser) break;

        switch (event) {
          case TextEvent e:
            if (!state.hasReceivedFirstToken) {
              state.hasReceivedFirstToken = true;
              _pushToProvider(convId, streamingHasFirstTokenProvider, true);
            }
            state.fullReply += e.text;
            state.textChunks[state.textChunks.length - 1] += e.text;
            // 节流：最长200ms更新一次 provider
            final now = DateTime.now();
            if (now.difference(state.lastTextUpdate) >= _textThrottle) {
              state.lastTextUpdate = now;
              // Set textSections first (no listener) so that when
              // fullReply fires its listener and reads streamingTextSectionsProvider
              // inside _rebuildLiveSegments, it sees the already-updated value.
              _pushToProvider(convId, streamingTextSectionsProvider,
                  List<String>.from(state.textChunks));
              _pushToProvider(
                  convId, streamingFullReplyProvider, state.fullReply);
            }

          case ReasoningEvent e:
            state.reasoningBuffer += e.text;
            final sections = List<String>.from(state.reasoningSections);
            if (sections.isNotEmpty) {
              sections[sections.length - 1] = state.reasoningBuffer;
            } else {
              sections.add(state.reasoningBuffer);
            }
            state.reasoningSections = sections;
            // 节流
            final now = DateTime.now();
            if (now.difference(state.lastReasoningUpdate) >=
                _reasoningThrottle) {
              state.lastReasoningUpdate = now;
              _pushToProvider(
                  convId, streamingReasoningProvider, state.reasoningBuffer);
              _pushToProvider(
                  convId, streamingReasoningSectionsProvider, sections);
            }

          case ReasoningSectionEndEvent():
            final sections = List<String>.from(state.reasoningSections);
            sections.add('');
            state.reasoningSections = sections;
            state.reasoningBuffer = ''; // Reset for new reasoning section
            _pushToProvider(
                convId, streamingReasoningSectionsProvider, sections);

          case ToolCallStartEvent e:
            final toolCallData = ToolCallData(
              id: e.toolCall.id,
              name: e.toolCall.name,
              arguments: Map<String, dynamic>.from(e.toolCall.arguments),
              status: ToolCallStatus.running,
            );
            state.toolCalls.add(toolCallData);
            state.accumulatedToolCalls.add(toolCallData);
            // Start a new text chunk at tool call boundary so that
            // assistant speech is interleaved between tool call rounds
            // rather than all appearing at the end.
            if (state.textChunks.last.isNotEmpty ||
                state.textChunks.length == 1) {
              state.textChunks.add('');
              // Record that this tool call starts a new round.
              // Consecutive tool calls that don't create new text chunks
              // are grouped together in the same round.
              state.toolCallRoundStarts.add(state.toolCalls.length - 1);
            }
            // Set textSections first (no listener) so that when
            // toolCalls fires its listener, it reads the updated value.
            _pushToProvider(convId, streamingTextSectionsProvider,
                List<String>.from(state.textChunks));
            _pushToProvider(convId, streamingToolCallsProvider,
                List<ToolCallData>.from(state.toolCalls));
            _pushToProvider(convId, streamingToolCallRoundStartsProvider,
                List<int>.from(state.toolCallRoundStarts));

          case ToolCallCompleteEvent e:
            for (var i = 0; i < state.toolCalls.length; i++) {
              if (state.toolCalls[i].id == e.toolCallId) {
                state.toolCalls[i] = state.toolCalls[i].copyWith(
                  status: ToolCallStatus.completed,
                  result: e.result,
                );
                break;
              }
            }
            for (var i = 0; i < state.accumulatedToolCalls.length; i++) {
              if (state.accumulatedToolCalls[i].id == e.toolCallId) {
                state.accumulatedToolCalls[i] =
                    state.accumulatedToolCalls[i].copyWith(
                  status: ToolCallStatus.completed,
                  result: e.result,
                );
                break;
              }
            }
            _pushToProvider(convId, streamingToolCallsProvider,
                List<ToolCallData>.from(state.toolCalls));
        }
      }
    } catch (e, s) {
      streamError = e;
      if (!state.cancelledByUser) {
        debugPrint('[ChatStreamManager] 流式请求异常: $e\n$s');
        try {
          await AppLogService.error('ChatStreamManager', '流式请求异常', e, s);
        } catch (_) {
          // Best effort: logging failure should not prevent cleanup
        }
        state.fullReply = '错误: ${e.toString()}';
        _pushToProvider(convId, streamingTextSectionsProvider,
            List<String>.from(state.textChunks));
        _pushToProvider(convId, streamingFullReplyProvider, state.fullReply);
        state.toolCalls.clear();
        _pushToProvider(convId, streamingToolCallsProvider, []);
      }
    } finally {
      // Stop periodic persistence
      state.persistTimer?.cancel();
      state.persistTimer = null;

      // Final throttle flush: push the last text to the UI.
      // Set textSections first (no listener) so that when
      // fullReply fires its listener and reads streamingTextSectionsProvider
      // inside _rebuildLiveSegments, it sees the already-updated value.
      _pushToProvider(convId, streamingTextSectionsProvider,
          List<String>.from(state.textChunks));
      _pushToProvider(convId, streamingFullReplyProvider, state.fullReply);

      // Capture request/response raw data from the ChatService instance
      // that was active when this stream started (snapped above). Using
      // the snapped reference is critical: adapter.currentChatService may
      // have been replaced mid-stream by a page re-entry calling configure()
      // or selectModel(). Reading through the replaced service returns null.
      try {
        final reqBody = _snappedChatService?.lastRequestBody;
        final headers = _snappedChatService?.lastRequestHeaders;
        final url = _snappedChatService?.lastRequestUrl;
        if (reqBody != null || headers != null || url != null) {
          rawRequestCapture = {};
          if (url != null) rawRequestCapture['url'] = url;
          if (headers != null) rawRequestCapture['headers'] = headers;
          if (reqBody != null) rawRequestCapture['body'] = reqBody;
        }
        final respData = _snappedChatService?.lastResponseData;
        final statusCode = _snappedChatService?.lastResponseStatusCode;
        final respHeaders = _snappedChatService?.lastResponseHeaders;
        if (respData != null || statusCode != null || respHeaders != null) {
          rawResponseCapture = {};
          if (statusCode != null) {
            rawResponseCapture['statusCode'] = statusCode;
          }
          if (respHeaders != null) {
            rawResponseCapture['headers'] = respHeaders;
          }
          if (respData != null) rawResponseCapture['data'] = respData;
        } else if (streamError is Exception) {
          rawResponseCapture = {'error': streamError.toString()};
        }
      } catch (_) {}

      // Do NOT overwrite state.reasoningSections or state.reasoningBuffer
      // from _adapter.reasoningContent. The manager already correctly
      // accumulates reasoning sections event-by-event (ReasoningEvent +
      // ReasoningSectionEndEvent), and _adapter.reasoningContent is a
      // cumulative buffer from the ChatService that is never reset per-round.
      // Overwriting would merge all reasoning into the last section.
    }

    // ── Post-stream processing ──
    ChatMessage? assistantMessage;
    final wasCancelled = state.cancelledByUser;

    try {
      if (state.fullReply.isNotEmpty) {
        final isError = state.fullReply.startsWith('错误:');
        final msg = ChatMessage(
          role: 'assistant',
          content: state.fullReply,
          id: state.streamingMsgId ?? '',
          isError: isError,
          reasoningContent:
              state.reasoningBuffer.isNotEmpty ? state.reasoningBuffer : null,
          rawRequest: rawRequestCapture,
          rawResponse: rawResponseCapture,
          toolCalls: state.accumulatedToolCalls.isNotEmpty
              ? List<ToolCallData>.from(state.accumulatedToolCalls)
              : null,
          reasoningSections: state.reasoningSections.isNotEmpty
              ? List<String>.from(state.reasoningSections)
              : null,
          textSections: state.textChunks.isNotEmpty
              ? List<String>.from(state.textChunks)
              : null,
          toolCallRoundStarts: state.toolCallRoundStarts.isNotEmpty
              ? List<int>.from(state.toolCallRoundStarts)
              : null,
        );
        state.history.add(msg);
        assistantMessage = msg;
      }
    } catch (e, s) {
      debugPrint('[ChatStreamManager] 后处理错误: $e\n$s');
    }

    // ── Persist BEFORE cleaning up stream state ──
    // This guard ensures save always runs, even if the code below throws.
    // It's the single persistence path for all streaming results.
    try {
      if (state.history.isNotEmpty) {
        await AppLogService.info('ChatStreamManager',
            '[STREAM-MGR] startStreaming: persisting historyLen=${state.history.length}');
        await _saveMessages(convId: convId, history: state.history);
      }
    } catch (_) {
      await AppLogService.error(
          'ChatStreamManager', '[STREAM-MGR] save failed', _);
    }

    // Build the result and complete the resultCompleter AFTER save
    final result = StreamResult(
      history: List.from(state.history),
      assistantMessage: assistantMessage,
      fullReply: state.fullReply,
      reasoningBuffer: state.reasoningBuffer,
      reasoningSections: List.from(state.reasoningSections),
      textSections: List.from(state.textChunks),
      toolCalls: List.from(state.accumulatedToolCalls),
      toolCallRoundStarts: List.from(state.toolCallRoundStarts),
      cancelled: wasCancelled,
    );

    // Complete the result completer so duplicate startStreaming calls
    // await the same future and get the final result.
    if (!state.resultCompleter!.isCompleted) {
      state.resultCompleter!.complete(result);
    }

    // Clean up this conversation's stream.
    // Identity guard: if _streams[convId] no longer references THIS state
    // object, a new stream was already started for the same convId (via the
    // Stop→re-Send path). In that case, skip removal and provider cleanup
    // to avoid destroying the new stream's state.
    if (_streams[convId] == state) {
      _streams.remove(convId);
    }
    state.resultCompleter = null;

    // Only clear per-conversation providers if no new stream replaced
    // this one. If a new stream is active for the same convId, its own
    // provider state should be left untouched.
    final replaced = _streams.containsKey(convId) && _streams[convId] != state;
    if (!replaced) {
      _setProvider(isStreamingProvider(convId), false);
      _setProvider(streamingMsgIdProvider(convId), null);
      _setProvider(streamingHasFirstTokenProvider(convId), false);
      _setProvider(streamingReasoningProvider(convId), '');
    }

    // Remove this conversation from the streaming set ONLY if no new
    // stream replaced this one. If _streams still contains convId (pointing
    // to a different state object), keep it in the streaming set.
    if (!_streams.containsKey(convId)) {
      final activeSet = <String>{
        ..._ref?.read(streamingConversationsProvider) ?? const {}
      };
      activeSet.remove(convId);
      _setProvider(streamingConversationsProvider, activeSet);
      // Dispose the per-conversation ChatService so a subsequent
      // startStreaming for the same convId creates a fresh service
      // with the latest config (from forceService / selectModel).
      _adapter.cancelService(convId);
    }

    // Do NOT clear segment-related providers here (streamingFullReplyProvider,
    // streamingTextSectionsProvider, streamingReasoningSectionsProvider,
    // streamingToolCallsProvider, streamingToolCallRoundStartsProvider).
    // The chat_page's post-stream code in _startStreaming handles provider
    // cleanup AFTER updating _history and calling _buildFinalSegments.
    // Clearing segment providers prematurely triggers _rebuildLiveSegments
    // with empty data, overwriting the correct segments (including reasoning
    // with isStreaming=true that should have been replaced by
    // _buildFinalSegments with isStreaming=false).

    return result;
  }

  /// 取消指定对话的流式请求。如果 [convId] 为 null，取消所有。
  void cancel([String? convId]) {
    if (convId != null) {
      final state = _streams[convId];
      if (state == null) return;
      state.cancelledByUser = true;
      // Cancel only this conversation's HTTP request.
      _adapter.cancelService(convId);
    } else {
      if (_streams.isEmpty) return;
      for (final s in _streams.values) {
        s.cancelledByUser = true;
      }
      // Cancel all services.
      _adapter.cancelAllServices();
    }
  }

  /// 释放资源。
  void dispose() {
    for (final s in _streams.values) {
      s.persistTimer?.cancel();
      s.persistTimer = null;
    }
    _streams.clear();
    _setProvider(streamingConversationsProvider, <String>{});
    _adapter.dispose();
  }

  // ── 私有方法 ──

  /// Pushes the state of the given conversation to its per-conversation
  /// family provider instances.
  void _pushStateToProviders(_ConversationStreamState s) {
    _setProvider(isStreamingProvider(s.convId), true);
    _setProvider(streamingMsgIdProvider(s.convId), s.streamingMsgId);
    _setProvider(streamingFullReplyProvider(s.convId), s.fullReply);
    _setProvider(
        streamingHasFirstTokenProvider(s.convId), s.hasReceivedFirstToken);
    _setProvider(streamingReasoningProvider(s.convId), s.reasoningBuffer);
    _setProvider(streamingReasoningSectionsProvider(s.convId),
        List<String>.from(s.reasoningSections));
    _setProvider(streamingToolCallsProvider(s.convId),
        List<ToolCallData>.from(s.toolCalls));
    _setProvider(streamingTextSectionsProvider(s.convId),
        List<String>.from(s.textChunks));
    _setProvider(streamingToolCallRoundStartsProvider(s.convId),
        List<int>.from(s.toolCallRoundStarts));
  }

  /// Clears streaming providers for a specific conversation.
  ///
  /// Only clears if [convId] does NOT currently have an active stream.
  /// If another conversation IS streaming (different convId), this
  /// conversation's unrelated provider entries are still cleared.
  void _clearProvidersFor(String convId) {
    if (_streams.containsKey(convId)) return; // Don't clear if still streaming
    _setProvider(isStreamingProvider(convId), false);
    _setProvider(streamingMsgIdProvider(convId), null);
    _setProvider(streamingFullReplyProvider(convId), '');
    _setProvider(streamingHasFirstTokenProvider(convId), false);
    _setProvider(streamingReasoningProvider(convId), '');
    _setProvider(streamingReasoningSectionsProvider(convId), []);
    _setProvider(streamingToolCallsProvider(convId), []);
    _setProvider(streamingTextSectionsProvider(convId), ['']);
    _setProvider(streamingToolCallRoundStartsProvider(convId), []);
  }

  /// Pushes a provider update for [convId]'s family instance.
  /// With family providers, there is no _activeConvId guard — each
  /// conversation writes to its own independent provider space.
  void _pushToProvider<T>(
      String convId, StateProvider<T> Function(String) family, T value) {
    if (_ref == null) return;
    _setProvider(family(convId), value);
  }

  /// Periodic partial persistence for the given conversation's stream.
  void _doPeriodicPersist(_ConversationStreamState s) {
    // Guard: if the timer was cancelled (stream ended), the state might
    // still be referenced from a late-arriving timer callback. The final
    // save has already run by now; don't overwrite it with partial data.
    if (s.persistTimer == null) return;
    if (s.cancelledByUser) return;
    if (s.fullReply.isEmpty && s.reasoningBuffer.isEmpty) return;
    if (s._isPersisting) return;
    s._isPersisting = true;
    final ref = _ref;
    if (ref == null) {
      debugPrint('[ChatStreamManager] 定期持久化失败: _ref is null');
      s._isPersisting = false;
      return;
    }
    try {
      final partialHistory = List<ChatMessage>.from(s.history);
      if (s.fullReply.isNotEmpty) {
        final exists = partialHistory.any((m) => m.id == s.streamingMsgId);
        if (!exists) {
          partialHistory.add(ChatMessage(
            role: 'assistant',
            content: s.fullReply,
            id: s.streamingMsgId ?? '',
            reasoningContent:
                s.reasoningBuffer.isNotEmpty ? s.reasoningBuffer : null,
            toolCalls: s.accumulatedToolCalls.isNotEmpty
                ? List<ToolCallData>.from(s.accumulatedToolCalls)
                : null,
            reasoningSections: s.reasoningSections.isNotEmpty
                ? List<String>.from(s.reasoningSections)
                : null,
            textSections: s.textChunks.any((c) => c.isNotEmpty)
                ? List<String>.from(s.textChunks)
                : null,
            toolCallRoundStarts: s.toolCallRoundStarts.isNotEmpty
                ? List<int>.from(s.toolCallRoundStarts)
                : null,
          ));
        }
      }
      ref.read(conversationsProvider.notifier).updateMessages(
            s.convId,
            partialHistory,
          );
    } catch (e) {
      debugPrint('[ChatStreamManager] 定期持久化失败: $e');
    } finally {
      s._isPersisting = false;
    }
  }

  Future<void> _saveMessages({
    required String convId,
    required List<ChatMessage> history,
  }) async {
    final ref = _ref;
    if (ref == null) {
      await AppLogService.warning(
          'ChatStreamManager', '保存消息失败: _ref is null, convId=$convId');
      return;
    }
    try {
      await ref
          .read(conversationsProvider.notifier)
          .updateMessages(convId, List<ChatMessage>.from(history));
      final lastMsg = history.isNotEmpty ? history.last : null;
      await AppLogService.info(
          'ChatStreamManager',
          '保存消息成功, convId=$convId, historyLen=${history.length}, '
              'hasToolCalls=${lastMsg?.toolCalls?.isNotEmpty ?? false}, '
              'hasReasoning=${lastMsg?.reasoningSections?.isNotEmpty ?? false}');
    } catch (e, s) {
      try {
        await AppLogService.error('ChatStreamManager', '保存消息失败', e, s);
      } catch (_) {}
    }
  }
}
