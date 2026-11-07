import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/legacy.dart'
    show StateProvider, StateProviderFamily;
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/assistant.dart' show Assistant;
import '../models/built_in_assistants.dart';
import '../models/message_block.dart';
import '../models/tool_call.dart';
import '../pages/chat/chat_types.dart';
import '../pages/chat/utils/format_chat_error.dart' show formatChatErrorMessage;
import '../providers/chat_stream_provider.dart';
import '../providers/context_management_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/system_assistant_provider.dart';
import '../providers/locale_provider.dart'
    show appLocalizationsForLocale, localeProvider;
import '../providers/provider_config.dart';
import 'app_log_service.dart';
import 'chat_adapter.dart';
import 'chat_protocol.dart' show rebuildToolResultText;
import 'chat_service.dart' show ChatService;
import 'context_manager.dart';
import 'chat_retry_policy.dart'
    show
        TransportRetryPolicy,
        isRetryableTransportFailure,
        shouldAutoContinueStream,
        waitForRetryOrCancellation;

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

part 'chat_stream_manager_state.dart';
part 'chat_stream_manager_events.dart';
part 'chat_stream_manager_providers.dart';
part 'chat_stream_manager_persist.dart';
part 'chat_stream_manager_compaction.dart';
part 'chat_stream_manager_title.dart';
part 'chat_stream_manager_finalize.dart';

// ============================================================================
// ChatStreamManager
// ============================================================================

class ChatStreamManager {
  final Ref? _ref;
  final TransportRetryPolicy _transportRetryPolicy;
  final Future<void> Function(Duration duration)? _retryDelay;
  late final ChatAdapter _adapter;

  // ── Per-conversation stream states ──
  final Map<String, _ConversationStreamState> _streams = {};
  final Map<String, Future<bool> Function(ChatMessage)>
      _pendingContinuationHandlers = {};

  /// Pages currently displaying a specific stream. A completed stream only
  /// needs its provider buffers retained while at least one page is attached.
  final Map<String, Map<Object, String>> _streamPageOwners = {};

  // ── Throttle constants ──
  static const Duration _textThrottle = Duration(milliseconds: 200); // 5次/秒
  static const Duration _reasoningThrottle = Duration(milliseconds: 200);

  /// Public constant for testing / verification.
  static const int textThrottleMs = 200;

  // ── Periodic persistence interval ──
  static const Duration _persistInterval = Duration(seconds: 5);

  // ── 上下文管理常量 ──
  /// 压缩请求的最大输出 token 数。
  static const int _compactionMaxTokens = 4096;

  /// Whether the partial streaming state contains anything worth
  /// persisting during periodic saves: visible text, any reasoning
  /// section content (including a reasoning round whose buffer was just
  /// reset by ReasoningSectionEndEvent), or tool calls.
  ///
  /// Pure and testable; used as the single source of truth by both the
  /// periodic-persist guard and the partial-message builder so they can
  /// never disagree.
  @visibleForTesting
  static bool partialPersistHasContent({
    List<String>? textSections,
    String? fullReply,
    required List<String> reasoningSections,
    required bool hasAccumulatedToolCalls,
  }) {
    return (textSections?.any((section) => section.isNotEmpty) ??
            (fullReply?.isNotEmpty ?? false)) ||
        reasoningSections.any((s) => s.isNotEmpty) ||
        hasAccumulatedToolCalls;
  }

  ChatStreamManager([this._ref])
      : _transportRetryPolicy = const TransportRetryPolicy(),
        _retryDelay = null {
    _adapter = ChatAdapter(localeOverride: () => _ref?.read(localeProvider));
  }

  @visibleForTesting
  ChatStreamManager.withRetryPolicy({
    Ref? ref,
    TransportRetryPolicy transportRetryPolicy = const TransportRetryPolicy(),
    Future<void> Function(Duration duration)? retryDelay,
  })  : _ref = ref,
        _transportRetryPolicy = transportRetryPolicy,
        _retryDelay = retryDelay {
    _adapter = ChatAdapter(localeOverride: () => _ref?.read(localeProvider));
  }

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

  /// Number of active-section characters waiting for the next throttled delta.
  int pendingReasoningDeltaLengthFor(String convId) =>
      _streams[convId]?._pendingReasoningDelta.length ?? 0;

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

  /// Records that a chat page is displaying [streamingMsgId] for [convId].
  void attachStreamPage(String convId, String streamingMsgId, Object owner) {
    (_streamPageOwners[convId] ??= {})[owner] = streamingMsgId;
  }

  /// Removes a page's stream attachment. A disposed page can arrive just
  /// after finalization, so clear its completed buffers here when no page
  /// remains attached to that message.
  void detachStreamPage(
    String convId,
    String streamingMsgId,
    Object owner, {
    bool clearIfCompleted = false,
  }) {
    final owners = _streamPageOwners[convId];
    owners?.remove(owner);
    if (owners?.isEmpty == true) _streamPageOwners.remove(convId);
    if (clearIfCompleted &&
        !_streams.containsKey(convId) &&
        !_hasAttachedStreamPage(convId, streamingMsgId)) {
      _clearCompletedSegmentProviders(convId);
    }
  }

  bool _hasAttachedStreamPage(String convId, String streamingMsgId) =>
      _streamPageOwners[convId]?.containsValue(streamingMsgId) ?? false;

  void _clearCompletedSegmentProviders(String convId) {
    final ref = _ref;
    if (ref == null) return;
    ref.read(streamingFullReplyProvider(convId).notifier).state = '';
    ref.read(streamingReasoningProvider(convId).notifier).state = '';
    ref.read(streamingReasoningAppendProvider(convId).notifier).state = null;
    ref.read(streamingReasoningSectionsProvider(convId).notifier).state = [];
    ref.read(streamingTextSectionsProvider(convId).notifier).state = [''];
    ref.read(streamingTextAppendProvider(convId).notifier).state = null;
    ref.read(streamingToolCallsProvider(convId).notifier).state = [];
    ref.read(streamingToolCallRoundStartsProvider(convId).notifier).state = [];
  }

  /// The streaming message ID for a specific conversation.
  String? streamingMsgIdFor(String convId) => _streams[convId]?.streamingMsgId;

  /// The full reply for a specific conversation.
 