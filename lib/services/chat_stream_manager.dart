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

  /// Tool calls accumulated during the stream.
  final List<ToolCallData> toolCalls;

  /// Whether the stream was cancelled by the user.
  final bool cancelled;

  const StreamResult({
    required this.history,
    this.assistantMessage,
    this.fullReply = '',
    this.reasoningBuffer = '',
    this.reasoningSections = const [],
    this.toolCalls = const [],
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
  String? streamingMsgId;
  String fullReply = '';
  String reasoningBuffer = '';
  List<String> reasoningSections = [];
  List<ToolCallData> toolCalls = [];
  List<ChatMessage> history = [];
  bool hasReceivedFirstToken = false;
  bool isComplete = false;

  /// Accumulator for tool calls across streaming rounds (used for history).
  final List<ToolCallData> accumulatedToolCalls = [];

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

  /// The conversation whose state is currently pushed to providers.
  String? _activeConvId;

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

  /// The currently active conversation ID (the one whose data is in providers).
  String? get activeStreamingConvId => _activeConvId;

  // ── Legacy getters (operate on the active conversation) ──

  /// The streaming conversation ID for the active conversation.
  String? get streamingConvId => _activeConvId;

  /// The streaming message ID for the active conversation.
  String? get streamingMsgId =>
      _activeConvId != null ? _streams[_activeConvId]?.streamingMsgId : null;

  /// The full reply for the active conversation.
  String get fullReply =>
      _activeConvId != null ? (_streams[_activeConvId]?.fullReply ?? '') : '';

  /// The reasoning buffer for the active conversation.
  String get reasoningBuffer => _activeConvId != null
      ? (_streams[_activeConvId]?.reasoningBuffer ?? '')
      : '';

  /// Reasoning sections for the active conversation.
  List<String> get reasoningSections => _activeConvId != null
      ? List.unmodifiable(_streams[_activeConvId]?.reasoningSections ?? [])
      : const [];

  /// Tool calls for the active conversation.
  List<ToolCallData> get toolCalls => _activeConvId != null
      ? List.unmodifiable(_streams[_activeConvId]?.toolCalls ?? [])
      : const [];

  /// Message history for the active conversation.
  List<ChatMessage> get history => _activeConvId != null
      ? List.unmodifiable(_streams[_activeConvId]?.history ?? [])
      : const [];

  bool get hasReceivedFirstToken =>
      _activeConvId != null &&
      (_streams[_activeConvId]?.hasReceivedFirstToken ?? false);

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

  // ── Provider 更新辅助 ──

  void _setProvider<T>(StateProvider<T> provider, T value) {
    if (_ref == null) return;
    _ref!.read(provider.notifier).state = value;
  }

  // ── 公共 API ──

  /// Sets the active conversation for provider output.
  ///
  /// When the user switches conversations in the chat page, call this to
  /// ensure the global providers reflect the newly selected conversation's
  /// streaming state (if any).
  void activateConversation(String convId) {
    if (_activeConvId == convId) return;
    _activeConvId = convId;
    final state = _streams[convId];
    if (state != null) {
      _pushStateToProviders(state);
    } else {
      _clearProviders();
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
  }) async {
    // If this conversation already has a stream running, return the
    // pending future so the caller awaits the same result.
    if (_streams.containsKey(convId)) {
      debugPrint('[ChatStreamManager] 对话 $convId 已有流式请求进行中');
      return _streams[convId]!.resultCompleter!.future;
    }

    // Create per-conversation state and its result completer.
    // ALL synchronous setup must happen BEFORE the first await so
    // that isStreaming / isStreamingFor are correct immediately.
    final resultCompleter = Completer<StreamResult>();
    final state = _ConversationStreamState(convId: convId)
      ..resultCompleter = resultCompleter;
    state.history = List.from(history);
    state.lastTextUpdate = DateTime.now();
    state.lastReasoningUpdate = DateTime.now();

    final aiMsgId = 'a${DateTime.now().millisecondsSinceEpoch}';
    state.streamingMsgId = aiMsgId;

    _streams[convId] = state;

    // If no active conversation yet, set this one as active
    if (_activeConvId == null || _activeConvId == convId) {
      _activeConvId = convId;
      _pushStateToProviders(state);
    }

    // Start periodic persistence timer
    state.persistTimer = Timer.periodic(_persistInterval, (_) {
      _doPeriodicPersist(state);
    });

    // Now safe to yield to event loop — all state is established.
    await AppLogService.debug('ChatStreamManager',
        '[DEBUG-HIST-MGR] startStreaming: received historyLen=${history.length}, convId=$convId');
    await AppLogService.info('ChatStreamManager', '开始流式请求, convId=$convId');

    Object? streamError;
    Map<String, dynamic>? rawRequestCapture;
    Map<String, dynamic>? rawResponseCapture;

    try {
      final stream = _adapter.sendStreamWithTools(
        text,
        history: state.history,
        reasoning: reasoning,
        reasoningEffort: reasoningEffort,
        reasoningParamValues: reasoningParamValues,
        tools: tools,
      );

      await for (final event in stream) {
        if (state.cancelledByUser) break;

        switch (event) {
          case TextEvent e:
            if (!state.hasReceivedFirstToken) {
              state.hasReceivedFirstToken = true;
              _maybeSetProvider(convId, streamingHasFirstTokenProvider, true);
            }
            state.fullReply += e.text;
            // 节流：最长200ms更新一次 provider
            final now = DateTime.now();
            if (now.difference(state.lastTextUpdate) >= _textThrottle) {
              state.lastTextUpdate = now;
              _maybeSetProvider(
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
              _maybeSetProvider(
                  convId, streamingReasoningProvider, state.reasoningBuffer);
              _maybeSetProvider(
                  convId, streamingReasoningSectionsProvider, sections);
            }

          case ReasoningSectionEndEvent():
            final sections = List<String>.from(state.reasoningSections);
            sections.add('');
            state.reasoningSections = sections;
            _maybeSetProvider(
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
            _maybeSetProvider(convId, streamingToolCallsProvider,
                List<ToolCallData>.from(state.toolCalls));

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
            _maybeSetProvider(convId, streamingToolCallsProvider,
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
        _maybeSetProvider(convId, streamingFullReplyProvider, state.fullReply);
        state.toolCalls.clear();
        _maybeSetProvider(convId, streamingToolCallsProvider, []);
      }
    } finally {
      // Stop periodic persistence
      state.persistTimer?.cancel();
      state.persistTimer = null;

      // Final throttle flush: push the last text to the UI
      _maybeSetProvider(convId, streamingFullReplyProvider, state.fullReply);

      // Capture request/response raw data
      try {
        final reqBody = _adapter.lastRequestBody;
        final headers = _adapter.lastRequestHeaders;
        final url = _adapter.lastRequestUrl;
        if (reqBody != null || headers != null || url != null) {
          rawRequestCapture = {};
          if (url != null) rawRequestCapture['url'] = url;
          if (headers != null) rawRequestCapture['headers'] = headers;
          if (reqBody != null) rawRequestCapture['body'] = reqBody;
        }
        final respData = _adapter.lastResponseData;
        final statusCode = _adapter.lastResponseStatusCode;
        final respHeaders = _adapter.lastResponseHeaders;
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

      // Capture reasoning content (safe: getter returns a String, should never throw)
      try {
        final finalReasoning = _adapter.reasoningContent;
        if (finalReasoning.isNotEmpty) {
          state.reasoningBuffer = finalReasoning;
          final sections = List<String>.from(state.reasoningSections);
          if (sections.isNotEmpty) {
            sections[sections.length - 1] = finalReasoning;
          } else {
            sections.add(finalReasoning);
          }
          state.reasoningSections = sections;
          _maybeSetProvider(convId, streamingReasoningProvider, finalReasoning);
          _maybeSetProvider(
              convId, streamingReasoningSectionsProvider, sections);
        }
      } catch (_) {
        // Best effort: reasoning capture failure should not crash the stream
      }
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
        await AppLogService.debug('ChatStreamManager',
            '[DEBUG-HIST-MGR] about to save: state.history.length=${state.history.length}, fullReply.isNotEmpty=${state.fullReply.isNotEmpty}');
        await _saveMessages(convId: convId, history: state.history);
        await AppLogService.debug('ChatStreamManager',
            '[DEBUG-HIST-MGR] save completed: state.history.length=${state.history.length}');
      }
    } catch (_) {
      await AppLogService.debug(
          'ChatStreamManager', '[DEBUG-HIST-MGR] save failed');
    }

    // Build the result and complete the resultCompleter AFTER save
    final result = StreamResult(
      history: List.from(state.history),
      assistantMessage: assistantMessage,
      fullReply: state.fullReply,
      reasoningBuffer: state.reasoningBuffer,
      reasoningSections: List.from(state.reasoningSections),
      toolCalls: List.from(state.accumulatedToolCalls),
      cancelled: wasCancelled,
    );

    // Complete the result completer so duplicate startStreaming calls
    // await the same future and get the final result.
    if (!state.resultCompleter!.isCompleted) {
      state.resultCompleter!.complete(result);
    }

    // Clean up this conversation's stream
    state.isComplete = true;
    state.resultCompleter = null;
    _streams.remove(convId);

    // If this was the active conversation, clear or switch providers
    if (_activeConvId == convId) {
      _activeConvId = null;
      // Try to switch to another active stream
      if (_streams.isNotEmpty) {
        _activeConvId = _streams.keys.first;
        _pushStateToProviders(_streams[_activeConvId]!);
      } else {
        _clearProviders();
      }
    }

    return result;
  }

  /// 取消指定对话的流式请求。如果 [convId] 为 null，取消所有。
  void cancel([String? convId]) {
    if (convId != null) {
      final state = _streams[convId];
      if (state == null) return;
      state.cancelledByUser = true;
    } else {
      if (_streams.isEmpty) return;
      for (final s in _streams.values) {
        s.cancelledByUser = true;
      }
    }
    _adapter.cancel();
  }

  /// 释放资源。
  void dispose() {
    for (final s in _streams.values) {
      s.persistTimer?.cancel();
      s.persistTimer = null;
    }
    _streams.clear();
    _activeConvId = null;
    _adapter.dispose();
  }

  // ── 私有方法 ──

  /// Pushes the state of the given conversation to global providers.
  void _pushStateToProviders(_ConversationStreamState s) {
    _setProvider(isStreamingProvider, true);
    _setProvider(streamingMsgIdProvider, s.streamingMsgId);
    _setProvider(streamingFullReplyProvider, s.fullReply);
    _setProvider(streamingHasFirstTokenProvider, s.hasReceivedFirstToken);
    _setProvider(streamingReasoningProvider, s.reasoningBuffer);
    _setProvider(streamingReasoningSectionsProvider,
        List<String>.from(s.reasoningSections));
    _setProvider(
        streamingToolCallsProvider, List<ToolCallData>.from(s.toolCalls));
  }

  /// Clears all global streaming providers.
  void _clearProviders() {
    _setProvider(isStreamingProvider, false);
    _setProvider(streamingMsgIdProvider, null);
    _setProvider(streamingFullReplyProvider, '');
    _setProvider(streamingHasFirstTokenProvider, false);
    _setProvider(streamingReasoningProvider, '');
    _setProvider(streamingReasoningSectionsProvider, []);
    _setProvider(streamingToolCallsProvider, []);
  }

  /// Only pushes a provider update if [convId] matches the active conversation.
  void _maybeSetProvider<T>(String convId, StateProvider<T> provider, T value) {
    if (_activeConvId != convId) return;
    _setProvider(provider, value);
  }

  /// Periodic partial persistence for the given conversation's stream.
  void _doPeriodicPersist(_ConversationStreamState s) {
    if (s.cancelledByUser) return;
    if (s.fullReply.isEmpty && s.reasoningBuffer.isEmpty) return;
    final ref = _ref;
    if (ref == null) {
      debugPrint('[ChatStreamManager] 定期持久化失败: _ref is null');
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
          ));
        }
      }
      ref.read(conversationsProvider.notifier).updateMessages(
            s.convId,
            partialHistory,
          );
    } catch (e) {
      debugPrint('[ChatStreamManager] 定期持久化失败: $e');
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
