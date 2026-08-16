part of 'chat_stream_manager.dart';

extension _ChatStreamManagerCompactionExt on ChatStreamManager {
  // ── 上下文压缩（compaction） ────────────────────────────────────

  /// 上下文管理：发送量超限时，用压缩助手把新增头部历史压缩为锚定摘要。
  ///
  /// [requestHistory] 为本次实际发送的消息子集（有摘要时 = 尾部快照起，
  /// 对齐 opencode filterCompacted），触发判断与估算都基于它——
  /// 压缩后发送量回到小值，不会每次发送都重复压缩。
  ///
  /// 成功后：
  /// - 摘要持久化到 [Conversation.contextSummary]（含前次摘要合并）
  /// - [Conversation.compactionTailStartId] 更新为新尾部起点
  ///   （固定快照，后续请求从该消息起发送）
  /// - [state.history] **不裁剪**（存储完整保留，对齐 opencode）
  /// - 当前 ChatService 注入摘要（后续请求走 system 级摘要）
  ///
  /// 任何失败（未配置、请求失败、结果为空、头部为空）都静默返回 false
  /// —— 宁可照发也不阻断用户消息。每轮发送最多执行一次，无循环。
  Future<bool> _compactIfNeeded({
    required _ConversationStreamState state,
    required String convId,
    required List<ToolDefinition> tools,
    required List<ChatMessage> requestHistory,
  }) async {
    final ref = _ref;
    if (ref == null) return false;

    // 1. 触发线 = 自定义压缩触发值（若启用）?? 模型设置的上下文窗口。
    //    context 是 per-model 配置（模型页"上下文长度"），与 provider 无关。
    final modelConfig = _adapter.modelConfig;
    final modelContext = (modelConfig?.typeConfig['context'] as num?)?.toInt();
    final ctxSettings = ref.read(contextManagementSettingsProvider);
    final threshold = ctxSettings.effectiveCompactionThreshold(modelContext);
    if (threshold == null) return false;

    // 基准：优先使用上次请求的实际输入计量（API usage，非估算）；
    // 无实际计量时（首次请求）退化为估算。取两者较大值：
    // - actual 可能落后于本轮增长（新消息/附件/工具结果）
    // - estimated 含本轮全部内容
    // 取 max 宁可多压一次，也不让请求超过触发线。
    // 估算基于**发送量**（requestHistory，非存储总量）——压缩后
    // 存储保留全部消息，但发送量回到小值，不会每次都触发压缩。
    final conv = ref
        .read(conversationsProvider)
        .where((c) => c.id == convId)
        .firstOrNull;
    final actualInput = conv?.lastInputTokens;
    final estimated = ContextManager.estimateHistoryTokens(
      requestHistory,
      assistantPrompt: _adapter.assistantPrompt,
      tools: tools,
    );
    final currentTokens = actualInput == null
        ? estimated
        : (actualInput > estimated ? actualInput : estimated);
    debugPrint('[CTX-MGR] convId=$convId current=$currentTokens'
        ' (actual=$actualInput estimated=$estimated) threshold=$threshold');
    if (currentTokens < threshold) return false;

    // 2. 解析压缩任务：提示词（自定义优先，默认内置）+ 模型
    //    （配置了独立模型就用它，否则跟随对话页当前模型）
    final settings = ref.read(systemAssistantSettingsProvider);
    final compactionPrompt =
        resolveSystemAssistantPrompt(settings.compaction,
            defaultAssistantId: kBuiltInCompactionAssistantId);
    if (compactionPrompt == null) return false;

    // 3. 划分头部（可压缩）与尾部（保留原文）。
    //    head 起点：有摘要时从 compactionTailStartId 之后开始
    //    （快照之前 = 已压缩内容，不再转写；对齐 opencode hidden）。
    final tailStart = ChatStreamManager._findTailStart(state.history);
    var headStart = 0;
    final tailStartId = conv?.compactionTailStartId;
    if (tailStartId != null) {
      final idx = state.history.indexWhere((m) => m.id == tailStartId);
      if (idx >= 0) headStart = idx;
    }
    if (headStart >= tailStart) return false; // 无新增可压缩内容
    final head = state.history
        .sublist(headStart, tailStart)
        // 压缩转写剥离附件（媒体不进摘要请求）
        .map((m) => m.attachments.isEmpty ? m : m.copyWith(attachments: []))
        .toList();
    final tail = state.history.sublist(tailStart);
    if (head.isEmpty) return false;

    // 4. 组装压缩请求：前次摘要（如有）+ 头部转写 + 模板指令
    final previousSummary = conv?.contextSummary;

    final sb = StringBuffer();
    if (previousSummary != null && previousSummary.isNotEmpty) {
      sb.writeln('<previous-summary>');
      sb.writeln(previousSummary.trim());
      sb.writeln('</previous-summary>');
      sb.writeln();
    }
    sb.writeln('以下是需要压缩的对话历史：');
    for (final m in head) {
      final role = m.role == 'user' ? '用户' : '助手';
      final content = m.content.trim();
      if (content.isNotEmpty) {
        sb.writeln('$role: $content');
      }
      // 工具事实进摘要：工具调用与结果（截断至 200 字符）是
      // agent 工作的关键证据，压缩后模型需要保留
      final toolCalls = m.toolCalls;
      if (toolCalls != null) {
        for (final tc in toolCalls) {
          if (tc.status == ToolCallStatus.running ||
              tc.status == ToolCallStatus.pending) {
            continue;
          }
          final result = rebuildToolResultText(tc);
          final trimmed =
              result.length > 200 ? '${result.substring(0, 200)}…' : result;
          sb.writeln('$role 调用了工具 ${tc.name}: $trimmed');
        }
      }
    }
    sb.writeln();
    sb.writeln('请将以上对话历史压缩为锚定摘要，严格按模板输出。');

    // 5. 执行压缩请求（轻量、无工具、maxTokens 适中）
    //    独立 task service：此前 getOrCreateService 让压缩与主请求
    //    共享同一 service（取消联动、usage 事件回调都随之共享）。
    //    现在压缩可能与主请求使用不同模型，必须独立 service——
    //    通过 convId 注册，让 manager.cancel 仍能中止在途压缩请求；
    //    usage 事件显式接线到 _commitUsage（压缩只累计 cost）。
    final requestSvc = _adapter.createTransientServiceForModel(
      entriesState: ref.read(providerEntriesProvider),
      modelId: settings.compaction.modelId,
      providerName: settings.compaction.providerName,
      modelDisplayName: settings.compaction.modelDisplayName,
      convId: convId,
    );
    if (requestSvc == null) return false;
    requestSvc.onUsageEvent = (usage, {required bool recordInput}) {
      _commitUsage(convId, usage, recordInput: recordInput);
    };
    String summary;
    try {
      summary = await requestSvc.sendPrompt(
        systemPrompt: compactionPrompt,
        history: [ChatMessage(role: 'user', content: sb.toString())],
        maxTokens: ChatStreamManager._compactionMaxTokens,
        // 压缩请求的输入 ≈ 压缩前头部大小：只累计 cost，
        // 不写入 lastInputTokens（避免下次触发判断膨胀/状态行虚高）
        recordInputTokens: false,
      );
    } catch (e) {
      debugPrint('[ChatStreamManager] 压缩请求失败: $e');
      return false;
    } finally {
      // 请求结束（成功/失败/取消）即释放任务 service，避免长会话
      // 累积未回收的 HTTP 客户端；若已被取消路径移除则为空操作。
      _adapter.releaseTaskService(convId);
    }
    // 压缩请求期间用户取消：不应用压缩结果（摘要持久化
    // 会覆盖用户可见状态）
    if (state.cancelledByUser) return false;
    if (summary.isEmpty) return false;

    // 6. 持久化摘要 + 尾部起点（prune 边界）+ 注入摘要。
    //    注意：**不裁剪 state.history** —— 对齐 opencode：
    //    存储完整保留全部消息，发给 API 的只是"摘要 + 尾部"子集
    //    （由 startStreaming 的 requestHistory 过滤实现）。
    await ref.read(conversationsProvider.notifier).updateContextSummary(
          convId,
          summary,
          tailStartId: tail.isNotEmpty ? tail.first.id : null,
        );
    _adapter.getOrCreateService(convId)?.setContextSummary(summary);
    await AppLogService.info(
        'ChatStreamManager',
        '[CTX-MGR] 上下文已压缩, convId=$convId, '
            'head=${head.length} 条消息 → 摘要 ${summary.length} 字符');
    return true;
  }
}
