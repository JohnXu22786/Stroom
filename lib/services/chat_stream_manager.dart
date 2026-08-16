import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/legacy.dart'
    show StateProvider, StateProviderFamily;
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/assistant.dart' show Assistant;
import '../models/message_block.dart';
import '../models/tool_call.dart';
import '../pages/chat/chat_types.dart';
import '../pages/chat/utils/format_chat_error.dart' show formatChatErrorMessage;
import '../providers/chat_stream_provider.dart';
import '../providers/context_management_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/system_assistant_provider.dart';
import '../providers/assistant_provider.dart';
import '../providers/provider_config.dart';
import 'app_log_service.dart';
import 'chat_adapter.dart';
import 'chat_protocol.dart' show rebuildToolResultText;
import 'chat_service.dart' show ChatService;
import 'context_manager.dart';

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
    required String fullReply,
    required List<String> reasoningSections,
    required bool hasAccumulatedToolCalls,
  }) {
    return fullReply.isNotEmpty ||
        reasoningSections.any((s) => s.isNotEmpty) ||
        hasAccumulatedToolCalls;
  }

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
    Assistant? assistant,
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

    // ── 上下文管理：请求前检查工具输出累计是否达到 prune 阈值 ──
    // 对齐 opencode（PRUNE_PROTECT=40K / PRUNE_MINIMUM=20K）：
    // 从新到旧累计工具输出 token，超过保护窗后开始收集，
    // 可 prune 量超 20K 才执行；执行 = 软删除标记（compactedAt，
    // 数据保留），此后每次请求渲染占位符释放上下文。
    // 阈值基于"工具输出累计"而非模型 context——1M 模型在 100k+
    // 上下文时工具输出也早已超阈值，与 opencode 行为一致。
    // 可在设置页"上下文管理"关闭（opencode compaction.prune）。
    final ctxSettings = _ref?.read(contextManagementSettingsProvider) ??
        const ContextManagementSettings();
    if (ctxSettings.pruneEnabled) {
      // 压缩边界（对齐 opencode summary break）：有摘要时扫描到
      // 尾部起点即停止（其之前 = 已压缩内容）
      final tailStartId = _ref
          ?.read(conversationsProvider)
          .where((c) => c.id == convId)
          .firstOrNull
          ?.compactionTailStartId;
      final pruned = ContextManager.pruneToolResults(
        state.history,
        stopAtMessageId: tailStartId,
      );
      if (!identical(pruned, state.history)) {
        AppLogService.info(
            'ChatStreamManager', '[CTX-MGR] 工具结果 prune 执行完成, convId=$convId');
      }
      state.history = pruned;
    }

    final aiMsgId =
        streamingMsgId ?? 'a${DateTime.now().microsecondsSinceEpoch}';
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
    // The assistant (and entries) are passed so the snapshot itself
    // resolves the assistant's model — otherwise the pre-stream snapshot
    // would cache a global-config service and the send below would
    // silently ignore the assistant binding (putIfAbsent first-writer
    // wins).
    final snappedChatService = _adapter.getOrCreateService(
      convId,
      assistant: assistant,
      entriesState: _ref?.read(providerEntriesProvider),
    );

    // ── 对话级计费累计（per-request 事件驱动） ──
    // 每次请求的完整 usage 数据返回时（流末尾/错误轮的 usage 事件）
    // **立即**增量累加到对话，而非整次发送攒到流结束一次性提交：
    // - 重发/重试/编辑只会在累计值上继续增加，绝不重置、不从头重算；
    // - 每请求提交一次，service 复用/异常清理也不会重复提交（双计）。
    // 压缩请求先于主请求执行，绑定在同一个 service 上，同样走此回调。
    snappedChatService?.onUsageEvent = (usage, {required bool recordInput}) {
      _commitUsage(convId, usage, recordInput: recordInput);
    };

    // ── 上下文管理：摘要注入 + 发送量过滤 + 超限自动压缩 ──
    // 1. 每次请求都注入对话已有的压缩摘要（如有）
    // 2. 发送历史 = 有摘要时从"压缩时记录的尾部起点"起（固定快照，
    //    对齐 opencode tail_start_id），无摘要时全量——这就是
    //    "上下文显示越来越少、存储还在"的机制
    // 3. 压缩触发基于**发送量**（非存储总量），超限时把
    //    [快照之后 .. 新尾部起点] 压缩为锚定摘要
    final conv = _ref
        ?.read(conversationsProvider)
        .where((c) => c.id == convId)
        .firstOrNull;
    snappedChatService?.setContextSummary(conv?.contextSummary);

    // 发送历史过滤（对齐 opencode filterCompacted）：
    // 有摘要时从 compactionTailStartId（固定快照）起发送，
    // 快照之前 = 已压缩内容，存储保留但不发送。
    // 快照消息不在历史中（被删）时安全回退为全量。
    final tailStartId = conv?.compactionTailStartId;
    final hasSummary = conv?.contextSummary?.trim().isNotEmpty ?? false;
    List<ChatMessage> requestHistory;
    if (hasSummary && tailStartId != null) {
      final idx = state.history.indexWhere((m) => m.id == tailStartId);
      requestHistory = idx >= 0 ? state.history.sublist(idx) : state.history;
    } else {
      requestHistory = state.history;
    }

    try {
      final compacted = await _compactIfNeeded(
        state: state,
        convId: convId,
        tools: tools,
        requestHistory: requestHistory,
      );
      // 压缩成功：tail 快照已更新，重新计算发送历史
      // （从新尾部起点起，头部被摘要替代）
      if (compacted) {
        final newConv = _ref
            ?.read(conversationsProvider)
            .where((c) => c.id == convId)
            .firstOrNull;
        final newTailStartId = newConv?.compactionTailStartId;
        if (newTailStartId != null) {
          final idx = state.history.indexWhere((m) => m.id == newTailStartId);
          if (idx >= 0) {
            requestHistory = state.history.sublist(idx);
          }
        }
      }
      // 压缩期间用户取消：不发起主请求（空流走正常清理路径，
      // 结果标记为 cancelled）
      if (state.cancelledByUser) {
        debugPrint('[ChatStreamManager] 压缩期间取消, convId=$convId');
      }
    } catch (e, s) {
      debugPrint('[ChatStreamManager] 上下文管理失败: $e\n$s');
    }

    // Start the provider stream BEFORE yielding to the event loop so
    // that the ChatService is guaranteed to be the one we just created.
    // The stream controller will buffer any events produced before the
    // await-for loop subscribes below.
    //
    // requestHistory 已在上方上下文管理块计算（有摘要时 = 尾部快照起）。
    final stream = state.cancelledByUser
        ? const Stream<ChatEvent>.empty()
        : _adapter.sendStreamWithTools(
            text,
            history: requestHistory,
            reasoning: reasoning,
            reasoningEffort: reasoningEffort,
            reasoningParamValues: reasoningParamValues,
            tools: tools,
            convId: convId,
            assistant: assistant,
            entriesState: _ref?.read(providerEntriesProvider),
          );

    // Now safe to yield to event loop — all state is established and the
    // provider stream is already created.

    Object? streamError;

    try {
      try {
        await AppLogService.info('ChatStreamManager',
            '[STREAM-MGR] startStreaming: begin, convId=$convId, historyLen=${history.length}');
      } catch (_) {
        // 日志失败不能误判为流错误（否则主请求已发出但响应
        // 永不被消费，回复丢失）
      }

      await for (final event in stream) {
        if (state.cancelledByUser) break;

        _handleStreamEvent(event, state, convId);
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
        // 用友好错误格式化（分类中文提示 + 保留原始异常）：
        // 未配置供应商/网络失败/超时等给出可操作的提示。
        // 已流出的部分回复不能丢：拼接在错误文本之后，
        // 用户仍可看到流中断前的回答内容。
        final errorText = formatChatErrorMessage(e);
        final partial = state.fullReply;
        state.fullReply =
            partial.isEmpty ? errorText : '$errorText\n\n---\n$partial';
        _pushToProvider(convId, streamingTextSectionsProvider,
            List<String>.from(state.textChunks));
        _pushToProvider(convId, streamingFullReplyProvider, state.fullReply);
        state.toolCalls.clear();
        _pushToProvider(convId, streamingToolCallsProvider, <ToolCallData>[]);
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
    }

    return _completeStream(
      state: state,
      convId: convId,
      streamError: streamError,
      snappedChatService: snappedChatService,
    );
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

  /// 把一次请求的 usage 计量**立即**累加到对话（对话级累计）。
  ///
  /// 由 ChatService.onUsageEvent 回调触发：每次请求的完整 usage 数据
  /// 返回时增量提交（Conversation.totalCost += costIncrement），
  /// 绝不从头重算。重发/重试/编辑只会继续累加，不会重置。
  ///
  /// [recordInput] 为 false 时只累计 cost（压缩/标题等内部任务请求的
  /// 输入 ≈ 头部大小/仅一条消息，写入 lastInputTokens 会污染"当前
  /// 上下文大小"：压缩触发判断膨胀、状态行显示虚高）。
  ///
  /// 取消语义：usage 事件在请求正常结束以及错误/取消路径（provider
  /// 已收集到部分计量时也会先产出事件再上抛）都会产出，这里一律按
  /// API 返回的原值提交——cost 是已发生的事实，必须保留累计；tokens
  /// 若因截断而偏小，lastInputTokens 是"最近一次请求"的语义，压缩
  /// 触发另有 max(实际, 估算) 兜底，不会因偏小值漏压缩。
  ///
  /// fire-and-forget（不 await）：幂等的增量累加 + 防抖持久化，
  /// 多请求并发提交安全。
  void _commitUsage(String convId, Map<String, dynamic> usage,
      {required bool recordInput}) {
    final ref = _ref;
    if (ref == null) return;
    try {
      final inputTokens = usage['inputTokens'] as int?;
      final outputTokens = usage['outputTokens'] as int?;
      // num 安全取值：cost 以 int（JSON 整数值反序列化）出现时
      // 也能累计——单个字段的类型异常不能把整次计量（含 tokens）丢弃。
      final cost =
          usage['cost'] is num ? (usage['cost'] as num).toDouble() : 0.0;
      final hasMetering =
          recordInput && (inputTokens != null || outputTokens != null);
      if (!hasMetering && cost <= 0) return;
      unawaited(ref.read(conversationsProvider.notifier).updateUsage(
            conversationId: convId,
            inputTokens: recordInput ? inputTokens : null,
            outputTokens: recordInput ? outputTokens : null,
            costIncrement: cost,
          ));
    } catch (e) {
      debugPrint('[ChatStreamManager] usage 计量更新失败: $e');
    }
  }

  // ── 上下文压缩（compaction） ────────────────────────────────────

  /// 找到尾部起始索引：从末尾数第 [tailUserTurns] 个用户消息。
  /// 尾部 = 从该索引开始的所有消息（保留原文）；
  /// 头部 = 该索引之前的消息（可压缩）。
  static int _findTailStart(
    List<ChatMessage> history, {
    int tailUserTurns = 2,
  }) {
    var turns = 0;
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i].role == 'user') {
        turns++;
        if (turns >= tailUserTurns) return i;
      }
    }
    return 0;
  }
}
