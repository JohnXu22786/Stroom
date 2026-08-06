part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageUiExt on _ChatPageState {
  /// Scrolls the chat list to the bottom-most message immediately when the
  /// keyboard opens, keeping the input area and latest message visible.
  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.jumpTo(
        _chatScrollController.position.maxScrollExtent,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_chatScrollController.hasClients) {
          _scrollToBottom();
        }
      });
    }
  }

  /// Restores the scroll position that was captured before the keyboard
  /// opened, so the user returns to where they were reading.
  void _restoreScrollPositionAfterKeyboard() {
    final savedPos = _lastScrollPositionBeforeKeyboard;
    _lastScrollPositionBeforeKeyboard = null;
    if (savedPos == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_chatScrollController.hasClients) {
        final maxScroll = _chatScrollController.position.maxScrollExtent;
        _chatScrollController.jumpTo(savedPos.clamp(0.0, maxScroll));
      }
    });
  }

  /// Handles chat list scroll events to track auto-scroll state.
  void _onChatScroll() {
    // While the initial positioning pass runs the list is hidden and all
    // scroll events are programmatic — skip auto-scroll/button bookkeeping
    // so the pass isn't disturbed.
    if (_pendingInitialScrollAdjustment) return;
    if (!_chatScrollController.hasClients) return;
    final maxScroll = _chatScrollController.position.maxScrollExtent;
    final currentScroll = _chatScrollController.position.pixels;
    final isAtBottom = (maxScroll - currentScroll) <= 80;

    if (isAtBottom) {
      // At bottom — user sees latest messages
      if (_showScrollToBottomButton || (!_autoScrollEnabled)) {
        setState(() {
          _showScrollToBottomButton = false;
          // Enable auto-scroll when user is at bottom (so new messages
          // automatically keep them at the bottom).
          if (_chatScrollController.hasClients &&
              _chatScrollController.position.maxScrollExtent > 0) {
            _autoScrollEnabled = true;
          }
        });
      }
    } else {
      // Scrolled up — disable auto-scroll and show button
      if (!_showScrollToBottomButton || _autoScrollEnabled) {
        setState(() {
          _autoScrollEnabled = false;
          _showScrollToBottomButton = true;
        });
      }
    }
  }

  /// Called when the user taps the scroll-to-bottom button.
  /// Enables auto-scroll and scrolls to the bottom.
  void _onScrollToBottomTap() {
    _scrollToBottom();
    setState(() {
      _autoScrollEnabled = true;
      _showScrollToBottomButton = false;
    });
  }

  /// Maximum number of frames the initial positioning pass may consume
  /// before giving up (defensive against pathological layouts).
  static const int _maxInitialAdjustSteps = 120;

  /// Consecutive frames the pass spends chasing a growing bottom
  /// (maxScrollExtent moving) before giving up and stepping up anyway —
  /// bounds how long a fast background stream can keep the list hidden.
  static const int _maxInitialAdjustChaseFrames = 30;

  /// Schedules the next frame of the initial positioning pass. At most one
  /// step runs per frame.
  void _scheduleInitialAdjustStep() {
    if (!mounted || _initialAdjustStepScheduled) return;
    _initialAdjustStepScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialAdjustStepScheduled = false;
      if (!mounted) return;
      if (_pendingInitialScrollAdjustment) _initialAdjustStep();
    });
  }

  /// One frame of the initial positioning pass, run while the list is
  /// hidden (offstage).
  ///
  /// A freshly loaded list starts at the top, so the last user message is
  /// usually not laid out yet. Each step jumps toward the bottom (where the
  /// latest messages live) until the last user message has a render box,
  /// then jumps to the resolved target — the top of that message, or the
  /// bottom when the remaining content fits in one viewport.
  ///
  /// Wrapped in try/catch: if a step ever throws, the pass must still
  /// terminate and reveal the list — a permanently hidden chat is worse
  /// than any wrong landing position.
  void _initialAdjustStep() {
    try {
      _initialAdjustStepInner();
    } catch (e, s) {
      debugPrint('[ChatPage] initial scroll adjustment failed: $e\n$s');
      _finishInitialScrollAdjustment();
    }
  }

  void _initialAdjustStepInner() {
    final c = _chatScrollController;
    if (!c.hasClients) {
      // List not attached yet — retry on the next frame.
      if (++_initialAdjustStepsTaken <= _maxInitialAdjustSteps) {
        _scheduleInitialAdjustStep();
      } else {
        _finishInitialScrollAdjustment();
      }
      return;
    }
    final pos = c.position;
    final maxExtent = pos.maxScrollExtent;
    if (maxExtent <= 0) {
      // Nothing scrollable — no positioning needed.
      _finishInitialScrollAdjustment();
      return;
    }

    final lastUserMsgId = _lastUserMessageId();
    if (lastUserMsgId == null) {
      // Conversation has no user message — settle at the true bottom.
      _settleAtBottomAndFinish();
      return;
    }
    // The target message must be in the chat controller (only the last
    // _pageSize messages are loaded into it). If it isn't, it can never be
    // laid out — settle at the true bottom.
    final targetInController =
        _controller?.messages.any((m) => m.id == lastUserMsgId) ?? false;
    if (!targetInController) {
      _settleAtBottomAndFinish();
      return;
    }
    final box = _messageKeys[lastUserMsgId]?.currentContext?.findRenderObject()
        as RenderBox?;
    if (box == null || !box.attached) {
      // Target message not laid out yet. First land at the bottom; while
      // maxScrollExtent is still moving (the sliver estimates it from the
      // built children, so jumping down grows it toward the true value —
      // or a background stream is growing the content), keep re-jumping
      // down. Once the bottom is stable, step UP one viewport per frame
      // until the target message is built. The chase cap makes the pass
      // give up on a fast-growing stream and step up anyway.
      if (++_initialAdjustStepsTaken > _maxInitialAdjustSteps) {
        _finishAtBottom();
        return;
      }
      final double next;
      if (pos.pixels < maxExtent - 1.0) {
        if (++_initialAdjustChaseFrames > _maxInitialAdjustChaseFrames) {
          _initialAdjustChaseFrames = 0;
          next = (pos.pixels - pos.viewportDimension).clamp(0.0, maxExtent);
          if (next >= pos.pixels - 1.0) {
            _finishAtBottom();
            return;
          }
        } else {
          next = maxExtent;
        }
      } else {
        _initialAdjustChaseFrames = 0;
        next = (pos.pixels - pos.viewportDimension).clamp(0.0, maxExtent);
        if (next >= pos.pixels - 1.0) {
          // No progress possible (degenerate viewport) — settle at the
          // bottom.
          _finishAtBottom();
          return;
        }
      }
      c.jumpTo(next);
      _scheduleInitialAdjustStep();
      return;
    }

    // Target message is laid out — resolve the exact scroll offset.
    final viewportBox =
        pos.context.notificationContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) {
      _finishAtBottom();
      return;
    }
    final targetTop = box.localToGlobal(Offset.zero).dy -
        viewportBox.localToGlobal(Offset.zero).dy +
        pos.pixels;
    // Measure the tail from the LAST message's render box (when it is
    // built, the geometry is exact — unlike maxScrollExtent, which the
    // sliver can only estimate while its last child is unbuilt).
    final lastMessageId = _controller?.messages.isNotEmpty == true
        ? _controller!.messages.last.id
        : null;
    final lastBox = lastMessageId == null
        ? null
        : _messageKeys[lastMessageId]?.currentContext?.findRenderObject()
            as RenderBox?;
    if (lastBox == null || !lastBox.attached) {
      // Tail not measurable (e.g. the last message is a streaming
      // placeholder without a key) — assume it does not fit and show the
      // last user message at the top. targetTop is measured from a built
      // box, so it is in-range by construction; the viewport clamps at
      // layout if the estimated maxScrollExtent ever disagrees.
      c.jumpTo(targetTop);
      _finishInitialScrollAdjustment();
      return;
    }
    final tailBottom = lastBox.localToGlobal(Offset.zero).dy -
        viewportBox.localToGlobal(Offset.zero).dy +
        pos.pixels +
        lastBox.size.height;
    final target = resolveInitialChatScrollTarget(
      lastUserMessageTop: targetTop,
      tailBottom: tailBottom,
      maxScrollExtent: maxExtent,
      viewportDimension: pos.viewportDimension,
    );
    c.jumpTo(target);
    _finishInitialScrollAdjustment();
  }

  /// Settles at the TRUE bottom: while maxScrollExtent is still moving
  /// (the sliver estimates it from the built children — jumping down grows
  /// it toward the true value), keep re-jumping down; once it stabilizes,
  /// finish the pass at the exact bottom. Used when no meaningful target
  /// can be positioned (no user message, or the target is older than the
  /// loaded controller window).
  void _settleAtBottomAndFinish() {
    final c = _chatScrollController;
    if (!c.hasClients) {
      _finishInitialScrollAdjustment();
      return;
    }
    final pos = c.position;
    if (pos.maxScrollExtent <= 0) {
      _finishInitialScrollAdjustment();
      return;
    }
    if (pos.pixels < pos.maxScrollExtent - 1.0) {
      if (++_initialAdjustStepsTaken > _maxInitialAdjustSteps) {
        _finishInitialScrollAdjustment();
        return;
      }
      c.jumpTo(pos.maxScrollExtent);
      _scheduleInitialAdjustStep();
      return;
    }
    _finishInitialScrollAdjustment();
  }

  /// Gives up the pass at the current bottom position and makes the list
  /// visible.
  void _finishAtBottom() {
    final c = _chatScrollController;
    if (c.hasClients && c.position.maxScrollExtent > 0) {
      c.jumpTo(c.position.maxScrollExtent);
    }
    _finishInitialScrollAdjustment();
  }

  /// Completes the initial positioning pass and makes the list visible.
  void _finishInitialScrollAdjustment() {
    _pendingInitialScrollAdjustment = false;
    _initialAdjustStepsTaken = 0;
    _initialAdjustChaseFrames = 0;
    _initialAdjustStepScheduled = false;
    // Re-run the normal scroll bookkeeping once against the settled
    // position: at the bottom it re-enables auto-scroll, elsewhere it
    // surfaces the scroll-to-bottom button.
    _onChatScroll();
    if (mounted) setState(() {});
  }

  /// ID of the last user message in [_history], or null when the
  /// conversation has no user messages.
  String? _lastUserMessageId() {
    for (var i = _history.length - 1; i >= 0; i--) {
      if (_history[i].role == 'user') return _history[i].id;
    }
    return null;
  }

  void _showJsonInspection(String msgId) {
    final chatMsg = _history.where((m) => m.id == msgId).firstOrNull;
    if (chatMsg == null) return;

    showJsonInspectionDialog(
      context: context,
      rawRequest: chatMsg.rawRequest,
      rawResponse: chatMsg.rawResponse,
    );
  }

  /// 上下文统计行：显示实际 context（API usage）、使用比例、累计花费。
  ///
  /// 与 opencode sidebar 一致的三项：
  /// - context：最近一次请求的实际输入 token 数（来自 API usage，不估算）
  /// - 使用比例：context / 模型上下文窗口（模型页"上下文长度"）
  /// - 花费：按模型价格累计的美元
  Widget _buildContextStatusLine(String convId) {
    final conv = ref
        .watch(conversationsProvider)
        .where((c) => c.id == convId)
        .firstOrNull;
    final modelContext =
        (_adapter.modelConfig?.typeConfig['context'] as num?)?.toInt();
    final inputTokens = conv?.lastInputTokens;
    final cost = conv?.totalCost ?? 0;
    final cs = Theme.of(context).colorScheme;

    final parts = <String>[];
    if (inputTokens != null) {
      parts.add('ctx ${formatTokenCount(inputTokens)}');
      if (modelContext != null && modelContext > 0) {
        final pct = (inputTokens / modelContext * 100);
        parts.add('${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%');
      }
    }
    parts.add('\$${formatCost(cost)}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Text(
        parts.join(' · '),
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 上下文压缩 banner：对话被压缩过时显示，点击可展开摘要预览。
  Widget _buildCompactionBanner(String convId) {
    final conv = ref
        .watch(conversationsProvider)
        .where((c) => c.id == convId)
        .firstOrNull;
    final summary = conv?.contextSummary;
    if (summary == null || summary.isEmpty) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.tertiaryContainer.withValues(alpha: 0.4),
      child: InkWell(
        onTap: () =>
            setState(() => _showCompactionSummary = !_showCompactionSummary),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.compress, size: 14, color: cs.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '上下文已压缩，旧对话已总结'
                      '${_showCompactionSummary ? '（点击收起）' : '（点击查看摘要）'}',
                      style: TextStyle(
                          fontSize: 12, color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
              if (_showCompactionSummary) ...[
                const SizedBox(height: 4),
                SelectableText(
                  summary,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onTertiaryContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetailDialog(BuildContext context, String messageId) {
    final chatMsg = _history.where((m) => m.id == messageId).firstOrNull;
    if (chatMsg == null) return;

    showDataDetailDialog(
      context: context,
      rawRequest: chatMsg.rawRequest,
      rawResponse: chatMsg.rawResponse,
    );
  }

  /// Shows a dialog with raw HTTP request/response data for the given message.
  void _showRawDataDialog(BuildContext context, String messageId) {
    _showErrorDetailDialog(context, messageId);
  }

  /// Formats an error value for display in the error bubble.
  /// If the value is a Map/List, converts to JSON string.
  /// If the value is already a String, returns it as-is (up to 200 chars).
  String _formatErrorValue(dynamic value) {
    if (value is String) {
      return value.length > 200 ? '${value.substring(0, 200)}...' : value;
    }
    if (value is Map || value is List) {
      try {
        final json = const JsonEncoder.withIndent('  ').convert(value);
        return json.length > 200 ? '${json.substring(0, 200)}...' : json;
      } catch (_) {
        return value.toString();
      }
    }
    return value?.toString() ?? '';
  }

  /// Top bar with title and search toggle.
  Widget _buildTopBar({required String title}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button when inside nested navigator and not first route
          if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                // Allow navigation back at any time, even during
                // streaming. The stream continues in the background,
                // messages are saved when streaming completes.
                Navigator.of(context).pop();
              },
            ),
          Expanded(
            child: GestureDetector(
              onLongPress: () =>
                  setState(() => _developerMode = !_developerMode),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (_developerMode)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'DEV',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── Search toggle ──
          IconButton(
            icon: Icon(
              _isSearching ? Icons.search_off : Icons.search,
              color:
                  _isSearching ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: '搜索消息',
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchMode = SearchMode.current;
            }),
          ),
        ],
      ),
    );
  }

  /// Banner shown when no chat API is configured.
  Widget _buildUnconfiguredBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '⚠️ 未配置聊天API — 前往设置',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: _navigateToProviderConfig,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '设置',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Scroll-to-bottom overlay button shown when the user scrolls up.
  Widget _buildScrollToBottomButton({required bool isDark}) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Material(
        elevation: 4,
        shape: const CircleBorder(),
        color: isDark ? Colors.grey[700] : Colors.grey[300],
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _onScrollToBottomTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_downward,
              size: 20,
              color: isDark ? Colors.grey[200] : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  /// Centered floating warning shown while editing a user message:
  /// re-sending the edit deletes this message and everything below it.
  /// Fades in on entry; dismissal (2s auto-hide or close button) is handled
  /// by [_ChatPageState] removing it from the Stack.
  Widget _buildEditWarningOverlay({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          color: isDark ? Colors.grey[850] : Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: isDark ? Colors.amber[300] : Colors.orange[700],
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '重新编辑发送后下面所有的消息将丢失',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[200] : Colors.grey[800],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('editWarningCloseButton'),
                  icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                  tooltip: '关闭',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(28, 28),
                    padding: const EdgeInsets.all(4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _hideEditWarning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Action buttons (copy / retry or edit / raw data / JSON / delete).
  Widget _buildMessageActionButtons({
    required BuildContext context,
    required TextMessage message,
    required bool isAi,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionButton(
          icon: Icons.copy,
          tooltip: '复制',
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: message.text,
              ),
            );
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(
              const SnackBar(
                content: Text('已复制'),
                duration: Duration(
                  seconds: 1,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 2),
        if (isAi)
          ActionButton(
            icon: Icons.refresh,
            tooltip: '重试',
            onPressed: () => _confirmRetryOrEdit(
              message.id,
            ),
          )
        else
          ActionButton(
            icon: Icons.edit_outlined,
            tooltip: '编辑',
            onPressed: () => _startEditMessage(
              message.id,
            ),
          ),
        // Raw data view button: only shown for AI messages when data exists.
        if (isAi &&
            _history.any(
              (m) =>
                  m.id == message.id &&
                  (m.rawRequest != null || m.rawResponse != null),
            )) ...[
          const SizedBox(width: 2),
          ActionButton(
            icon: Icons.data_exploration,
            tooltip: '查看数据详情',
            onPressed: () => _showRawDataDialog(
              context,
              message.id,
            ),
          ),
        ],
        if (_developerMode &&
            isAi &&
            _history.any(
              (m) =>
                  m.id == message.id &&
                  (m.rawRequest != null || m.rawResponse != null),
            )) ...[
          const SizedBox(width: 2),
          ActionButton(
            icon: Icons.code,
            tooltip: 'JSON 审查',
            onPressed: () => _showJsonInspection(
              message.id,
            ),
          ),
        ],
        const SizedBox(width: 2),
        ActionButton(
          icon: Icons.delete_outline,
          tooltip: '删除',
          onPressed: () => _confirmDeleteMessage(
            message.id,
          ),
        ),
      ],
    );
  }
}
